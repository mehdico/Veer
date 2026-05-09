import Foundation

struct SearchCandidate: Sendable, Equatable {
    let id: UUID
    let text: String
}

protocol SearchEngine: Sendable {
    func search(query: String, in candidates: [SearchCandidate]) -> [UUID]
}
