import SwiftUI
import UIKit

struct ReorderRowPresentation {
    let isDragging: Bool
    let isSettling: Bool
    let offset: CGFloat
    let shift: CGFloat
    let zIndex: Double
}

@Observable
@MainActor
final class TaskReorderCoordinator {
    private(set) var draggingTaskID: UUID?
    private(set) var dragTranslation: CGFloat = 0
    private(set) var dragSourceIndex: Int?
    private(set) var dragTargetIndex: Int?
    private(set) var isSettling = false

    private var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private var softImpact = UIImpactFeedbackGenerator(style: .soft)

    var isDragging: Bool { draggingTaskID != nil }
    var isInteractionActive: Bool { isDragging || isSettling }
    var onSettledDisplayTasks: (([Task]?) -> Void)?

    func presentation(
        for task: Task,
        at index: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> ReorderRowPresentation {
        let isDraggingRow = draggingTaskID == task.id
        let shift = rowShift(at: index, listTasks: listTasks, rowFrames: rowFrames)
        let zIndex: Double = isDraggingRow ? 2 : (shift != 0 ? 1 : 0)
        return ReorderRowPresentation(
            isDragging: isDraggingRow,
            isSettling: isSettling,
            offset: isDraggingRow ? dragTranslation : 0,
            shift: shift,
            zIndex: zIndex
        )
    }

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
            cancelDrag()
            return
        }

        defer { impact(.light) }

        let reorderedTasks: [Task]?
        let finalTranslation: CGFloat

        if
            let source = dragSourceIndex,
            let target = dragTargetIndex,
            source != target
        {
            finalTranslation = settleTranslation(
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
            reorderedTasks = ordered
        } else {
            reorderedTasks = nil
            finalTranslation = 0
        }

        settle(reorderedTasks: reorderedTasks, settleTranslation: finalTranslation)
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

    private func cancelDrag() {
        onSettledDisplayTasks?(nil)
        resetDragState()
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
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = lightImpact
        case .medium: generator = mediumImpact
        case .soft: generator = softImpact
        default:
            generator = UIImpactFeedbackGenerator(style: style)
        }
        generator.prepare()
        generator.impactOccurred()
    }
}
