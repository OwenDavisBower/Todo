import SwiftUI
import SwiftData
import AppIntents

@main
struct todoApp: App {
    init() {
        TodoShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ModelContainerProvider.shared)
    }
}
