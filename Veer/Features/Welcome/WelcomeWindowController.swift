import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController {
    /// Breaks the window → hosted view → `onTrusted` → controller reference
    /// chain so the welcome window can deallocate after closing.
    private final class WeakRef {
        weak var controller: WelcomeWindowController?
    }

    convenience init(access: any AccessChecking, onClose: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Veer"
        window.isReleasedWhenClosed = false
        window.center()
        window.setAccessibilityIdentifier(AccessibilityIdentifiers.welcomeWindow)

        let ref = WeakRef()
        let host = NSHostingView(rootView: WelcomeView(access: access, onTrusted: {
            ref.controller?.close()
            onClose()
        }))
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        self.init(window: window)
        ref.controller = self
    }
}
