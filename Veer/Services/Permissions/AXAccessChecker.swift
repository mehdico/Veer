import ApplicationServices
import AppKit

@MainActor
final class AXAccessChecker: AccessChecking {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
