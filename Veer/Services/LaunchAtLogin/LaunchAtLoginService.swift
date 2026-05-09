import Foundation

@MainActor
protocol LaunchAtLoginService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}
