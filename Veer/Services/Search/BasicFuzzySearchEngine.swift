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

    func highlightRanges(query: String, in text: String) -> [Range<String.Index>] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Character-wise folding keeps every folded unit aligned with an index
        // in the original text, so ranges always map back safely.
        let queryUnits = trimmed.map { String($0).lowercased() }
        let chars = Array(text)
        guard !queryUnits.isEmpty, !chars.isEmpty else { return [] }
        let textUnits = chars.map { String($0).lowercased() }

        if let start = Self.contiguousMatchStart(queryUnits: queryUnits, textUnits: textUnits) {
            return [Self.characterRange(start, start + queryUnits.count - 1, in: text, characterCount: chars.count)]
        }

        // Subsequence match: highlight the span from the first to the last
        // matched character, mirroring the scoring fallback.
        var queryIndex = 0
        var first: Int?
        var last: Int?
        for (index, unit) in textUnits.enumerated() {
            guard queryIndex < queryUnits.count else { break }
            if unit == queryUnits[queryIndex] {
                if first == nil { first = index }
                last = index
                queryIndex += 1
            }
        }
        guard queryIndex == queryUnits.count, let first, let last else { return [] }
        return [Self.characterRange(first, last, in: text, characterCount: chars.count)]
    }

    private static func contiguousMatchStart(queryUnits: [String], textUnits: [String]) -> Int? {
        guard queryUnits.count <= textUnits.count else { return nil }
        for start in 0...(textUnits.count - queryUnits.count) {
            var matches = true
            for offset in 0..<queryUnits.count where textUnits[start + offset] != queryUnits[offset] {
                matches = false
                break
            }
            if matches { return start }
        }
        return nil
    }

    private static func characterRange(
        _ startOffset: Int,
        _ endOffset: Int,
        in text: String,
        characterCount: Int
    ) -> Range<String.Index> {
        let lower = text.index(text.startIndex, offsetBy: min(startOffset, characterCount - 1))
        let upper = text.index(text.startIndex, offsetBy: min(endOffset, characterCount - 1) + 1)
        return lower..<upper
    }
}
