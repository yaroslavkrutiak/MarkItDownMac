import SwiftUI

/// Shown after a successful conversion. Glass-styled with animated checkmark,
/// source→output flow, output path card, and collision info.
struct ConversionResultView: View {

    let outputURL: URL
    let outputResult: FileOutputManager.OutputResult?
    let sourceURL: URL
    var onConvertAnother: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: CGFloat = 0
    @State private var copiedPath = false

    private var sourceExt: String { sourceURL.pathExtension.lowercased() }
    private var sourceCategory: FormatCategory { FormatCategory.category(for: sourceExt) }
    private var sourceColor: Color { GlassStyle.chipColor(for: sourceCategory) }

    var body: some View {
        VStack(spacing: 16) {
            // Animated checkmark
            animatedCheckmark

            // Source → Output flow
            sourceToOutputFlow

            // Output path card
            outputPathCard

            // Collision note
            if let result = outputResult, result.didCollide {
                collisionNote(result)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button { onConvertAnother() } label: {
                    Text("Convert Another")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accentGlassButton()
                }
                .buttonStyle(.plain)

                Button { copyPath() } label: {
                    Text(copiedPath ? "Copied!" : "Copy Path")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))
                        .glassButton()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Animated Checkmark

    @ViewBuilder
    private var animatedCheckmark: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.25), Color.green.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .green.opacity(0.2), radius: 12)

                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .scaleEffect(checkmarkScale)
            .opacity(checkmarkOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkmarkScale = 1
                    checkmarkOpacity = 1
                }
            }

            VStack(spacing: 4) {
                Text("Conversion complete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))

                Text("\(outputURL.lastPathComponent) created")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Source → Output Flow

    @ViewBuilder
    private var sourceToOutputFlow: some View {
        HStack(spacing: 8) {
            // Source icon
            fileIcon(ext: sourceExt, color: sourceColor)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.5))

            // Output icon
            fileIcon(ext: "md", color: .green)

            Text(outputURL.lastPathComponent)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.55))
                .lineLimit(1)

            Spacer()
        }
    }

    // MARK: - Output Path Card

    @ViewBuilder
    private var outputPathCard: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        } label: {
            HStack {
                Text(outputURL.path)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Color.green.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("REVEAL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.green.opacity(0.6))
                    .tracking(0.6)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collision Note

    @ViewBuilder
    private func collisionNote(_ result: FileOutputManager.OutputResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NAMING — COLLISION RESOLVED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            HStack(spacing: 4) {
                Text(result.originalName)
                    .strikethrough()
                    .foregroundStyle(.secondary.opacity(0.4))

                Text("already existed")
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .font(.system(size: 11))

            HStack(spacing: 4) {
                Text("→")
                    .foregroundStyle(.secondary)
                Text(outputURL.lastPathComponent)
                    .foregroundStyle(Color.green.opacity(0.7))
                Text("created")
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassPanel()
    }

    // MARK: - Helpers

    private func fileIcon(ext: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.8), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 30, height: 30)
            .overlay(
                Text(ext.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.3), radius: 3, y: 1)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputURL.path, forType: .string)
        copiedPath = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedPath = false
        }
    }
}
