import SwiftUI
import UIKit

@Observable
@MainActor
final class TaskReorderCoordinator {
    private(set) var draggingTaskID: UUID?
    private(set) var dragTranslation: CGFloat = 0
    private(set) var dragSourceIndex: Int?
    private(set) var dragTargetIndex: Int?
    private(set) var isSettling = false
    private(set) var snapshotTasks: [Task]?

    var isDragging: Bool { draggingTaskID != nil }

    func displayTasks(fallback: [Task]) -> [Task] {
        snapshotTasks ?? fallback
    }

    func clearSnapshot() {
        snapshotTasks = nil
    }

    func handleDragChanged(
        task: Task,
        at index: Int,
        translation: CGFloat,
        tasks: [Task],
        rowFrames: [UUID: CGRect],
        allowsReorder: Bool
    ) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
            snapshotTasks = tasks
            draggingTaskID = task.id
            dragSourceIndex = index
            dragTargetIndex = index
            impact(.medium)
        }

        dragTranslation = translation

        guard
            let source = dragSourceIndex,
            let draggedFrame = rowFrames[task.id]
        else { return }

        let listTasks = displayTasks(fallback: tasks)
        let fingerY = draggedFrame.midY + translation
        let newTarget = insertionIndex(
            fingerY: fingerY,
            source: source,
            listTasks: listTasks,
            rowFrames: rowFrames
        )

        guard newTarget != dragTargetIndex else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.1)) {
            dragTargetIndex = newTarget
        }
        impact(.soft)
    }

    func endDrag(
        task: Task,
        tasks: [Task],
        rowFrames: [UUID: CGRect],
        allowsReorder: Bool
    ) {
        guard allowsReorder, draggingTaskID == task.id else {
            snapshotTasks = nil
            resetDragState()
            return
        }

        defer { impact(.light) }

        guard
            let source = dragSourceIndex,
            let target = dragTargetIndex
        else {
            settle(reorderedTasks: nil, settleTranslation: 0)
            return
        }

        let listTasks = displayTasks(fallback: tasks)
        let settleTranslation = CGFloat(target - source) * rowDisplacement(
            for: source,
            listTasks: listTasks,
            rowFrames: rowFrames
        )

        guard source != target else {
            settle(reorderedTasks: nil, settleTranslation: 0)
            return
        }

        var ordered = listTasks
        ordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: target > source ? target + 1 : target
        )

        settle(reorderedTasks: ordered, settleTranslation: settleTranslation)
    }

    func rowShift(
        at index: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect],
        target: Int? = nil
    ) -> CGFloat {
        guard
            let source = dragSourceIndex,
            let resolvedTarget = target ?? dragTargetIndex,
            source != resolvedTarget,
            draggingTaskID != listTasks[index].id,
            let sourceFrame = rowFrames[listTasks[source].id]
        else { return 0 }

        let displacement = sourceFrame.height

        if source < resolvedTarget, index > source, index <= resolvedTarget {
            return -displacement
        }
        if source > resolvedTarget, index >= resolvedTarget, index < source {
            return displacement
        }
        return 0
    }

    func reorderZIndex(for index: Int, task: Task, listTasks: [Task], rowFrames: [UUID: CGRect]) -> Double {
        if draggingTaskID == task.id { return 2 }
        if rowShift(at: index, listTasks: listTasks, rowFrames: rowFrames) != 0 { return 1 }
        return 0
    }

    private func settle(reorderedTasks: [Task]?, settleTranslation: CGFloat) {
        isSettling = true

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragTranslation = settleTranslation
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let reorderedTasks {
                    self.snapshotTasks = reorderedTasks
                    TaskStore.applySortOrder(to: reorderedTasks)
                }
                self.resetDragState()
                self.isSettling = false
            }
        }
    }

    private func insertionIndex(
        fingerY: CGFloat,
        source: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> Int {
        var target = source

        for (index, task) in listTasks.enumerated() {
            guard index != source, let frame = rowFrames[task.id] else { continue }

            let midY = frame.midY + rowShift(
                at: index,
                listTasks: listTasks,
                rowFrames: rowFrames,
                target: target
            )

            if index < source, fingerY < midY {
                target = index
                break
            }
            if index > source, fingerY > midY {
                target = index
            }
        }

        return target
    }

    private func rowDisplacement(
        for sourceIndex: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> CGFloat {
        let taskID = listTasks[sourceIndex].id
        if let frame = rowFrames[taskID] {
            return frame.height
        }
        if let frame = rowFrames.values.first {
            return frame.height
        }
        return 0
    }

    private func resetDragState() {
        draggingTaskID = nil
        dragTranslation = 0
        dragSourceIndex = nil
        dragTargetIndex = nil
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
