import SwiftUI

struct CustomTaskListView: View {
    let tasks: [Task]
    let filter: TaskFilter
    let allowsReorder: Bool
    var showAddRow = false
    var autofocusAddRow = false
    let onEdit: (Task) -> Void
    let onComplete: (Task) -> Void
    let onRestore: (Task) -> Void
    let onDelete: (Task) -> Void
    let onAddTask: (String) -> Void
    let onDismissAddRow: () -> Void

    @State private var draggingTaskID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragSourceIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var isSettlingReorder = false
    @State private var frozenTasks: [Task]?
    @State private var isRemovingTask = false
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var dragStartHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var moveHaptic = UIImpactFeedbackGenerator(style: .soft)
    @State private var dragEndHaptic = UIImpactFeedbackGenerator(style: .light)
    @State private var keyboardHeight: CGFloat = 0

    private let rowSpacing: CGFloat = 12
    private let listCoordinateSpace = "taskList"
    private let addRowID = "addTaskRow"

    private var listTasks: [Task] { frozenTasks ?? tasks }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    listContent
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
                        .background(AppTheme.background)
                }
                .background(AppTheme.background.ignoresSafeArea())
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollDisabled(draggingTaskID != nil)
                .coordinateSpace(name: listCoordinateSpace)
                .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
                .onChange(of: showAddRow) { _, isShowing in
                    if isShowing {
                        scrollToAddRow(using: proxy)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    guard
                        let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                    else { return }
                    keyboardHeight = frame.height
                    if showAddRow {
                        scrollToAddRow(using: proxy)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardHeight = 0
                }
            }
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
                ForEach(Array(listTasks.enumerated()), id: \.element.id) { index, task in
                    TaskRowView(
                        task: task,
                        filter: filter,
                        showDragHandle: allowsReorder,
                        isDragging: draggingTaskID == task.id,
                        isSettling: isSettlingReorder,
                        reorderOffset: draggingTaskID == task.id ? dragTranslation : 0,
                        reorderShift: rowShift(at: index),
                        bottomSpacing: index < listTasks.count - 1 ? rowSpacing : 0,
                        listCoordinateSpace: listCoordinateSpace,
                        onTap: { onEdit(task) },
                        onComplete: { commitRemoval { onComplete(task) } },
                        onRestore: { commitRemoval { onRestore(task) } },
                        onDelete: { commitRemoval { onDelete(task) } },
                        onCollapseStarted: { freezeForRemoval() },
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
                    .zIndex(reorderZIndex(for: index, task: task))
                }

                if showAddRow {
                    if !listTasks.isEmpty {
                        Color.clear.frame(height: rowSpacing)
                    }

                    VStack(spacing: 0) {
                        AddTaskRowView(
                            autofocus: autofocusAddRow,
                            onSubmit: onAddTask,
                            onDismissWhenEmpty: onDismissAddRow
                        )

                        if keyboardHeight > 0 {
                            AppTheme.background
                                .frame(height: rowSpacing)
                        }
                    }
                    .id(addRowID)
                }

                Spacer(minLength: 0)
            }
        .onChange(of: tasks.map(\.id)) { _, newIDs in
            if let frozenTasks, frozenTasks.map(\.id) == newIDs {
                self.frozenTasks = nil
            } else if draggingTaskID == nil, !isSettlingReorder, !isRemovingTask {
                frozenTasks = nil
            }
        }
    }

    private func scrollToAddRow(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(addRowID, anchor: .bottom)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(addRowID, anchor: .bottom)
                }
            }
        }
    }

    private func handleReorderDrag(task: Task, at index: Int, translation: CGFloat) {
        guard allowsReorder else { return }

        if draggingTaskID == nil {
            frozenTasks = tasks
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

        for (index, task) in listTasks.enumerated() {
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

    private func reorderZIndex(for index: Int, task: Task) -> Double {
        if draggingTaskID == task.id { return 2 }
        if rowShift(at: index) != 0 { return 1 }
        return 0
    }

    private func rowShift(at index: Int, target: Int? = nil) -> CGFloat {
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

    private func endReorderDrag(task: Task) {
        guard allowsReorder, draggingTaskID == task.id else {
            frozenTasks = nil
            resetReorderState()
            return
        }

        defer { impact(dragEndHaptic) }

        guard
            let source = dragSourceIndex,
            let target = dragTargetIndex
        else {
            settleAndReset(reorderedTasks: nil)
            return
        }

        let settleTranslation = CGFloat(target - source) * rowDisplacement(for: source)

        guard source != target else {
            settleAndReset(reorderedTasks: nil, settleTranslation: 0)
            return
        }

        var ordered = listTasks
        ordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: target > source ? target + 1 : target
        )

        settleAndReset(reorderedTasks: ordered, settleTranslation: settleTranslation)
    }

    private func rowDisplacement(for sourceIndex: Int) -> CGFloat {
        let taskID = listTasks[sourceIndex].id
        if let frame = rowFrames[taskID] {
            return frame.height
        }
        if let frame = rowFrames.values.first {
            return frame.height
        }
        return 0
    }

    private func settleAndReset(reorderedTasks: [Task]?, settleTranslation: CGFloat = 0) {
        isSettlingReorder = true

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragTranslation = settleTranslation
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let reorderedTasks {
                    frozenTasks = reorderedTasks
                    TaskStore.applySortOrder(to: reorderedTasks)
                }
                resetReorderState()
                isSettlingReorder = false
            }
        }
    }

    private func freezeForRemoval() {
        guard frozenTasks == nil else { return }
        frozenTasks = tasks
        isRemovingTask = true
    }

    private func commitRemoval(action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            action()
            frozenTasks = nil
            isRemovingTask = false
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
