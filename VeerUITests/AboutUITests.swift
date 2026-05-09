import XCTest

@MainActor
final class AboutUITests: XCTestCase {
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

    func testAboutMenuOpensAboutWindow() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let aboutItem = app.menuItems["aboutButton"]
        XCTAssertTrue(aboutItem.waitForExistence(timeout: 2))
        aboutItem.click()
        let aboutWindow = app.windows["aboutWindow"]
        XCTAssertTrue(aboutWindow.waitForExistence(timeout: 3))
    }
}
