import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Veer"
        window.isReleasedWhenClosed = false
        window.center()
        window.setAccessibilityIdentifier(AccessibilityIdentifiers.aboutWindow)
        let host = NSHostingView(rootView: AboutView())
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        self.init(window: window)
    }
}
