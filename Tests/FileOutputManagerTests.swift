import Testing
import Foundation
@testable import MarkItDownCore

@Suite("FileOutputManager")
struct FileOutputManagerTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileOutputManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func basicRename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("report.pdf")
        let output = FileOutputManager.outputURL(for: source, in: dir)
        #expect(output.lastPathComponent == "report.md")
    }

    @Test func collisionIncrement() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "".write(to: dir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)

        let source = dir.appendingPathComponent("report.pdf")
        let output = FileOutputManager.outputURL(for: source, in: dir)
        #expect(output.lastPathComponent == "report-1.md")
    }

    @Test func multipleCollisions() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in ["report.md", "report-1.md", "report-2.md"] {
            try "".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let source = dir.appendingPathComponent("report.xlsx")
        let output = FileOutputManager.outputURL(for: source, in: dir)
        #expect(output.lastPathComponent == "report-3.md")
    }

    @Test func outputNextToSource() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("data.csv")
        let output = FileOutputManager.outputURL(for: source)
        #expect(output.deletingLastPathComponent().path == dir.path)
        #expect(output.lastPathComponent == "data.md")
    }

    @Test func explicitOutputDir() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let outDir = dir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let source = dir.appendingPathComponent("slides.pptx")
        let output = FileOutputManager.outputURL(for: source, in: outDir)
        #expect(output.deletingLastPathComponent().path == outDir.path)
        #expect(output.lastPathComponent == "slides.md")
    }
}
