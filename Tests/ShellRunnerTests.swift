import Testing
import Foundation
@testable import MarkItDownCore

@Suite("ShellRunner")
struct ShellRunnerTests {

    private let runner = ShellRunner.shared

    @Test func echoCapture() throws {
        let result = try runner.runShell("echo hello")
        #expect(result.exitCode == 0)
        #expect(result.output == "hello")
    }

    @Test func stderrCapture() throws {
        let result = try runner.runShell("echo oops >&2; exit 1")
        #expect(result.exitCode == 1)
        #expect(result.error == "oops")
    }

    @Test func timeout() {
        #expect(throws: ShellError.self) {
            try runner.runShell("sleep 10", timeout: 1)
        }
    }

    @Test func nonZeroExit() throws {
        let result = try runner.runShell("exit 42")
        #expect(result.exitCode == 42)
    }

    @Test func pathIncludesHomebrew() throws {
        let result = try runner.runShell("echo $PATH")
        #expect(result.output.contains("/opt/homebrew/bin"))
    }
}
