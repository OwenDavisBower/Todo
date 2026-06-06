import SwiftUI

struct CustomTaskListView: View {
    let tasks: [Task]
    let filter: TaskFilter
    let allowsReorder: Bool
    let onEdit: (Task) -> Void
    let onComplete: (Task) -> Void
    let onRestore: (Task) -> Void
    let onDelete: (Task) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var draggingTaskID: UUID?
    @State private var reorderDragOffset: CGFloat = 0
    @State private var rowFrames: [UUID: CGRect] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    TaskRowView(
                        task: task,
                        filter: filter,
                        showDragHandle: allowsReorder,
                        isDragging: draggingTaskID == task.id,
                        reorderOffset: draggingTaskID == task.id ? reorderDragOffset : 0,
                        onTap: { onEdit(task) },
                        onComplete: { onComplete(task) },
                        onRestore: { onRestore(task) },
                        onDelete: { onDelete(task) },
                        onReorderDragChanged: { translation in
                            handleReorderDrag(task: task, fromIndex: index, translation: translation)
                        },
                        onReorderDragEnded: {
                            endReorderDrag(task: task, fromIndex: index)
                        }
                    )
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: RowFrameKey.self,
                                value: [task.id: geometry.frame(in: .named("taskList"))]
                            )
                        }
                    }
                    .zIndex(draggingTaskID == task.id ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .coordinateSpace(name: "taskList")
        .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
    }

    private func handleReorderDrag(task: Task, fromIndex: Int, translation: CGFloat) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
            draggingTaskID = task.id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        reorderDragOffset = translation
    }

    private func endReorderDrag(task: Task, fromIndex: Int) {
        guard allowsReorder, draggingTaskID == task.id else {
            draggingTaskID = nil
            reorderDragOffset = 0
            return
        }

        guard let draggedFrame = rowFrames[task.id] else {
            draggingTaskID = nil
            reorderDragOffset = 0
            return
        }

        let draggedCenterY = draggedFrame.midY + reorderDragOffset
        var targetIndex = fromIndex

        for (index, otherTask) in tasks.enumerated() {
            guard otherTask.id != task.id, let frame = rowFrames[otherTask.id] else { continue }

            if draggedCenterY < frame.midY, index < fromIndex {
                targetIndex = index
                break
            }
            if draggedCenterY > frame.midY, index > fromIndex {
                targetIndex = index
            }
        }

        if targetIndex != fromIndex {
            let destination = targetIndex > fromIndex ? targetIndex + 1 : targetIndex
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                onReorder(IndexSet(integer: fromIndex), destination)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            draggingTaskID = nil
            reorderDragOffset = 0
        }
    }
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
