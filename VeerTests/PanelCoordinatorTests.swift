import Foundation
import Testing
@testable import Veer

@MainActor
struct PanelCoordinatorTests {
    @Test func toggleFlipsIsShown() {
        let panel = PanelCoordinator()
        #expect(panel.isShown == false)
        panel.toggle()
        #expect(panel.isShown == true)
        panel.toggle()
        #expect(panel.isShown == false)
    }

    @Test func showHideIdempotent() {
        let panel = PanelCoordinator()
        panel.show()
        panel.show()
        #expect(panel.isShown == true)
        panel.hide()
        panel.hide()
        #expect(panel.isShown == false)
    }

    @Test func moveAlsoShowsPanel() {
        let panel = PanelCoordinator()
        panel.move(to: .left)
        #expect(panel.position == .left)
        #expect(panel.isShown == true)
    }

    @Test func moveWhileShownUpdatesPosition() {
        let panel = PanelCoordinator()
        panel.show()
        panel.move(to: .top)
        #expect(panel.position == .top)
        #expect(panel.isShown == true)
    }

    @Test func onStateChangeFiresOnEachMutation() {
        let panel = PanelCoordinator()
        var fireCount = 0
        panel.onStateChange = { fireCount += 1 }
        panel.toggle()
        panel.move(to: .right)
        panel.hide()
        #expect(fireCount == 3)
    }

    @Test func defaultsAreBottomMediumHorizontalAndHidden() {
        let panel = PanelCoordinator()
        #expect(panel.isShown == false)
        #expect(panel.position == .bottom)
        #expect(panel.horizontal == true)
    }

    @Test func syncSearchChromeHeightSwitchesBetweenHiddenAndBar() {
        let panel = PanelCoordinator()
        #expect(panel.searchChromeHeight == 0)
        panel.syncSearchChromeHeight(isSearching: true)
        #expect(panel.searchChromeHeight == Constants.Panel.searchBarHeight)
        panel.syncSearchChromeHeight(isSearching: true)
        panel.syncSearchChromeHeight(isSearching: false)
        #expect(panel.searchChromeHeight == 0)
    }
}
