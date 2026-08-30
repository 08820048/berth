import XCTest
@testable import Berth

final class PortScanEngineTests: XCTestCase {
    func testAggregatesIPv4AndIPv6IntoOneEntry() {
        let sockets = [
            ListeningSocket(pid: 22, processName: "node", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: 3000),
            ListeningSocket(pid: 22, processName: "node", uid: 501, protocolName: "TCP", address: "::1", port: 3000),
        ]
        let engine = PortScanEngine(
            commandRunner: FakeCommandRunner(output: ""),
            processInfo: FakeProcessInfo(
                snapshot: ProcessSnapshot(
                    pid: 22,
                    executablePath: "/usr/local/bin/node",
                    commandLine: "node node_modules/next/dist/server/next-server.js",
                    cwd: nil,
                    startedAt: nil,
                    username: "xuyi"
                )
            ),
            currentUID: 501,
            watchedPorts: [3000]
        )
        let entries = engine.aggregate(sockets)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].port, 3000)
        XCTAssertEqual(entries[0].pids, [22])
        XCTAssertEqual(entries[0].frameworkDisplayName, "Next.js")
        XCTAssertEqual(entries[0].group, .development)
        XCTAssertTrue(entries[0].usesProcessTreeByDefault)
    }

    func testWatchedUnknownProcessIsDevelopment() {
        let sockets = [
            ListeningSocket(pid: 8, processName: "Python", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: 3456),
        ]
        let engine = PortScanEngine(
            commandRunner: FakeCommandRunner(output: ""),
            processInfo: FakeProcessInfo(
                snapshot: ProcessSnapshot(
                    pid: 8,
                    executablePath: "/usr/bin/python3",
                    commandLine: "python3 -m http.server 3456",
                    cwd: nil,
                    startedAt: nil,
                    username: "xuyi"
                )
            ),
            currentUID: 501,
            watchedPorts: [3456]
        )
        let entry = engine.aggregate(sockets).first
        XCTAssertEqual(entry?.group, .development)
        XCTAssertEqual(entry?.isWatched, true)
        XCTAssertEqual(entry?.isConflict, true)
    }
}

struct FakeCommandRunner: CommandRunning {
    let output: String
    func run(executable: String, arguments: [String], timeout: TimeInterval) throws -> String {
        output
    }
}

struct FakeProcessInfo: ProcessInfoReading {
    var snapshot: ProcessSnapshot
    func snapshot(pid: Int32, uid: uid_t, fallbackName: String) -> ProcessSnapshot {
        snapshot
    }
    func children(of pid: Int32) -> [Int32] { [] }
}
