import Foundation
import os

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

        let group = DispatchGroup()
        group.enter()

        let resultBox = OSAllocatedUnfairLock<Result<String, Error>?>(initialState: nil)

        process.terminationHandler = { _ in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus != 0, data.isEmpty {
                let errText = String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)"
                resultBox.withLock {
                    $0 = .failure(ScanError.lsofFailed(errText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } else {
                resultBox.withLock {
                    $0 = .success(String(data: data, encoding: .utf8) ?? "")
                }
            }
            group.leave()
        }

        try process.run()

        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 0.5)
            throw ScanError.timedOut
        }

        return try resultBox.withLock { $0 }!.get()
    }
}
