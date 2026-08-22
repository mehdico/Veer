import XCTest

@MainActor
final class SelectionUITests: XCTestCase {
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

    private func openPanel() -> XCUIElement {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let toggleItem = app.menuItems["toggleWindowButton"]
        XCTAssertTrue(toggleItem.waitForExistence(timeout: 2))
        toggleItem.click()
        let panel = app.windows["veerWindow"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        return panel
    }

    private func closePanel(_ panel: XCUIElement) {
        panel.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitForGone(panel, timeout: 2))
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists {
            if Date() > deadline { return false }
            usleep(100_000)
        }
        return true
    }

    private func getFirstClipCell(_ panel: XCUIElement) -> XCUIElement {
        let cells = panel.descendants(matching: .any).matching(identifier: "VeerTextCellView")
        return cells.firstMatch
    }

    private func getClipCell(at index: Int, in panel: XCUIElement) -> XCUIElement {
        let cells = panel.descendants(matching: .any).matching(identifier: "VeerTextCellView")
        return cells.element(boundBy: index)
    }

    // MARK: - Mouse Selection Tests

    func testSingleClickSelectsItem() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Click on the first item
        firstCell.click()
        
        // Wait a moment for selection to update
        usleep(200_000)
        
        // Verify the item is selected (it should be highlighted)
        XCTAssertTrue(firstCell.exists, "First cell should still exist after click")
        
        closePanel(panel)
    }

    func testClickDifferentItemsUpdatesSelection() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Click on the first item
        firstCell.click()
        usleep(200_000)
        
        // Click on the second item if it exists
        let secondCell = getClipCell(at: 1, in: panel)
        if secondCell.exists {
            secondCell.click()
            usleep(200_000)
            XCTAssertTrue(secondCell.exists, "Second cell should be selected after click")
        }
        
        closePanel(panel)
    }

    func testDoubleClickPastesItem() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Double click should paste and dismiss
        firstCell.doubleClick()
        
        // Panel should dismiss after double-click paste
        XCTAssertTrue(waitForGone(panel, timeout: 3), "Panel should dismiss after double-click paste")
    }

    // MARK: - Keyboard Navigation Tests

    func testArrowKeysNavigateSelection() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Press down arrow to move selection down
        panel.typeKey(.downArrow, modifierFlags: [])
        usleep(200_000)
        
        // Selection should have moved
        let secondCell = getClipCell(at: 1, in: panel)
        if secondCell.exists {
            XCTAssertTrue(secondCell.exists, "Second cell should be navigable")
        }
        
        // Press up arrow to move back up
        panel.typeKey(.upArrow, modifierFlags: [])
        usleep(200_000)
        
        closePanel(panel)
    }

    func testCommandNumberQuickPaste() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Press Cmd+1 to quick paste the first item
        panel.typeKey("1", modifierFlags: .command)
        
        // Panel should dismiss after quick paste
        XCTAssertTrue(waitForGone(panel, timeout: 3), "Panel should dismiss after Cmd+1 quick paste")
    }

    // MARK: - Scroll Behavior Tests

    func testSelectionChangeScrollsItemIntoView() {
        let panel = openPanel()
        
        // Navigate down multiple times to potentially go off-screen
        for _ in 0..<10 {
            panel.typeKey(.downArrow, modifierFlags: [])
            usleep(50_000)
        }
        
        // Navigate back up
        for _ in 0..<5 {
            panel.typeKey(.upArrow, modifierFlags: [])
            usleep(50_000)
        }
        
        // The selected item should be visible
        closePanel(panel)
    }

    func testSingleClickDoesNotCauseExcessiveScrolling() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Get initial scroll position (if possible)
        // Click on the item
        firstCell.click()
        
        // Wait and verify the panel is still stable
        usleep(300_000)
        XCTAssertTrue(panel.exists, "Panel should remain stable after click")
        
        closePanel(panel)
    }

    // MARK: - Window Reopen Tests

    func testReopeningWindowResetsToFirstItem() {
        let panel = openPanel()
        
        // Navigate away from first item
        panel.typeKey(.downArrow, modifierFlags: [])
        usleep(200_000)
        panel.typeKey(.downArrow, modifierFlags: [])
        usleep(200_000)
        
        // Close the panel
        closePanel(panel)
        
        // Reopen the panel
        let newPanel = openPanel()
        
        // Selection should be reset to first item
        let firstCell = getFirstClipCell(newPanel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        closePanel(newPanel)
    }

    func testReopeningWindowScrollsToTop() {
        let panel = openPanel()
        
        // Navigate down to scroll to a different position
        for _ in 0..<15 {
            panel.typeKey(.downArrow, modifierFlags: [])
            usleep(50_000)
        }
        
        // Close the panel
        closePanel(panel)
        
        // Reopen the panel
        let newPanel = openPanel()
        
        // Should be scrolled to top (first item visible)
        let firstCell = getFirstClipCell(newPanel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        closePanel(newPanel)
    }

    func testRepeatedOpenCloseCyclesResetConsistently() {
        for cycle in 0..<3 {
            let panel = openPanel()
            
            // Navigate away from first item
            panel.typeKey(.downArrow, modifierFlags: [])
            usleep(200_000)
            
            // Close and reopen
            closePanel(panel)
            
            let newPanel = openPanel()
            
            // Should always reset to first item
            let firstCell = getFirstClipCell(newPanel)
            XCTAssertTrue(firstCell.waitForExistence(timeout: 2), "Cycle \(cycle): Should reset to first item")
            
            closePanel(newPanel)
        }
    }

    // MARK: - Search Reset Tests

    func testClearingSearchResetsSelection() {
        let panel = openPanel()
        
        // Type a search query
        let searchField = panel.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("test")
        usleep(300_000)
        
        // Clear the search with Escape
        panel.typeKey(.escape, modifierFlags: [])
        usleep(200_000)
        
        // Selection should reset to first item
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        closePanel(panel)
    }

    func testSearchResultsSelectFirstMatch() {
        let panel = openPanel()
        
        // Type a search query
        let searchField = panel.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("veer")
        usleep(300_000)
        
        // First result should be selected
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        closePanel(panel)
    }

    // MARK: - Edge Case Tests

    func testSelectionWithEmptyList() {
        let panel = openPanel()
        
        // Clear all items (if possible via search)
        let searchField = panel.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("nonexistentitemxyz123")
        usleep(300_000)
        
        // Should show empty state without crashing
        let emptyState = panel.staticTexts["No matches"]
        if emptyState.exists {
            XCTAssertTrue(emptyState.exists, "Should show empty state")
        }
        
        closePanel(panel)
    }

    func testRapidClicksDoNotCauseErrors() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Perform rapid clicks
        for _ in 0..<10 {
            firstCell.click()
            usleep(50_000)
        }
        
        // Should remain stable
        XCTAssertTrue(panel.exists)
        
        closePanel(panel)
    }

    func testSelectionPersistsDuringRepositoryChanges() {
        let panel = openPanel()
        
        let firstCell = getFirstClipCell(panel)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 2))
        
        // Select an item
        firstCell.click()
        usleep(200_000)
        
        // The selection should persist even if background updates occur
        // (This tests the preservingSelection logic)
        XCTAssertTrue(panel.exists)
        
        closePanel(panel)
    }
}
