import Foundation
import Testing
@testable import Veer

@MainActor
struct PanelLayoutTests {
    @Test func topBottomVariantsAlwaysHorizontal() {
        let p = PanelCoordinator()
        for pos: PanelPosition in [.top, .bottom, .bottomSmall, .bottomLarge] {
            p.position = pos
            p.horizontal = false
            #expect(p.effectiveHorizontal == true)
            p.horizontal = true
            #expect(p.effectiveHorizontal == true)
        }
    }

    @Test func sidePositionsAlwaysVertical() {
        let p = PanelCoordinator()
        for pos: PanelPosition in [.left, .right] {
            p.position = pos
            p.horizontal = true
            #expect(p.effectiveHorizontal == false)
            p.horizontal = false
            #expect(p.effectiveHorizontal == false)
        }
    }

    @Test func centerAndFullScreenFollowHorizontalSetting() {
        let p = PanelCoordinator()
        for pos: PanelPosition in [.centerExtraSmall, .centerSmall, .centerMedium, .centerLarge, .fullScreen] {
            p.position = pos
            p.horizontal = true
            #expect(p.effectiveHorizontal == true)
            p.horizontal = false
            #expect(p.effectiveHorizontal == false)
        }
    }
}
