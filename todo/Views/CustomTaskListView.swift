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
    @State private var reorderDragOffset: CGFloat = 0
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var liveTaskIDs: [UUID]?
    @State private var dragCurrentIndex: Int?
    @State private var cachedTasksByID: [UUID: Task]?

    private let rowSpacing: CGFloat = 12

    private var displayTasks: [Task] {
        guard let liveTaskIDs else { return tasks }
        let lookup = cachedTasksByID ?? Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        return liveTaskIDs.compactMap { lookup[$0] }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: rowSpacing) {
                ForEach(displayTasks) { task in
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
                            handleReorderDrag(task: task, translation: translation)
                        },
                        onReorderDragEnded: {
                            endReorderDrag(task: task)
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
        .scrollDisabled(draggingTaskID != nil)
        .coordinateSpace(name: "taskList")
        .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
    }

    private func handleReorderDrag(task: Task, translation: CGFloat) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
            cachedTasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
            liveTaskIDs = tasks.map(\.id)
            dragCurrentIndex = displayTasks.firstIndex { $0.id == task.id }
            draggingTaskID = task.id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        reorderDragOffset = translation

        guard
            let currentIndex = dragCurrentIndex,
            let draggedFrame = rowFrames[task.id]
        else { return }

        let draggedCenterY = draggedFrame.midY + reorderDragOffset
        var targetIndex = currentIndex

        for (index, otherTask) in displayTasks.enumerated() {
            guard otherTask.id != task.id, let frame = rowFrames[otherTask.id] else { continue }

            if index < currentIndex, draggedCenterY < frame.midY {
                targetIndex = index
                break
            }
            if index > currentIndex, draggedCenterY > frame.midY {
                targetIndex = index
            }
        }

        guard targetIndex != currentIndex else { return }
        moveTask(from: currentIndex, to: targetIndex, draggedFrame: draggedFrame)
        dragCurrentIndex = targetIndex
    }

    private func moveTask(from: Int, to: Int, draggedFrame: CGRect) {
        guard var ids = liveTaskIDs else { return }

        let movedID = ids.remove(at: from)
        ids.insert(movedID, at: to)
        reorderDragOffset -= rowDisplacement(from: from, to: to)

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.1)) {
            liveTaskIDs = ids
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func rowDisplacement(from: Int, to: Int) -> CGFloat {
        guard from != to else { return 0 }

        if to > from {
            return (from + 1 ... to).reduce(into: CGFloat.zero) { total, index in
                let task = displayTasks[index]
                let height = rowFrames[task.id]?.height ?? 0
                total += height + rowSpacing
            }
        }

        return (to ..< from).reduce(into: CGFloat.zero) { total, index in
            let task = displayTasks[index]
            let height = rowFrames[task.id]?.height ?? 0
            total -= height + rowSpacing
        }
    }

    private func endReorderDrag(task: Task) {
        defer { resetReorderState() }

        guard allowsReorder, draggingTaskID == task.id, liveTaskIDs != nil else { return }

        let ordered = displayTasks
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            TaskStore.applySortOrder(to: ordered)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func resetReorderState() {
        draggingTaskID = nil
        reorderDragOffset = 0
        liveTaskIDs = nil
        dragCurrentIndex = nil
        cachedTasksByID = nil
    }
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
