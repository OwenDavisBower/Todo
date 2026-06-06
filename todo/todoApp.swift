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
                .tint(AppTheme.ink)
        }
        .modelContainer(ModelContainerProvider.shared)
    }
}
