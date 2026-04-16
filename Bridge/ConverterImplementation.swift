import Foundation

/// The *implementor* interface in the Bridge pattern.
///
/// Any back-end that can turn a file into Markdown conforms to this protocol.
/// The UI layer never references a concrete implementor directly — it talks
/// exclusively through ``ConverterBridge``.
protocol ConverterImplementation: Sendable {
    /// Convert the file at `fileURL` and return the Markdown string.
    func convert(fileURL: URL) throws -> String

    /// Whether the underlying tool is installed and reachable.
    func isInstalled() -> Bool

    /// Query the installed tool for the file extensions it actually supports.
    /// Returns lowercased extensions **without** a leading dot (e.g. `["pdf", "docx"]`).
    func installedSupportedFormats() -> [String]
}
