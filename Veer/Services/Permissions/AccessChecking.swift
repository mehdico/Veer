import Foundation

@MainActor
protocol AccessChecking: AnyObject {
    func isTrusted() -> Bool
    func requestTrust()
}
