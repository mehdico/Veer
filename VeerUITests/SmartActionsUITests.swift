import XCTest

@MainActor
final class SmartActionsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed=smartActions"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func openPanel() -> XCUIElement {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let toggleItem = app.menuItems["toggleWindowButton"]
        XCTAssertTrue(toggleItem.waitForExistence(timeout: 2))
        toggleItem.click()
        let panel = app.windows["yippyWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        return panel
    }

    private func search(_ panel: XCUIElement, for query: String) {
        let searchField = panel.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText(query)
    }

    /// The default layout is cards: ↓ opens the action strip (and ↓ again
    /// closes it), ← / → step between the actions while it's open, ↑ exits.
    private func stepActions(_ panel: XCUIElement) {
        panel.typeKey(.downArrow, modifierFlags: [])
    }

    private func nextAction(_ panel: XCUIElement) {
        panel.typeKey(.rightArrow, modifierFlags: [])
    }

    private func previousAction(_ panel: XCUIElement) {
        panel.typeKey(.leftArrow, modifierFlags: [])
    }

    private func exitActions(_ panel: XCUIElement) {
        panel.typeKey(.upArrow, modifierFlags: [])
    }

    func testURLClipRevealsActionsAndLaunchingActionDismissesPanel() {
        let panel = openPanel()
        search(panel, for: "veer")

        stepActions(panel)

        let strip = panel.descendants(matching: .any)["clipActionStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 2))
        let openButton = panel.buttons["clipAction_openURL"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 2))
        XCTAssertEqual(openButton.label, "Open in Browser")
        XCTAssertTrue(panel.buttons["clipAction_copyMarkdownLink"].exists)

        openButton.click()

        XCTAssertTrue(waitForGone(panel, timeout: 3), "Panel should dismiss after a launching action")
    }

    func testCopyActionViaReturnDismissesPanel() {
        let panel = openPanel()
        search(panel, for: "veer")

        stepActions(panel) // opens strip, first action highlighted
        nextAction(panel) // step to Copy Markdown Link
        panel.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(waitForGone(panel, timeout: 3), "Copy action should dismiss the panel, ready to paste")
    }

    func testDownArrowTogglesStrip() {
        let panel = openPanel()
        search(panel, for: "veer")

        stepActions(panel) // open
        let openButton = panel.buttons["clipAction_openURL"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 2))
        XCTAssertTrue(openButton.isSelected, "First action should be highlighted")

        stepActions(panel) // ↓ again closes
        XCTAssertTrue(waitForGone(openButton, timeout: 2), "↓ again should close the strip")
    }

    func testStepKeysCycleAndExitKeyCloses() {
        let panel = openPanel()
        search(panel, for: "veer")

        stepActions(panel)
        let openButton = panel.buttons["clipAction_openURL"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 2))
        XCTAssertTrue(openButton.isSelected, "First action should be highlighted")
        let caption = panel.staticTexts["clipActionTitle"]
        XCTAssertTrue(caption.waitForExistence(timeout: 2))
        XCTAssertEqual(caption.label, "Open in Browser", "Caption should name the highlighted action")

        nextAction(panel)
        let copyButton = panel.buttons["clipAction_copyMarkdownLink"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 2))
        XCTAssertTrue(copyButton.isSelected, "Second action should be highlighted")
        XCTAssertFalse(openButton.isSelected)
        XCTAssertEqual(caption.label, "Copy Markdown Link", "Caption should follow the highlight")

        nextAction(panel)
        XCTAssertTrue(openButton.isSelected, "Stepping past the last action should wrap to the first")
        XCTAssertEqual(caption.label, "Open in Browser")

        previousAction(panel)
        XCTAssertTrue(copyButton.isSelected, "← should step backward and wrap to the last action")
        XCTAssertEqual(caption.label, "Copy Markdown Link")

        exitActions(panel)
        XCTAssertTrue(waitForGone(openButton, timeout: 2), "Exit key should close the strip")
    }

    func testReturnRunsHighlightedActionWithoutMouse() {
        let panel = openPanel()
        search(panel, for: "veer")

        stepActions(panel) // first action: Open in Browser
        panel.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(waitForGone(panel, timeout: 3), "Keyboard-only launching action should dismiss the panel")
    }

    func testContextMenuSmartActionsForURLClip() {
        let panel = openPanel()
        search(panel, for: "veer")

        let cell = panel.descendants(matching: .any)["YippyTextCellView"]
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
        cell.rightClick()

        let smartMenu = app.menuItems["Smart Actions"]
        XCTAssertTrue(smartMenu.waitForExistence(timeout: 2), "Mouse users should find Smart Actions in the context menu")
        smartMenu.click()

        let openItem = app.menuItems["Open in Browser"]
        XCTAssertTrue(openItem.waitForExistence(timeout: 2))
        openItem.click()

        XCTAssertTrue(waitForGone(panel, timeout: 3), "Launching action from the context menu should dismiss the panel")
    }

    func testHexColorClipRevealsCopySwiftColorAction() {
        let panel = openPanel()
        search(panel, for: "FF5733")

        stepActions(panel)

        let colorButton = panel.buttons["clipAction_copySwiftColor"]
        XCTAssertTrue(colorButton.waitForExistence(timeout: 2))
        XCTAssertEqual(colorButton.label, "Copy Swift Color")
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists {
            if Date() > deadline { return false }
            usleep(100_000)
        }
        return true
    }
}
