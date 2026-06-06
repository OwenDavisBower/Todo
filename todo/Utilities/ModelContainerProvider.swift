import SwiftData

enum ModelContainerProvider {
    static let shared: ModelContainer = {
        let schema = Schema([Task.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(TaskStore.appGroupIdentifier),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            print("ModelContainer creation failed: \(error)")
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
