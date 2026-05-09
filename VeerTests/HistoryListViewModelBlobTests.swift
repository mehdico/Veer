import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct HistoryListViewModelBlobTests {
    @Test func blobReturnsDataForExistingTypeAndNilOtherwise() throws {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        let payload = ClipPayload(typed: [
            NSPasteboard.PasteboardType.string.rawValue: Data("hello".utf8),
            NSPasteboard.PasteboardType.rtf.rawValue: Data([0xAA, 0xBB, 0xCC]),
        ])
        guard case let .inserted(id) = try repo.insert(payload: payload, sourceBundleId: nil) else {
            Issue.record("Insert failed"); return
        }
        let vm = HistoryListViewModel(
            repository: repo,
            paster: MockPaster(),
            pasteboardWriter: MockPasteboardWriter(),
            panel: PanelCoordinator(),
            pasteDelay: .zero
        )

        #expect(vm.blob(for: id, type: NSPasteboard.PasteboardType.rtf.rawValue) == Data([0xAA, 0xBB, 0xCC]))
        #expect(vm.blob(for: id, type: NSPasteboard.PasteboardType.pdf.rawValue) == nil)
        #expect(vm.blob(for: UUID(), type: NSPasteboard.PasteboardType.string.rawValue) == nil)
    }
}
