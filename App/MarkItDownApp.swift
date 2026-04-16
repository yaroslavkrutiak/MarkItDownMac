import SwiftUI

@main
struct MarkItDownApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bridge = ConverterBridge(
        implementation: MarkItDownCLIImplementation()
    )

    @AppStorage(GlassStyle.glassEnabledKey) private var glassEnabled = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
                .environment(\.glassEnabled, glassEnabled)
                .background(GlassWindowBackground())
                .task { await bridge.loadFormats() }
        }
        .defaultSize(width: 420, height: 520)
    }
}
