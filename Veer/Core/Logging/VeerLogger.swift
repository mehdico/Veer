import Foundation
import OSLog

enum LoggerCategory: String {
    case general
    case repository
    case pasteboard
    case hotkeys
    case panel
    case settings
    case launcher
}

struct VeerLogger: Sendable {
    private let log: os.Logger

    init(category: LoggerCategory) {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.veer.app"
        self.log = os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// `@autoclosure` keeps call-site string interpolation unevaluated when
    /// the level is filtered — logging on hot paths stays cheap when muted.
    func info(_ message: @autoclosure () -> String) {
        let message = message()
        log.info("\(message, privacy: .public)")
    }

    func warning(_ message: @autoclosure () -> String) {
        let message = message()
        log.warning("\(message, privacy: .public)")
    }

    func error(_ message: @autoclosure () -> String) {
        let message = message()
        log.error("\(message, privacy: .public)")
    }

    func error(_ message: String, _ error: Error) {
        let detail = error.localizedDescription
        log.error("\(message, privacy: .public): \(detail, privacy: .public)")
    }
}
