import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let defaultsKey = "appLanguage"
    var id: String { rawValue }

    static func saved(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    func localizationIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferredLanguages).first ?? "en"
    }

    var locale: Locale { Locale(identifier: localizationIdentifier()) }

    @MainActor var displayName: String {
        switch self {
        case .system: L10n.string("settings.language.system")
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }
}

@MainActor
@Observable
final class L10n {
    static let shared = L10n()
    private let defaults: UserDefaults

    // Reading a translation observes the language without recreating panel state.
    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: AppLanguage.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = .saved(in: defaults)
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        format(key, language: shared.language, arguments: args)
    }

    nonisolated static func format(_ key: String, language: AppLanguage, arguments args: [CVarArg] = []) -> String {
        let identifier = language.localizationIdentifier()
        let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        let bundle = Bundle.main.path(forResource: identifier, ofType: "lproj").flatMap(Bundle.init(path:)) ?? english
        let fallback = english.localizedString(forKey: key, value: key, table: nil)
        let format = bundle.localizedString(forKey: key, value: fallback, table: nil)
        if args.isEmpty { return format }
        if format.contains("%#@") {
            // Native stringsdict plural rules must follow the app language, not macOS.
            return String(format: format, locale: Locale(identifier: identifier), arguments: args)
        }
        // Ports and PIDs are identifiers: never add grouping separators.
        return String(format: format, arguments: args)
    }

    static func errorDescription(_ error: Error) -> String {
        if let error = error as? ScanError {
            return error.description(language: shared.language)
        }
        return error.localizedDescription
    }
}

enum DurationFormat {
    @MainActor
    static func short(from start: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return L10n.string("duration.seconds", seconds) }
        if seconds < 3600 { return L10n.string("duration.minutes", seconds / 60) }
        if seconds < 86_400 { return L10n.string("duration.hours", seconds / 3600) }
        return L10n.string("duration.days", seconds / 86_400)
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
    private let maxSamples = 512

    func percent(pid: Int32, totalNanos: UInt64, now: Date = .now) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        // 清理：若超限且当前 PID 不在缓存中，移除最老的样本
        if samples.count >= maxSamples, samples[pid] == nil {
            if let oldest = samples.min(by: { $0.value.0 < $1.value.0 }) {
                samples.removeValue(forKey: oldest.key)
            }
        }

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
