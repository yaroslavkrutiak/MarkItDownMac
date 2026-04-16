import Foundation

struct ShellResult {
    let output: String
    let error: String
    let exitCode: Int32
}

enum ShellError: LocalizedError {
    case timeout
    case executionFailed(stderr: String, exitCode: Int32)
    case commandNotFound(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Command timed out."
        case .executionFailed(let stderr, let code):
            return "Process exited with code \(code): \(stderr)"
        case .commandNotFound(let cmd):
            return "\(cmd) was not found on this system."
        }
    }
}

final class ShellRunner: Sendable {

    static let shared = ShellRunner()

    let defaultTimeout: TimeInterval = 60

    // MARK: - Public

    /// Run an executable at `path` with the given arguments.
    func run(
        executablePath: String,
        arguments: [String] = [],
        timeout: TimeInterval? = nil
    ) throws -> ShellResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = Self.enrichedEnvironment()

        // Collect pipe data via readability handlers to avoid deadlocks.
        let stdoutStore = PipeStore()
        let stderrStore = PipeStore()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { stdoutStore.append(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { stderrStore.append(data) }
        }

        try process.run()

        let effectiveTimeout = timeout ?? defaultTimeout
        let timedOut = waitForExit(process: process, timeout: effectiveTimeout)

        // Tear down handlers and drain remaining bytes.
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutStore.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderrStore.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        if timedOut {
            process.terminate()
            throw ShellError.timeout
        }

        return ShellResult(
            output: stdoutStore.string,
            error: stderrStore.string,
            exitCode: process.terminationStatus
        )
    }

    /// Convenience: run a command string via the user's shell.
    func runShell(_ command: String, timeout: TimeInterval? = nil) throws -> ShellResult {
        try run(executablePath: "/bin/zsh", arguments: ["-l", "-c", command], timeout: timeout)
    }

    // MARK: - Helpers

    private func waitForExit(process: Process, timeout: TimeInterval) -> Bool {
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }
        return group.wait(timeout: .now() + timeout) == .timedOut
    }

    private static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extra = [
            "\(home)/.pyenv/shims",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
        ]
        let current = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extra + [current]).joined(separator: ":")
        return env
    }
}

// Thread-safe accumulator for pipe data.
private final class PipeStore: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
