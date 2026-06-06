import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Task> { !$0.isCompleted },
        sort: \Task.sortOrder
    ) private var activeTasks: [Task]
    @Query(
        filter: #Predicate<Task> { $0.isCompleted },
        sort: \Task.completedAt,
        order: .reverse
    ) private var doneTasks: [Task]

    @State private var filter: TaskFilter = .active
    @State private var isAddSheetExpanded = false
    @State private var editingTask: Task?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(selection: $filter, counts: count(for:))

                Group {
                    switch filter {
                    case .active:
                        taskList(tasks: activeTasks, allowsReorder: true)
                    case .done:
                        taskList(tasks: doneTasks, allowsReorder: false)
                    }
                }
                .overlay {
                    if isAddSheetExpanded {
                        AppTheme.ink.opacity(0.06)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isAddSheetExpanded = false
                            }
                    }
                }
            }
            .themedBackground()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if filter == .active {
                    AddTaskBottomSheet(isExpanded: $isAddSheetExpanded) { title, dueDate in
                        _ = TaskStore.addTask(title: title, dueDate: dueDate, in: modelContext)
                    }
                }
            }
            .onChange(of: filter) { _, _ in
                isAddSheetExpanded = false
            }
            .sheet(item: $editingTask) { task in
                TaskEditSheet(task: task, navigationTitle: "Edit Task") { title, dueDate in
                    TaskStore.update(task, title: title, dueDate: dueDate)
                }
            }
        }
    }

    @ViewBuilder
    private func taskList(tasks: [Task], allowsReorder: Bool) -> some View {
        if tasks.isEmpty {
            EmptyStateView(filter: filter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            CustomTaskListView(
                tasks: tasks,
                filter: filter,
                allowsReorder: allowsReorder,
                onEdit: { editingTask = $0 },
                onComplete: { task in
                    TaskStore.complete(task)
                },
                onRestore: { task in
                    TaskStore.uncomplete(task, in: modelContext)
                },
                onDelete: { task in
                    TaskStore.delete(task, in: modelContext)
                }
            )
        }
    }

    private func count(for filter: TaskFilter) -> Int {
        switch filter {
        case .active: activeTasks.count
        case .done: doneTasks.count
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Task.self, inMemory: true)
}
