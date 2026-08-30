import Foundation

struct FrameworkMatch: Equatable, Sendable {
    let displayName: String
    let group: PortGroupKind
    let usesProcessTreeByDefault: Bool
}

struct FrameworkRule: Sendable {
    let displayName: String
    let group: PortGroupKind
    let commandPatterns: [String]
    let processNames: [String]
    let usesProcessTreeByDefault: Bool
}

enum FrameworkCatalog {
    static let rules: [FrameworkRule] = [
        FrameworkRule(
            displayName: "Next.js",
            group: .development,
            commandPatterns: ["next-server", "next-swc", "next dev", "/node_modules/next/", " next "],
            processNames: ["next-server", "next"],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Vite",
            group: .development,
            commandPatterns: ["vite"],
            processNames: ["vite"],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Nuxt",
            group: .development,
            commandPatterns: ["nuxt"],
            processNames: ["nuxt"],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Nest",
            group: .development,
            commandPatterns: ["@nestjs", "nest start"],
            processNames: [],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Express",
            group: .development,
            commandPatterns: ["node_modules/express", "express"],
            processNames: [],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Django",
            group: .development,
            commandPatterns: ["django", "manage.py runserver"],
            processNames: [],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "FastAPI",
            group: .development,
            commandPatterns: ["fastapi"],
            processNames: [],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Python API",
            group: .development,
            commandPatterns: ["uvicorn", "gunicorn"],
            processNames: ["uvicorn", "gunicorn"],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Rails",
            group: .development,
            commandPatterns: ["rails server", "rails s", "puma", "unicorn"],
            processNames: ["puma", "unicorn"],
            usesProcessTreeByDefault: true
        ),
        FrameworkRule(
            displayName: "Spring",
            group: .development,
            commandPatterns: ["org.springframework", "spring-boot", "SpringApplication"],
            processNames: [],
            usesProcessTreeByDefault: false
        ),
        FrameworkRule(
            displayName: "PostgreSQL",
            group: .database,
            commandPatterns: ["postgres", "postgresql"],
            processNames: ["postgres", "postgresql"],
            usesProcessTreeByDefault: false
        ),
        FrameworkRule(
            displayName: "Redis",
            group: .database,
            commandPatterns: ["redis-server"],
            processNames: ["redis-server"],
            usesProcessTreeByDefault: false
        ),
        FrameworkRule(
            displayName: "MongoDB",
            group: .database,
            commandPatterns: ["mongod"],
            processNames: ["mongod"],
            usesProcessTreeByDefault: false
        ),
        FrameworkRule(
            displayName: "Docker",
            group: .container,
            commandPatterns: ["com.docker", "docker-proxy", "docker"],
            processNames: ["com.docker.backend", "docker-proxy", "docker"],
            usesProcessTreeByDefault: false
        ),
    ]

    static func match(processName: String, commandLine: String) -> FrameworkMatch? {
        let haystack = "\(processName) \(commandLine)".lowercased()
        let process = processName.lowercased()
        for rule in rules {
            if rule.processNames.contains(where: { $0.lowercased() == process }) {
                return FrameworkMatch(
                    displayName: rule.displayName,
                    group: rule.group,
                    usesProcessTreeByDefault: rule.usesProcessTreeByDefault
                )
            }
            if rule.commandPatterns.contains(where: { haystack.contains($0.lowercased()) }) {
                return FrameworkMatch(
                    displayName: rule.displayName,
                    group: rule.group,
                    usesProcessTreeByDefault: rule.usesProcessTreeByDefault
                )
            }
        }
        return nil
    }

    static func usesProcessTree(processName: String, commandLine: String) -> Bool {
        if let match = match(processName: processName, commandLine: commandLine) {
            return match.usesProcessTreeByDefault
        }
        let lowered = "\(processName) \(commandLine)".lowercased()
        return ["node", "python", "python3", "vite", "next"].contains(where: { lowered.contains($0) })
    }
}
