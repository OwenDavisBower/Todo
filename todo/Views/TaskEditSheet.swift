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
                        .foregroundStyle(AppTheme.ink)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                        .tint(AppTheme.ink)
                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                        .tint(AppTheme.ink)
                    }
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .themedBackground()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.sage)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.medium)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                titleFocused = true
            }
        }
        .tint(AppTheme.ink)
        .presentationBackground(AppTheme.background)
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
