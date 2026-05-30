import AppKit
import SwiftUI

@MainActor
final class PanelWindowController: NSWindowController, NSWindowDelegate {
    private let env: AppEnvironment
    private let coordinator: PanelCoordinator
    private var lastSearchChromeHeight: CGFloat?

    init(env: AppEnvironment, coordinator: PanelCoordinator) {
        self.env = env
        self.coordinator = coordinator
        let window = PanelWindow()
        super.init(window: window)
        window.delegate = self

        let host = NSHostingView(rootView: HistoryRootView(env: env))
        host.layer?.backgroundColor = .clear
        host.frame = window.visualEffectView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.visualEffectView?.addSubview(host)

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
                let frame = panelFrame(for: screen)
                let animateSearchResize = shouldAnimateSearchChromeResize()
                setWindowFrame(frame, on: window, animated: animateSearchResize)
            }
            window.orderFrontRegardless()
            window.makeKey()
        } else {
            window.orderOut(nil)
        }
        lastSearchChromeHeight = coordinator.searchChromeHeight
    }

    private func shouldAnimateSearchChromeResize() -> Bool {
        guard coordinator.isShown, let lastSearchChromeHeight else { return false }
        return lastSearchChromeHeight != coordinator.searchChromeHeight
    }

    private func panelFrame(for screen: NSScreen) -> NSRect {
        let base = coordinator.position.baseForSizing
        let contentOverride = env.settings.panelSize(for: base.rawValue).map {
            NSSize(width: $0.width, height: $0.height)
        }
        var frame = coordinator.position.frame(
            for: screen,
            horizontal: coordinator.horizontal,
            overrideSize: contentOverride
        )
        frame.size.height += coordinator.searchChromeHeight
        return frame
    }

    private func setWindowFrame(_ frame: NSRect, on window: NSWindow, animated: Bool) {
        guard animated else {
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window, coordinator.isShown else { return }
        let base = coordinator.position.baseForSizing
        var size = window.frame.size
        size.height = max(0, size.height - coordinator.searchChromeHeight)
        env.settings.setPanelSize(size, for: base.rawValue)

        if coordinator.position.isCentered, let screen = window.screen ?? coordinator.currentScreen() {
            let chrome = coordinator.searchChromeHeight
            let contentSize = NSSize(width: size.width, height: size.height)
            let totalSize = NSSize(width: contentSize.width, height: contentSize.height + chrome)
            let origin = NSPoint(
                x: screen.frame.minX + (screen.frame.width - totalSize.width) / 2,
                y: screen.frame.minY + (screen.frame.height - totalSize.height) / 2
            )
            let target = NSRect(origin: origin, size: totalSize)
            if window.frame != target {
                window.setFrame(target, display: true)
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.coordinator.isShown else { return }
            if let nextKey = NSApp.keyWindow, nextKey !== self.window {
                return
            }
            self.coordinator.hide()
        }
    }
}
