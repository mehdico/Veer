import Foundation
@testable import Veer

@MainActor
final class MockClipActionRunner: ClipActionRunning {
    private(set) var runActions: [ClipAction] = []
    func run(_ action: ClipAction) {
        runActions.append(action)
    }
}
