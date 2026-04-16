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

    /// Run a shell command and stream stdout/stderr lines as they arrive.
    func runShellStreaming(
        _ command: String,
        timeout: TimeInterval? = nil
    ) -> (lines: AsyncStream<String>, exitCode: AsyncStream<Int32>) {
        let effectiveTimeout = timeout ?? defaultTimeout

        let (lineStream, lineCont) = AsyncStream<String>.makeStream()
        let (exitStream, exitCont) = AsyncStream<Int32>.makeStream()

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = Self.enrichedEnvironment()

        let buffer = LineBuffer(continuation: lineCont)

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { buffer.append(data, prefix: nil) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { buffer.append(data, prefix: "[stderr] ") }
        }

        do {
            try process.run()
        } catch {
            lineCont.yield("[error] Failed to start process: \(error.localizedDescription)")
            lineCont.finish()
            exitCont.yield(-1)
            exitCont.finish()
            return (lineStream, exitStream)
        }

        DispatchQueue.global(qos: .utility).async {
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                group.leave()
            }
            let timedOut = group.wait(timeout: .now() + effectiveTimeout) == .timedOut

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            buffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), prefix: nil)
            buffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile(), prefix: "[stderr] ")
            buffer.flush()

            if timedOut {
                process.terminate()
                lineCont.yield("[error] Command timed out")
                exitCont.yield(-1)
            } else {
                exitCont.yield(process.terminationStatus)
            }
            lineCont.finish()
            exitCont.finish()
        }

        return (lineStream, exitStream)
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

// Thread-safe line splitter that yields complete lines to an AsyncStream.
private final class LineBuffer: @unchecked Sendable {
    private var partial = Data()
    private let lock = NSLock()
    private let continuation: AsyncStream<String>.Continuation

    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }

    func append(_ data: Data, prefix: String?) {
        guard !data.isEmpty else { return }
        lock.lock()
        partial.append(data)
        // Split on newlines and yield complete lines.
        while let range = partial.range(of: Data([0x0A])) {
            let lineData = partial.subdata(in: partial.startIndex..<range.lowerBound)
            partial.removeSubrange(partial.startIndex..<range.upperBound)
            if let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .carriageReturns) {
                let yielded = (prefix ?? "") + line
                lock.unlock()
                continuation.yield(yielded)
                lock.lock()
            }
        }
        lock.unlock()
    }

    func flush() {
        lock.lock()
        let remaining = partial
        partial = Data()
        lock.unlock()
        if let line = String(data: remaining, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !line.isEmpty {
            continuation.yield(line)
        }
    }
}

private extension CharacterSet {
    static let carriageReturns = CharacterSet(charactersIn: "\r")
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
