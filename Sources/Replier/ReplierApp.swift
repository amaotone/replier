import SwiftUI
import ReplierCore

@MainActor
final class AppContainer {
    let panelController: PanelController
    let hotkeyManager: HotkeyManager

    init() {
        let panelController = PanelController(drafter: MockReplyDrafter(), style: StyleProfile())
        self.panelController = panelController
        self.hotkeyManager = HotkeyManager {
            panelController.show()
        }
    }
}

@main
struct ReplierApp: App {
    private let container = AppContainer()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("replier", systemImage: "text.bubble") {
            VStack {
                Text("ReplierCore \(ReplierCore.version)")
                Button("パネルを開く ⌥⌘R") {
                    container.panelController.show()
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}
