import Foundation

struct ListDisplayPin {
    enum Reason {
        case removal
        case reorder
    }

    let tasks: [Task]
    let ids: [UUID]
    let reason: Reason

    init(tasks: [Task], reason: Reason) {
        self.tasks = tasks
        self.ids = tasks.map(\.id)
        self.reason = reason
    }

    static func afterReorderSettlement(_ ordered: [Task]?, replacing current: ListDisplayPin?) -> ListDisplayPin? {
        if let ordered {
            return ListDisplayPin(tasks: ordered, reason: .reorder)
        }
        if current?.reason == .reorder {
            return nil
        }
        return current
    }

    static func matchesTasks(_ tasks: [Task], ids: [UUID]) -> Bool {
        tasks.map(\.id) == ids
    }
}
