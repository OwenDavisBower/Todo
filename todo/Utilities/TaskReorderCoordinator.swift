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

    private var cachedShifts: [UUID: CGFloat] = [:]
    private var shiftCacheKey: ShiftCacheKey?

    var isDragging: Bool { draggingTaskID != nil }
    var isInteractionActive: Bool { isDragging || isSettling }

    func presentation(
        for task: Task,
        at index: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> ReorderRowPresentation {
        updateShiftCache(listTasks: listTasks, rowFrames: rowFrames)

        let isDraggingRow = draggingTaskID == task.id
        let shift = cachedShifts[task.id] ?? 0
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
        invalidateShiftCache()
        impact(.soft)
    }

    func endDrag(
        task: Task,
        listTasks: [Task],
        rowFrames: [UUID: CGRect],
        allowsReorder: Bool,
        onSettled: @escaping ([Task]?) -> Void
    ) {
        guard allowsReorder, draggingTaskID == task.id else {
            cancelDrag(onSettled: onSettled)
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

        settle(
            reorderedTasks: reorderedTasks,
            settleTranslation: finalTranslation,
            onSettled: onSettled
        )
    }

    private func settle(
        reorderedTasks: [Task]?,
        settleTranslation: CGFloat,
        onSettled: @escaping ([Task]?) -> Void
    ) {
        isSettling = true

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragTranslation = settleTranslation
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onSettled(reorderedTasks)
                self.resetDragState()
                self.isSettling = false
            }
        }
    }

    private func cancelDrag(onSettled: @escaping ([Task]?) -> Void) {
        onSettled(nil)
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

            let midY = frame.midY + computeRowShift(
                at: index,
                source: source,
                target: target,
                listTasks: listTasks,
                rowFrames: rowFrames
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

    private func updateShiftCache(listTasks: [Task], rowFrames: [UUID: CGRect]) {
        guard
            let source = dragSourceIndex,
            let target = dragTargetIndex,
            source != target
        else {
            if !cachedShifts.isEmpty {
                cachedShifts = [:]
                shiftCacheKey = nil
            }
            return
        }

        let framePositions = listTasks.map { rowFrames[$0.id]?.minY ?? 0 }
        let key = ShiftCacheKey(source: source, target: target, framePositions: framePositions)
        guard key != shiftCacheKey else { return }

        shiftCacheKey = key
        cachedShifts = Dictionary(uniqueKeysWithValues: listTasks.enumerated().map { index, task in
            (
                task.id,
                computeRowShift(
                    at: index,
                    source: source,
                    target: target,
                    listTasks: listTasks,
                    rowFrames: rowFrames
                )
            )
        })
    }

    private func invalidateShiftCache() {
        cachedShifts = [:]
        shiftCacheKey = nil
    }

    private func computeRowShift(
        at index: Int,
        source: Int,
        target: Int,
        listTasks: [Task],
        rowFrames: [UUID: CGRect]
    ) -> CGFloat {
        guard
            source != target,
            draggingTaskID != listTasks[index].id
        else { return 0 }

        if source < target, index > source, index <= target {
            return -rowGap(from: index - 1, to: index, listTasks: listTasks, rowFrames: rowFrames)
        }
        if source > target, index >= target, index < source {
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
        invalidateShiftCache()
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

private struct ShiftCacheKey: Equatable {
    let source: Int
    let target: Int
    let framePositions: [CGFloat]
}
