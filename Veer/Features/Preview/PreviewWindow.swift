import AppKit

final class PreviewWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Preview"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setAccessibilityIdentifier(AccessibilityIdentifiers.previewWindow)

        setupVisualEffectView()
    }

    private(set) var visualEffectView: NSVisualEffectView?

    private func setupVisualEffectView() {
        let vev = NSVisualEffectView()
        vev.material = .hudWindow
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = Constants.UI.windowCornerRadius
        vev.setAccessibilityIdentifier(AccessibilityIdentifiers.previewWindow)

        contentView = vev
        self.visualEffectView = vev
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
