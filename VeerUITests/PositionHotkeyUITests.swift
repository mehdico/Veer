import XCTest

@MainActor
final class PositionHotkeyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed=mixed"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testEachPositionSubmenuItemMovesPanel() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        let positions = [
            "positionLeftButton",
            "positionRightButton",
            "positionTopButton",
            "positionBottomButton",
            "positionCenterMedium",
        ]

        for id in positions {
            statusItem.click()
            app.menuItems["positionButton"].hover()
            let item = app.menuItems[id]
            XCTAssertTrue(item.waitForExistence(timeout: 2), "Position item \(id) not found")
            item.click()
            XCTAssertTrue(app.windows["yippyWindow"].waitForExistence(timeout: 2),
                          "Panel did not appear after \(id)")
        }
    }
}
