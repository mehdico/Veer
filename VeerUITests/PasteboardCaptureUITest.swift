import AppKit
import XCTest

@MainActor
final class PasteboardCaptureUITest: XCTestCase {
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

    func testPasteboardChangeIncrementsHistoryCount() throws {
        let statusItem = app.menuBars.statusItems["statusItemButton"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("veer-ui-test-\(UUID().uuidString)", forType: .string)

        Thread.sleep(forTimeInterval: 0.3)

        statusItem.click()
        let debugItem = app.menuItems["debugHistoryCount"]
        XCTAssertTrue(debugItem.waitForExistence(timeout: 2))
        XCTAssertTrue(debugItem.title.contains("history "), "Title was: \(debugItem.title)")

        let count = parseCount(from: debugItem.title)
        XCTAssertGreaterThanOrEqual(count, 1)
    }

    private func parseCount(from title: String) -> Int {
        let digits = title.split(separator: " ").last ?? ""
        return Int(digits) ?? 0
    }
}
