import XCTest

@MainActor
final class WelcomeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-trusted=false"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testWelcomeWindowAppearsWhenAccessibilityNotTrusted() {
        let welcome = app.windows["welcomeWindow"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["welcomeAllowAccessButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["howToUseLabel"].exists)
        XCTAssertTrue(app.staticTexts["waitingForControlLabel"].exists)
    }
}
