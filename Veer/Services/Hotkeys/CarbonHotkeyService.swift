import Carbon.HIToolbox
import Foundation

private struct CarbonHotkeyRegistration {
    let id: UInt32
    let ref: EventHotKeyRef
    let handler: () -> Void
}

@MainActor
final class CarbonHotkeyService: HotkeyService {
    private static let signature: OSType = 0x56454552 // 'VEER'

    nonisolated(unsafe) private var registrations: [HotkeyShortcut: CarbonHotkeyRegistration] = [:]
    // Static: `dispatchTable` below is shared across instances, so per-instance
    // counters would collide and overwrite each other's handlers.
    nonisolated(unsafe) private static var nextID: UInt32 = 1
    nonisolated(unsafe) private var eventHandler: EventHandlerRef?
    private let logger = VeerLogger(category: .hotkeys)

    // Mutated only from @MainActor `register`/`unregisterAll`/`deinit`. Read from the
    // Carbon trampoline below, which is invoked synchronously on the main thread because
    // the handler is installed on `GetApplicationEventTarget()` (Carbon delivers app-target
    // events on the main run loop). The trampoline asserts main-thread to fail loud if
    // that contract ever breaks.
    nonisolated(unsafe) static var dispatchTable: [UInt32: () -> Void] = [:]

    init() {
        installEventHandlerIfNeeded()
    }

    deinit {
        if let eventHandler { RemoveEventHandler(eventHandler) }
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
            Self.dispatchTable.removeValue(forKey: registration.id)
        }
    }

    func register(_ shortcut: HotkeyShortcut, handler: @escaping () -> Void) {
        if let existing = registrations.removeValue(forKey: shortcut) {
            UnregisterEventHotKey(existing.ref)
            Self.dispatchTable.removeValue(forKey: existing.id)
        }
        let id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            logger.warning("Failed to register hotkey \(shortcut.rawValue) (status \(status)). Accessibility permission may be missing.")
            return
        }
        registrations[shortcut] = CarbonHotkeyRegistration(id: id, ref: ref, handler: handler)
        Self.dispatchTable[id] = handler
    }

    func unregisterAll() {
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
            Self.dispatchTable.removeValue(forKey: registration.id)
        }
        registrations.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, _) -> OSStatus in
                assert(Thread.isMainThread, "Carbon hotkey trampoline must run on main thread")
                guard let eventRef else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                if let handler = CarbonHotkeyService.dispatchTable[hotKeyID.id] {
                    handler()
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
        guard status == noErr else {
            logger.error("Failed to install Carbon event handler (status \(status))")
            return
        }
    }
}
