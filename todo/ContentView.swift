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
    @State private var isShowingAddRow = false
    @State private var shouldAutofocusAddRow = false
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
            }
            .themedBackground()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                if filter == .active, !isShowingAddRow {
                    addTaskButton
                }
            }
            .onChange(of: filter) { _, _ in
                isShowingAddRow = false
                shouldAutofocusAddRow = false
            }
            .sheet(item: $editingTask) { task in
                TaskEditSheet(task: task, navigationTitle: "Edit Task") { title, dueDate in
                    TaskStore.update(task, title: title, dueDate: dueDate)
                }
            }
        }
    }

    private var addTaskButton: some View {
        Button {
            shouldAutofocusAddRow = true
            isShowingAddRow = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.blush)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(AppTheme.sage)
                        .shadow(color: AppTheme.ink.opacity(0.12), radius: 12, y: 4)
                }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Add task")
    }

    @ViewBuilder
    private func taskList(tasks: [Task], allowsReorder: Bool) -> some View {
        if tasks.isEmpty, !isShowingAddRow {
            EmptyStateView(filter: filter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            CustomTaskListView(
                tasks: tasks,
                filter: filter,
                allowsReorder: allowsReorder,
                showAddRow: filter == .active && isShowingAddRow,
                autofocusAddRow: shouldAutofocusAddRow,
                onEdit: { editingTask = $0 },
                onComplete: { task in
                    TaskStore.complete(task)
                },
                onRestore: { task in
                    TaskStore.uncomplete(task, in: modelContext)
                },
                onDelete: { task in
                    TaskStore.delete(task, in: modelContext)
                },
                onAddTask: { title in
                    _ = TaskStore.addTask(title: title, in: modelContext)
                    shouldAutofocusAddRow = false
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
