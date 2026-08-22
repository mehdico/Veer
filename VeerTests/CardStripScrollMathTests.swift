import CoreGraphics
import Foundation
import Testing
@testable import Veer

@MainActor
struct CardStripScrollMathTests {

    /// Cards fill the content with a symmetric margin; the origin formula
    /// recovers it so the leading index tracks the viewport's leading edge.
    private func contentLength(side: CGFloat, count: Int) -> CGFloat {
        let stride = side + CardStripScrollMath.spacing
        return CGFloat(count) * stride
    }

    @Test func leadingIndexStartsAtZero() {
        let side: CGFloat = 200
        let count = 40
        let length = contentLength(side: side, count: count)
        #expect(CardStripScrollMath.leadingIndex(contentLength: length, side: side, count: count, visibleLeading: 0) == 0)
    }

    @Test func leadingIndexFollowsScroll() {
        let side: CGFloat = 200
        let count = 40
        let stride = side + CardStripScrollMath.spacing
        let length = contentLength(side: side, count: count)
        // Scroll so card 5's leading edge aligns with the viewport's leading edge.
        let lead5 = CGFloat(5) * stride
        #expect(CardStripScrollMath.leadingIndex(contentLength: length, side: side, count: count, visibleLeading: lead5) == 5)
        // And card 12.
        let lead12 = CGFloat(12) * stride
        #expect(CardStripScrollMath.leadingIndex(contentLength: length, side: side, count: count, visibleLeading: lead12) == 12)
    }

    @Test func leadingIndexClampsAtBoundaries() {
        let side: CGFloat = 200
        let count = 40
        let length = contentLength(side: side, count: count)
        #expect(CardStripScrollMath.leadingIndex(contentLength: length, side: side, count: count, visibleLeading: 1e9) == count - 1)
        #expect(CardStripScrollMath.leadingIndex(contentLength: length, side: side, count: count, visibleLeading: -1e9) == 0)
    }

    @Test func leadingIndexHandlesEdgeCounts() {
        let side: CGFloat = 200
        #expect(CardStripScrollMath.leadingIndex(contentLength: 0, side: side, count: 0, visibleLeading: 0) == 0)
        #expect(CardStripScrollMath.leadingIndex(contentLength: 300, side: side, count: 1, visibleLeading: 0) == 0)
        #expect(CardStripScrollMath.leadingIndex(contentLength: 300, side: side, count: 1, visibleLeading: 9999) == 0)
    }

    /// Reproduces the bug: a stale "first visible" of 0 (as if the scroll
    /// binding never updated during a trackpad swipe) would keep ⌘1 glued to
    /// card 0 even after scrolling far right, and once card 0 leaves the window
    /// no card would carry ⌘1 at all. The math must instead assign ⌘1 to the
    /// card actually at the leading edge for any scroll position.
    @Test func leadingIndexStaysValidAcrossWholeStrip() {
        let side: CGFloat = 200
        let count = 40
        let stride = side + CardStripScrollMath.spacing
        let length = contentLength(side: side, count: count)
        for leading in 0..<count {
            let idx = CardStripScrollMath.leadingIndex(
                contentLength: length, side: side, count: count,
                visibleLeading: CGFloat(leading) * stride
            )
            #expect(idx == leading, "leading index \(idx) != expected \(leading)")
        }
    }
}
