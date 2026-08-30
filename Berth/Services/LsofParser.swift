import Foundation

enum LsofParser {
    static func parse(_ output: String) -> [ListeningSocket] {
        var sockets: [ListeningSocket] = []
        var pid: Int32?
        var command: String?
        var uid: uid_t?
        var proto: String?
        var name: String?

        func flushFile() {
            defer {
                proto = nil
                name = nil
            }
            guard
                let pid,
                let command,
                let uid,
                let currentProto = proto,
                let currentName = name,
                let parsed = parseName(currentName)
            else {
                return
            }
            sockets.append(
                ListeningSocket(
                    pid: pid,
                    processName: command,
                    uid: uid,
                    protocolName: currentProto,
                    address: parsed.address,
                    port: parsed.port
                )
            )
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let flag = line.first else { continue }
            let value = String(line.dropFirst())
            switch flag {
            case "p":
                flushFile()
                pid = Int32(value)
                command = nil
                uid = nil
            case "c":
                command = value
            case "u":
                uid = uid_t(value)
            case "P":
                flushFile()
                proto = value
            case "n":
                name = value
            case "T":
                if value.hasPrefix("ST=") && !value.contains("LISTEN") {
                    proto = nil
                    name = nil
                }
            default:
                break
            }
        }
        flushFile()
        return sockets
    }

    static func parseName(_ name: String) -> (address: String, port: Int)? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("["), let closing = trimmed.firstIndex(of: "]") {
            let address = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closing])
            let rest = trimmed[trimmed.index(after: closing)...]
            guard rest.hasPrefix(":"), let port = Int(rest.dropFirst()) else { return nil }
            return (normalizeAddress(address), port)
        }

        if let colon = trimmed.lastIndex(of: ":") {
            let address = String(trimmed[..<colon])
            let portPart = String(trimmed[trimmed.index(after: colon)...])
            let portString = portPart.split(separator: "->").first.map(String.init) ?? portPart
            guard let port = Int(portString) else { return nil }
            return (normalizeAddress(address.isEmpty ? "*" : address), port)
        }
        return nil
    }

    static func normalizeAddress(_ address: String) -> String {
        switch address {
        case "0.0.0.0", "::", "*":
            return "*"
        case "::ffff:127.0.0.1":
            return "127.0.0.1"
        default:
            return address
        }
    }
}
