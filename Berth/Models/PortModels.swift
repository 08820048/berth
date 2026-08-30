import Foundation

enum PortGroupKind: String, Sendable, CaseIterable, Identifiable {
    case development
    case database
    case container
    case system
    case other

    var id: String { rawValue }
}

enum BindScope: String, Sendable {
    case loopback
    case allInterfaces
    case specific
}

struct ListeningSocket: Equatable, Sendable, Hashable {
    let pid: Int32
    let processName: String
    let uid: uid_t
    let protocolName: String
    let address: String
    let port: Int
}

struct PortEntry: Identifiable, Sendable, Equatable {
    var id: String { "\(port)-\(pids.sorted().map(String.init).joined(separator: ","))" }

    let port: Int
    let sockets: [ListeningSocket]
    let pids: [Int32]
    let uid: uid_t
    let user: String
    let processName: String
    let executablePath: String?
    let commandLine: String
    let cwd: String?
    let projectName: String
    let projectPath: String?
    let frameworkDisplayName: String?
    let group: PortGroupKind
    let bindScope: BindScope
    let startedAt: Date?
    let isProtected: Bool
    let protectionReasonKey: String?
    let usesProcessTreeByDefault: Bool
    var cpuPercent: Double? = nil
    var memoryBytes: UInt64? = nil
    var containerName: String? = nil
    var containerID: String? = nil
    var containerEngine: String? = nil
    var isWatched: Bool = false
    var isConflict: Bool = false

    var projectKey: String { projectPath ?? projectName }

    var displayFramework: String {
        frameworkDisplayName ?? processName
    }

    var bindLabel: String {
        let addresses = Set(sockets.map(\.address))
        if addresses.contains("*") || addresses.contains("0.0.0.0") || addresses.contains("::") {
            return "*"
        }
        if addresses.count == 1, let only = addresses.first {
            return Self.compactAddress(only)
        }
        if addresses.allSatisfy({ Self.isLoopback($0) }) {
            return "127.0.0.1"
        }
        return addresses.sorted().map(Self.compactAddress).joined(separator: ", ")
    }

    var title: String {
        if let containerName {
            let engine = containerEngine ?? frameworkDisplayName ?? "Docker"
            return "\(engine) · \(containerName)"
        }
        return "\(displayFramework) · \(projectName)"
    }

    var canOpenInBrowser: Bool {
        group == .development || group == .other
    }

    var allowsPrimaryStop: Bool {
        !isProtected && (group == .development || group == .other)
    }

    var isDatabaseLike: Bool {
        group == .database || group == .container
    }

    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }

    var primaryPID: Int32 { pids.first ?? 0 }

    static func recencyDescending(_ lhs: PortEntry, _ rhs: PortEntry) -> Bool {
        switch (lhs.startedAt, rhs.startedAt) {
        case let (left?, right?):
            if left != right { return left > right }
            return lhs.port < rhs.port
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.port < rhs.port
        }
    }

    static func newestStart(_ entries: [PortEntry]) -> Date {
        entries.compactMap(\.startedAt).max() ?? .distantPast
    }

    static func isLoopback(_ address: String) -> Bool {
        address == "127.0.0.1" || address == "::1" || address == "localhost"
    }

    static func compactAddress(_ address: String) -> String {
        switch address {
        case "::1": return "127.0.0.1"
        case "::", "0.0.0.0": return "*"
        default: return address
        }
    }
}

enum ScanError: Error, Equatable, LocalizedError {
    case lsofFailed(String)
    case timedOut
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .lsofFailed(let message):
            return message
        case .timedOut:
            return "Scan timed out"
        case .emptyOutput:
            return "lsof returned no data"
        }
    }
}

struct StopPrompt: Equatable, Identifiable, Sendable {
    let entry: PortEntry
    let force: Bool

    var id: String { "\(entry.id)-\(force)" }
}

enum StopPhase: Equatable, Sendable {
    case confirm
    case working
    case finished(StopOutcome)
}

enum StopOutcome: Equatable, Sendable {
    case released
    case alreadyGone
    case stillOccupied
    case protected
    case permissionDenied
    case processExited
    case failed(String)
}

struct BannerMessage: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case success
        case error
        case warning
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let port: Int?
}

enum QuickFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case development
    case database
    case exposed

    var id: String { rawValue }
}
