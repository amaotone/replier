import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

@MainActor
final class AppContainer {
    let panelController: PanelController
    let hotkeyManager: HotkeyManager
    let onboardingWindowController: OnboardingWindowController

    init() {
        let useMock = ProcessInfo.processInfo.arguments.contains("--mock")
        let drafter: any ReplyDrafting = useMock ? MockReplyDrafter() : CodexReplyDrafter()
        Task { await drafter.prewarm() }

        let styleProfileStore = StyleProfileStore(directory: StyleProfileStore.defaultDirectory())

        let panelController = PanelController(drafter: drafter, styleProfileStore: styleProfileStore)
        self.panelController = panelController
        self.hotkeyManager = HotkeyManager {
            panelController.show()
        }
        self.onboardingWindowController = OnboardingWindowController(styleProfileStore: styleProfileStore)

        if !UserDefaults.standard.bool(forKey: OnboardingModel.hasCompletedOnboardingKey) {
            onboardingWindowController.show()
        }
    }
}

@main
struct ReplierApp: App {
    private let container: AppContainer

    init() {
        // Baseline policy: menu bar only, no Dock icon. AppContainer may raise this to
        // `.regular` if it opens the first-launch onboarding window.
        NSApplication.shared.setActivationPolicy(.accessory)
        self.container = AppContainer()
    }

    var body: some Scene {
        MenuBarExtra("replier", systemImage: "text.bubble") {
            VStack {
                Text("ReplierCore \(ReplierCore.version)")
                Button("パネルを開く ⌥⌘R") {
                    container.panelController.show()
                }
                Button("設定とオンボーディング") {
                    container.onboardingWindowController.show()
                }
                Divider()
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}
