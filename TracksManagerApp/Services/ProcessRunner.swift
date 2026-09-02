import Foundation

struct ProcessResult: Sendable {
    let standardOutput: Data
    let standardError: Data
    let exitCode: Int32
}

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(URL)
    case failedToStart(String)
    case nonZeroExit(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let url):
            return "L'outil requis est introuvable : \(url.path)"
        case .failedToStart(let message):
            return "Impossible de démarrer l'outil : \(message)"
        case .nonZeroExit(let code, let stderr):
            if stderr.isEmpty {
                return "L'outil a échoué avec le code \(code)."
            }
            return "L'outil a échoué avec le code \(code) : \(stderr)"
        }
    }
}

struct ProcessRunner: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ProcessRunnerError.executableNotFound(executableURL)
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.currentDirectoryURL = currentDirectoryURL

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.failedToStart(error.localizedDescription)
        }

        let result = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { process in
                    let output = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: ProcessResult(
                        standardOutput: output,
                        standardError: errorOutput,
                        exitCode: process.terminationStatus
                    ))
                }
            }
        }, onCancel: {
            if process.isRunning {
                process.terminate()
            }
        })

        guard result.exitCode == 0 else {
            let stderrText = String(data: result.standardError, encoding: .utf8) ?? ""
            throw ProcessRunnerError.nonZeroExit(code: result.exitCode, stderr: stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result
    }
}
