import Foundation
import SwiftUI
import Testing
@testable import Veer

@MainActor
struct PanelKeyHandlerTests {
    @Test func isPrintableRejectsControlCharactersAndDel() {
        let del = Character(Unicode.Scalar(0x7F)!)
        let backspace = Character(Unicode.Scalar(0x08)!)
        let nul = Character(Unicode.Scalar(0x00)!)
        let c1 = Character(Unicode.Scalar(0x9F)!)
        #expect(PanelKeyHandler.isPrintable(del) == false)
        #expect(PanelKeyHandler.isPrintable(backspace) == false)
        #expect(PanelKeyHandler.isPrintable(nul) == false)
        #expect(PanelKeyHandler.isPrintable(c1) == false)
    }

    @Test func isPrintableAcceptsTypicalCharactersAndSpace() {
        for ch in "abcXYZ 1!@#$%é漢" {
            #expect(PanelKeyHandler.isPrintable(ch) == true, "Expected printable: \(ch)")
        }
    }

    @Test func navigationRepeatIntervalStartsSlowThenAccelerates() {
        #expect(PanelNavigationRepeatGate.repeatInterval(afterRepeatCount: 0) == .milliseconds(150))
        #expect(PanelNavigationRepeatGate.repeatInterval(afterRepeatCount: 2) == .milliseconds(150))
        #expect(PanelNavigationRepeatGate.repeatInterval(afterRepeatCount: 3) == .milliseconds(100))
        #expect(PanelNavigationRepeatGate.repeatInterval(afterRepeatCount: 11) == .milliseconds(100))
        #expect(PanelNavigationRepeatGate.repeatInterval(afterRepeatCount: 12) == .milliseconds(65))
    }

    @Test func navigationRepeatGateAcceptsFirstPressImmediately() {
        var gate = PanelNavigationRepeatGate()
        #expect(gate.shouldAccept(phase: [.down], direction: .down) == true)
    }

    // MARK: - Key routing with a real search field

    @MainActor
    private func makeViewModel(seedCount: Int = 0) throws -> (HistoryListViewModel, ClipRepositoryLive, MockPaster, MockPasteboardWriter) {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        for i in 0..<seedCount {
            _ = try repo.insert(
                payload: ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("item-\(i)".utf8)]),
                sourceBundleId: "com.test"
            )
        }
        let paster = MockPaster()
        let writer = MockPasteboardWriter()
        let vm = HistoryListViewModel(
            repository: repo,
            paster: paster,
            pasteboardWriter: writer,
            panel: PanelCoordinator()
        )
        vm.refresh()
        return (vm, repo, paster, writer)
    }

    private func handle(
        _ key: KeyEquivalent,
        characters: String,
        modifiers: EventModifiers = [],
        viewModel: HistoryListViewModel
    ) -> KeyPress.Result {
        PanelKeyHandler.handle(
            key: key,
            characters: characters,
            modifiers: modifiers,
            phase: [.down],
            viewModel: viewModel
        )
    }

    @Test func printableKeysPassThroughToTheSearchField() throws {
        let (vm, _, _, _) = try makeViewModel()
        let result = handle(
            "a",
            characters: "a",
            viewModel: vm
        )
        #expect(result == .ignored)
        #expect(vm.searchText.isEmpty)
    }

    @Test func plainBackspacePassesThroughToTheSearchField() throws {
        let (vm, _, _, _) = try makeViewModel()
        let result = handle(
            .delete,
            characters: "\u{7F}",
            viewModel: vm
        )
        #expect(result == .ignored)
    }

    @Test func commandAndControlBackspaceDeleteTheSelectedClip() throws {
        let (vm, repo, _, _) = try makeViewModel(seedCount: 3)
        for mods in [EventModifiers.command, EventModifiers.control] {
            let result = handle(
                .delete,
                characters: "\u{7F}",
                modifiers: mods,
                viewModel: vm
            )
            #expect(result == .handled)
        }
        #expect(try repo.fetchAll(limit: nil).count == 1)
    }

    @Test func commandCCopiesSelectedClipWithoutPasting() throws {
        let (vm, _, paster, writer) = try makeViewModel(seedCount: 3)
        vm.panel.show()
        let result = handle(
            "c",
            characters: "c",
            modifiers: .command,
            viewModel: vm
        )
        #expect(result == .handled)
        #expect(writer.writeCount == 1)
        #expect(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) } == "item-2")
        #expect(paster.pasteCount == 0)
        #expect(vm.panel.isShown == true, "⌘C must not dismiss the panel")
    }

    @Test func optionReturnPastesSelectedClipAsPlainText() async throws {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        _ = try repo.insert(
            payload: ClipPayload(typed: [
                NSPasteboard.PasteboardType.string.rawValue: Data("styled".utf8),
                NSPasteboard.PasteboardType.rtf.rawValue: Data("{\\rtf1}".utf8),
            ]),
            sourceBundleId: "com.test"
        )
        let paster = MockPaster()
        let writer = MockPasteboardWriter()
        let vm = HistoryListViewModel(
            repository: repo,
            paster: paster,
            pasteboardWriter: writer,
            panel: PanelCoordinator()
        )
        vm.refresh()

        let result = handle(
            .return,
            characters: "\r",
            modifiers: .option,
            viewModel: vm
        )
        #expect(result == .handled)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(writer.lastWrite?.keys.sorted() == [NSPasteboard.PasteboardType.string.rawValue])
        #expect(paster.pasteCount == 1)
    }

    @Test func optionArrowsPassThroughWhileSearching() throws {
        let (vm, _, _, _) = try makeViewModel(seedCount: 2)
        vm.searchText = "item"
        let result = handle(
            .leftArrow,
            characters: "",
            modifiers: .option,
            viewModel: vm
        )
        #expect(result == .ignored)
    }

    @Test func spaceTogglesPreviewOnlyWhenNotSearching() throws {
        let (vm, _, _, _) = try makeViewModel()
        let idle = handle(
            .space,
            characters: " ",
            viewModel: vm
        )
        #expect(idle == .handled)

        vm.searchText = "item"
        let searching = handle(
            .space,
            characters: " ",
            viewModel: vm
        )
        #expect(searching == .ignored)
    }
}
