import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StatusBarController: NSObject, StatusMenuActions, NSMenuDelegate {
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
        statusItem.menu?.delegate = self
        syncLaunchAtLoginCheckmark()
        #if DEBUG
        observeRepositoryForDebugCount()
        #endif
    }

    deinit {
        debugObserverTask?.cancel()
    }

    /// Keeps state-dependent items honest right before the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        syncLaunchAtLoginCheckmark()
        guard let menu = statusItem.menu else { return }
        let panelShown = env.panel.isShown
        if let toggle = menu.items.first(where: {
            $0.accessibilityIdentifier() == AccessibilityIdentifiers.toggleWindowButton
        }) {
            toggle.title = panelShown ? "Hide Veer" : "Show Veer"
        }
        if let delete = menu.items.first(where: {
            $0.accessibilityIdentifier() == AccessibilityIdentifiers.deleteSelectedButton
        }) {
            delete.isEnabled = panelShown
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(named: "StatusBarIcon")
            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Veer")
        image?.isTemplate = true
        button.image = image
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
        let count: Int
        if let live = env.repository as? ClipRepositoryLive {
            count = (try? live.count()) ?? 0
        } else {
            count = (try? env.repository.fetchAll(limit: nil).count) ?? 0
        }
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
        let confirmed = env.alerter.presentConfirmation(
            message: "Clear history?",
            informativeText: "This removes every clip from your history. This can't be undone.",
            confirmTitle: "Clear History",
            cancelTitle: "Cancel"
        )
        guard confirmed else { return }
        try? env.repository.clear()
    }

    func selectPosition(_ sender: NSMenuItem) {
        guard let position = PanelPosition(rawValue: sender.tag) else { return }
        env.panel.move(to: position)
    }

    func exportHistory(_ sender: Any?) {
        guard let data = HistoryImportExport.exportJSON(from: env.repository) else {
            env.alerter.presentWarning(
                message: "Nothing to export",
                informativeText: "Your clipboard history is empty."
            )
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Veer History.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            env.alerter.presentError(error)
        }
    }

    func importHistory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let count = try HistoryImportExport.importJSON(data, into: env.repository)
            if count > 0 {
                env.alerter.presentWarning(
                    message: "Import Complete",
                    informativeText: "\(count) clips imported."
                )
            } else {
                env.alerter.presentWarning(
                    message: "Nothing Imported",
                    informativeText: "No clips were imported. The file may be empty or all clips are duplicates."
                )
            }
        } catch {
            env.alerter.presentError(error)
        }
    }

    func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
