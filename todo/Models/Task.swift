import Foundation
import SwiftData

@Model
final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?

    init(
        title: String,
        sortOrder: Int,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.sortOrder = sortOrder
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.completedAt = nil
    }
}
