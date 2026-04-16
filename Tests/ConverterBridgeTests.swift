import Testing
import Foundation
@testable import MarkItDownCore

@Suite("ConverterBridge")
@MainActor
struct ConverterBridgeTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BridgeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func toolNotInstalled() async throws {
        let mock = MockConverterImplementation()
        mock.installed = false
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        #expect(bridge.isToolInstalled == false)

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        await #expect(throws: ConversionError.self) {
            try await bridge.validateAndConvert(
                fileURL: dir.appendingPathComponent("x.pdf"),
                outputDir: dir
            )
        }
    }

    @Test func successfulConversion() async throws {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("report.pdf")
        try "pdf".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Report\n\nContent.")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        #expect(output.lastPathComponent == "report.md")

        let content = try String(contentsOf: output, encoding: .utf8)
        #expect(content.contains("Content."))
    }

    @Test func anyExtensionAccepted() async throws {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("data.weird_ext")
        try "data".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Data")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        #expect(output.lastPathComponent == "data.md")
    }

    @Test func conversionFailure() async throws {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("bad.pdf")
        try "bad".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .failure(ShellError.executionFailed(stderr: "crash", exitCode: 1))

        await #expect(throws: ConversionError.self) {
            try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        }
    }

    @Test func collisionSafeOutput() async throws {
        let mock = MockConverterImplementation()
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("doc.pdf")
        try "pdf".write(to: source, atomically: true, encoding: .utf8)
        try "existing".write(to: dir.appendingPathComponent("doc.md"), atomically: true, encoding: .utf8)
        mock.convertResult = .success("# New")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        #expect(output.lastPathComponent == "doc-1.md")
    }

    @Test func formatListLoaded() async {
        let mock = MockConverterImplementation()
        mock.formats = ["pdf", "xlsx", "docx"]
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()
        #expect(bridge.supportedExtensions == ["pdf", "xlsx", "docx"])
    }

    @Test func emptyFormatListDoesNotBlock() async throws {
        let mock = MockConverterImplementation()
        mock.formats = []
        let bridge = ConverterBridge(implementation: mock)
        await bridge.loadFormats()

        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("file.xlsx")
        try "data".write(to: source, atomically: true, encoding: .utf8)
        mock.convertResult = .success("# Sheet")

        let output = try await bridge.validateAndConvert(fileURL: source, outputDir: dir)
        #expect(output.pathExtension == "md")
    }
}
