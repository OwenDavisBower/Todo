import SwiftUI

struct TaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @FocusState private var titleFocused: Bool

    let navigationTitle: String
    let onSave: (String, Date?) -> Void

    init(
        task: Task? = nil,
        navigationTitle: String = "New Task",
        onSave: @escaping (String, Date?) -> Void
    ) {
        _title = State(initialValue: task?.title ?? "")
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? Calendar.current.startOfDay(for: Date()))
        self.navigationTitle = navigationTitle
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .focused($titleFocused)
                }

                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                titleFocused = true
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, hasDueDate ? dueDate : nil)
        dismiss()
    }
}

#Preview {
    TaskEditSheet { _, _ in }
}
