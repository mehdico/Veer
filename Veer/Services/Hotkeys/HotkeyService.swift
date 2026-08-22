import Foundation

@MainActor
protocol HotkeyService: AnyObject {
    func register(_ shortcut: HotkeyShortcut, handler: @escaping () -> Void)
    /// Registers a hotkey from a resolved key code + Carbon modifier mask,
    /// so user-recorded shortcuts can replace the fixed defaults.
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void)
    func unregisterAll()
}
