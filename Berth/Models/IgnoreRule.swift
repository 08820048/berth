import Foundation

enum IgnoreRule: Equatable, Hashable, Codable, Sendable, Identifiable {
    case port(Int)
    case process(String)
    case path(String)

    var id: String {
        switch self {
        case .port(let value): return "port:\(value)"
        case .process(let value): return "process:\(value.lowercased())"
        case .path(let value): return "path:\(value)"
        }
    }

    func matches(_ entry: PortEntry) -> Bool {
        switch self {
        case .port(let value):
            return entry.port == value
        case .process(let value):
            return entry.processName.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        case .path(let value):
            let prefix = (value as NSString).expandingTildeInPath
            return [entry.cwd, entry.projectPath].compactMap { $0 }.contains { path in
                path == prefix || path.hasPrefix(prefix.hasSuffix("/") ? prefix : prefix + "/")
            }
        }
    }
}

enum IgnoreMatcher {
    static func isIgnored(_ entry: PortEntry, rules: [IgnoreRule]) -> Bool {
        rules.contains { $0.matches(entry) }
    }
}
