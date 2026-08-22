import CoreGraphics

/// Pure geometry for the horizontal/vertical card strip: given uniformly sized
/// cards of `side` separated by an 8pt gap, laid out in scrollable content of
/// `contentLength`, returns the index of the card whose leading edge sits at the
/// viewport's leading edge (`visibleLeading`). The content origin is solved from
/// the known content size so no margin constant is hard-coded, and the result is
/// clamped to `[0, count - 1]`.
enum CardStripScrollMath {
    static let spacing: CGFloat = 8

    static func leadingIndex(
        contentLength: CGFloat,
        side: CGFloat,
        count: Int,
        visibleLeading: CGFloat
    ) -> Int {
        guard count > 0 else { return 0 }
        guard count > 1 else { return 0 }
        let stride = side + spacing
        guard stride > 0 else { return 0 }
        let origin = (contentLength - side - CGFloat(count - 1) * stride) / 2
        let raw = (visibleLeading - origin) / stride
        return min(max(Int(raw.rounded()), 0), count - 1)
    }
}
