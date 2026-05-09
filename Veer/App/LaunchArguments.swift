import Foundation

enum LaunchArguments {
    static let uiTesting = "--uitesting"
    static let mockTrustedFalse = "--mock-trusted=false"
    static let seedPrefix = "--seed="

    static var isUITesting: Bool {
        CommandLine.arguments.contains(uiTesting)
    }

    static var mockAccessibilityTrusted: Bool {
        !CommandLine.arguments.contains(mockTrustedFalse)
    }

    static var seedFixture: String? {
        CommandLine.arguments
            .first { $0.hasPrefix(seedPrefix) }
            .map { String($0.dropFirst(seedPrefix.count)) }
    }
}
