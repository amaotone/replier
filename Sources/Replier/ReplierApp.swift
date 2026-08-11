import SwiftUI
import ReplierCore

@main
struct ReplierApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("replier", systemImage: "text.bubble") {
            VStack {
                Text("ReplierCore \(ReplierCore.version)")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}
