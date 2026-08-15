import SwiftUI

extension AttributedString {
    /// Builds an attributed string from `text` with a search-highlight
    /// background over the given character ranges. Ranges that don't map onto
    /// the attributed string are skipped.
    static func highlighted(_ text: String, ranges: [Range<String.Index>]) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.4)
        }
        return attributed
    }
}
