import Foundation

enum TaskTitleMatching {
    static func matchingTasks(_ tasks: [Task], normalizedSearch: String) -> [Task] {
        guard !normalizedSearch.isEmpty else { return [] }

        var exact: [Task] = []
        var contains: [Task] = []
        var fuzzyCandidates: [(Task, Int)] = []
        let maxDistance = max(2, normalizedSearch.count / 2)

        for task in tasks {
            let normalizedTitle = task.title.lowercased()
            if normalizedTitle == normalizedSearch {
                exact.append(task)
            } else if normalizedTitle.contains(normalizedSearch) {
                contains.append(task)
            } else {
                let distance = levenshtein(normalizedTitle, normalizedSearch)
                if distance <= maxDistance {
                    fuzzyCandidates.append((task, distance))
                }
            }
        }

        if !exact.isEmpty { return exact }
        if !contains.isEmpty { return contains }
        guard let best = fuzzyCandidates.min(by: { $0.1 < $1.1 }) else { return [] }
        return [best.0]
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
