import Foundation

protocol CommandRunning: Sendable {
    func run(executable: String, arguments: [String], timeout: TimeInterval) throws -> String
}

struct ShellCommandRunner: CommandRunning {
    func run(executable: String, arguments: [String], timeout: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            throw ScanError.timedOut
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0, data.isEmpty {
            let errText = String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw ScanError.lsofFailed(errText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
