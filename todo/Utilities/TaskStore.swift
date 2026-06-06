import Foundation
import SwiftData
import SwiftUI

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

    static func reorder(_ tasks: [Task], from source: IndexSet, to destination: Int) {
        var ordered = tasks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in ordered.enumerated() {
            task.sortOrder = index
        }
    }

    static func findTask(id: UUID, in context: ModelContext) -> Task? {
        let taskID = id
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.id == taskID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func findTask(matching title: String, in context: ModelContext) -> Task? {
        let search = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return nil }

        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { !$0.isCompleted }
        )
        guard let tasks = try? context.fetch(descriptor) else { return nil }

        if let exact = tasks.first(where: { $0.title.lowercased() == search }) {
            return exact
        }
        if let contains = tasks.first(where: { $0.title.lowercased().contains(search) }) {
            return contains
        }
        return tasks.min(by: { levenshtein($0.title.lowercased(), search) < levenshtein($1.title.lowercased(), search) })
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

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var matrix = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)

        for i in 0...left.count { matrix[i][0] = i }
        for j in 0...right.count { matrix[0][j] = j }

        for i in 1...left.count {
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        return matrix[left.count][right.count]
    }
}
