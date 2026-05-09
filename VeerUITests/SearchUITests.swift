import XCTest

@MainActor
final class SearchUITests: XCTestCase {
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

    func testSearchFiltersHistory() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["toggleWindowButton"].click()

        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))

        let searchField = panel.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("Plain")

        let textCell = panel.descendants(matching: .any)["YippyTextCellView"]
        XCTAssertTrue(textCell.waitForExistence(timeout: 2))

        let imageCell = panel.descendants(matching: .any)["YippyTiffCellView"]
        XCTAssertFalse(imageCell.exists, "Image cell should be filtered out")
    }
}
