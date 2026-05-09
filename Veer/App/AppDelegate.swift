import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment: AppEnvironment = LaunchArguments.isUITesting ? .uiTest() : .live()

    private var statusBar: StatusBarController?
    private var panelController: PanelWindowController?
    private var previewController: PreviewWindowController?
    private var welcomeController: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(env: environment)
        panelController = PanelWindowController(env: environment, coordinator: environment.panel)
        previewController = PreviewWindowController(env: environment, coordinator: environment.preview)

        registerHotkeys()
        environment.ingestor.start()

        if !environment.access.isTrusted() {
            showWelcomeWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.ingestor.stop()
        environment.hotkeys.unregisterAll()
    }

    private func registerHotkeys() {
        environment.hotkeys.register(.togglePanel) { [weak self] in
            self?.environment.panel.toggle()
        }
        environment.hotkeys.register(.positionLeft) { [weak self] in
            self?.environment.panel.move(to: .left)
        }
        environment.hotkeys.register(.positionRight) { [weak self] in
            self?.environment.panel.move(to: .right)
        }
        environment.hotkeys.register(.positionTop) { [weak self] in
            self?.environment.panel.move(to: .top)
        }
        environment.hotkeys.register(.positionBottom) { [weak self] in
            self?.environment.panel.move(to: .bottom)
        }
    }

    private func showWelcomeWindow() {
        let access = environment.access
        welcomeController = WelcomeWindowController(access: access) { [weak self] in
            self?.welcomeController = nil
        }
        welcomeController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
