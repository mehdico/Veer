import Foundation
import Testing
@testable import Veer

@MainActor
struct PanelLayoutTests {
    @Test func allPositionsFollowHorizontalSetting() {
        let p = PanelCoordinator()
        let positions: [PanelPosition] = [
            .top, .bottom, .bottomSmall, .bottomLarge,
            .left, .right,
            .centerExtraSmall, .centerSmall, .centerMedium, .centerLarge,
        ]
        for pos in positions {
            p.position = pos
            p.horizontal = true
            #expect(p.effectiveHorizontal == true)
            p.horizontal = false
            #expect(p.effectiveHorizontal == false)
        }
    }
}
