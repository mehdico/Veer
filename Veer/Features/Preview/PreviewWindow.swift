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
        backgroundColor = .windowBackgroundColor
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setAccessibilityIdentifier(AccessibilityIdentifiers.previewWindow)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
