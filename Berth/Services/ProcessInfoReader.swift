import Darwin
import Foundation

struct ProcessSnapshot: Sendable, Equatable {
    let pid: Int32
    let executablePath: String?
    let commandLine: String
    let cwd: String?
    let startedAt: Date?
    let username: String
    var cpuPercent: Double? = nil
    var memoryBytes: UInt64? = nil
}

protocol ProcessInfoReading: Sendable {
    func snapshot(pid: Int32, uid: uid_t, fallbackName: String) -> ProcessSnapshot
    func children(of pid: Int32) -> [Int32]
}

struct DarwinProcessInfoReader: ProcessInfoReading {
    func snapshot(pid: Int32, uid: uid_t, fallbackName: String) -> ProcessSnapshot {
        let usage = Self.taskUsage(pid: pid)
        return ProcessSnapshot(
            pid: pid,
            executablePath: Self.executablePath(pid: pid),
            commandLine: Self.commandLine(pid: pid) ?? fallbackName,
            cwd: Self.cwd(pid: pid),
            startedAt: Self.startDate(pid: pid),
            username: Self.username(uid: uid),
            cpuPercent: usage.flatMap { CPUTimeCache.shared.percent(pid: pid, totalNanos: $0.cpuNanos) },
            memoryBytes: usage?.rss
        )
    }

    func children(of pid: Int32) -> [Int32] {
        let viaSysctl = sysctlChildren(of: pid)
        if !viaSysctl.isEmpty { return viaSysctl }
        return pgrepChildren(of: pid)
    }

    private func sysctlChildren(of pid: Int32) -> [Int32] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size: Int = 0
        if sysctl(&mib, 3, nil, &size, nil, 0) != 0 { return [] }
        let count = max(size / MemoryLayout<kinfo_proc>.stride, 0)
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        let result = procs.withUnsafeMutableBufferPointer { buffer in
            sysctl(&mib, 3, buffer.baseAddress, &size, nil, 0)
        }
        if result != 0 { return [] }
        let actual = size / MemoryLayout<kinfo_proc>.stride
        return procs.prefix(actual).compactMap { info in
            let child = info.kp_proc.p_pid
            let parent = info.kp_eproc.e_ppid
            return parent == pid && child > 0 ? child : nil
        }
    }

    private func pgrepChildren(of pid: Int32) -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(pid)]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return text.split(whereSeparator: \.isNewline).compactMap { Int32($0) }
    }

    static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    static func cwd(pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let needed = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        let got = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, needed)
        guard got == needed else { return nil }
        return tupleString(info.pvi_cdir.vip_path)
    }

    static func commandLine(pid: Int32) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0
        if sysctl(&mib, 3, nil, &size, nil, 0) != 0 || size < 4 {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        let ok = buffer.withUnsafeMutableBytes { raw in
            sysctl(&mib, 3, raw.baseAddress, &size, nil, 0)
        }
        guard ok == 0, buffer.count >= 4 else { return nil }

        let argc = buffer.prefix(4).withUnsafeBytes { $0.load(as: Int32.self) }
        var index = 4
        while index < buffer.count, buffer[index] != 0 { index += 1 }
        while index < buffer.count, buffer[index] == 0 { index += 1 }

        var args: [String] = []
        args.reserveCapacity(Int(max(argc, 0)))
        for _ in 0..<max(argc, 0) {
            var end = index
            while end < buffer.count, buffer[end] != 0 { end += 1 }
            if end > index, let chunk = String(bytes: buffer[index..<end], encoding: .utf8), !chunk.isEmpty {
                args.append(chunk)
            }
            index = end + 1
            if index >= buffer.count { break }
        }
        guard !args.isEmpty else { return nil }
        return args.joined(separator: " ")
    }

    static func startDate(pid: Int32) -> Date? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            sysctl(&mib, 4, pointer, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return nil }
        let tv = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
    }

    static func taskUsage(pid: Int32) -> (rss: UInt64, cpuNanos: UInt64)? {
        var info = proc_taskinfo()
        let needed = Int32(MemoryLayout<proc_taskinfo>.stride)
        let got = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, needed)
        guard got == needed else { return nil }
        return (info.pti_resident_size, info.pti_total_user &+ info.pti_total_system)
    }

    static func username(uid: uid_t) -> String {
        if let pw = getpwuid(uid) {
            return String(cString: pw.pointee.pw_name)
        }
        return String(uid)
    }

    private static func tupleString<T>(_ tuple: T) -> String {
        var copy = tuple
        return withUnsafeBytes(of: &copy) { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
            return String(cString: base)
        }
    }
}
