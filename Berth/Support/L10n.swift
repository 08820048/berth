import Foundation

enum L10n {
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
        if args.isEmpty { return format }
        return String(format: format, locale: .current, arguments: args)
    }
}

enum DurationFormat {
    static func short(from start: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86_400)d"
    }
}

enum MemoryFormat {
    static func short(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024)K" }
        if bytes < 1024 * 1024 * 1024 { return "\(bytes / (1024 * 1024))M" }
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1fG", gb)
    }
}

final class CPUTimeCache: @unchecked Sendable {
    static let shared = CPUTimeCache()
    private let lock = NSLock()
    private var samples: [Int32: (Date, UInt64)] = [:]

    func percent(pid: Int32, totalNanos: UInt64, now: Date = .now) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        if let previous = samples[pid] {
            let elapsed = now.timeIntervalSince(previous.0)
            samples[pid] = (now, totalNanos)
            guard elapsed > 0.15, totalNanos >= previous.1 else { return nil }
            let cpuSeconds = Double(totalNanos - previous.1) / 1_000_000_000
            return max(0, (cpuSeconds / elapsed) * 100)
        }
        samples[pid] = (now, totalNanos)
        return nil
    }
}
