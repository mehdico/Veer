import AppKit
import Foundation

@MainActor
protocol Alerting: AnyObject {
    func presentError(_ error: Error)
    func presentWarning(message: String, informativeText: String?)
    /// Asks the user to confirm a destructive action. Returns true when confirmed.
    /// The confirm button is the default (focused) button.
    func presentConfirmation(message: String, informativeText: String?, confirmTitle: String, cancelTitle: String) -> Bool
}

@MainActor
final class NSAlerter: Alerting {
    func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.alertStyle = .warning
        alert.runModal()
    }

    func presentWarning(message: String, informativeText: String?) {
        let alert = NSAlert()
        alert.messageText = message
        if let informativeText { alert.informativeText = informativeText }
        alert.alertStyle = .warning
        alert.runModal()
    }

    func presentConfirmation(message: String, informativeText: String?, confirmTitle: String, cancelTitle: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        if let informativeText { alert.informativeText = informativeText }
        alert.alertStyle = .warning
        // First button is the default: focused, triggered by Return.
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: cancelTitle)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

@MainActor
final class SilentAlerter: Alerting {
    private(set) var errors: [Error] = []
    private(set) var warnings: [(message: String, informativeText: String?)] = []
    private(set) var confirmations: [(message: String, informativeText: String?, confirmTitle: String, cancelTitle: String)] = []
    var confirmationResponse = true
    func presentError(_ error: Error) { errors.append(error) }
    func presentWarning(message: String, informativeText: String?) {
        warnings.append((message, informativeText))
    }
    func presentConfirmation(message: String, informativeText: String?, confirmTitle: String, cancelTitle: String) -> Bool {
        confirmations.append((message, informativeText, confirmTitle, cancelTitle))
        return confirmationResponse
    }
}
