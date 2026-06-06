import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Task> { $0.isCompleted }) private var completedTasks: [Task]

    var body: some View {
        List {
            Section("Data") {
                Button("Clear Completed Tasks", role: .destructive) {
                    withAnimation {
                        TaskStore.clearCompleted(in: modelContext)
                    }
                }
                .disabled(completedTasks.isEmpty)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: Task.self, inMemory: true)
}
