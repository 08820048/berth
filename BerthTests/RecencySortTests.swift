import XCTest
@testable import Berth

final class RecencySortTests: XCTestCase {
    func testNewerStartComesFirst() {
        let older = entry(port: 3000, started: Date(timeIntervalSince1970: 1_000))
        let newer = entry(port: 5173, started: Date(timeIntervalSince1970: 2_000))
        let missing = entry(port: 4000, started: nil)
        let sorted = [older, missing, newer].sorted(by: PortEntry.recencyDescending)
        XCTAssertEqual(sorted.map(\.port), [5173, 3000, 4000])
    }

    private func entry(port: Int, started: Date?) -> PortEntry {
        PortEntry(
            port: port,
            sockets: [ListeningSocket(pid: 1, processName: "node", uid: 501, protocolName: "TCP", address: "127.0.0.1", port: port)],
            pids: [1],
            uid: 501,
            user: "xuyi",
            processName: "node",
            executablePath: nil,
            commandLine: "node",
            cwd: nil,
            projectName: "app",
            projectPath: nil,
            frameworkDisplayName: "Node",
            group: .development,
            bindScope: .loopback,
            startedAt: started,
            isProtected: false,
            protectionReasonKey: nil,
            usesProcessTreeByDefault: true
        )
    }
}
