import AppKit
import SwiftUI

@MainActor
final class PreviewWindowController: NSWindowController {
    private let env: AppEnvironment
    private let coordinator: PreviewCoordinator

    init(env: AppEnvironment, coordinator: PreviewCoordinator) {
        self.env = env
        self.coordinator = coordinator
        let window = PreviewWindow()
        super.init(window: window)
        let host = NSHostingView(rootView: PreviewRootView(viewModel: env.historyViewModel, coordinator: coordinator))
        host.layer?.backgroundColor = .clear
        host.frame = window.visualEffectView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.visualEffectView?.addSubview(host)
        window.center()

        coordinator.onStateChange = { [weak self] in self?.applyState() }
        applyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyState() {
        guard let window else { return }
        if coordinator.isShown {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }
}
