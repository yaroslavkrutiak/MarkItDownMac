import SwiftUI
import UniformTypeIdentifiers

/// A glass-styled drag-and-drop target for file input.
struct DropZoneView: View {

    var supportedExtensions: [String]
    var onFilePicked: (URL) -> Void

    @State private var isTargeted = false
    @State private var rejectedExtension: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            // Icon container
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isTargeted
                        ? Color.accentColor.opacity(0.15)
                        : Color.primary.opacity(0.06)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isTargeted
                                ? Color.accentColor.opacity(0.4)
                                : Color.primary.opacity(0.18),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                )
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text("Drop file here")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))

                Text("PDF, DOCX, PPTX, images, audio and more")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Unsupported format rejection banner
            if let ext = rejectedExtension {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: .red.opacity(0.5), radius: 4)

                    Text(".\(ext) is not supported by MarkItDown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted
                        ? Color.accentColor.opacity(0.6)
                        : Color.primary.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .animation(.easeInOut(duration: 0.2), value: rejectedExtension)
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            DispatchQueue.main.async {
                checkAndForward(url)
            }
        }
        return true
    }

    private func checkAndForward(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if !supportedExtensions.isEmpty && !supportedExtensions.contains(ext) {
            rejectedExtension = ext
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if rejectedExtension == ext {
                    rejectedExtension = nil
                }
            }
        }
        // Always forward — no format gate
        onFilePicked(url)
    }
}
