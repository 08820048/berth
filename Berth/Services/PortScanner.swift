import Foundation

struct PortScanEngine: Sendable {
    var commandRunner: any CommandRunning
    var processInfo: any ProcessInfoReading
    var lsofPath: String
    var currentUID: uid_t
    var watchedPorts: Set<Int>
    var docker: DockerInspector

    init(
        commandRunner: any CommandRunning = ShellCommandRunner(),
        processInfo: any ProcessInfoReading = DarwinProcessInfoReader(),
        lsofPath: String = "/usr/sbin/lsof",
        currentUID: uid_t = getuid(),
        watchedPorts: Set<Int> = WatchedPorts.defaults,
        docker: DockerInspector? = nil
    ) {
        self.commandRunner = commandRunner
        self.processInfo = processInfo
        self.lsofPath = lsofPath
        self.currentUID = currentUID
        self.watchedPorts = watchedPorts
        self.docker = docker ?? DockerInspector(commandRunner: commandRunner)
    }

    func scan() throws -> [PortEntry] {
        let output = try commandRunner.run(
            executable: lsofPath,
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcPnTu"],
            timeout: 2.0
        )
        let sockets = LsofParser.parse(output)
        return aggregate(sockets, containers: docker.publishedPorts())
    }

    func aggregate(_ sockets: [ListeningSocket], containers: [Int: ContainerBinding] = [:]) -> [PortEntry] {
        let grouped = Dictionary(grouping: sockets, by: \.port)
        return grouped.keys.sorted().compactMap { port in
            makeEntry(port: port, sockets: grouped[port] ?? [], containers: containers)
        }
    }

    func makeEntry(port: Int, sockets: [ListeningSocket], containers: [Int: ContainerBinding] = [:]) -> PortEntry? {
        guard !sockets.isEmpty else { return nil }
        let uniquePIDs = Array(Set(sockets.map(\.pid))).sorted()
        let primary = sockets.first(where: { $0.uid == currentUID }) ?? sockets[0]
        let snapshot = processInfo.snapshot(pid: primary.pid, uid: primary.uid, fallbackName: primary.processName)
        var identity = ProjectNameResolver.resolve(
            cwd: snapshot.cwd,
            executablePath: snapshot.executablePath,
            processName: primary.processName
        )
        var match = FrameworkCatalog.match(processName: primary.processName, commandLine: snapshot.commandLine)
        let protection = ProtectedProcessPolicy.inspect(
            processName: primary.processName,
            executablePath: snapshot.executablePath,
            uid: primary.uid
        )
        let binding = containers[port]
        let engine = DockerPortParser.engineName(imagePath: snapshot.executablePath, processHint: snapshot.commandLine)
        if let binding {
            identity = ProjectIdentity(name: binding.name, path: identity.path)
            if let imageMatch = FrameworkCatalog.match(processName: binding.image, commandLine: binding.image) {
                match = FrameworkMatch(displayName: imageMatch.displayName, group: .container, usesProcessTreeByDefault: false)
            } else {
                match = FrameworkMatch(displayName: binding.engine, group: .container, usesProcessTreeByDefault: false)
            }
        } else if match?.group == .container {
            match = FrameworkMatch(displayName: engine, group: .container, usesProcessTreeByDefault: false)
        }

        let group = classify(
            port: port,
            match: match,
            protection: protection,
            cwd: snapshot.cwd,
            projectPath: identity.path,
            isContainer: binding != nil || match?.group == .container
        )
        let bindScope = bindScope(for: sockets)
        let treeDefault = FrameworkCatalog.usesProcessTree(
            processName: primary.processName,
            commandLine: snapshot.commandLine
        )
        let watched = watchedPorts.contains(port)
        let conflict = ConflictPolicy.isConflict(
            watched: watched,
            framework: match,
            group: group,
            projectPath: identity.path,
            cwd: snapshot.cwd
        )

        return PortEntry(
            port: port,
            sockets: sockets.uniqued(),
            pids: uniquePIDs,
            uid: primary.uid,
            user: snapshot.username,
            processName: primary.processName,
            executablePath: snapshot.executablePath,
            commandLine: snapshot.commandLine,
            cwd: snapshot.cwd,
            projectName: identity.name,
            projectPath: identity.path,
            frameworkDisplayName: match?.displayName,
            group: group,
            bindScope: bindScope,
            startedAt: snapshot.startedAt,
            isProtected: protection != nil,
            protectionReasonKey: protection.map { "protection.\($0.rawValue)" },
            usesProcessTreeByDefault: treeDefault && group == .development,
            cpuPercent: snapshot.cpuPercent,
            memoryBytes: snapshot.memoryBytes,
            containerName: binding?.name,
            containerID: binding?.id,
            containerEngine: binding?.engine ?? (group == .container ? engine : nil),
            isWatched: watched,
            isConflict: conflict
        )
    }

    func classify(
        port: Int,
        match: FrameworkMatch?,
        protection: ProtectionReason?,
        cwd: String?,
        projectPath: String?,
        isContainer: Bool
    ) -> PortGroupKind {
        if protection != nil {
            return .system
        }
        if isContainer || match?.group == .container {
            return .container
        }
        if let match {
            return match.group
        }
        if watchedPorts.contains(port) {
            return .development
        }
        if projectPath != nil || cwd.flatMap({ ProjectNameResolver.nearestManifestRoot(from: $0) }) != nil {
            return .development
        }
        return .other
    }

    func bindScope(for sockets: [ListeningSocket]) -> BindScope {
        let addresses = Set(sockets.map(\.address))
        if addresses.contains("*") || addresses.contains("0.0.0.0") || addresses.contains("::") {
            return .allInterfaces
        }
        if addresses.allSatisfy({ PortEntry.isLoopback($0) }) {
            return .loopback
        }
        return .specific
    }
}

enum ConflictPolicy {
    static func isConflict(
        watched: Bool,
        framework: FrameworkMatch?,
        group: PortGroupKind,
        projectPath: String?,
        cwd: String?
    ) -> Bool {
        guard watched, group != .system, group != .database, group != .container else { return false }
        if framework != nil { return false }
        if let projectPath, ProjectNameResolver.isUserProjectPath(projectPath) { return false }
        if let cwd, ProjectNameResolver.isUserProjectPath(cwd),
           ProjectNameResolver.nearestManifestRoot(from: cwd) != nil {
            return false
        }
        return true
    }
}

private extension Array where Element == ListeningSocket {
    func uniqued() -> [ListeningSocket] {
        var seen = Set<ListeningSocket>()
        return filter { seen.insert($0).inserted }
    }
}
