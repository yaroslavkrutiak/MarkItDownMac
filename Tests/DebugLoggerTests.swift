import Testing
import Foundation
@testable import MarkItDownCore

@Suite("DebugLogger")
struct DebugLoggerTests {

    private let logger = DebugLogger.shared

    private func cleanup() {
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(
            at: logger.logDirectory,
            includingPropertiesForKeys: nil
        ) {
            for f in files where f.lastPathComponent.hasPrefix("markitdown-") {
                try? fm.removeItem(at: f)
            }
        }
    }

    @Test func logCreation() throws {
        logger.isEnabled = true
        defer { logger.isEnabled = false; cleanup() }

        logger.logFailure(
            sourceFile: URL(fileURLWithPath: "/tmp/test.xlsx"),
            command: "markitdown /tmp/test.xlsx",
            exitCode: 1,
            stdout: "",
            stderr: "some error",
            error: "Non-zero exit code"
        )

        let log = logger.latestLog()
        #expect(log != nil)

        if let log = log {
            let content = try String(contentsOf: log, encoding: .utf8)
            #expect(content.contains("test.xlsx"))
            #expect(content.contains("some error"))
            #expect(content.contains("Non-zero exit code"))
        }
    }

    @Test func noLogWhenDisabled() {
        logger.isEnabled = false
        defer { cleanup() }

        let before = logger.latestLog()

        logger.logFailure(
            sourceFile: URL(fileURLWithPath: "/tmp/x.pdf"),
            command: "test",
            exitCode: 1,
            stdout: "", stderr: "", error: "err"
        )

        let after = logger.latestLog()
        #expect(before?.lastPathComponent == after?.lastPathComponent)
    }

    @Test func logDirectoryExists() {
        let dir = logger.logDirectory
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }
}
