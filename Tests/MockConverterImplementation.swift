import Foundation

/// A mock `ConverterImplementation` for testing the bridge logic
/// without requiring Python or markitdown.
final class MockConverterImplementation: ConverterImplementation {

    var installed = true
    var formats: [String] = ["pdf", "docx", "xlsx", "pptx", "html", "csv"]
    var convertResult: Result<String, Error> = .success("# Mock output")

    func convert(fileURL: URL) throws -> String {
        switch convertResult {
        case .success(let md): return md
        case .failure(let err): throw err
        }
    }

    func isInstalled() -> Bool { installed }

    func installedSupportedFormats() -> [String] { formats }
}
