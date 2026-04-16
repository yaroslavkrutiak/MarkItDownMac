import SwiftUI
import UniformTypeIdentifiers

/// The root view — a state machine cycling through
/// idle → converting → success / error.
struct ContentView: View {

    @EnvironmentObject private var bridge: ConverterBridge

    @State private var state: ConversionState = .idle

    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .idle:
                idleView
            case .converting(let url):
                ConvertingView(fileURL: url)
            case .success(let source, let output, let result):
                ConversionResultView(
                    outputURL: output,
                    outputResult: result,
                    sourceURL: source,
                    onConvertAnother: { state = .idle }
                )
            case .error(let error):
                errorView(error)
            }
        }
        .frame(minWidth: 380, minHeight: 460)
        .padding(24)
        .overlay(alignment: .bottomTrailing) { debugToggle }
        .animation(.default, value: stateTag)
    }

    // MARK: - Idle State

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 16) {
            DropZoneView(
                supportedExtensions: bridge.supportedExtensions,
                onFilePicked: { url in startConversion(url) }
            )

            // "or" divider
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }

            // Select File button
            Button { openFilePanel() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text("Select File from Finder\u{2026}")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.primary.opacity(0.85))
            }
            .buttonStyle(.plain)
            .glassButton()
            .keyboardShortcut("o", modifiers: .command)

            if !bridge.isToolInstalled {
                notInstalledHint
            } else if !bridge.supportedExtensions.isEmpty {
                SupportedFormatsPanel(extensions: bridge.supportedExtensions)
            }
        }
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ error: ConversionError) -> some View {
        VStack(spacing: 16) {
            // Error icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.25), Color.red.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .red.opacity(0.2), radius: 12)

                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
            }

            Text(errorTitle(error))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))

            // "What failed" card
            VStack(alignment: .leading, spacing: 4) {
                Text("What happened")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.8))

                Text(error.localizedDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.18), lineWidth: 0.5)
            )

            // "How to fix" card
            if let hint = error.recoverySuggestion {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Install via pip:")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(hint)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.orange.opacity(0.8))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .glassPanel(cornerRadius: 10)
            }

            // Debug log link
            if bridge.debugEnabled, let log = DebugLogger.shared.latestLog() {
                Button {
                    NSWorkspace.shared.open(log)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                        Text("Open Debug Log")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    Task {
                        await bridge.loadFormats()
                        state = .idle
                    }
                } label: {
                    Text("Retry Detection")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accentGlassButton()

                Button {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                    )
                } label: {
                    Text("Open Terminal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .glassButton()
            }
        }
    }

    // MARK: - Not Installed Hint

    @ViewBuilder
    private var notInstalledHint: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.orange.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("markitdown is not installed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                Text("pip install markitdown")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassPanel(cornerRadius: 10)
    }

    // MARK: - Debug Toggle

    @ViewBuilder
    private var debugToggle: some View {
        Button {
            bridge.debugEnabled.toggle()
        } label: {
            Image(systemName: bridge.debugEnabled ? "ladybug.fill" : "ladybug")
                .font(.system(size: 12))
                .foregroundStyle(bridge.debugEnabled ? .orange : .secondary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 8)
        .padding(8)
        .help(bridge.debugEnabled
              ? "Debug logging ON — logs in ~/Library/Logs/MarkItDownMac/"
              : "Enable debug logging")
    }

    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startConversion(url)
    }

    private func startConversion(_ url: URL) {
        guard bridge.isToolInstalled else {
            state = .error(.toolNotInstalled)
            return
        }

        state = .converting(url)
        Task {
            do {
                let output = try await bridge.validateAndConvertStreaming(fileURL: url)
                state = .success(source: url, output: output, result: bridge.lastOutputResult)
            } catch let err as ConversionError {
                state = .error(err)
            } catch {
                state = .error(.conversionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Helpers

    private func errorTitle(_ error: ConversionError) -> String {
        switch error {
        case .toolNotInstalled: return "markitdown not found"
        case .conversionFailed: return "Conversion failed"
        case .outputWriteFailed: return "Could not write output"
        }
    }

    private var stateTag: Int {
        switch state {
        case .idle: return 0
        case .converting: return 1
        case .success: return 2
        case .error: return 3
        }
    }
}

private enum ConversionState {
    case idle
    case converting(URL)
    case success(source: URL, output: URL, result: FileOutputManager.OutputResult?)
    case error(ConversionError)
}
