import XCTest

@MainActor
final class StatusBarUITests: XCTestCase {
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

    func testStatusItemAppearsAndOpensMenu() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let menu = app.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2))
    }

    func testAllTopLevelMenuItemsAreReachable() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let identifiers = [
            "aboutButton",
            "helpButton",
            "preferencesButton",
            "toggleWindowButton",
            "launchAtLoginButton",
            "deleteSelectedButton",
            "clearHistoryButton",
            "positionButton",
            "quitButton",
        ]
        for id in identifiers {
            XCTAssertTrue(app.menuItems[id].waitForExistence(timeout: 2), "Missing menu item: \(id)")
        }
    }

    func testPositionSubmenuExposesAllElevenPositions() {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let positionItem = app.menuItems["positionButton"]
        XCTAssertTrue(positionItem.waitForExistence(timeout: 2))
        positionItem.hover()

        let positionIdentifiers = [
            "positionRightButton",
            "positionLeftButton",
            "positionTopButton",
            "positionBottomButtonSmall",
            "positionBottomButton",
            "positionBottomButtonLarge",
            "positionCenterExtraSmall",
            "positionCenterSmall",
            "positionCenterMedium",
            "positionCenterLarge",
        ]
        for id in positionIdentifiers {
            XCTAssertTrue(app.menuItems[id].waitForExistence(timeout: 2), "Missing position item: \(id)")
        }
    }
}
