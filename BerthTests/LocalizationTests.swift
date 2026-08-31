import Observation
import XCTest
@testable import Berth

final class LocalizationTests: XCTestCase {
    func testBothLanguagesAndIdentifierFormatting() {
        for (language, title) in [(AppLanguage.english, "Settings"), (.simplifiedChinese, "设置")] {
            XCTAssertEqual(L10n.format("settings.title", language: language), title)
            XCTAssertEqual(
                L10n.format("confirm.detail", language: language, arguments: [14023, 31411]),
                "localhost:14023 · pid 31411"
            )
            XCTAssertFalse(L10n.format("a11y.portEmpty", language: language, arguments: [3000]).contains("a11y."))
        }
        XCTAssertEqual(L10n.format("settings.refreshUnit", language: .english, arguments: [1]), "1 second")
        XCTAssertEqual(L10n.format("settings.refreshUnit", language: .english, arguments: [3]), "3 seconds")
        XCTAssertEqual(L10n.format("settings.refreshUnit", language: .simplifiedChinese, arguments: [1]), "1 秒")
        XCTAssertEqual(L10n.format("menu.count", language: .english, arguments: [1]), "1 development port")
        XCTAssertEqual(L10n.format("stop.projectReleased", language: .english, arguments: [2, "demo"]), "Released 2 ports in demo")
        XCTAssertEqual(L10n.format("stop.projectReleased", language: .simplifiedChinese, arguments: [2, "demo"]), "已释放 2 个端口（demo）")
    }

    func testSystemMatchingAndUnknownKeyFallback() {
        XCTAssertEqual(AppLanguage.system.localizationIdentifier(preferredLanguages: ["zh-Hans-CN"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.localizationIdentifier(preferredLanguages: ["en-GB"]), "en")
        XCTAssertEqual(AppLanguage.system.localizationIdentifier(preferredLanguages: ["fr-FR"]), "en")
        XCTAssertEqual(AppLanguage.english.localizationIdentifier(preferredLanguages: ["zh-Hans"]), "en")
        XCTAssertEqual(L10n.format("missing.test.key", language: .simplifiedChinese), "missing.test.key")
    }

    @MainActor
    func testLanguagePersistsAndInvalidPreferenceFallsBack() throws {
        let suite = "Berth.LocalizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let localizer = L10n(defaults: defaults)
        XCTAssertEqual(localizer.language, .system)
        localizer.language = .english
        XCTAssertEqual(L10n(defaults: defaults).language, .english)
        localizer.language = .simplifiedChinese
        XCTAssertEqual(L10n(defaults: defaults).language, .simplifiedChinese)
        defaults.set("not-supported", forKey: AppLanguage.defaultsKey)
        XCTAssertEqual(L10n(defaults: defaults).language, .system)
    }

    @MainActor
    func testExistingTranslationReadersAreInvalidated() {
        let stored = UserDefaults.standard.object(forKey: AppLanguage.defaultsKey)
        let previous = L10n.shared.language
        defer {
            L10n.shared.language = previous
            if let stored { UserDefaults.standard.set(stored, forKey: AppLanguage.defaultsKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.defaultsKey) }
        }
        L10n.shared.language = .english
        let changed = expectation(description: "A view that reads translations observes language changes")
        withObservationTracking {
            XCTAssertEqual(L10n.string("row.release"), "Release")
        } onChange: {
            changed.fulfill()
        }
        AppSettings().language = .simplifiedChinese
        XCTAssertEqual(L10n.string("row.release"), "释放")
        XCTAssertEqual(L10n.errorDescription(ScanError.timedOut), "端口扫描超时，请重试。")
        let now = Date(timeIntervalSince1970: 100_000)
        XCTAssertEqual(DurationFormat.short(from: now.addingTimeInterval(-3600), now: now), "1时")
        L10n.shared.language = .english
        XCTAssertEqual(L10n.string("row.release"), "Release")
        XCTAssertEqual(DurationFormat.short(from: now.addingTimeInterval(-3600), now: now), "1h")
        wait(for: [changed], timeout: 1)
    }

    func testTranslationTablesHaveMatchingKeysAndPlaceholders() throws {
        func table(_ language: String) throws -> [String: String] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let english = try table("en")
        let chinese = try table("zh-Hans")
        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        let pattern = try NSRegularExpression(pattern: "%[@d]")
        func placeholders(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { (text as NSString).substring(with: $0.range) }
        }
        for (key, value) in english {
            let translated = try XCTUnwrap(chinese[key])
            XCTAssertFalse(translated.isEmpty, key)
            XCTAssertEqual(placeholders(value), placeholders(translated), key)
        }
    }

}
