import Foundation
@testable import MarkItDownCore

/// A mock `ConverterImplementation` for testing the bridge logic
/// without requiring Python or markitdown.
final class MockConverterImplementation: ConverterImplementation {

    var installed = true
    var formats: [String] = ["pdf", "docx", "xlsx", "pptx", "html", "csv"]
    var convertResult: Result<String, Error> = .success("# Mock output")

    /// When set, `convertStreaming` yields these lines instead of using the default.
    var streamingLines: [String]? = nil

    func convert(fileURL: URL) throws -> String {
        switch convertResult {
        case .success(let md): return md
        case .failure(let err): throw err
        }
    }

    func convertStreaming(fileURL: URL) -> AsyncThrowingStream<String, Error> {
        if let lines = streamingLines {
            return AsyncThrowingStream { cont in
                for line in lines { cont.yield(line) }
                cont.finish()
            }
        }
        // Fall back to default: yield full convert() result as one chunk.
        return AsyncThrowingStream { cont in
            do {
                let result = try self.convert(fileURL: fileURL)
                cont.yield(result)
                cont.finish()
            } catch {
                cont.finish(throwing: error)
            }
        }
    }

    func isInstalled() -> Bool { installed }

    func installedSupportedFormats() -> [String] { formats }
}
