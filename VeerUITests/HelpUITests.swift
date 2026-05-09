import XCTest

@MainActor
final class HelpUITests: XCTestCase {
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

    func testHelpMenuOpensHelpWindow() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let helpItem = app.menuItems["helpButton"]
        XCTAssertTrue(helpItem.waitForExistence(timeout: 2))
        helpItem.click()
        let helpWindow = app.windows["helpWindow"]
        XCTAssertTrue(helpWindow.waitForExistence(timeout: 3))
    }
}
