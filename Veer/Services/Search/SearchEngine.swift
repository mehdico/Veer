import Foundation

struct SearchCandidate: Sendable, Equatable {
    let id: UUID
    let text: String
    /// `text` lowercased once at construction, so searching never re-lowercases the corpus.
    let folded: String

    init(id: UUID, text: String) {
        self.id = id
        self.text = text
        self.folded = text.lowercased()
    }
}

protocol SearchEngine: Sendable {
    func search(query: String, in candidates: [SearchCandidate]) -> [UUID]
    /// Character ranges in `text` that matched `query`, for highlighting
    /// matches in result cells. Empty when nothing matched.
    func highlightRanges(query: String, in text: String) -> [Range<String.Index>]
}

extension SearchEngine {
    func highlightRanges(query: String, in text: String) -> [Range<String.Index>] { [] }
}
