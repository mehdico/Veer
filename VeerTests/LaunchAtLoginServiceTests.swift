import Foundation
import Testing
@testable import Veer

@MainActor
struct LaunchAtLoginServiceTests {
    @Test func noopServiceTogglesEnabledFlag() throws {
        let launcher = NoopLaunchAtLoginService()
        #expect(launcher.isEnabled == false)
        try launcher.setEnabled(true)
        #expect(launcher.isEnabled == true)
        try launcher.setEnabled(false)
        #expect(launcher.isEnabled == false)
    }
}
