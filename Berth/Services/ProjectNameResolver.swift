import Foundation

struct ProjectIdentity: Equatable, Sendable {
    let name: String
    let path: String?
}

enum ProjectNameResolver {
    static func resolve(cwd: String?, executablePath: String?, processName: String) -> ProjectIdentity {
        let start = cwd.flatMap { normalizedDirectory($0) }
            ?? executablePath.flatMap { normalizedDirectory(URL(fileURLWithPath: $0).deletingLastPathComponent().path) }

        guard let start, Self.isUserProjectPath(start) else {
            return ProjectIdentity(name: processName, path: nil)
        }

        if let gitRoot = walkUp(from: start, untilFileExists: ".git") {
            return ProjectIdentity(name: URL(fileURLWithPath: gitRoot).lastPathComponent, path: gitRoot)
        }

        if let manifestRoot = nearestManifestRoot(from: start) {
            if let manifestName = manifestPackageName(in: manifestRoot) {
                return ProjectIdentity(name: manifestName, path: manifestRoot)
            }
            return ProjectIdentity(name: URL(fileURLWithPath: manifestRoot).lastPathComponent, path: manifestRoot)
        }

        return ProjectIdentity(name: URL(fileURLWithPath: start).lastPathComponent, path: start)
    }

    static func nearestManifestRoot(from directory: String) -> String? {
        walkUp(from: directory) { dir in
            FileManager.default.fileExists(atPath: dir + "/package.json")
                || FileManager.default.fileExists(atPath: dir + "/pyproject.toml")
                || FileManager.default.fileExists(atPath: dir + "/Cargo.toml")
                || FileManager.default.fileExists(atPath: dir + "/go.mod")
        }
    }

    static func manifestPackageName(in root: String) -> String? {
        if let name = packageJSONName(at: root + "/package.json") { return name }
        if let name = tomlName(at: root + "/pyproject.toml") { return name }
        if let name = tomlName(at: root + "/Cargo.toml") { return name }
        if let name = goModuleName(at: root + "/go.mod") { return name }
        return nil
    }

    static func packageJSONName(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String
        else { return nil }
        let trimmed = name.split(separator: "/").last.map(String.init) ?? name
        return trimmed.isEmpty ? nil : trimmed
    }

    static func tomlName(at path: String) -> String? {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("name") else { continue }
            if let quoted = firstQuotedString(in: trimmed) {
                return quoted
            }
        }
        return nil
    }

    static func goModuleName(at path: String) -> String? {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("module ") {
                let module = trimmed.dropFirst("module ".count).trimmingCharacters(in: .whitespaces)
                return module.split(separator: "/").last.map(String.init)
            }
        }
        return nil
    }

    static func walkUp(from directory: String, untilFileExists fileName: String) -> String? {
        walkUp(from: directory) { dir in
            var isDirectory: ObjCBool = false
            let path = dir + "/" + fileName
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        }
    }

    static func walkUp(from directory: String, matches: (String) -> Bool) -> String? {
        var current = URL(fileURLWithPath: directory)
        let fm = FileManager.default
        while true {
            if matches(current.path) { return current.path }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            if !fm.fileExists(atPath: parent.path) { return nil }
            current = parent
        }
    }

    static func isUserProjectPath(_ path: String) -> Bool {
        let systemPrefixes = ["/usr", "/bin", "/sbin", "/System", "/Library", "/cores", "/private/var/db", "/etc"]
        return !systemPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func normalizedDirectory(_ path: String) -> String? {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? path : URL(fileURLWithPath: path).deletingLastPathComponent().path
        }
        return nil
    }

    private static func firstQuotedString(in line: String) -> String? {
        guard let first = line.firstIndex(of: "\"") ?? line.firstIndex(of: "'") else { return nil }
        let quote = line[first]
        let rest = line[line.index(after: first)...]
        guard let end = rest.firstIndex(of: quote) else { return nil }
        let value = String(rest[..<end])
        return value.isEmpty ? nil : value
    }
}
