import Foundation

enum TaskTitleMatching {
    static func matchingTasks(_ tasks: [Task], search: String) -> [Task] {
        let normalized = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        let exact = tasks.filter { $0.title.lowercased() == normalized }
        if !exact.isEmpty { return exact }

        let contains = tasks.filter { $0.title.lowercased().contains(normalized) }
        if !contains.isEmpty { return contains }

        if let best = tasks.min(by: {
            levenshtein($0.title.lowercased(), normalized) < levenshtein($1.title.lowercased(), normalized)
        }) {
            return [best]
        }
        return []
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var matrix = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)

        for i in 0...left.count { matrix[i][0] = i }
        for j in 0...right.count { matrix[0][j] = j }

        for i in 1...left.count {
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        return matrix[left.count][right.count]
    }
}
