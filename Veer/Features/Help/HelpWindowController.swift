import AppKit
import SwiftUI

@MainActor
final class HelpWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Veer Help"
        window.isReleasedWhenClosed = false
        window.center()
        window.setAccessibilityIdentifier(AccessibilityIdentifiers.helpWindow)
        let host = NSHostingView(rootView: HelpView())
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        self.init(window: window)
    }
}
