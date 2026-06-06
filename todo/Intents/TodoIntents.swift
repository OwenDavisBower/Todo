import AppIntents
import SwiftData
import SwiftUI

struct TodoTaskEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")
    static var defaultQuery = TodoTaskEntityQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct TodoTaskEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [TodoTaskEntity.ID]) async throws -> [TodoTaskEntity] {
        let context = ModelContext(ModelContainerProvider.shared)
        let idSet = Set(identifiers)
        return activeTasks(in: context)
            .filter { idSet.contains($0.id) }
            .map { TodoTaskEntity(id: $0.id, title: $0.title) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [TodoTaskEntity] {
        let context = ModelContext(ModelContainerProvider.shared)
        let search = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else {
            return try await suggestedEntities()
        }

        return TaskTitleMatching.matchingTasks(activeTasks(in: context), search: string)
            .map { TodoTaskEntity(id: $0.id, title: $0.title) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TodoTaskEntity] {
        let context = ModelContext(ModelContainerProvider.shared)
        return activeTasks(in: context).map { TodoTaskEntity(id: $0.id, title: $0.title) }
    }

    @MainActor
    private func activeTasks(in context: ModelContext) -> [Task] {
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to your list.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Due Date")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title)") {
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = ModelContext(ModelContainerProvider.shared)
        let task = TaskStore.addTask(title: title, dueDate: dueDate, in: context)
        try context.save()

        let summary: String
        if let dueDate = task.dueDate {
            let label = DueDateFormatting.label(for: dueDate)
            summary = "Added \"\(task.title)\" due \(label.text)"
        } else {
            summary = "Added \"\(task.title)\""
        }

        return .result(value: summary)
    }
}

struct DeleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Task"
    static var description = IntentDescription("Remove a task from your list.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var task: TodoTaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = ModelContext(ModelContainerProvider.shared)

        guard let model = TaskStore.findTask(id: task.id, in: context) else {
            throw IntentError.taskNotFound(task.title)
        }

        let deletedTitle = model.title
        TaskStore.delete(model, in: context)
        try context.save()

        return .result(value: "Removed \"\(deletedTitle)\"")
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case taskNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .taskNotFound(let title):
            "No active task found matching \"\(title)\""
        }
    }
}

struct TodoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Remind me in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: DeleteTaskIntent(),
            phrases: [
                "Remove \(\.$task) from \(.applicationName)",
            ],
            shortTitle: "Delete Task",
            systemImageName: "trash"
        )
    }
}
