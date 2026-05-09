import XCTest

@MainActor
final class LayoutToggleUITests: XCTestCase {
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

    func testTopPositionSwitchesToHorizontalLayout() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["toggleWindowButton"].click()

        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))

        statusItem.click()
        app.menuItems["positionButton"].hover()
        let topItem = app.menuItems["positionTopButton"]
        XCTAssertTrue(topItem.waitForExistence(timeout: 2))
        topItem.click()

        XCTAssertTrue(panel.waitForExistence(timeout: 2))
        let cell = panel.descendants(matching: .any)["YippyTextCellView"]
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
    }
}
