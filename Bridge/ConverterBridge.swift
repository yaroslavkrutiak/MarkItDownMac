import Foundation

/// Errors surfaced by the bridge to the UI layer.
enum ConversionError: LocalizedError, Equatable {
    case toolNotInstalled
    case conversionFailed(String)
    case outputWriteFailed(String)

    var errorDescription: String? {
        switch self {
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
        case .conversionFailed:
            return "Enable debug logging (bug icon) and retry to capture details."
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

    /// Extensions discovered from the installed tool. Informational only —
    /// conversion is never blocked based on this list.
    @Published private(set) var supportedExtensions: [String] = []
    @Published private(set) var isToolInstalled: Bool = false
    @Published var debugEnabled: Bool {
        didSet { DebugLogger.shared.isEnabled = debugEnabled }
    }

    /// Live log lines from the current streaming conversion.
    @Published var conversionLog: [String] = []

    /// Output resolution info from the most recent conversion.
    @Published private(set) var lastOutputResult: FileOutputManager.OutputResult? = nil

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

    /// Convert the file with live log streaming and write the `.md` output.
    ///
    /// Populates ``conversionLog`` with lines as they arrive and stores
    /// collision info in ``lastOutputResult``.
    func validateAndConvertStreaming(fileURL: URL, outputDir: URL? = nil) async throws -> URL {
        guard isToolInstalled else { throw ConversionError.toolNotInstalled }

        conversionLog = []
        lastOutputResult = nil

        let ext = fileURL.pathExtension.lowercased()
        conversionLog.append("→ Validating format: \(ext)")

        let impl = implementation
        let sourceURL = fileURL

        conversionLog.append("→ Starting conversion")

        var fullOutput = ""
        let stream = impl.convertStreaming(fileURL: sourceURL)
        do {
            for try await line in stream {
                conversionLog.append(line)
                if !line.hasPrefix("[stderr] ") && !line.hasPrefix("[error] ") {
                    if !fullOutput.isEmpty { fullOutput += "\n" }
                    fullOutput += line
                }
            }
        } catch {
            throw ConversionError.conversionFailed(error.localizedDescription)
        }

        conversionLog.append("→ Conversion complete")

        let result = FileOutputManager.resolveOutput(for: fileURL, in: outputDir)
        lastOutputResult = result

        do {
            try fullOutput.write(to: result.url, atomically: true, encoding: .utf8)
        } catch {
            throw ConversionError.outputWriteFailed(error.localizedDescription)
        }

        return result.url
    }

    /// Convert the file and write the `.md` output. No format gate —
    /// markitdown itself decides what it can and cannot handle.
    ///
    /// - Parameters:
    ///   - fileURL: Source file to convert.
    ///   - outputDir: Where to write the result. `nil` → same directory as source.
    /// - Returns: URL of the newly created Markdown file.
    func validateAndConvert(fileURL: URL, outputDir: URL? = nil) async throws -> URL {
        guard isToolInstalled else { throw ConversionError.toolNotInstalled }

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
