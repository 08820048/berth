import XCTest
@testable import Berth

final class KillPolicyTests: XCTestCase {
    func testSystemProcessesAreProtected() {
        XCTAssertEqual(
            ProtectedProcessPolicy.inspect(processName: "mDNSResponder", executablePath: "/usr/sbin/mDNSResponder", uid: 0),
            .systemProcess
        )
        XCTAssertEqual(
            ProtectedProcessPolicy.inspect(processName: "WindowServer", executablePath: "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/Resources/WindowServer", uid: 88),
            .systemProcess
        )
    }

    func testUserDevProcessIsNotProtected() {
        XCTAssertNil(
            ProtectedProcessPolicy.inspect(
                processName: "node",
                executablePath: "/Users/x/.nvm/versions/node/v20/bin/node",
                uid: 501
            )
        )
    }

    func testTerminatorKillsChildrenBeforeParentAndReleasesPort() {
        let fake = FakeSignaler(children: [10: [11]])
        let state = KillState()
        fake.onKill = { pid, _ in
            state.livePIDs.remove(pid)
            if state.livePIDs.isEmpty { state.portAlive = false }
            return 0
        }

        let terminator = ProcessTerminator(
            signaler: fake,
            scan: {
                guard state.portAlive else { return [] }
                return [Self.sampleEntry(port: 3000, pids: [10])]
            },
            sleepNanos: { _ in }
        )

        let outcome = terminator.stop(port: 3000, force: false, includeTree: true)
        XCTAssertEqual(outcome, .released)
        XCTAssertEqual(fake.killed, [11, 10])
    }

    func testProtectedEntryIsNotKilled() {
        let fake = FakeSignaler(children: [:])
        let terminator = ProcessTerminator(
            signaler: fake,
            scan: { [Self.protectedEntry(port: 53)] },
            sleepNanos: { _ in }
        )
        XCTAssertEqual(terminator.stop(port: 53, force: true, includeTree: false), .protected)
        XCTAssertTrue(fake.killed.isEmpty)
    }

    func testPrimaryStopRules() {
        let dev = Self.sampleEntry(port: 3000, pids: [1])
        XCTAssertTrue(dev.allowsPrimaryStop)
        let db = PortEntry(
            port: 5432,
            sockets: [ListeningSocket(pid: 2, processName: "postgres", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: 5432)],
            pids: [2],
            uid: 501,
            user: "xuyi",
            processName: "postgres",
            executablePath: nil,
            commandLine: "postgres",
            cwd: nil,
            projectName: "postgres",
            projectPath: nil,
            frameworkDisplayName: "PostgreSQL",
            group: .database,
            bindScope: .loopback,
            startedAt: nil,
            isProtected: false,
            protectionReasonKey: nil,
            usesProcessTreeByDefault: false
        )
        XCTAssertFalse(db.allowsPrimaryStop)
        XCTAssertTrue(db.isDatabaseLike)
        XCTAssertFalse(Self.protectedEntry(port: 5353).allowsPrimaryStop)
    }

    private static func sampleEntry(port: Int, pids: [Int32]) -> PortEntry {
        PortEntry(
            port: port,
            sockets: pids.map { ListeningSocket(pid: $0, processName: "node", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: port) },
            pids: pids,
            uid: 501,
            user: "xuyi",
            processName: "node",
            executablePath: nil,
            commandLine: "next-server",
            cwd: "/tmp/blog",
            projectName: "blog-web",
            projectPath: "/tmp/blog",
            frameworkDisplayName: "Next.js",
            group: .development,
            bindScope: .loopback,
            startedAt: nil,
            isProtected: false,
            protectionReasonKey: nil,
            usesProcessTreeByDefault: true
        )
    }

    private static func protectedEntry(port: Int) -> PortEntry {
        PortEntry(
            port: port,
            sockets: [ListeningSocket(pid: 1, processName: "mDNSResponder", uid: 0, protocolName: "TCP", address: "*", port: port)],
            pids: [1],
            uid: 0,
            user: "root",
            processName: "mDNSResponder",
            executablePath: "/usr/sbin/mDNSResponder",
            commandLine: "mDNSResponder",
            cwd: nil,
            projectName: "mDNSResponder",
            projectPath: nil,
            frameworkDisplayName: nil,
            group: .system,
            bindScope: .allInterfaces,
            startedAt: nil,
            isProtected: true,
            protectionReasonKey: "protection.systemProcess",
            usesProcessTreeByDefault: false
        )
    }
}

final class KillState: @unchecked Sendable {
    var livePIDs: Set<Int32> = [10, 11]
    var portAlive = true
}

final class FakeSignaler: ProcessSignaling, @unchecked Sendable {
    var children: [Int32: [Int32]]
    var killed: [Int32] = []
    var onKill: ((Int32, Int32) -> Int32)?

    init(children: [Int32: [Int32]]) {
        self.children = children
    }

    func send(signal: Int32, to pid: Int32) -> Int32 {
        killed.append(pid)
        return onKill?(pid, signal) ?? 0
    }

    func children(of pid: Int32) -> [Int32] {
        children[pid] ?? []
    }

    func isAlive(_ pid: Int32) -> Bool {
        true
    }
}
