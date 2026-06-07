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
    let onAddTask: (String, Date?) -> Void
    let onDismissAddRow: () -> Void

    @State private var reorder = TaskReorderCoordinator()
    @State private var frozenTasks: [Task]?
    @State private var isRemovingTask = false
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var keyboardHeight: CGFloat = 0

    private let rowSpacing: CGFloat = 12
    private let listCoordinateSpace = "taskList"
    private let addRowID = "addTaskRow"

    private var listTasks: [Task] {
        reorder.displayTasks(fallback: frozenTasks ?? tasks)
    }

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
                .scrollDisabled(reorder.isDragging)
                .coordinateSpace(name: listCoordinateSpace)
                .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
                .onChange(of: showAddRow) { _, isShowing in
                    if isShowing {
                        scrollToAddRow(using: proxy)
                    }
                }
                .onChange(of: tasks.count) { oldCount, newCount in
                    if showAddRow, newCount > oldCount {
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
                        isDragging: reorder.draggingTaskID == task.id,
                        isSettling: reorder.isSettling,
                        reorderOffset: reorder.draggingTaskID == task.id ? reorder.dragTranslation : 0,
                        reorderShift: reorder.rowShift(at: index, listTasks: listTasks, rowFrames: rowFrames),
                        bottomSpacing: index < listTasks.count - 1 ? rowSpacing : 0,
                        listCoordinateSpace: listCoordinateSpace,
                        onTap: { onEdit(task) },
                        onComplete: { commitRemoval { onComplete(task) } },
                        onRestore: { commitRemoval { onRestore(task) } },
                        onDelete: { commitRemoval { onDelete(task) } },
                        onCollapseStarted: { freezeForRemoval() },
                        onReorderDragChanged: { translation in
                            reorder.handleDragChanged(
                                task: task,
                                at: index,
                                translation: translation,
                                tasks: tasks,
                                rowFrames: rowFrames,
                                allowsReorder: allowsReorder
                            )
                        },
                        onReorderDragEnded: {
                            reorder.endDrag(
                                task: task,
                                tasks: tasks,
                                rowFrames: rowFrames,
                                allowsReorder: allowsReorder
                            )
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
                    .zIndex(reorder.reorderZIndex(for: index, task: task, listTasks: listTasks, rowFrames: rowFrames))
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showAddRow)
        .onChange(of: tasks.map(\.id)) { _, newIDs in
            if let reorderSnapshot = reorder.snapshotTasks, reorderSnapshot.map(\.id) == newIDs {
                reorder.clearSnapshot()
            } else if let frozenTasks, frozenTasks.map(\.id) == newIDs {
                self.frozenTasks = nil
            } else if !reorder.isDragging, !reorder.isSettling, !isRemovingTask {
                reorder.clearSnapshot()
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

    private func freezeForRemoval() {
        guard frozenTasks == nil, reorder.snapshotTasks == nil else { return }
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
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
