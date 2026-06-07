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

    var isDragging: Bool { draggingTaskID != nil }
    var onSettledDisplayTasks: (([Task]?) -> Void)?

    func handleDragChanged(
        task: Task,
        at index: Int,
        translation: CGFloat,
        listTasks: [Task],
        rowFrames: [UUID: CGRect],
        allowsReorder: Bool
    ) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
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
        listTasks: [Task],
        rowFrames: [UUID: CGRect],
        allowsReorder: Bool
    ) {
        guard allowsReorder, draggingTaskID == task.id else {
            onSettledDisplayTasks?(nil)
            resetDragState()
            return
        }

        defer { impact(.light) }

        guard
            let source = dragSourceIndex,
            let target = dragTargetIndex,
            source != target
        else {
            settle(reorderedTasks: nil, settleTranslation: 0)
            return
        }

        let settleTranslation = settleTranslation(
            from: source,
            to: target,
            listTasks: listTasks,
            rowFrames: rowFrames
        )

        var ordered = listTasks
        ordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: target > source ? target + 1 : target
        )

        settle(reorderedTasks: ordered, settleTranslation: settleTranslation)
    }

    func rowLayout(
        at index: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> (shift: CGFloat, zIndex: Double) {
        let shift = rowShift(at: index, listTasks: listTasks, rowFrames: rowFrames)
        let zIndex: Double
        if draggingTaskID == listTasks[index].id {
            zIndex = 2
        } else if shift != 0 {
            zIndex = 1
        } else {
            zIndex = 0
        }
        return (shift, zIndex)
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
                    TaskStore.applySortOrder(to: reorderedTasks)
                    self.onSettledDisplayTasks?(reorderedTasks)
                } else {
                    self.onSettledDisplayTasks?(nil)
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

    private func rowShift(
        at index: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect],
        target: Int? = nil
    ) -> CGFloat {
        guard
            let source = dragSourceIndex,
            let resolvedTarget = target ?? dragTargetIndex,
            source != resolvedTarget,
            draggingTaskID != listTasks[index].id
        else { return 0 }

        if source < resolvedTarget, index > source, index <= resolvedTarget {
            return -rowGap(from: index - 1, to: index, listTasks: listTasks, rowFrames: rowFrames)
        }
        if source > resolvedTarget, index >= resolvedTarget, index < source {
            return rowGap(from: index, to: index + 1, listTasks: listTasks, rowFrames: rowFrames)
        }
        return 0
    }

    private func settleTranslation(
        from source: Int,
        to target: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> CGFloat {
        guard
            let sourceFrame = frame(for: source, in: listTasks, rowFrames: rowFrames),
            let targetFrame = frame(for: target, in: listTasks, rowFrames: rowFrames)
        else { return 0 }
        return targetFrame.minY - sourceFrame.minY
    }

    private func rowGap(
        from lowerIndex: Int,
        to upperIndex: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> CGFloat {
        guard
            let lowerFrame = frame(for: lowerIndex, in: listTasks, rowFrames: rowFrames),
            let upperFrame = frame(for: upperIndex, in: listTasks, rowFrames: rowFrames)
        else { return 0 }
        return upperFrame.minY - lowerFrame.minY
    }

    private func frame(for index: Int, in listTasks: [Task], rowFrames: [UUID: CGRect]) -> CGRect? {
        guard listTasks.indices.contains(index) else { return nil }
        return rowFrames[listTasks[index].id]
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
