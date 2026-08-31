import Foundation
import ServiceManagement

enum WatchedPorts {
    static let defaults: Set<Int> = [
        3000, 3001, 4000, 4173, 5000, 5173, 5432, 6379, 8000, 8080, 8888, 9000, 27017,
    ]
}

enum RefreshMode: String, CaseIterable, Identifiable {
    case live, standard, powerSaver

    var id: String { rawValue }

    var seconds: Double {
        switch self {
        case .live: 1
        case .standard: 3
        case .powerSaver: 10
        }
    }

    /// 将旧的逐秒取值就近归入档位（老用户无感迁移）。
    static func nearest(to interval: Double) -> RefreshMode {
        if interval <= 2 { return .live }
        if interval <= 6 { return .standard }
        return .powerSaver
    }
}

@MainActor
@Observable
final class AppSettings {
    static let defaultWatchedPorts: Set<Int> = WatchedPorts.defaults

    var language: AppLanguage {
        get { L10n.shared.language }
        set { L10n.shared.language = newValue }
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showMenuBarCount = "showMenuBarCount"
        static let showSystemPorts = "showSystemPorts"
        static let watchedPorts = "watchedPorts"
        static let ignoredPorts = "ignoredPorts"
        static let ignoreRules = "ignoreRules"
        static let pinnedProjects = "pinnedProjects"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
    }

    var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    /// 刷新档位（实时/标准/省电），实际存储仍为 refreshInterval 秒数。
    var refreshMode: RefreshMode {
        get { RefreshMode.nearest(to: refreshInterval) }
        set { refreshInterval = newValue.seconds }
    }

    var showMenuBarCount: Bool {
        didSet { UserDefaults.standard.set(showMenuBarCount, forKey: Keys.showMenuBarCount) }
    }

    var showSystemPorts: Bool {
        didSet { UserDefaults.standard.set(showSystemPorts, forKey: Keys.showSystemPorts) }
    }

    var watchedPorts: Set<Int> {
        didSet { UserDefaults.standard.set(Array(watchedPorts).sorted(), forKey: Keys.watchedPorts) }
    }

    var ignoreRules: [IgnoreRule] {
        didSet { persistIgnoreRules() }
    }

    var pinnedProjects: [String] {
        didSet { UserDefaults.standard.set(pinnedProjects, forKey: Keys.pinnedProjects) }
    }

    var hotKey: HotKeySpec {
        didSet {
            UserDefaults.standard.set(Int(hotKey.keyCode), forKey: Keys.hotKeyCode)
            UserDefaults.standard.set(Int(hotKey.carbonModifiers), forKey: Keys.hotKeyModifiers)
        }
    }

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    init() {
        let defaults = UserDefaults.standard
        let storedInterval = defaults.object(forKey: Keys.refreshInterval) as? Double ?? 3
        refreshInterval = min(max(storedInterval, 1), 15)
        showMenuBarCount = defaults.object(forKey: Keys.showMenuBarCount) as? Bool ?? true
        showSystemPorts = defaults.bool(forKey: Keys.showSystemPorts)
        if let stored = defaults.array(forKey: Keys.watchedPorts) as? [Int], !stored.isEmpty {
            watchedPorts = Set(stored)
        } else {
            watchedPorts = Self.defaultWatchedPorts
        }

        var rules: [IgnoreRule] = []
        if let data = defaults.data(forKey: Keys.ignoreRules),
           let decoded = try? JSONDecoder().decode([IgnoreRule].self, from: data) {
            rules = decoded
        }
        if let ignored = defaults.array(forKey: Keys.ignoredPorts) as? [Int] {
            for port in ignored where !rules.contains(.port(port)) {
                rules.append(.port(port))
            }
        }
        ignoreRules = rules
        pinnedProjects = defaults.stringArray(forKey: Keys.pinnedProjects) ?? []

        if defaults.object(forKey: Keys.hotKeyCode) != nil {
            hotKey = HotKeySpec(
                keyCode: UInt32(defaults.integer(forKey: Keys.hotKeyCode)),
                carbonModifiers: UInt32(defaults.integer(forKey: Keys.hotKeyModifiers))
            )
        } else {
            hotKey = .defaultShortcut
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func ignore(_ rule: IgnoreRule) {
        if !ignoreRules.contains(rule) {
            ignoreRules.append(rule)
        }
    }

    func unignore(_ rule: IgnoreRule) {
        ignoreRules.removeAll { $0 == rule }
    }

    func isPinned(_ key: String) -> Bool {
        pinnedProjects.contains(key)
    }

    func togglePin(_ key: String) {
        if let index = pinnedProjects.firstIndex(of: key) {
            pinnedProjects.remove(at: index)
        } else {
            pinnedProjects.append(key)
        }
    }

    private func persistIgnoreRules() {
        if let data = try? JSONEncoder().encode(ignoreRules) {
            UserDefaults.standard.set(data, forKey: Keys.ignoreRules)
        }
        let ports = ignoreRules.compactMap { rule -> Int? in
            if case .port(let value) = rule { return value }
            return nil
        }
        UserDefaults.standard.set(ports, forKey: Keys.ignoredPorts)
    }
}
