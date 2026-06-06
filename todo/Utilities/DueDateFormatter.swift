import Foundation
import SwiftUI

struct DueDateLabel {
    let text: String
    let isOverdue: Bool

    var color: Color {
        isOverdue ? AppTheme.ink : AppTheme.sage
    }

    var background: Color {
        isOverdue ? AppTheme.lilac : AppTheme.surface
    }
}

enum DueDateFormatting {
    static func label(for date: Date, relativeTo now: Date = Date()) -> DueDateLabel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0

        switch days {
        case 0:
            return DueDateLabel(text: "Today", isOverdue: false)
        case 1:
            return DueDateLabel(text: "Tomorrow", isOverdue: false)
        case let d where d > 1:
            return DueDateLabel(text: "\(d)d", isOverdue: false)
        case let d where d < 0:
            return DueDateLabel(text: "\(abs(d))d ago", isOverdue: true)
        default:
            return DueDateLabel(text: "", isOverdue: false)
        }
    }
}
