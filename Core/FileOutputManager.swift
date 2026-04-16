import Foundation

enum FileOutputManager {

    /// Result of resolving a collision-safe output path.
    struct OutputResult {
        let url: URL
        let didCollide: Bool
        let originalName: String
    }

    /// Build a collision-safe `.md` output path for the given source file,
    /// returning whether a collision was resolved.
    static func resolveOutput(for source: URL, in directory: URL? = nil) -> OutputResult {
        let fm = FileManager.default
        let dir = directory ?? source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent
        let originalName = baseName + ".md"

        let candidate = dir.appendingPathComponent(baseName).appendingPathExtension("md")
        if !fm.fileExists(atPath: candidate.path) {
            return OutputResult(url: candidate, didCollide: false, originalName: originalName)
        }

        var counter = 1
        while true {
            let numbered = dir
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension("md")
            if !fm.fileExists(atPath: numbered.path) {
                return OutputResult(url: numbered, didCollide: true, originalName: originalName)
            }
            counter += 1
        }
    }

    /// Build a collision-safe `.md` output path for the given source file.
    ///
    /// - Parameters:
    ///   - source: The original file URL (e.g. `report.pdf`).
    ///   - directory: Optional output directory. When `nil`, the output is
    ///     placed next to the source file.
    /// - Returns: A URL like `report.md`, `report-1.md`, `report-2.md`, etc.
    static func outputURL(for source: URL, in directory: URL? = nil) -> URL {
        resolveOutput(for: source, in: directory).url
    }
}
