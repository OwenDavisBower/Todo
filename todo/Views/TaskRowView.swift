import SwiftUI

struct TaskRowView: View {
    let task: Task
    var showDragHandle: Bool = true
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                if showDragHandle {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(AppTheme.mist)
                        .font(.caption)
                }

                Text(task.title)
                    .font(.body)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let dueDate = task.dueDate {
                    let label = DueDateFormatting.label(for: dueDate)
                    Text(label.text)
                        .font(.caption2.weight(label.isOverdue ? .semibold : .regular))
                        .foregroundStyle(label.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(label.background)
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
    .themedBackground()
}
