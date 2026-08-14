import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct HistoryListViewModelTests {
    private func makeViewModel(
        seedCount: Int = 0,
        pasteDelay: Duration = .zero
    ) async throws -> (HistoryListViewModel, ClipRepositoryLive, MockPaster, MockPasteboardWriter, PanelCoordinator) {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        for i in 0..<seedCount {
            _ = try repo.insert(
                payload: ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("item-\(i)".utf8)]),
                sourceBundleId: "com.test"
            )
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let paster = MockPaster()
        let writer = MockPasteboardWriter()
        let panel = PanelCoordinator()
        let vm = HistoryListViewModel(
            repository: repo,
            paster: paster,
            pasteboardWriter: writer,
            panel: panel,
            pasteDelay: pasteDelay
        )
        vm.refresh()
        return (vm, repo, paster, writer, panel)
    }

    @Test func refreshLoadsItemsNewestFirst() async throws {
        let (vm, _, _, _, _) = try await makeViewModel(seedCount: 3)
        #expect(vm.items.map(\.preview) == ["item-2", "item-1", "item-0"])
        #expect(vm.selectedIndex == 0)
    }

    @Test func navigateUpDownAreClampedToBounds() async throws {
        let (vm, _, _, _, _) = try await makeViewModel(seedCount: 3)
        vm.navigateUp()
        #expect(vm.selectedIndex == 0)
        vm.navigateDown()
        #expect(vm.selectedIndex == 1)
        vm.navigateDown(by: 99)
        #expect(vm.selectedIndex == 2)
        vm.navigateUp(by: 99)
        #expect(vm.selectedIndex == 0)
    }

    @Test func navigateOnEmptyListIsNoop() async throws {
        let (vm, _, _, _, _) = try await makeViewModel(seedCount: 0)
        vm.navigateDown()
        vm.navigateUp()
        #expect(vm.selectedIndex == 0)
    }

    @Test func searchFiltersAndResetsBoundsAfterClearing() async throws {
        let (vm, _, _, _, _) = try await makeViewModel(seedCount: 3)
        vm.searchText = "item-0"
        #expect(vm.filteredItems.count == 1)
        vm.searchText = ""
        #expect(vm.filteredItems.count == 3)
    }

    @Test func deleteSelectedRemovesFromRepository() async throws {
        let (vm, repo, _, _, _) = try await makeViewModel(seedCount: 3)
        let initial = try repo.fetchAll(limit: nil).count
        vm.deleteSelected()
        let after = try repo.fetchAll(limit: nil).count
        #expect(after == initial - 1)
    }

    @Test func pasteSelectedWritesPasteboardHidesPanelAndPastes() async throws {
        let (vm, _, paster, writer, panel) = try await makeViewModel(seedCount: 2)
        panel.show()
        await vm.pasteSelected()
        #expect(writer.writeCount == 1)
        let writtenString = writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(writtenString == "item-1")
        #expect(panel.isShown == false)
        #expect(paster.pasteCount == 1)
    }

    @Test func pasteSelectedMovesItemToFrontOfQueue() async throws {
        let (vm, repo, _, _, _) = try await makeViewModel(seedCount: 3)
        vm.selectedIndex = 2

        await vm.pasteSelected()

        #expect(try repo.fetchAll(limit: nil).map(\.preview) == ["item-0", "item-2", "item-1"])
        vm.refresh()
        #expect(vm.items.map(\.preview) == ["item-0", "item-2", "item-1"])
        #expect(vm.selectedIndex == 0)
    }

    @Test func selectAndPasteMovesItemToFrontOfQueue() async throws {
        let (vm, repo, _, _, _) = try await makeViewModel(seedCount: 5)

        await vm.selectAndPaste(quickIndex: 3)

        #expect(try repo.fetchAll(limit: nil).map(\.preview) == ["item-1", "item-4", "item-3", "item-2", "item-0"])
        vm.refresh()
        #expect(vm.items.first?.preview == "item-1")
    }

    @Test func selectAndPasteHonorsQuickIndex() async throws {
        let (vm, _, paster, writer, _) = try await makeViewModel(seedCount: 5)
        await vm.selectAndPaste(quickIndex: 3)
        let written = writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "item-1")
        #expect(vm.selectedIndex == 3)
        #expect(paster.pasteCount == 1)
    }

    @Test func selectAndPasteOutOfRangeIsNoop() async throws {
        let (vm, _, paster, writer, _) = try await makeViewModel(seedCount: 2)
        await vm.selectAndPaste(quickIndex: 9)
        #expect(paster.pasteCount == 0)
        #expect(writer.writeCount == 0)
    }

    @Test func startBindsToRepositoryChanges() async throws {
        let (vm, repo, _, _, _) = try await makeViewModel(seedCount: 0)
        vm.start()
        defer { vm.stop() }

        _ = try repo.insert(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("new".utf8)]),
            sourceBundleId: nil
        )
        let deadline = Date().addingTimeInterval(10)
        while vm.items.isEmpty && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(vm.items.first?.preview == "new")
    }

    @Test func searchSelectionClampsAfterFilterShrinks() async throws {
        let (vm, _, _, _, _) = try await makeViewModel(seedCount: 3)
        vm.selectedIndex = 2
        vm.searchText = "item-1"
        vm.refresh()
        #expect(vm.filteredItems.count == 1)
        #expect(vm.selectedIndex == 0)
    }
}
