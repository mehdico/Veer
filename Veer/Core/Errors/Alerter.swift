import AppKit
import Foundation

@MainActor
protocol Alerting: AnyObject {
    func presentError(_ error: Error)
    func presentWarning(message: String, informativeText: String?)
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
}

@MainActor
final class SilentAlerter: Alerting {
    private(set) var errors: [Error] = []
    private(set) var warnings: [(message: String, informativeText: String?)] = []
    func presentError(_ error: Error) { errors.append(error) }
    func presentWarning(message: String, informativeText: String?) {
        warnings.append((message, informativeText))
    }
}
