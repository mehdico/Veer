import XCTest

/// Exercises the horizontal card-strip scrolling fixes:
///  - the ⌘N shortcuts must follow the leading (left-most) visible card instead
///    of staying glued to the original first card and eventually vanishing, and
///  - clicking a card that is already on screen must not yank the strip so the
///    clicked card lands on the right edge.
@MainActor
final class CardStripScrollUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // "many" seeds 40 distinct text clips so the strip can be scrolled well
        // past the first nine cards (where ⌘N badges would otherwise run out).
        app.launchArguments = ["--uitesting", "--seed=many"]
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

    private func cardCell(_ index: Int, in panel: XCUIElement) -> XCUIElement {
        panel.descendants(matching: .any).matching(identifier: "cardCell_\(index)").firstMatch
    }

    private func hasShortcut(_ number: Int, in panel: XCUIElement) -> Bool {
        panel.descendants(matching: .any).matching(identifier: "cardShortcut_\(number)").firstMatch.exists
    }

    /// Index of the card currently showing the ⌘1 badge (the leading card).
    private func leadingCardIndex(in panel: XCUIElement) -> Int? {
        for i in 0..<40 {
            if cardCell(i, in: panel).descendants(matching: .any)
                .matching(identifier: "cardShortcut_1").firstMatch.exists
            {
                return i
            }
        }
        return nil
    }

    /// Scroll the strip right until the first card has scrolled out of view.
    private func scrollRightPastFirstCard(_ panel: XCUIElement) {
        let firstCell = cardCell(0, in: panel)
        var swipes = 0
        while firstCell.exists, swipes < 40 {
            panel.swipeLeft()
            usleep(120_000)
            swipes += 1
        }
    }

    func testShortcutsFollowLeadingCardAfterScroll() {
        let panel = openPanel()

        // Baseline: the first card carries ⌘1.
        XCTAssertTrue(hasShortcut(1, in: panel), "⌘1 should be present initially")
        XCTAssertEqual(leadingCardIndex(in: panel), 0, "First card should lead initially")

        scrollRightPastFirstCard(panel)

        // The ⌘1 badge must still exist — now on the new leading card — instead
        // of having vanished once the original first card scrolled away.
        XCTAssertTrue(hasShortcut(1, in: panel),
                      "⌘1 shortcut disappeared after scrolling — badges did not follow the leading card")

        // And it must belong to the new leading card, not the original first one.
        let lead = leadingCardIndex(in: panel)
        XCTAssertNotNil(lead)
        XCTAssertNotEqual(lead, 0, "⌘1 badge did not move to the leading card after scrolling")
    }

    func testClickingVisibleCardDoesNotScrollStrip() {
        let panel = openPanel()

        scrollRightPastFirstCard(panel)

        guard let leadBefore = leadingCardIndex(in: panel), leadBefore > 0 else {
            XCTFail("Could not scroll the strip to a non-zero leading card")
            return
        }

        // Pick the right-most visible card (most likely to trigger the old
        // snap-to-right-edge behaviour) — it must still be on screen.
        var targetIndex = leadBefore
        for i in (leadBefore + 1)..<(leadBefore + 12) {
            if cardCell(i, in: panel).exists {
                targetIndex = i
            } else {
                break
            }
        }
        let targetCell = cardCell(targetIndex, in: panel)
        XCTAssertTrue(targetCell.exists, "Target card should be visible on screen")
        targetCell.click()
        usleep(200_000)

        // Clicking a visible card must not move the strip.
        let leadAfter = leadingCardIndex(in: panel)
        XCTAssertEqual(leadAfter, leadBefore,
                       "Clicking a visible card scrolled the strip (leading changed from \(leadBefore) to \(String(describing: leadAfter)))")
    }
}
