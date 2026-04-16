import AppKit
import UserNotifications

/// Handles the Finder Quick Action (macOS Service) and posts notifications.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var bridge: ConverterBridge = {
        ConverterBridge(implementation: MarkItDownCLIImplementation())
    }()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        requestNotificationPermission()

        // Pre-warm the format list for the Service handler.
        Task {
            await bridge.loadFormats()
        }
    }

    // MARK: - macOS Service (Finder Quick Action)

    /// Entry point for the **Convert to Markdown** service.
    /// Declared in Info.plist under NSServices with `NSMessage = convertToMarkdown`.
    @objc func convertToMarkdown(
        _ pboard: NSPasteboard,
        userData: String,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let items = pboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] else {
            errorPointer.pointee = "No files received." as NSString
            return
        }

        let urls = items.map { URL(fileURLWithPath: $0) }

        Task {
            for url in urls {
                do {
                    let output = try await bridge.validateAndConvert(fileURL: url)
                    postNotification(title: "Converted", body: output.lastPathComponent)
                } catch {
                    postNotification(title: "Conversion failed", body: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
