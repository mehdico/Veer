import XCTest

@MainActor
final class CellRenderingUITests: XCTestCase {
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

    func testEachCellTypeAppearsInPanel() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["toggleWindowButton"].click()

        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))

        let identifiers = [
            "YippyTextCellView",
            "YippyRichTextCellView",
            "YippyTiffCellView",
            "YippyColorCellView",
            "YippyPdfCellView",
        ]
        for id in identifiers {
            XCTAssertTrue(
                panel.descendants(matching: .any)[id].waitForExistence(timeout: 3),
                "Missing cell: \(id)"
            )
        }

        let fileFound = panel.descendants(matching: .any)["YippyFileIconCellView"].exists
            || panel.descendants(matching: .any)["YippyFileThumbnailCellView"].exists
        XCTAssertTrue(fileFound, "Missing file cell (icon or thumbnail variant)")
    }
}
