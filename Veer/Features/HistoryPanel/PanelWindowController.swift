import AppKit
import SwiftUI

@MainActor
final class PanelWindowController: NSWindowController, NSWindowDelegate {
    private let env: AppEnvironment
    private let coordinator: PanelCoordinator

    init(env: AppEnvironment, coordinator: PanelCoordinator) {
        self.env = env
        self.coordinator = coordinator
        let window = PanelWindow()
        super.init(window: window)
        window.delegate = self
        let host = NSHostingView(rootView: HistoryRootView(env: env))
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        coordinator.onStateChange = { [weak self] in self?.applyState() }
        applyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyState() {
        guard let window else { return }
        if coordinator.isShown {
            let screen = coordinator.currentScreen()
            if let screen {
                let base = coordinator.position.baseForSizing
                let override = env.settings.panelSize(for: base.rawValue).map { NSSize(width: $0.width, height: $0.height) }
                window.setFrame(
                    coordinator.position.frame(for: screen, horizontal: coordinator.horizontal, overrideSize: override),
                    display: true
                )
            }
            window.orderFrontRegardless()
            window.makeKey()
        } else {
            window.orderOut(nil)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window, coordinator.isShown else { return }
        let base = coordinator.position.baseForSizing
        env.settings.setPanelSize(window.frame.size, for: base.rawValue)
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.coordinator.isShown else { return }
            // Keep the panel up if focus moved to another Veer-owned window (e.g. preview).
            if let nextKey = NSApp.keyWindow, nextKey !== self.window {
                return
            }
            self.coordinator.hide()
        }
    }
}
