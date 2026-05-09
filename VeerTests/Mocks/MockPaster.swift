import Foundation
@testable import Veer

@MainActor
final class MockPaster: PasteSimulating {
    private(set) var pasteCount = 0
    func simulatePaste() { pasteCount += 1 }
}

@MainActor
final class MockPasteboardWriter: PasteboardWriting {
    private(set) var lastWrite: [String: Data]?
    private(set) var writeCount = 0
    func write(typed: [String: Data]) {
        lastWrite = typed
        writeCount += 1
    }
}
