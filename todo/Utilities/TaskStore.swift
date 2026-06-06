import Foundation
import SwiftData

enum TaskStore {
    static let appGroupIdentifier = "group.com.owendavisbower.todo"

    static func nextSortOrder(in context: ModelContext, completed: Bool = false) -> Int {
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.isCompleted == completed },
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let maxOrder = (try? context.fetch(descriptor).first?.sortOrder) ?? -1
        return maxOrder + 1
    }

    static func addTask(
        title: String,
        dueDate: Date? = nil,
        in context: ModelContext
    ) -> Task {
        let task = Task(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: nextSortOrder(in: context),
            dueDate: dueDate
        )
        context.insert(task)
        return task
    }

    static func complete(_ task: Task) {
        task.isCompleted = true
        task.completedAt = Date()
    }

    static func uncomplete(_ task: Task, in context: ModelContext) {
        task.isCompleted = false
        task.completedAt = nil
        task.sortOrder = nextSortOrder(in: context)
    }

    static func applySortOrder(to tasks: [Task]) {
        for (index, task) in tasks.enumerated() {
            task.sortOrder = index
        }
    }

    static func update(_ task: Task, title: String, dueDate: Date?) {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = dueDate
    }

    static func delete(_ task: Task, in context: ModelContext) {
        context.delete(task)
    }

    static func findTask(id: UUID, in context: ModelContext) -> Task? {
        let taskID = id
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.id == taskID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func activeTasks(withIDs ids: [UUID], in context: ModelContext) -> [Task] {
        guard !ids.isEmpty else { return [] }

        let idSet = Set(ids)
        let tasksByID = Dictionary(
            uniqueKeysWithValues: activeTasks(in: context)
                .filter { idSet.contains($0.id) }
                .map { ($0.id, $0) }
        )
        return ids.compactMap { tasksByID[$0] }
    }

    static func activeTasks(in context: ModelContext) -> [Task] {
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func clearCompleted(in context: ModelContext) {
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.isCompleted }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            context.delete(task)
        }
    }
}
