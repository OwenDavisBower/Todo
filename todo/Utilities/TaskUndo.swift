import SwiftData
import SwiftUI

struct TaskSnapshot {
    let id: UUID
    let title: String
    let sortOrder: Int
    let dueDate: Date?
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?

    init(_ task: Task) {
        id = task.id
        title = task.title
        sortOrder = task.sortOrder
        dueDate = task.dueDate
        isCompleted = task.isCompleted
        createdAt = task.createdAt
        completedAt = task.completedAt
    }
}

enum TaskUndoAction {
    case completion(taskID: UUID)
    case deletion(TaskSnapshot)
    case restoration(taskID: UUID, completedAt: Date?)
}

struct TaskUndoOffer {
    let message: String
    let action: TaskUndoAction
}

@Observable
final class TaskUndoController {
    private(set) var offer: TaskUndoOffer?
    private var autoDismissID = UUID()

    private static let autoDismissDelay: TimeInterval = 5
    private static let animation = Animation.spring(response: 0.38, dampingFraction: 0.82)

    func present(message: String, action: TaskUndoAction) {
        invalidateAutoDismiss()
        withAnimation(Self.animation) {
            offer = TaskUndoOffer(message: message, action: action)
        }
        scheduleAutoDismiss()
    }

    func dismiss() {
        invalidateAutoDismiss()
        withAnimation(Self.animation) {
            offer = nil
        }
    }

    func undo(in context: ModelContext) {
        guard let action = offer?.action else { return }
        invalidateAutoDismiss()

        switch action {
        case .completion(let taskID):
            TaskStore.undoCompletion(taskID: taskID, in: context)
        case .deletion(let snapshot):
            TaskStore.restore(snapshot, in: context)
        case .restoration(let taskID, let completedAt):
            TaskStore.undoRestoration(taskID: taskID, completedAt: completedAt, in: context)
        }

        withAnimation(Self.animation) {
            offer = nil
        }
    }

    private func scheduleAutoDismiss() {
        let dismissID = UUID()
        autoDismissID = dismissID
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoDismissDelay) { [weak self] in
            guard let self, self.autoDismissID == dismissID else { return }
            self.dismiss()
        }
    }

    private func invalidateAutoDismiss() {
        autoDismissID = UUID()
    }
}
