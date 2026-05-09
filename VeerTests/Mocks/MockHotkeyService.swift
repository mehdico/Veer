import Foundation
@testable import Veer

@MainActor
final class MockHotkeyService: HotkeyService {
    private(set) var handlers: [HotkeyShortcut: () -> Void] = [:]
    private(set) var unregisterCalls = 0

    func register(_ shortcut: HotkeyShortcut, handler: @escaping () -> Void) {
        handlers[shortcut] = handler
    }

    func unregisterAll() {
        handlers.removeAll()
        unregisterCalls += 1
    }

    func fire(_ shortcut: HotkeyShortcut) {
        handlers[shortcut]?()
    }
}
