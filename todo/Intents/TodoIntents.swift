import AppIntents
import SwiftData
import SwiftUI

struct TodoTaskEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")
    static var defaultQuery = TodoTaskEntityQuery()

    var id: UUID
    var title: String

    init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }

    init(_ task: Task) {
        self.init(id: task.id, title: task.title)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct TodoTaskEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    private func activeEntities(in context: ModelContext) -> [TodoTaskEntity] {
        TaskStore.activeTasks(in: context).map(TodoTaskEntity.init)
    }

    @MainActor
    func entities(for identifiers: [TodoTaskEntity.ID]) async throws -> [TodoTaskEntity] {
        let context = ModelContainerProvider.makeContext()
        return TaskStore.tasks(withIDs: identifiers, in: context).map(TodoTaskEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [TodoTaskEntity] {
        let context = ModelContainerProvider.makeContext()
        let activeTasks = TaskStore.activeTasks(in: context)
        let normalizedSearch = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedSearch.isEmpty else {
            return activeTasks.map(TodoTaskEntity.init)
        }

        return TaskTitleMatching.matchingTasks(activeTasks, normalizedSearch: normalizedSearch)
            .map(TodoTaskEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [TodoTaskEntity] {
        let context = ModelContainerProvider.makeContext()
        return activeEntities(in: context)
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
        let summary = try ModelContainerProvider.withSavedContext { context in
            let task = TaskStore.addTask(title: title, dueDate: dueDate, in: context)

            if let dueDate = task.dueDate {
                let label = DueDateFormatting.label(for: dueDate)
                return "Added \"\(task.title)\" due \(label.text)"
            }
            return "Added \"\(task.title)\""
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
        let summary = try ModelContainerProvider.withSavedContext { context in
            guard let model = TaskStore.findTask(id: task.id, in: context) else {
                throw IntentError.taskNotFound(task.title)
            }

            let deletedTitle = model.title
            TaskStore.delete(model, in: context)
            return "Removed \"\(deletedTitle)\""
        }

        return .result(value: summary)
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
