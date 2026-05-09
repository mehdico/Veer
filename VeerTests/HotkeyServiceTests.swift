import Carbon.HIToolbox
import Foundation
import Testing
@testable import Veer

@MainActor
struct HotkeyServiceTests {
    @Test func togglePanelShortcutUsesCommandShiftV() {
        #expect(HotkeyShortcut.togglePanel.keyCode == UInt32(kVK_ANSI_V))
        #expect(HotkeyShortcut.togglePanel.modifiers == UInt32(cmdKey | shiftKey))
    }

    @Test func positionShortcutsUseControlOptionCommand() {
        let expected = UInt32(cmdKey | optionKey | controlKey)
        for shortcut in [HotkeyShortcut.positionLeft, .positionRight, .positionTop, .positionBottom] {
            #expect(shortcut.modifiers == expected)
        }
    }

    @Test func directionalShortcutsMapToCorrectArrowKeys() {
        #expect(HotkeyShortcut.positionLeft.keyCode == UInt32(kVK_LeftArrow))
        #expect(HotkeyShortcut.positionRight.keyCode == UInt32(kVK_RightArrow))
        #expect(HotkeyShortcut.positionTop.keyCode == UInt32(kVK_UpArrow))
        #expect(HotkeyShortcut.positionBottom.keyCode == UInt32(kVK_DownArrow))
    }

    @Test func positionTargetMapsCorrectly() {
        #expect(HotkeyShortcut.togglePanel.positionTarget == nil)
        #expect(HotkeyShortcut.positionLeft.positionTarget == .left)
        #expect(HotkeyShortcut.positionRight.positionTarget == .right)
        #expect(HotkeyShortcut.positionTop.positionTarget == .top)
        #expect(HotkeyShortcut.positionBottom.positionTarget == .bottom)
    }

    @Test func mockServiceFiresHandler() {
        let mock = MockHotkeyService()
        var fired = 0
        mock.register(.togglePanel) { fired += 1 }
        mock.fire(.togglePanel)
        mock.fire(.togglePanel)
        #expect(fired == 2)
    }

    @Test func unregisterAllRemovesHandlers() {
        let mock = MockHotkeyService()
        mock.register(.togglePanel) {}
        mock.register(.positionLeft) {}
        #expect(mock.handlers.count == 2)
        mock.unregisterAll()
        #expect(mock.handlers.isEmpty)
        #expect(mock.unregisterCalls == 1)
    }
}
