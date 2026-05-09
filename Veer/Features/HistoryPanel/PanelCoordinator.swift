import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PanelCoordinator {
    var isShown: Bool = false
    var position: PanelPosition = .bottom
    var horizontal: Bool = true

    @ObservationIgnored
    var onStateChange: (() -> Void)?

    @ObservationIgnored
    var frontmostProvider: () -> NSRunningApplication? = {
        NSWorkspace.shared.frontmostApplication
    }

    @ObservationIgnored
    private(set) var previousApp: NSRunningApplication?

    func toggle() {
        if !isShown { capturePreviousApp() }
        isShown.toggle()
        onStateChange?()
    }

    func show() {
        guard !isShown else { return }
        capturePreviousApp()
        isShown = true
        onStateChange?()
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        onStateChange?()
    }

    func move(to position: PanelPosition) {
        self.position = position
        if !isShown {
            capturePreviousApp()
            isShown = true
        }
        onStateChange?()
    }

    func restorePreviousApp() {
        previousApp?.activate(options: [])
    }

    var effectiveHorizontal: Bool { horizontal }

    func currentScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private func capturePreviousApp() {
        guard let app = frontmostProvider(), app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = app
    }
}
