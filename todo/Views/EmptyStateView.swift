import SwiftUI

struct EmptyStateView: View {
    let filter: TaskFilter

    var body: some View {
        ContentUnavailableView {
            Label(filter.emptyTitle, systemImage: filter.emptyIcon)
        } description: {
            Text(filter.emptyMessage)
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case active
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "Active"
        case .done: "Done"
        }
    }

    var emptyTitle: String {
        switch self {
        case .active: "No tasks"
        case .done: "Nothing done yet"
        }
    }

    var emptyIcon: String {
        switch self {
        case .active: "checklist"
        case .done: "checkmark.circle"
        }
    }

    var emptyMessage: String {
        switch self {
        case .active: "Tap + to add your first task."
        case .done: "Completed tasks will appear here."
        }
    }
}
