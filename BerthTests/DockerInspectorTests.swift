import XCTest
@testable import Berth

final class DockerInspectorTests: XCTestCase {
    func testParsesPublishedHostPorts() {
        let line = "abc123\tblog-db\tpostgres:16\t0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp"
        let bindings = DockerPortParser.parseDockerPSLine(line)
        XCTAssertEqual(Set(bindings.map(\.hostPort)), [5432])
        XCTAssertEqual(bindings.first?.name, "blog-db")
        XCTAssertEqual(bindings.first?.containerPort, 5432)
    }

    func testParsesDockerProxyCommand() {
        let command = "/usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 80"
        let parsed = DockerPortParser.parseProxyCommand(command)
        XCTAssertEqual(parsed?.host, 8080)
        XCTAssertEqual(parsed?.container, 80)
    }

    func testEngineDetection() {
        XCTAssertEqual(DockerPortParser.engineName(imagePath: "/Applications/OrbStack.app/x", processHint: nil), "OrbStack")
        XCTAssertEqual(DockerPortParser.engineName(imagePath: nil, processHint: "colima"), "Colima")
        XCTAssertEqual(DockerPortParser.engineName(imagePath: "/usr/bin/docker-proxy", processHint: nil), "Docker")
    }

    func testScanAttachesContainerName() {
        let sockets = [
            ListeningSocket(pid: 9, processName: "docker-proxy", uid: 0, protocolName: "TCP", address: "*", port: 5432),
        ]
        let engine = PortScanEngine(
            commandRunner: FakeCommandRunner(output: ""),
            processInfo: FakeProcessInfo(
                snapshot: ProcessSnapshot(
                    pid: 9,
                    executablePath: "/usr/bin/docker-proxy",
                    commandLine: "docker-proxy -host-port 5432 -container-port 5432",
                    cwd: nil,
                    startedAt: nil,
                    username: "root"
                )
            ),
            currentUID: 501,
            watchedPorts: [5432]
        )
        let containers = [
            5432: ContainerBinding(id: "abc123", name: "blog-db", image: "postgres:16", hostPort: 5432, containerPort: 5432, engine: "Docker"),
        ]
        let entry = engine.aggregate(sockets, containers: containers).first
        XCTAssertEqual(entry?.group, .container)
        XCTAssertEqual(entry?.containerName, "blog-db")
        XCTAssertEqual(entry?.containerID, "abc123")
        XCTAssertEqual(entry?.frameworkDisplayName, "PostgreSQL")
        XCTAssertEqual(entry?.projectName, "blog-db")
    }

    func testStopUsesContainerCLIInsteadOfKill() {
        let fake = FakeSignaler(children: [:])
        let docker = FakeContainerStopper()
        let state = KillState()
        docker.onStop = { _ in
            state.portAlive = false
            return true
        }
        let terminator = ProcessTerminator(
            signaler: fake,
            scan: {
                guard state.portAlive else { return [] }
                return [Self.containerEntry]
            },
            sleepNanos: { _ in },
            containers: docker
        )
        XCTAssertEqual(terminator.stop(port: 5432, force: false, includeTree: false), .released)
        XCTAssertEqual(docker.stopped, ["abc123"])
        XCTAssertTrue(fake.killed.isEmpty)
    }

    private static let containerEntry = PortEntry(
        port: 5432,
        sockets: [ListeningSocket(pid: 9, processName: "docker-proxy", uid: 0, protocolName: "TCP", address: "*", port: 5432)],
        pids: [9],
        uid: 0,
        user: "root",
        processName: "docker-proxy",
        executablePath: "/usr/bin/docker-proxy",
        commandLine: "docker-proxy",
        cwd: nil,
        projectName: "blog-db",
        projectPath: nil,
        frameworkDisplayName: "Docker",
        group: .container,
        bindScope: .allInterfaces,
        startedAt: nil,
        isProtected: false,
        protectionReasonKey: nil,
        usesProcessTreeByDefault: false,
        containerName: "blog-db",
        containerID: "abc123",
        containerEngine: "Docker"
    )
}

final class FakeContainerStopper: ContainerStopping, @unchecked Sendable {
    var stopped: [String] = []
    var onStop: ((String) -> Bool)?

    func stop(idOrName: String) -> Bool {
        stopped.append(idOrName)
        return onStop?(idOrName) ?? true
    }
}
