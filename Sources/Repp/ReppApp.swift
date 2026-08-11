import SwiftUI
import ReppCore

@main
struct ReppApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("repp", systemImage: "text.bubble") {
            VStack {
                Text("ReppCore \(ReppCore.version)")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}
