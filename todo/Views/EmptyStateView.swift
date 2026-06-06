import SwiftUI

struct EmptyStateView: View {
    let filter: TaskFilter

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: filter.emptyIcon)
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(AppTheme.mist)

            Text(filter.emptyTitle)
                .font(.title3.weight(.light))
                .foregroundStyle(AppTheme.ink)

            Text(filter.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.sage)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
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
        case .active: "circle"
        case .done: "checkmark"
        }
    }

    var emptyMessage: String {
        switch self {
        case .active: "Type below to add your first task."
        case .done: "Completed tasks will appear here."
        }
    }
}
