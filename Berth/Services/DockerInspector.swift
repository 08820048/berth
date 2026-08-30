import Foundation

struct ContainerBinding: Equatable, Sendable {
    let id: String
    let name: String
    let image: String
    let hostPort: Int
    let containerPort: Int?
    let engine: String
}

enum DockerPortParser {
    static func hostMappings(from portsField: String) -> [(host: Int, container: Int?)] {
        var result: [(Int, Int?)] = []
        let parts = portsField.split(separator: ",")
        for part in parts {
            let text = part.trimmingCharacters(in: .whitespaces)
            guard let arrow = text.range(of: "->") else { continue }
            let left = String(text[..<arrow.lowerBound])
            let right = String(text[arrow.upperBound...])
            guard let hostPort = portValue(from: left) else { continue }
            result.append((hostPort, portValue(from: right)))
        }
        return result
    }

    static func parseDockerPSLine(_ line: String) -> [ContainerBinding] {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 4 else { return [] }
        let id = fields[0]
        let name = fields[1]
        let image = fields[2]
        let ports = fields[3]
        let engine = engineName(imagePath: nil, processHint: nil)
        return hostMappings(from: ports).map { mapping in
            ContainerBinding(
                id: id,
                name: name,
                image: image,
                hostPort: mapping.host,
                containerPort: mapping.container,
                engine: engine
            )
        }
    }

    static func parseProxyCommand(_ commandLine: String) -> (host: Int, container: Int?)? {
        let tokens = commandLine.split(whereSeparator: \.isWhitespace).map(String.init)
        var host: Int?
        var container: Int?
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if token == "-host-port" || token == "--host-port", index + 1 < tokens.count {
                host = Int(tokens[index + 1])
                index += 2
                continue
            }
            if token == "-container-port" || token == "--container-port", index + 1 < tokens.count {
                container = Int(tokens[index + 1])
                index += 2
                continue
            }
            index += 1
        }
        guard let host else { return nil }
        return (host, container)
    }

    static func engineName(imagePath: String?, processHint: String?) -> String {
        let haystack = "\(imagePath ?? "") \(processHint ?? "")".lowercased()
        if haystack.contains("orbstack") { return "OrbStack" }
        if haystack.contains("colima") { return "Colima" }
        return "Docker"
    }

    private static func portValue(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let slash = trimmed.firstIndex(of: "/") {
            return portValue(from: String(trimmed[..<slash]))
        }
        if let colon = trimmed.lastIndex(of: ":") {
            return Int(trimmed[trimmed.index(after: colon)...])
        }
        return Int(trimmed)
    }
}

protocol ContainerStopping: Sendable {
    func stop(idOrName: String) -> Bool
}

struct DockerInspector: Sendable, ContainerStopping {
    var commandRunner: any CommandRunning
    var dockerPath: String

    init(commandRunner: any CommandRunning = ShellCommandRunner(), dockerPath: String? = nil) {
        self.commandRunner = commandRunner
        self.dockerPath = dockerPath ?? Self.resolvedDockerPath() ?? "/usr/local/bin/docker"
    }

    static func resolvedDockerPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/usr/bin/docker",
            NSHomeDirectory() + "/.orbstack/bin/docker",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func publishedPorts() -> [Int: ContainerBinding] {
        guard FileManager.default.isExecutableFile(atPath: dockerPath) else { return [:] }
        let output: String
        do {
            output = try commandRunner.run(
                executable: dockerPath,
                arguments: ["ps", "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}"],
                timeout: 1.5
            )
        } catch {
            return [:]
        }
        var map: [Int: ContainerBinding] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            for binding in DockerPortParser.parseDockerPSLine(String(line)) {
                map[binding.hostPort] = binding
            }
        }
        return map
    }

    func stop(idOrName: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: dockerPath) else { return false }
        do {
            _ = try commandRunner.run(
                executable: dockerPath,
                arguments: ["stop", "-t", "2", idOrName],
                timeout: 8
            )
            return true
        } catch {
            return false
        }
    }
}
