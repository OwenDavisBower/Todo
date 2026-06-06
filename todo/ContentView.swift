import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Task> { !$0.isCompleted }, sort: \Task.sortOrder)
    private var activeTasks: [Task]
    @Query(filter: #Predicate<Task> { $0.isCompleted }, sort: \Task.completedAt, order: .reverse)
    private var doneTasks: [Task]

    @State private var filter: TaskFilter = .active
    @State private var showingAddSheet = false
    @State private var editingTask: Task?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(TaskFilter.allCases) { tab in
                        Text("\(tab.title) (\(count(for: tab)))").tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    switch filter {
                    case .active:
                        taskList(tasks: activeTasks, allowsReorder: true)
                    case .done:
                        taskList(tasks: doneTasks, allowsReorder: false)
                    }
                }
            }
            .navigationTitle("Todo")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
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
                    task.title = title
                    task.dueDate = dueDate
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
            List {
                ForEach(tasks) { task in
                    TaskRowView(task: task, showDragHandle: allowsReorder) {
                        editingTask = task
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if filter == .active {
                            Button {
                                withAnimation {
                                    TaskStore.complete(task)
                                }
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        } else {
                            Button {
                                withAnimation {
                                    TaskStore.uncomplete(task, in: modelContext)
                                }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(task)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    guard allowsReorder else { return }
                    TaskStore.reorder(tasks, from: source, to: destination)
                }
            }
            .listStyle(.plain)
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
