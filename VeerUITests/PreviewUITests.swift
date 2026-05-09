import XCTest

@MainActor
final class PreviewUITests: XCTestCase {
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

    func testSpaceOpensPreviewWindowAndAgainCloses() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["toggleWindowButton"].click()

        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))

        panel.typeKey(.space, modifierFlags: [])
        let preview = app.windows["previewWindow"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))

        panel.typeKey(.space, modifierFlags: [])
        XCTAssertFalse(preview.exists, "Preview window should hide on second space press")
    }
}
