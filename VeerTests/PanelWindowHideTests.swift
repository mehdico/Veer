import AppKit
import Testing
@testable import Veer

@MainActor
struct PanelWindowHideTests {
    @Test func hidesWhenPanelLostKeyAndNoSuccessor() {
        let panel = PanelWindow()
        #expect(PanelWindowController.shouldHidePanelAfterResignKey(panel: panel, keyWindow: nil) == true)
    }

    @Test func staysOpenWhenPreviewIsKey() {
        let panel = PanelWindow()
        let preview = PreviewWindow()
        #expect(PanelWindowController.shouldHidePanelAfterResignKey(panel: panel, keyWindow: preview) == false)
    }

    @Test func hidesWhenAnotherAppWindowIsKey() {
        let panel = PanelWindow()
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: false)
        #expect(PanelWindowController.shouldHidePanelAfterResignKey(panel: panel, keyWindow: other) == true)
    }
}
