import Foundation
@testable import Veer

@MainActor
final class MockAccessChecker: AccessChecking {
    var trusted: Bool
    private(set) var requestCount: Int = 0

    init(trusted: Bool = true) { self.trusted = trusted }

    func isTrusted() -> Bool { trusted }
    func requestTrust() { requestCount += 1 }
}
