import Foundation

@MainActor
protocol HotkeyService: AnyObject {
    func register(_ shortcut: HotkeyShortcut, handler: @escaping () -> Void)
    func unregisterAll()
}
