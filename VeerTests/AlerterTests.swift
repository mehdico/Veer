import Foundation
import Testing
@testable import Veer

@MainActor
struct AlerterTests {
    struct DummyError: Error, LocalizedError {
        var errorDescription: String? { "dummy" }
    }

    @Test func silentAlerterRecordsErrorsAndWarnings() {
        let alerter = SilentAlerter()
        alerter.presentError(DummyError())
        alerter.presentWarning(message: "watch out", informativeText: "details")
        alerter.presentWarning(message: "another", informativeText: nil)

        #expect(alerter.errors.count == 1)
        #expect(alerter.warnings.count == 2)
        #expect(alerter.warnings[0].message == "watch out")
        #expect(alerter.warnings[0].informativeText == "details")
        #expect(alerter.warnings[1].informativeText == nil)
    }

    @Test func silentAlerterRecordsConfirmationsAndHonorsResponse() {
        let alerter = SilentAlerter()
        alerter.confirmationResponse = true
        #expect(alerter.presentConfirmation(message: "Delete?", informativeText: "gone", confirmTitle: "Delete", cancelTitle: "Cancel"))

        alerter.confirmationResponse = false
        #expect(!alerter.presentConfirmation(message: "Delete?", informativeText: nil, confirmTitle: "Delete", cancelTitle: "Cancel"))

        #expect(alerter.confirmations.count == 2)
        #expect(alerter.confirmations[0].confirmTitle == "Delete")
        #expect(alerter.confirmations[0].cancelTitle == "Cancel")
        #expect(alerter.confirmations[0].informativeText == "gone")
        #expect(alerter.confirmations[1].informativeText == nil)
    }
}
