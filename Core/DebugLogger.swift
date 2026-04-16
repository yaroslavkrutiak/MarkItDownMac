import Foundation

/// Writes timestamped `.log` files to `~/Library/Logs/MarkItDownMac/`
/// whenever a conversion fails and debug mode is on.
final class DebugLogger: @unchecked Sendable {

    static let shared = DebugLogger()

    private let defaults = UserDefaults.standard
    private let key = "debugLoggingEnabled"

    var isEnabled: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }

    /// Directory where log files are written.
    var logDirectory: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MarkItDownMac")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Write a failure log. Call this only when `isEnabled` is true.
    func logFailure(
        sourceFile: URL,
        command: String,
        exitCode: Int32,
        stdout: String,
        stderr: String,
        error: String
    ) {
        guard isEnabled else { return }

        let ts = Self.timestampFormatter.string(from: Date())
        let fileName = "markitdown-\(ts).log"
        let logURL = logDirectory.appendingPathComponent(fileName)

        let content = """
        MarkItDownMac Debug Log
        =======================
        Timestamp : \(ts)
        Source    : \(sourceFile.path)

        Command
        -------
        \(command)

        Exit Code
        ---------
        \(exitCode)

        STDOUT
        ------
        \(stdout.isEmpty ? "(empty)" : stdout)

        STDERR
        ------
        \(stderr.isEmpty ? "(empty)" : stderr)

        Error
        -----
        \(error)
        """

        try? content.write(to: logURL, atomically: true, encoding: .utf8)
    }

    /// URL of the most recently written log, if any.
    func latestLog() -> URL? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        return files
            .filter { $0.pathExtension == "log" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
            .first
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
