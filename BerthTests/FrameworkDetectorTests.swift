import XCTest
@testable import Berth

final class FrameworkDetectorTests: XCTestCase {
    func testDetectsNextFromCommandLine() {
        let match = FrameworkCatalog.match(
            processName: "node",
            commandLine: "node /Users/x/blog/node_modules/next/dist/server/next-server.js"
        )
        XCTAssertEqual(match?.displayName, "Next.js")
        XCTAssertEqual(match?.group, .development)
        XCTAssertEqual(match?.usesProcessTreeByDefault, true)
    }

    func testDetectsVitePostgresAndDocker() {
        XCTAssertEqual(
            FrameworkCatalog.match(processName: "node", commandLine: "./node_modules/.bin/vite")?.displayName,
            "Vite"
        )
        XCTAssertEqual(
            FrameworkCatalog.match(processName: "postgres", commandLine: "/usr/local/bin/postgres")?.displayName,
            "PostgreSQL"
        )
        XCTAssertEqual(
            FrameworkCatalog.match(processName: "docker-proxy", commandLine: "com.docker.backend")?.group,
            .container
        )
    }

    func testUvicornMapsToPythonAPI() {
        let match = FrameworkCatalog.match(processName: "python3", commandLine: "uvicorn app.main:app --port 8000")
        XCTAssertEqual(match?.displayName, "Python API")
    }
}
