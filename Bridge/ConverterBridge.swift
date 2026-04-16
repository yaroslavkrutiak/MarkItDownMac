import Foundation

/// Errors surfaced by the bridge to the UI layer.
enum ConversionError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case toolNotInstalled
    case conversionFailed(String)
    case outputWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "The format .\(ext) is not supported by the installed version of markitdown."
        case .toolNotInstalled:
            return "markitdown is not installed."
        case .conversionFailed(let detail):
            return "Conversion failed: \(detail)"
        case .outputWriteFailed(let detail):
            return "Could not write output file: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .toolNotInstalled:
            return "Install it with:  pip install markitdown"
        case .unsupportedFormat:
            return "Try updating markitdown:  pip install --upgrade markitdown"
        default:
            return nil
        }
    }
}

/// The *abstraction* in the Bridge pattern.
///
/// The UI layer holds a ``ConverterBridge`` and never touches a concrete
/// ``ConverterImplementation`` directly.
@MainActor
final class ConverterBridge: ObservableObject {

    @Published private(set) var supportedExtensions: [String] = []
    @Published private(set) var isToolInstalled: Bool = false
    @Published var debugEnabled: Bool {
        didSet { DebugLogger.shared.isEnabled = debugEnabled }
    }

    private let implementation: ConverterImplementation

    init(implementation: ConverterImplementation) {
        self.implementation = implementation
        self.debugEnabled = DebugLogger.shared.isEnabled
    }

    // MARK: - Bootstrap

    /// Call once on app launch to cache the installed format list.
    func loadFormats() async {
        let impl = implementation
        let (installed, formats) = await Task.detached {
            (impl.isInstalled(), impl.installedSupportedFormats())
        }.value
        isToolInstalled = installed
        supportedExtensions = formats
    }

    // MARK: - Public API

    /// Returns `true` if the extension is in the discovered list, or if
    /// discovery returned nothing (in which case we allow everything through
    /// and let markitdown itself reject unsupported files).
    func isSupportedFormat(_ url: URL) -> Bool {
        if supportedExtensions.isEmpty { return true }
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// Validate the file, convert it, and write the `.md` output.
    ///
    /// - Parameters:
    ///   - fileURL: Source file to convert.
    ///   - outputDir: Where to write the result. `nil` → same directory as source.
    /// - Returns: URL of the newly created Markdown file.
    func validateAndConvert(fileURL: URL, outputDir: URL? = nil) async throws -> URL {
        guard isToolInstalled else { throw ConversionError.toolNotInstalled }
        guard isSupportedFormat(fileURL) else {
            throw ConversionError.unsupportedFormat(fileURL.pathExtension)
        }

        let impl = implementation
        let sourceURL = fileURL
        let markdown: String = try await Task.detached {
            do {
                return try impl.convert(fileURL: sourceURL)
            } catch {
                throw ConversionError.conversionFailed(error.localizedDescription)
            }
        }.value

        let outputURL = FileOutputManager.outputURL(for: fileURL, in: outputDir)

        do {
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConversionError.outputWriteFailed(error.localizedDescription)
        }

        return outputURL
    }
}
