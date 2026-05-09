import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, StatusMenuActions {
    private let env: AppEnvironment
    private let statusItem: NSStatusItem
    private var debugObserverTask: Task<Void, Never>?
    private var helpController: HelpWindowController?
    private var aboutController: AboutWindowController?
    private var settingsController: SettingsWindowController?

    init(env: AppEnvironment) {
        self.env = env
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        statusItem.menu = StatusMenuBuilder.build(target: self)
        syncLaunchAtLoginCheckmark()
        #if DEBUG
        observeRepositoryForDebugCount()
        #endif
    }

    deinit {
        debugObserverTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Veer")
        button.setAccessibilityIdentifier(AccessibilityIdentifiers.statusItemButton)
    }

    private func syncLaunchAtLoginCheckmark() {
        guard let menu = statusItem.menu,
              let item = menu.items.first(where: {
                  $0.accessibilityIdentifier() == AccessibilityIdentifiers.launchAtLoginButton
              })
        else { return }
        item.state = env.launcher.isEnabled ? .on : .off
    }

    #if DEBUG
    private func observeRepositoryForDebugCount() {
        updateDebugCount()
        let stream = env.repository.changes
        debugObserverTask = Task { @MainActor [weak self] in
            for await _ in stream {
                self?.updateDebugCount()
            }
        }
    }

    private func updateDebugCount() {
        guard let menu = statusItem.menu,
              let item = menu.items.first(where: {
                  $0.accessibilityIdentifier() == AccessibilityIdentifiers.debugHistoryCount
              })
        else { return }
        let count = (try? env.repository.fetchAll(limit: nil).count) ?? 0
        item.title = "Debug: history \(count)"
    }
    #endif

    func showAbout(_ sender: Any?) {
        if aboutController == nil {
            aboutController = AboutWindowController()
        }
        aboutController?.showWindow(nil)
        aboutController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHelp(_ sender: Any?) {
        if helpController == nil {
            helpController = HelpWindowController()
        }
        helpController?.showWindow(nil)
        helpController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPreferences(_ sender: Any?) {
        if settingsController == nil {
            settingsController = SettingsWindowController(env: env)
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func togglePanel(_ sender: Any?) {
        env.panel.toggle()
    }

    func toggleLaunchAtLogin(_ sender: Any?) {
        do {
            try env.launcher.setEnabled(!env.launcher.isEnabled)
        } catch {
            env.alerter.presentError(error)
        }
        syncLaunchAtLoginCheckmark()
    }

    func deleteSelected(_ sender: Any?) {
        env.historyViewModel.deleteSelected()
    }

    func clearHistory(_ sender: Any?) {
        try? env.repository.clear()
    }

    func selectPosition(_ sender: NSMenuItem) {
        guard let position = PanelPosition(rawValue: sender.tag) else { return }
        env.panel.move(to: position)
    }

    func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
