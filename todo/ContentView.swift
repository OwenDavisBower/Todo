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
    @State private var showingAddSheet = false
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
            .navigationTitle("Todo")
            .navigationBarTitleDisplayMode(.large)
            .themedNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.light))
                            .foregroundStyle(AppTheme.sage)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.blush)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.ink)
                        )
                }
                .padding(24)
                .accessibilityLabel("Add task")
            }
            .sheet(isPresented: $showingAddSheet) {
                TaskEditSheet { title, dueDate in
                    _ = TaskStore.addTask(title: title, dueDate: dueDate, in: modelContext)
                }
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
                    withAnimation {
                        TaskStore.complete(task)
                    }
                },
                onRestore: { task in
                    withAnimation {
                        TaskStore.uncomplete(task, in: modelContext)
                    }
                },
                onDelete: { task in
                    withAnimation {
                        TaskStore.delete(task, in: modelContext)
                    }
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
