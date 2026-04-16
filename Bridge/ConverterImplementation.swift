import Foundation

/// The *implementor* interface in the Bridge pattern.
///
/// Any back-end that can turn a file into Markdown conforms to this protocol.
/// The UI layer never references a concrete implementor directly — it talks
/// exclusively through ``ConverterBridge``.
protocol ConverterImplementation: Sendable {
    /// Convert the file at `fileURL` and return the Markdown string.
    func convert(fileURL: URL) throws -> String

    /// Convert the file, streaming process output lines as they arrive.
    /// The final element is the complete Markdown result.
    func convertStreaming(fileURL: URL) -> AsyncThrowingStream<String, Error>

    /// Whether the underlying tool is installed and reachable.
    func isInstalled() -> Bool

    /// Query the installed tool for the file extensions it actually supports.
    /// Returns lowercased extensions **without** a leading dot (e.g. `["pdf", "docx"]`).
    func installedSupportedFormats() -> [String]
}

extension ConverterImplementation {
    /// Default: calls the synchronous `convert()` and yields the result as one chunk.
    func convertStreaming(fileURL: URL) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            do {
                let result = try self.convert(fileURL: fileURL)
                continuation.yield(result)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
