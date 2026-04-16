import SwiftUI

@main
struct MarkItDownApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bridge = ConverterBridge(
        implementation: MarkItDownCLIImplementation()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
                .task { await bridge.loadFormats() }
        }
        .defaultSize(width: 420, height: 520)
    }
}
