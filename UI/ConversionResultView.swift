import SwiftUI

/// Shown after a successful conversion. Displays the output path and
/// provides a "Reveal in Finder" action.
struct ConversionResultView: View {

    let outputURL: URL
    var onConvertAnother: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)

            Text("Conversion complete")
                .font(.headline)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            } label: {
                Label(outputURL.lastPathComponent, systemImage: "folder")
            }
            .buttonStyle(.link)
            .help("Reveal in Finder")

            Button("Convert Another") {
                onConvertAnother()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
