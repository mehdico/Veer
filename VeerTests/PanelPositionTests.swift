import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct PanelPositionTests {
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)

    @Test func rightPositionAnchorsToRightEdgeAndUsesPanelWidth() {
        let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .right)
        #expect(frame.width == Constants.Panel.width)
        #expect(frame.maxX == screen.maxX)
        #expect(frame.height == visible.height)
    }

    @Test func leftPositionAnchorsToLeftEdge() {
        let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .left)
        #expect(frame.minX == screen.minX)
        #expect(frame.width == Constants.Panel.width)
    }

    @Test func topPositionUsesHorizontalHeightWhenHorizontal() {
        let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .top)
        #expect(frame.height == Constants.Panel.horizontalHeight)
        #expect(frame.maxY == visible.maxY)
        #expect(frame.width == screen.width)
    }

    @Test func topPositionUsesVerticalHeightWhenVertical() {
        let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: false, position: .top)
        #expect(frame.height == Constants.Panel.verticalHeight)
    }

    @Test func bottomVariantsScaleHeight() {
        let small = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .bottomSmall)
        let medium = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .bottom)
        let large = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: .bottomLarge)
        #expect(small.height == floor(Constants.Panel.horizontalHeight))
        #expect(medium.height == floor(Constants.Panel.horizontalHeight * 1.7))
        #expect(large.height == floor(Constants.Panel.horizontalHeight * 2.4))
        for r in [small, medium, large] {
            #expect(r.minY == screen.minY)
            #expect(r.width == screen.width)
        }
    }

    @Test func centerVariantsAreCenteredAndScaled() {
        let cases: [(PanelPosition, CGFloat)] = [
            (.centerExtraSmall, 1.0/3.0),
            (.centerSmall, 0.5),
            (.centerMedium, 0.7),
            (.centerLarge, 0.85),
        ]
        for (position, factor) in cases {
            let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: position)
            #expect(abs(frame.width - screen.width * factor) < 0.001)
            #expect(abs(frame.height - screen.height * factor) < 0.001)
            #expect(abs(frame.midX - screen.midX) < 0.001)
            #expect(abs(frame.midY - screen.midY) < 0.001)
        }
    }

    @Test func everyCaseProducesNonEmptyFrame() {
        for position in PanelPosition.allCases {
            let frame = PanelPosition.computeFrame(screenFrame: screen, visibleFrame: visible, horizontal: true, position: position)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
        }
    }
}
