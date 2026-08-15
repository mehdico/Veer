import Foundation
import Testing
@testable import Veer

@MainActor
struct SearchEngineTests {
    private let engine = BasicFuzzySearchEngine()

    private func make(_ pairs: [(String, String)]) -> ([UUID], [SearchCandidate]) {
        var ids: [UUID] = []
        var candidates: [SearchCandidate] = []
        for (label, text) in pairs {
            let id = UUID()
            ids.append(id)
            _ = label
            candidates.append(SearchCandidate(id: id, text: text))
        }
        return (ids, candidates)
    }

    @Test func emptyQueryReturnsAllInOriginalOrder() {
        let (ids, candidates) = make([("a", "alpha"), ("b", "beta"), ("c", "gamma")])
        #expect(engine.search(query: "", in: candidates) == ids)
        #expect(engine.search(query: "   ", in: candidates) == ids)
    }

    @Test func nonMatchingQueryReturnsEmpty() {
        let (_, candidates) = make([("a", "alpha"), ("b", "beta")])
        #expect(engine.search(query: "zzz", in: candidates).isEmpty)
    }

    @Test func substringMatchOutscoresFuzzyMatch() {
        let (ids, candidates) = make([
            ("fuzzy", "f-something-z"),
            ("substr", "fizz match"),
        ])
        let result = engine.search(query: "fizz", in: candidates)
        #expect(result.first == ids[1])
    }

    @Test func earlierSubstringMatchRanksHigher() {
        let (ids, candidates) = make([
            ("late", "zzzz hello world"),
            ("early", "hello universe"),
            ("middle", "ab hello"),
        ])
        let result = engine.search(query: "hello", in: candidates)
        #expect(result == [ids[1], ids[2], ids[0]])
    }

    @Test func subsequenceMatchesAreReturned() {
        let (ids, candidates) = make([
            ("compact", "foobarbaz"),
            ("noisy", "f-noise-o-o-b-junk"),
        ])
        let result = engine.search(query: "fbz", in: candidates)
        #expect(result.contains(ids[0]))
    }

    @Test func caseInsensitive() {
        let (_, candidates) = make([("a", "Hello World")])
        #expect(engine.search(query: "HELLO", in: candidates).count == 1)
        #expect(engine.search(query: "hello", in: candidates).count == 1)
    }

    @Test func compactSubsequenceBeatsLooseSubsequence() {
        let (ids, candidates) = make([
            ("loose", "f x x x x x b z"),
            ("compact", "x x f b z y"),
        ])
        let result = engine.search(query: "fbz", in: candidates)
        #expect(result.first == ids[1])
    }

    @Test func highlightRangesEmptyQueryReturnsNothing() {
        #expect(engine.highlightRanges(query: "", in: "hello").isEmpty)
        #expect(engine.highlightRanges(query: "   ", in: "hello").isEmpty)
    }

    @Test func highlightRangesNoMatchReturnsNothing() {
        #expect(engine.highlightRanges(query: "zzz", in: "foobarbaz").isEmpty)
    }

    @Test func highlightRangesContiguousMatchCoversMatch() {
        let text = "Hello World"
        let ranges = engine.highlightRanges(query: "world", in: text)
        #expect(ranges == [text.range(of: "World")!])
    }

    @Test func highlightRangesContiguousMatchIsCaseInsensitive() {
        let text = "Hello World"
        let ranges = engine.highlightRanges(query: "WORLD", in: text)
        #expect(ranges == [text.range(of: "World")!])
    }

    @Test func highlightRangesSubsequenceSpansFirstToLastMatch() {
        let text = "foobarbaz"
        let ranges = engine.highlightRanges(query: "fbz", in: text)
        #expect(ranges.count == 1)
        let end = text.index(text.startIndex, offsetBy: 9)
        #expect(ranges[0] == text.startIndex..<end)
    }
}
