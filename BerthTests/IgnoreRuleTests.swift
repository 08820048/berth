import XCTest
@testable import Berth

final class IgnoreRuleTests: XCTestCase {
    func testPortProcessAndPathMatching() {
        let entry = PortEntry(
            port: 3000,
            sockets: [ListeningSocket(pid: 1, processName: "node", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: 3000)],
            pids: [1],
            uid: 501,
            user: "xuyi",
            processName: "node",
            executablePath: nil,
            commandLine: "next-server",
            cwd: "/Users/xuyi/code/blog-web",
            projectName: "blog-web",
            projectPath: "/Users/xuyi/code/blog-web",
            frameworkDisplayName: "Next.js",
            group: .development,
            bindScope: .loopback,
            startedAt: nil,
            isProtected: false,
            protectionReasonKey: nil,
            usesProcessTreeByDefault: true
        )
        XCTAssertTrue(IgnoreRule.port(3000).matches(entry))
        XCTAssertFalse(IgnoreRule.port(3001).matches(entry))
        XCTAssertTrue(IgnoreRule.process("NODE").matches(entry))
        XCTAssertTrue(IgnoreRule.path("/Users/xuyi/code/blog-web").matches(entry))
        XCTAssertTrue(IgnoreRule.path("/Users/xuyi/code").matches(entry))
        XCTAssertFalse(IgnoreRule.path("/Users/xuyi/other").matches(entry))
        XCTAssertTrue(IgnoreMatcher.isIgnored(entry, rules: [.process("node")]))
        XCTAssertFalse(IgnoreMatcher.isIgnored(entry, rules: [.port(5173)]))
    }
}

final class ConflictPolicyTests: XCTestCase {
    func testWatchedUnknownProcessIsConflict() {
        XCTAssertTrue(
            ConflictPolicy.isConflict(
                watched: true,
                framework: nil,
                group: .development,
                projectPath: nil,
                cwd: nil
            )
        )
    }

    func testKnownFrameworkIsNotConflict() {
        XCTAssertFalse(
            ConflictPolicy.isConflict(
                watched: true,
                framework: FrameworkMatch(displayName: "Next.js", group: .development, usesProcessTreeByDefault: true),
                group: .development,
                projectPath: nil,
                cwd: nil
            )
        )
    }

    func testDatabaseIsNotConflict() {
        XCTAssertFalse(
            ConflictPolicy.isConflict(
                watched: true,
                framework: nil,
                group: .database,
                projectPath: nil,
                cwd: nil
            )
        )
    }
}
