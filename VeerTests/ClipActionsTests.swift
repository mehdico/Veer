import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct ClipActionsTests {
    private func makeViewModel(
        texts: [String]
    ) async throws -> (HistoryListViewModel, ClipRepositoryLive, MockClipActionRunner, PanelCoordinator) {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        for text in texts {
            _ = try repo.insert(
                payload: ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8)]),
                sourceBundleId: "com.test"
            )
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let runner = MockClipActionRunner()
        let panel = PanelCoordinator()
        let vm = HistoryListViewModel(
            repository: repo,
            paster: MockPaster(),
            pasteboardWriter: MockPasteboardWriter(),
            panel: panel,
            actionRunner: runner
        )
        vm.refresh()
        return (vm, repo, runner, panel)
    }

    private func snapshot(kind: CellKind, preview: String) -> ClipItemSnapshot {
        let raw: String
        switch kind {
        case .image: raw = NSPasteboard.PasteboardType.png.rawValue
        case .text: raw = NSPasteboard.PasteboardType.string.rawValue
        case .richText: raw = NSPasteboard.PasteboardType.rtf.rawValue
        default: raw = NSPasteboard.PasteboardType.string.rawValue
        }
        return ClipItemSnapshot(
            id: UUID(),
            createdAt: .init(),
            sourceBundleId: nil,
            preview: preview,
            typeRawValues: [raw]
        )
    }

    @Test func actionsDetectedForURLTextClip() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com/veer"])
        let clip = try #require(vm.items.first)
        let actions = vm.actions(for: clip)
        #expect(actions == [
            .openURL(try #require(URL(string: "https://example.com/veer"))),
            .copyMarkdownLink(try #require(URL(string: "https://example.com/veer"))),
        ])
    }

    @Test func actionsEmptyForPlainTextAndNonTextKinds() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["Plain text fixture"])
        let textClip = try #require(vm.items.first)
        #expect(vm.actions(for: textClip).isEmpty)

        let imageClip = snapshot(kind: .image, preview: "FF5733")
        #expect(vm.actions(for: imageClip).isEmpty)
    }

    @Test func runPrimaryActionRunsFirstDetectedActionAndHidesPanel() async throws {
        let (vm, _, runner, panel) = try await makeViewModel(texts: ["https://example.com"])
        panel.show()

        vm.runPrimaryAction()

        #expect(runner.runActions.first == .openURL(try #require(URL(string: "https://example.com"))))
        #expect(panel.isShown == false)
    }

    @Test func runPrimaryActionIsNoopForUndetectedClip() async throws {
        let (vm, _, runner, panel) = try await makeViewModel(texts: ["Plain text fixture"])
        panel.show()

        vm.runPrimaryAction()

        #expect(runner.runActions.isEmpty)
        #expect(panel.isShown == true)
    }

    @Test func launchingActionHidesPanelAndPreview() async throws {
        let (vm, _, _, panel) = try await makeViewModel(texts: [])
        let preview = PreviewCoordinator()
        vm.preview = preview
        panel.show()
        preview.show(snapshot(kind: .text, preview: "https://example.com"))

        vm.run(.openURL(try #require(URL(string: "https://example.com"))))

        #expect(panel.isShown == false)
        #expect(preview.isShown == false)
    }

    @Test func copyActionDismissesPanelAndPreview() async throws {
        let (vm, _, _, panel) = try await makeViewModel(texts: [])
        let preview = PreviewCoordinator()
        vm.preview = preview
        panel.show()
        preview.show(snapshot(kind: .text, preview: "https://example.com"))

        vm.run(.copyMarkdownLink(try #require(URL(string: "https://example.com"))))

        #expect(panel.isShown == false)
        #expect(preview.isShown == false)
    }

    @Test func stepActionsRevealsStepsAndCycles() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com", "Plain text fixture"])
        vm.selectedIndex = 1 // URL clip with 2 actions

        vm.stepActions()
        #expect(vm.actionsExpanded == true)
        #expect(vm.actionIndex == 0)
        vm.stepActions()
        #expect(vm.actionsExpanded == true)
        #expect(vm.actionIndex == 1)
        vm.stepActions()
        #expect(vm.actionsExpanded == true)
        #expect(vm.actionIndex == 0) // wraps around
    }

    @Test func closeActionStripExitsAndResets() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com"])
        vm.stepActions()
        #expect(vm.actionsExpanded == true)

        vm.closeActionStrip()

        #expect(vm.actionsExpanded == false)
        #expect(vm.actionIndex == 0)
    }

    @Test func stepActionsKeepsSingleActionStripOpen() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["hello@example.com"])

        vm.stepActions()
        #expect(vm.actionsExpanded == true)
        #expect(vm.actionIndex == 0)
        vm.stepActions()
        #expect(vm.actionsExpanded == true)
        #expect(vm.actionIndex == 0)
    }

    @Test func stepActionsDoesNothingForUndetectedClip() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["Plain text fixture"])

        vm.stepActions()

        #expect(vm.actionsExpanded == false)
    }

    @Test func stepActionsKeepsSelection() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com", "Plain text fixture"])
        vm.selectedIndex = 1

        vm.stepActions()

        #expect(vm.selectedIndex == 1)
        #expect(vm.actionsExpanded == true)
    }

    @Test func selectionChangeClosesActionStrip() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com", "https://example.org"])
        vm.selectedIndex = 1
        vm.stepActions()
        #expect(vm.actionsExpanded == true)

        vm.navigateUp()

        #expect(vm.selectedIndex == 0)
        #expect(vm.actionsExpanded == false)
    }

    @Test func resetForShowClosesActionStrip() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com"])
        vm.stepActions()
        #expect(vm.actionsExpanded == true)

        vm.resetForShow()

        #expect(vm.actionsExpanded == false)
        #expect(vm.actionIndex == 0)
    }

    @Test func runHighlightedActionRunsSteppedAction() async throws {
        let (vm, _, runner, _) = try await makeViewModel(texts: ["https://example.com"])
        vm.stepActions()
        vm.stepActions()
        #expect(vm.actionIndex == 1)

        vm.runHighlightedAction()

        #expect(runner.runActions.first == .copyMarkdownLink(try #require(URL(string: "https://example.com"))))
    }
}
