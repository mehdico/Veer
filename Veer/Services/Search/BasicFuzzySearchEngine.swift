import Foundation

final class BasicFuzzySearchEngine: SearchEngine {
    func search(query: String, in candidates: [SearchCandidate]) -> [UUID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidates.map(\.id) }
        let q = trimmed.lowercased()
        let scored: [(UUID, Double)] = candidates.compactMap { candidate in
            guard let score = Self.score(query: q, in: candidate.folded) else { return nil }
            return (candidate.id, score)
        }
        return scored.sorted { $0.1 < $1.1 }.map(\.0)
    }

    static func score(query: String, in text: String) -> Double? {
        if let range = text.range(of: query) {
            let position = text.distance(from: text.startIndex, to: range.lowerBound)
            return -1000 + Double(position)
        }
        // Subsequence match, walking character indices without allocating arrays.
        var queryIndex = query.startIndex
        var textIndex = text.startIndex
        var position = 0
        var firstMatch: Int?
        var lastMatch: Int?
        while textIndex < text.endIndex, queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                if firstMatch == nil { firstMatch = position }
                lastMatch = position
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
            position += 1
        }
        guard queryIndex == query.endIndex, let first = firstMatch, let last = lastMatch else {
            return nil
        }
        let span = Double(last - first)
        return Double(first) + span * 0.5
    }
}
