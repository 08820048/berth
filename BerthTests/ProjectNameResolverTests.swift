import XCTest
@testable import Berth

final class ProjectNameResolverTests: XCTestCase {
    func testGitRootNameWins() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/.git", withIntermediateDirectories: true)
        try "{\"name\":\"package-name\"}".write(toFile: root + "/package.json", atomically: true, encoding: .utf8)
        let nested = root + "/apps/web"
        try FileManager.default.createDirectory(atPath: nested, withIntermediateDirectories: true)

        let identity = ProjectNameResolver.resolve(cwd: nested, executablePath: nil, processName: "node")
        XCTAssertEqual(identity.name, URL(fileURLWithPath: root).lastPathComponent)
        XCTAssertEqual(identity.path, root)
    }

    func testPackageJSONNameWithoutGit() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try "{\"name\":\"@scope/blog-web\"}".write(toFile: root + "/package.json", atomically: true, encoding: .utf8)
        let identity = ProjectNameResolver.resolve(cwd: root, executablePath: nil, processName: "node")
        XCTAssertEqual(identity.name, "blog-web")
        XCTAssertEqual(identity.path, root)
    }

    func testGoModuleLastComponent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try "module github.com/acme/harbor-api\n".write(toFile: root + "/go.mod", atomically: true, encoding: .utf8)
        let identity = ProjectNameResolver.resolve(cwd: root, executablePath: nil, processName: "main")
        XCTAssertEqual(identity.name, "harbor-api")
    }

    private func makeTempDir() throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("berth-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}
