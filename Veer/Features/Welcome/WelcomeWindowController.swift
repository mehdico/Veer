import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController {
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

        var controllerRef: WelcomeWindowController?
        let host = NSHostingView(rootView: WelcomeView(access: access, onTrusted: {
            controllerRef?.close()
            onClose()
        }))
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        self.init(window: window)
        controllerRef = self
    }
}
