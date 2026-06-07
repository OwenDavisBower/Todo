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
    @State private var displayPin: ListDisplayPin?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var keyboardHeight: CGFloat = 0

    private let rowSpacing: CGFloat = 12
    private let listCoordinateSpace = "taskList"
    private let addRowID = "addTaskRow"

    private var listTasks: [Task] {
        displayPin?.tasks ?? tasks
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
                .scrollDisabled(reorder.isInteractionActive)
                .coordinateSpace(name: listCoordinateSpace)
                .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
                .onChange(of: showAddRow) { _, isShowing in
                    if isShowing {
                        scheduleScrollToAddRow(using: proxy)
                    }
                }
                .onChange(of: tasks.count) { oldCount, newCount in
                    if showAddRow, newCount > oldCount {
                        scheduleScrollToAddRow(using: proxy)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    guard
                        let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                    else { return }
                    keyboardHeight = frame.height
                    scheduleScrollToAddRow(using: proxy)
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
                    let rowPresentation = reorder.presentation(
                        for: task,
                        at: index,
                        listTasks: listTasks,
                        rowFrames: rowFrames
                    )

                    TaskRowView(
                        task: task,
                        filter: filter,
                        showDragHandle: allowsReorder,
                        isDragging: rowPresentation.isDragging,
                        isSettling: rowPresentation.isSettling,
                        reorderOffset: rowPresentation.offset,
                        reorderShift: rowPresentation.shift,
                        bottomSpacing: index < listTasks.count - 1 ? rowSpacing : 0,
                        listCoordinateSpace: listCoordinateSpace,
                        onTap: { onEdit(task) },
                        onComplete: { commitRemoval { onComplete(task) } },
                        onRestore: { commitRemoval { onRestore(task) } },
                        onDelete: { commitRemoval { onDelete(task) } },
                        onCollapseStarted: { pinForRemoval() },
                        onReorderDragChanged: { translation in
                            guard displayPin?.reason != .removal else { return }
                            if !reorder.isDragging {
                                displayPin = ListDisplayPin(tasks: listTasks, reason: .reorder)
                            }
                            reorder.handleDragChanged(
                                task: task,
                                at: index,
                                translation: translation,
                                listTasks: listTasks,
                                rowFrames: rowFrames,
                                allowsReorder: allowsReorder
                            )
                        },
                        onReorderDragEnded: {
                            reorder.endDrag(
                                task: task,
                                listTasks: listTasks,
                                rowFrames: rowFrames,
                                allowsReorder: allowsReorder
                            ) { ordered in
                                if let ordered {
                                    TaskStore.applySortOrder(to: ordered)
                                }
                                displayPin = ListDisplayPin.afterReorderSettlement(
                                    ordered,
                                    replacing: displayPin
                                )
                            }
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
                    .zIndex(rowPresentation.zIndex)
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
        .onChange(of: tasks) { _, queryTasks in
            syncDisplayPin(with: queryTasks)
        }
    }

    private func syncDisplayPin(with queryTasks: [Task]) {
        guard let pin = displayPin else { return }

        if ListDisplayPin.matchesTasks(queryTasks, ids: pin.ids) {
            displayPin = nil
            return
        }

        if !reorder.isInteractionActive, pin.reason != .removal {
            displayPin = nil
        }
    }

    /// Scrolls to the add row after layout settles. The row is inserted with animation
    /// and the keyboard shifts content, so a short delay plus a follow-up scroll keeps
    /// the field visible above the keyboard.
    private func scheduleScrollToAddRow(using proxy: ScrollViewProxy) {
        guard showAddRow else { return }

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

    private func pinForRemoval() {
        guard displayPin == nil else { return }
        displayPin = ListDisplayPin(tasks: tasks, reason: .removal)
    }

    private func commitRemoval(action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            action()
            displayPin = nil
        }
    }
}

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
