import AppKit
import SwiftUI

@MainActor
final class PanelWindowController: NSWindowController, NSWindowDelegate {
    private let env: AppEnvironment
    private let coordinator: PanelCoordinator
    private var wasPanelShown = false
    private var resizePersistWork: DispatchWorkItem?
    private var outsideClickMonitor: Any?
    private var workspaceObserver: NSObjectProtocol?

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
                // Resize in the same frame the search chrome appears/disappears
                // (display: false lets SwiftUI commit the new layout before the
                // window redraws). No animation: animating the window height
                // while the chrome height changes re-lays the list every frame,
                // which is the visible sizing glitch.
                window.setFrame(frame, display: false)
            }
            window.orderFrontRegardless()
            if !wasPanelShown {
                window.makeKey()
            }
            wasPanelShown = true
        } else {
            window.orderOut(nil)
            wasPanelShown = false
        }
        setOutsideClickMonitor(enabled: coordinator.isShown)
    }

    private func setOutsideClickMonitor(enabled: Bool) {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
        guard enabled else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleOutsideClick()
            }
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.coordinator.isShown else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
            self.coordinator.hide()
        }
    }

    private func handleOutsideClick() {
        guard coordinator.isShown, let window else { return }
        let point = NSEvent.mouseLocation
        if Self.pointHitsVisibleVeerPanel(point) { return }
        coordinator.hide()
    }

    private static func pointHitsVisibleVeerPanel(_ point: NSPoint) -> Bool {
        NSApp.windows.contains { window in
            window.isVisible
                && (window is PanelWindow || window is PreviewWindow)
                && window.frame.contains(point)
        }
    }

    private func panelFrame(for screen: NSScreen) -> NSRect {
        let base = coordinator.position.baseForSizing
        let contentOverride = env.settings
            .panelSize(for: base.rawValue, matchingScreenSize: screen.frame.size)
            .map { NSSize(width: $0.width, height: $0.height) }
        var frame = coordinator.position.frame(
            for: screen,
            horizontal: coordinator.horizontal,
            overrideSize: contentOverride
        )
        frame.size.height += coordinator.searchChromeHeight
        return frame
    }

    func windowDidResize(_ notification: Notification) {
        guard let window, coordinator.isShown else { return }
        if coordinator.position.isCentered, let screen = window.screen ?? coordinator.currentScreen() {
            let chrome = coordinator.searchChromeHeight
            var size = window.frame.size
            size.height = max(0, size.height - chrome)
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
        // Persist on a debounce so live-resize doesn't JSON-encode and write defaults per tick.
        resizePersistWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistPanelSize()
        }
        resizePersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func persistPanelSize() {
        guard let window, coordinator.isShown else { return }
        let base = coordinator.position.baseForSizing
        var size = window.frame.size
        size.height = max(0, size.height - coordinator.searchChromeHeight)
        if let screenSize = window.screen?.frame.size ?? coordinator.currentScreen()?.frame.size {
            env.settings.setPanelSize(size, for: base.rawValue, onScreenOfSize: screenSize)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, self.coordinator.isShown else { return }
            guard Self.shouldHidePanelAfterResignKey(panel: window, keyWindow: NSApp.keyWindow) else { return }
            self.coordinator.hide()
        }
    }

    static func shouldHidePanelAfterResignKey(panel: NSWindow, keyWindow: NSWindow?) -> Bool {
        if panel.isKeyWindow { return false }
        guard let keyWindow else { return true }
        if keyWindow is PreviewWindow { return false }
        return true
    }
}
