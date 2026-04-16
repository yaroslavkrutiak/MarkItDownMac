import SwiftUI
import UniformTypeIdentifiers

/// The root view — a state machine cycling through
/// idle → validating → converting → success / error.
struct ContentView: View {

    @EnvironmentObject private var bridge: ConverterBridge

    @State private var state: ConversionState = .idle

    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .idle:
                idleView
            case .validating:
                progressView(label: "Validating format...")
            case .converting(let url):
                progressView(label: "Converting \(url.lastPathComponent)...")
            case .success(let url):
                ConversionResultView(outputURL: url) {
                    state = .idle
                }
            case .error(let error):
                errorView(error)
            }
        }
        .frame(minWidth: 400, minHeight: 340)
        .padding(24)
        .overlay(alignment: .bottomTrailing) { debugToggle }
        .animation(.default, value: stateTag)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 20) {
            DropZoneView(
                supportedExtensions: bridge.supportedExtensions,
                onFilePicked: { url in startConversion(url) }
            )

            Button("Select File...") { openFilePanel() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)

            if !bridge.isToolInstalled {
                notInstalledHint
            } else if !bridge.supportedExtensions.isEmpty {
                Text(FormatCategory.summary(bridge.supportedExtensions))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func progressView(label: String) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorView(_ error: ConversionError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 42))
                .foregroundStyle(.red)

            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let hint = error.recoverySuggestion {
                Text(hint)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button("Try Again") { state = .idle }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    @ViewBuilder
    private var notInstalledHint: some View {
        VStack(spacing: 4) {
            Text("markitdown is not installed")
                .font(.callout)
                .foregroundStyle(.orange)
            Text("pip install markitdown")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var debugToggle: some View {
        HStack(spacing: 6) {
            if bridge.debugEnabled, case .error = state,
               let log = DebugLogger.shared.latestLog() {
                Button("Open Log") {
                    NSWorkspace.shared.open(log)
                }
                .font(.caption2)
                .buttonStyle(.link)
            }

            Button {
                bridge.debugEnabled.toggle()
            } label: {
                Image(systemName: bridge.debugEnabled ? "ladybug.fill" : "ladybug")
                    .foregroundStyle(bridge.debugEnabled ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(bridge.debugEnabled ? "Debug logging ON — logs in ~/Library/Logs/MarkItDownMac/" : "Enable debug logging")
        }
        .padding(8)
    }

    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = bridge.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startConversion(url)
    }

    private func startConversion(_ url: URL) {
        guard bridge.isToolInstalled else {
            state = .error(.toolNotInstalled)
            return
        }

        state = .validating
        Task {
            guard bridge.isSupportedFormat(url) else {
                state = .error(.unsupportedFormat(url.pathExtension))
                return
            }
            state = .converting(url)
            do {
                let output = try await bridge.validateAndConvert(fileURL: url)
                state = .success(output)
            } catch let err as ConversionError {
                state = .error(err)
            } catch {
                state = .error(.conversionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - State identity for animation

    private var stateTag: Int {
        switch state {
        case .idle: return 0
        case .validating: return 1
        case .converting: return 2
        case .success: return 3
        case .error: return 4
        }
    }
}

private enum ConversionState {
    case idle
    case validating
    case converting(URL)
    case success(URL)
    case error(ConversionError)
}
