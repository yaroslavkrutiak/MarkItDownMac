import SwiftUI
import UniformTypeIdentifiers

/// A dashed rounded rectangle that accepts file drops.
struct DropZoneView: View {

    var supportedExtensions: [String]
    var onFilePicked: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.07) : Color.clear)
                )

            VStack(spacing: 12) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Drop a file here")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 260, minHeight: 160)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            DispatchQueue.main.async { onFilePicked(url) }
        }
        return true
    }
}
