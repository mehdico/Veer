import Foundation

final class BasicFuzzySearchEngine: SearchEngine {
    func search(query: String, in candidates: [SearchCandidate]) -> [UUID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidates.map(\.id) }
        let q = trimmed.lowercased()
        let scored: [(UUID, Double)] = candidates.compactMap { candidate in
            guard let score = Self.score(query: q, in: candidate.text.lowercased()) else { return nil }
            return (candidate.id, score)
        }
        return scored.sorted { $0.1 < $1.1 }.map(\.0)
    }

    static func score(query: String, in text: String) -> Double? {
        if let range = text.range(of: query) {
            let position = text.distance(from: text.startIndex, to: range.lowerBound)
            return -1000 + Double(position)
        }
        let qChars = Array(query)
        let tChars = Array(text)
        var queryIndex = 0
        var firstMatch: Int?
        var lastMatch: Int?
        for i in tChars.indices where queryIndex < qChars.count {
            if tChars[i] == qChars[queryIndex] {
                if firstMatch == nil { firstMatch = i }
                lastMatch = i
                queryIndex += 1
            }
        }
        guard queryIndex == qChars.count, let first = firstMatch, let last = lastMatch else {
            return nil
        }
        let span = Double(last - first)
        return Double(first) + span * 0.5
    }
}
