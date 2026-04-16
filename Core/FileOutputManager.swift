import Foundation

enum FileOutputManager {

    /// Build a collision-safe `.md` output path for the given source file.
    ///
    /// - Parameters:
    ///   - source: The original file URL (e.g. `report.pdf`).
    ///   - directory: Optional output directory. When `nil`, the output is
    ///     placed next to the source file.
    /// - Returns: A URL like `report.md`, `report-1.md`, `report-2.md`, etc.
    static func outputURL(for source: URL, in directory: URL? = nil) -> URL {
        let fm = FileManager.default
        let dir = directory ?? source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent

        let candidate = dir.appendingPathComponent(baseName).appendingPathExtension("md")
        if !fm.fileExists(atPath: candidate.path) {
            return candidate
        }

        var counter = 1
        while true {
            let numbered = dir
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension("md")
            if !fm.fileExists(atPath: numbered.path) {
                return numbered
            }
            counter += 1
        }
    }
}
