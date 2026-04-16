import Foundation

// ---------------------------------------------------------------------------
// Minimal test harness
// ---------------------------------------------------------------------------

nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0
nonisolated(unsafe) var errors: [(String, String)] = []

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ msg: String) { description = msg }
}

func check(_ cond: Bool, _ msg: String = "", file: String = #file, line: Int = #line) throws {
    guard cond else {
        throw TestFailure("\(msg.isEmpty ? "Assertion failed" : msg) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a == b else {
        throw TestFailure("Expected \(b), got \(a) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
}

func test(_ name: String, _ body: () throws -> Void) {
    do {
        try body()
        passed += 1
        print("  PASS  \(name)")
    } catch {
        failed += 1
        errors.append((name, "\(error)"))
        print("  FAIL  \(name): \(error)")
    }
}

func makeTempDir(_ prefix: String = "Test") -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func removeTempDir(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

func bridgeTest(_ name: String, _ body: @escaping @MainActor () async throws -> Void) {
    nonisolated(unsafe) var done = false
    nonisolated(unsafe) var err: Error?
    Task { @MainActor in
        do { try await body() }
        catch { err = error }
        done = true
    }
    while !done { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01)) }
    if let e = err {
        failed += 1
        errors.append((name, "\(e)"))
        print("  FAIL  \(name): \(e)")
    } else {
        passed += 1
        print("  PASS  \(name)")
    }
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

@main
enum TestMain {
    static func main() {
        fileOutputManagerTests()
        shellRunnerTests()
        debugLoggerTests()

        nonisolated(unsafe) var bridgeDone = false
        Task { @MainActor in
            converterBridgeTests()
            bridgeDone = true
        }
        while !bridgeDone { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01)) }

        print("\n===========================")
        print("  \(passed) passed, \(failed) failed")
        if !errors.isEmpty {
            print("\nFailures:")
            for (name, msg) in errors { print("  - \(name): \(msg)") }
        }
        print("===========================\n")
        exit(failed > 0 ? 1 : 0)
    }
}

// ---------------------------------------------------------------------------
// FileOutputManager
// ---------------------------------------------------------------------------

func fileOutputManagerTests() {
    print("\n--- FileOutputManager ---")

    test("basic rename") {
        let dir = makeTempDir("FOM"); defer { removeTempDir(dir) }
        let output = FileOutputManager.outputURL(for: dir.appendingPathComponent("report.pdf"), in: dir)
        try assertEqual(output.lastPathComponent, "report.md")
    }

    test("collision increment") {
        let dir = makeTempDir("FOM"); defer { removeTempDir(dir) }
        try "".write(to: dir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        let output = FileOutputManager.outputURL(for: dir.appendingPathComponent("report.pdf"), in: dir)
        try assertEqual(output.lastPathComponent, "report-1.md")
    }

    test("multiple collisions") {
        let dir = makeTempDir("FOM"); defer { removeTempDir(dir) }
        for n in ["report.md", "report-1.md", "report-2.md"] {
            try "".write(to: dir.appendingPathComponent(n), atomically: true, encoding: .utf8)
        }
        let output = FileOutputManager.outputURL(for: dir.appendingPathComponent("report.xlsx"), in: dir)
        try assertEqual(output.lastPathComponent, "report-3.md")
    }

    test("output next to source") {
        let dir = makeTempDir("FOM"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("data.csv")
        let output = FileOutputManager.outputURL(for: source)
        try assertEqual(output.deletingLastPathComponent().path, dir.path)
        try assertEqual(output.lastPathComponent, "data.md")
    }

    test("explicit output dir") {
        let dir = makeTempDir("FOM"); defer { removeTempDir(dir) }
        let outDir = dir.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let output = FileOutputManager.outputURL(for: dir.appendingPathComponent("slides.pptx"), in: outDir)
        try assertEqual(output.deletingLastPathComponent().path, outDir.path)
        try assertEqual(output.lastPathComponent, "slides.md")
    }
}

// ---------------------------------------------------------------------------
// ShellRunner
// ---------------------------------------------------------------------------

func shellRunnerTests() {
    print("\n--- ShellRunner ---")

    test("echo capture") {
        let r = try ShellRunner.shared.runShell("echo hello")
        try assertEqual(r.exitCode, 0)
        try assertEqual(r.output, "hello")
    }

    test("stderr capture") {
        let r = try ShellRunner.shared.runShell("echo oops >&2; exit 1")
        try assertEqual(r.exitCode, 1)
        try assertEqual(r.error, "oops")
    }

    test("timeout") {
        var didThrow = false
        do { _ = try ShellRunner.shared.runShell("sleep 10", timeout: 1) }
        catch is ShellError { didThrow = true }
        try check(didThrow, "Expected ShellError.timeout")
    }

    test("non-zero exit") {
        let r = try ShellRunner.shared.runShell("exit 42")
        try assertEqual(r.exitCode, 42)
    }

    test("PATH includes homebrew") {
        let r = try ShellRunner.shared.runShell("echo $PATH")
        try check(r.output.contains("/opt/homebrew/bin"), "PATH missing /opt/homebrew/bin")
    }
}

// ---------------------------------------------------------------------------
// DebugLogger
// ---------------------------------------------------------------------------

func debugLoggerTests() {
    print("\n--- DebugLogger ---")
    let logger = DebugLogger.shared

    test("log creation") {
        logger.isEnabled = true
        defer { logger.isEnabled = false }
        logger.logFailure(
            sourceFile: URL(fileURLWithPath: "/tmp/test.xlsx"),
            command: "markitdown /tmp/test.xlsx",
            exitCode: 1, stdout: "", stderr: "some error", error: "Non-zero exit code"
        )
        let log = logger.latestLog()
        try check(log != nil, "Log file should exist")
        let content = try String(contentsOf: log!, encoding: .utf8)
        try check(content.contains("test.xlsx"))
        try check(content.contains("some error"))
        try? FileManager.default.removeItem(at: log!)
    }

    test("no log when disabled") {
        logger.isEnabled = false
        let before = logger.latestLog()
        logger.logFailure(
            sourceFile: URL(fileURLWithPath: "/tmp/x.pdf"),
            command: "test", exitCode: 1, stdout: "", stderr: "", error: "err"
        )
        let after = logger.latestLog()
        try assertEqual(before?.lastPathComponent ?? "nil", after?.lastPathComponent ?? "nil")
    }
}

// ---------------------------------------------------------------------------
// ConverterBridge (via mock)
// ---------------------------------------------------------------------------

@MainActor
func converterBridgeTests() {
    print("\n--- ConverterBridge ---")

    bridgeTest("tool not installed") {
        let mock = MockConverterImplementation()
        mock.installed = false
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()
        try check(!bridge.isToolInstalled)

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        var threw = false
        do {
            _ = try await bridge.validateAndConvert(
                fileURL: dir.appendingPathComponent("x.pdf"), outputDir: dir)
        } catch is ConversionError { threw = true }
        try check(threw, "Should throw toolNotInstalled")
    }

    bridgeTest("successful conversion") {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("report.pdf")
        try "pdf".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Report")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        try assertEqual(output.lastPathComponent, "report.md")
        let content = try String(contentsOf: output, encoding: .utf8)
        try check(content.contains("Report"))
    }

    bridgeTest("any extension accepted") {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("data.weird_ext")
        try "d".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Data")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        try assertEqual(output.lastPathComponent, "data.md")
    }

    bridgeTest("conversion failure") {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("bad.pdf")
        try "bad".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .failure(ShellError.executionFailed(stderr: "crash", exitCode: 1))

        var threw = false
        do {
            _ = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        } catch is ConversionError { threw = true }
        try check(threw, "Should throw conversionFailed")
    }

    bridgeTest("collision-safe output") {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("doc.pdf")
        try "pdf".write(to: source, atomically: true, encoding: .utf8)
        try "existing".write(to: dir.appendingPathComponent("doc.md"), atomically: true, encoding: .utf8)
        mock.convertResult = .success("# New")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        try assertEqual(output.lastPathComponent, "doc-1.md")
    }

    bridgeTest("empty format list does not block") {
        let mock = MockConverterImplementation()
        mock.formats = []
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()
        try check(bridge.supportedExtensions.isEmpty)

        let dir = makeTempDir("Bridge"); defer { removeTempDir(dir) }
        let source = dir.appendingPathComponent("file.xlsx")
        try "data".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Sheet")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        try assertEqual(output.pathExtension, "md")
    }
}
