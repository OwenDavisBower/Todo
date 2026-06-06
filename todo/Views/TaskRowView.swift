import SwiftUI

struct TaskRowView: View {
    let task: Task
    var showDragHandle: Bool = true
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if showDragHandle {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }

                Text(task.title)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let dueDate = task.dueDate {
                    let label = DueDateFormatting.label(for: dueDate)
                    Text(label.text)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(label.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(label.isOverdue ? Color.red.opacity(0.12) : Color.secondary.opacity(0.12))
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    List {
        TaskRowView(
            task: Task(title: "Buy groceries", sortOrder: 0, dueDate: Date()),
            onTap: {}
        )
    }
}
