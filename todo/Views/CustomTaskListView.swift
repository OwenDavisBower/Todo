import SwiftUI

struct CustomTaskListView: View {
    let tasks: [Task]
    let filter: TaskFilter
    let allowsReorder: Bool
    let onEdit: (Task) -> Void
    let onComplete: (Task) -> Void
    let onRestore: (Task) -> Void
    let onDelete: (Task) -> Void

    @State private var draggingTaskID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragSourceIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var dragStartHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var moveHaptic = UIImpactFeedbackGenerator(style: .soft)
    @State private var dragEndHaptic = UIImpactFeedbackGenerator(style: .light)

    private let rowSpacing: CGFloat = 12
    private let listCoordinateSpace = "taskList"

    var body: some View {
        ScrollView {
            VStack(spacing: rowSpacing) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    TaskRowView(
                        task: task,
                        filter: filter,
                        showDragHandle: allowsReorder,
                        isDragging: draggingTaskID == task.id,
                        reorderOffset: dragTranslation,
                        reorderShift: rowShift(at: index),
                        listCoordinateSpace: listCoordinateSpace,
                        onTap: { onEdit(task) },
                        onComplete: { onComplete(task) },
                        onRestore: { onRestore(task) },
                        onDelete: { onDelete(task) },
                        onReorderDragChanged: { translation in
                            handleReorderDrag(task: task, at: index, translation: translation)
                        },
                        onReorderDragEnded: {
                            endReorderDrag(task: task)
                        }
                    )
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: RowFrameKey.self,
                                value: [task.id: geometry.frame(in: .named(listCoordinateSpace))]
                            )
                        }
                    }
                    .zIndex(draggingTaskID == task.id ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDisabled(draggingTaskID != nil)
        .coordinateSpace(name: listCoordinateSpace)
        .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
    }

    private func handleReorderDrag(task: Task, at index: Int, translation: CGFloat) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
            draggingTaskID = task.id
            dragSourceIndex = index
            dragTargetIndex = index
            impact(dragStartHaptic)
        }

        dragTranslation = translation

        guard
            let source = dragSourceIndex,
            let draggedFrame = rowFrames[task.id]
        else { return }

        let fingerY = draggedFrame.midY + translation
        let newTarget = insertionIndex(fingerY: fingerY, source: source)

        guard newTarget != dragTargetIndex else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.1)) {
            dragTargetIndex = newTarget
        }
        impact(moveHaptic)
    }

    private func insertionIndex(fingerY: CGFloat, source: Int) -> Int {
        var target = source

        for (index, task) in tasks.enumerated() {
            guard index != source, let frame = rowFrames[task.id] else { continue }

            let midY = frame.midY + rowShift(at: index, target: target)

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

    private func rowShift(at index: Int, target: Int? = nil) -> CGFloat {
        guard
            let source = dragSourceIndex,
            let resolvedTarget = target ?? dragTargetIndex,
            source != resolvedTarget,
            draggingTaskID != tasks[index].id,
            let sourceFrame = rowFrames[tasks[source].id]
        else { return 0 }

        let displacement = sourceFrame.height + rowSpacing

        if source < resolvedTarget, index > source, index <= resolvedTarget {
            return -displacement
        }
        if source > resolvedTarget, index >= resolvedTarget, index < source {
            return displacement
        }
        return 0
    }

    private func endReorderDrag(task: Task) {
        guard allowsReorder, draggingTaskID == task.id else {
            resetReorderState()
            return
        }

        defer { impact(dragEndHaptic) }

        guard
            let source = dragSourceIndex,
            let target = dragTargetIndex,
            source != target
        else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                resetReorderState()
            }
            return
        }

        var ordered = tasks
        ordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: target > source ? target + 1 : target
        )

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            TaskStore.applySortOrder(to: ordered)
            resetReorderState()
        }
    }

    private func impact(_ generator: UIImpactFeedbackGenerator) {
        generator.prepare()
        generator.impactOccurred()
    }

    private func resetReorderState() {
        draggingTaskID = nil
        dragTranslation = 0
        dragSourceIndex = nil
        dragTargetIndex = nil
    }
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
