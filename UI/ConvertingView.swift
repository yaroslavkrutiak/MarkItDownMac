import SwiftUI

/// The converting state view: file preview, progress ring, and live process log.
struct ConvertingView: View {

    let fileURL: URL
    @EnvironmentObject private var bridge: ConverterBridge

    private var ext: String { fileURL.pathExtension.lowercased() }
    private var category: FormatCategory { FormatCategory.category(for: ext) }
    private var categoryColor: Color { GlassStyle.chipColor(for: category) }

    var body: some View {
        VStack(spacing: 20) {
            // File preview card
            filePreviewCard

            // Progress ring + label
            VStack(spacing: 12) {
                ProgressRingView(lineWidth: 3, color: .accentColor, size: 48)

                VStack(spacing: 4) {
                    Text("Converting to Markdown\u{2026}")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))

                    Text("Running markitdown")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Process log panel
            processLogPanel
        }
    }

    // MARK: - File Preview Card

    @ViewBuilder
    private var filePreviewCard: some View {
        HStack(spacing: 12) {
            // File type icon
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.8), categoryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Text(ext.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: categoryColor.opacity(0.3), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileURL.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(fileURL.deletingLastPathComponent().lastPathComponent)
                    if let size = fileSize {
                        Text("·")
                        Text(size)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .glassPanel(cornerRadius: 11)
    }

    // MARK: - Process Log Panel

    @ViewBuilder
    private var processLogPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROCESS LOG")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(bridge.conversionLog.enumerated()), id: \.offset) { index, line in
                            Text(colorizedLine(line))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.7))
                                .textSelection(.enabled)
                                .id(index)
                        }
                        // Blinking cursor
                        BlinkingCursor()
                            .id("cursor")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: bridge.conversionLog.count) { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("cursor", anchor: .bottom)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(12)
        .glassPanel()
    }

    // MARK: - Helpers

    private var fileSize: String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let bytes = attrs[.size] as? Int64 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func colorizedLine(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        if line.contains("✓") || line.contains("complete") {
            result.foregroundColor = .green.opacity(0.7)
        } else if line.hasPrefix("[stderr]") || line.hasPrefix("[error]") {
            result.foregroundColor = .red.opacity(0.7)
        } else if line.hasPrefix("→") {
            result.foregroundColor = .cyan.opacity(0.6)
        }
        return result
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(visible ? 0.4 : 0))
            .frame(width: 6, height: 12)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}
