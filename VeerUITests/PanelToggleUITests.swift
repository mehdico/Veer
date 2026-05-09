import XCTest

@MainActor
final class PanelToggleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testToggleWindowMenuShowsAndHidesPanel() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        statusItem.click()
        let toggleItem = app.menuItems["toggleWindowButton"]
        XCTAssertTrue(toggleItem.waitForExistence(timeout: 2))
        toggleItem.click()

        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))

        statusItem.click()
        app.menuItems["toggleWindowButton"].click()
        XCTAssertFalse(panel.waitForNonExistence(timeout: 0.0))
    }
}

extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let start = Date()
        while exists {
            if Date().timeIntervalSince(start) > timeout { return false }
            usleep(100_000)
        }
        return true
    }
}
