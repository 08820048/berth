import Darwin
import Foundation

protocol ProcessSignaling: Sendable {
    func send(signal: Int32, to pid: Int32) -> Int32
    func children(of pid: Int32) -> [Int32]
    func isAlive(_ pid: Int32) -> Bool
}

struct DarwinProcessSignaler: ProcessSignaling {
    let processInfo: any ProcessInfoReading

    init(processInfo: any ProcessInfoReading = DarwinProcessInfoReader()) {
        self.processInfo = processInfo
    }

    func send(signal: Int32, to pid: Int32) -> Int32 {
        kill(pid, signal)
    }

    func children(of pid: Int32) -> [Int32] {
        processInfo.children(of: pid)
    }

    func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}

struct ProcessTerminator: Sendable {
    var signaler: any ProcessSignaling
    var scan: @Sendable () throws -> [PortEntry]
    var sleepNanos: @Sendable (UInt64) -> Void
    var containers: (any ContainerStopping)?

    init(
        signaler: any ProcessSignaling = DarwinProcessSignaler(),
        scan: @escaping @Sendable () throws -> [PortEntry],
        sleepNanos: @escaping @Sendable (UInt64) -> Void = { nanos in
            Thread.sleep(forTimeInterval: Double(nanos) / 1_000_000_000)
        },
        containers: (any ContainerStopping)? = nil
    ) {
        self.signaler = signaler
        self.scan = scan
        self.sleepNanos = sleepNanos
        self.containers = containers
    }

    func stop(
        port: Int,
        force: Bool,
        includeTree: Bool
    ) -> StopOutcome {
        let before: [PortEntry]
        do {
            before = try scan()
        } catch {
            return .failed(error.localizedDescription)
        }
        guard let entry = before.first(where: { $0.port == port }) else {
            return .alreadyGone
        }
        if entry.isProtected {
            return .protected
        }

        if let containers, let target = entry.containerID ?? entry.containerName {
            if containers.stop(idOrName: target) {
                waitForRelease(port: port, timeout: force ? 0.8 : 2.0)
                if let after = try? scan(), !after.contains(where: { $0.port == port }) {
                    return .released
                }
            }
        }

        // 二次校验：防止窗口期内端口被其他进程抢占（尤其是系统进程替换）
        do {
            let recheck = try scan()
            guard let rechecked = recheck.first(where: { $0.port == port }) else {
                return .alreadyGone
            }
            guard Set(rechecked.pids) == Set(entry.pids) else {
                return .alreadyGone
            }
        } catch {
            return .failed(error.localizedDescription)
        }

        var targets = Set(entry.pids)
        if includeTree {
            for pid in entry.pids {
                descendants(of: pid).forEach { targets.insert($0) }
            }
        }

        let ordered = killOrder(Array(targets))
        let signal: Int32 = force ? SIGKILL : SIGTERM
        var sawPermissionDenied = false
        var sawMissing = false

        for pid in ordered {
            let result = signaler.send(signal: signal, to: pid)
            if result != 0 {
                if errno == EPERM {
                    sawPermissionDenied = true
                } else if errno == ESRCH {
                    sawMissing = true
                }
            }
        }

        waitForRelease(port: port, timeout: force ? 0.4 : 2.0, pids: ordered)

        do {
            let after = try scan()
            if after.contains(where: { $0.port == port }) {
                if sawPermissionDenied { return .permissionDenied }
                return .stillOccupied
            }
            if sawPermissionDenied && !sawMissing {
                return .permissionDenied
            }
            return .released
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func descendants(of pid: Int32) -> [Int32] {
        var found: [Int32] = []
        var queue = signaler.children(of: pid)
        var seen = Set<Int32>([pid])
        while let next = queue.first {
            queue.removeFirst()
            if seen.contains(next) { continue }
            seen.insert(next)
            found.append(next)
            queue.append(contentsOf: signaler.children(of: next))
        }
        return found
    }

    func killOrder(_ pids: [Int32]) -> [Int32] {
        var remaining = Set(pids)
        var ordered: [Int32] = []
        while !remaining.isEmpty {
            let ready = remaining.filter { pid in
                signaler.children(of: pid).filter { remaining.contains($0) }.isEmpty
            }
            if ready.isEmpty {
                ordered.append(contentsOf: remaining.sorted().reversed())
                break
            }
            let batch = ready.sorted().reversed()
            ordered.append(contentsOf: batch)
            batch.forEach { remaining.remove($0) }
        }
        return ordered
    }

    private func waitForRelease(port: Int, timeout: TimeInterval, pids: [Int32] = []) {
        let start = Date()
        sleepNanos(300_000_000)
        while Date().timeIntervalSince(start) < timeout {
            if pids.isEmpty {
                if let current = try? scan(), !current.contains(where: { $0.port == port }) {
                    return
                }
            } else {
                if !pids.contains(where: signaler.isAlive) {
                    return
                }
            }
            sleepNanos(200_000_000)
        }
    }
}
