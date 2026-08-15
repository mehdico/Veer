import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct ClipActionsTests {
    private func makeViewModel(
        texts: [String],
        settings: SettingsStore? = nil,
        translationAvailabilityCheck: ((String) async -> Bool)? = nil
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
            settings: settings,
            actionRunner: runner,
            translationAvailabilityCheck: translationAvailabilityCheck
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

    @Test func fileClipGetsFinderAndCopyActions() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veer-actions-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let (vm, repo, _, _) = try await makeViewModel(texts: [])
        _ = try repo.insert(
            payload: ClipPayload(typed: [
                NSPasteboard.PasteboardType.fileURL.rawValue: Data(url.absoluteString.utf8),
            ]),
            sourceBundleId: "com.test"
        )
        vm.refresh()

        let clip = try #require(vm.items.first)
        #expect(vm.actions(for: clip) == [
            .revealInFinder(url),
            .openFile(url),
            .copyPath(url),
            .copyFile(url),
            .copyMarkdownLink(url),
        ])
    }

    @Test func folderClipAddsTerminalAction() async throws {
        let (vm, repo, _, _) = try await makeViewModel(texts: [])
        _ = try repo.insert(
            payload: ClipPayload(typed: [
                NSPasteboard.PasteboardType.fileURL.rawValue: Data("file:///tmp".utf8),
            ]),
            sourceBundleId: "com.test"
        )
        vm.refresh()

        let clip = try #require(vm.items.first)
        let actions = vm.actions(for: clip)
        #expect(actions.contains(.openInTerminal(URL(fileURLWithPath: "/tmp"))))
        #expect(actions.count == 6)
    }

    @Test func existingPathTextGetsFileActions() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["/tmp"])
        let clip = try #require(vm.items.first)

        let actions = vm.actions(for: clip)
        #expect(actions.first == .revealInFinder(URL(fileURLWithPath: "/tmp")))
        #expect(actions.contains(.openInTerminal(URL(fileURLWithPath: "/tmp"))))
    }

    @Test func imageClipGetsDownloadAndPNGActions() async throws {
        let png = try #require(Self.redPixelPNG())
        let (vm, repo, _, _) = try await makeViewModel(texts: [])
        _ = try repo.insert(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.png.rawValue: png]),
            sourceBundleId: "com.test"
        )
        vm.refresh()

        let clip = try #require(vm.items.first)
        #expect(vm.actions(for: clip) == [
            .saveToDownloads(source: .data(png), fileExtension: "png", suggestedName: nil),
            .copyAsPNG(source: .data(png)),
        ])
    }

    @Test func colorClipGetsHexRGBAndUIColorActions() async throws {
        let color = NSColor(srgbRed: 1.0, green: 87.0 / 255.0, blue: 51.0 / 255.0, alpha: 1.0)
        let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
        let (vm, repo, _, _) = try await makeViewModel(texts: [])
        _ = try repo.insert(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.color.rawValue: data]),
            sourceBundleId: "com.test"
        )
        vm.refresh()

        let clip = try #require(vm.items.first)
        #expect(vm.actions(for: clip) == [
            .copyHexColor("#FF5733"),
            .copyCSSRGB(red: 255, green: 87, blue: 51),
            .copyUIColor(red: 1.0, green: 0.3411764705882353, blue: 0.2, alpha: 1.0),
        ])
    }

    @Test func richTextClipGetsCopyPlainTextAction() async throws {
        let attr = NSAttributedString(string: "Formatted hello", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 14),
        ])
        let rtf = try attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let (vm, repo, _, _) = try await makeViewModel(texts: [])
        _ = try repo.insert(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.rtf.rawValue: rtf]),
            sourceBundleId: "com.test"
        )
        vm.refresh()

        let clip = try #require(vm.items.first)
        let actions = vm.actions(for: clip)
        #expect(actions.last == .copyPlainText("Formatted hello"))
    }

    @Test func searchWebToggleAddsActionForPlainProse() async throws {
        let suite = try #require(UserDefaults(suiteName: "veer-tests-\(UUID().uuidString)"))
        let settings = SettingsStore(defaults: suite)
        settings.alwaysSearchWeb = true
        let (vm, _, _, _) = try await makeViewModel(texts: ["Plain text fixture"], settings: settings)
        let clip = try #require(vm.items.first)

        #expect(vm.actions(for: clip) == [.searchWeb("Plain text fixture")])
    }

    @Test func nonEnglishProseGetsTranslateActionWhenPackAvailable() async throws {
        let (vm, _, _, _) = try await makeViewModel(
            texts: ["Bonjour tout le monde, comment allez-vous aujourd'hui ?"],
            translationAvailabilityCheck: { _ in true }
        )
        let clip = try #require(vm.items.first)

        let actions = vm.actions(for: clip)
        #expect(actions == [.translate(
            text: "Bonjour tout le monde, comment allez-vous aujourd'hui ?",
            sourceLanguage: "fr"
        )])
    }

    @Test func nonEnglishProseWithoutPackGetsNoTranslateAction() async throws {
        let (vm, _, _, _) = try await makeViewModel(
            texts: ["Bonjour tout le monde, comment allez-vous aujourd'hui ?"],
            translationAvailabilityCheck: { _ in false }
        )
        let clip = try #require(vm.items.first)

        #expect(vm.actions(for: clip).isEmpty)
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

    @Test func stepActionsBackwardWrapsToLastAction() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com"])

        vm.stepActions() // opens on first action
        #expect(vm.actionIndex == 0)
        vm.stepActionsBackward()
        #expect(vm.actionIndex == 1) // wraps to the last action
        vm.stepActionsBackward()
        #expect(vm.actionIndex == 0)
    }

    @Test func stepActionsBackwardOpensStripWhenClosed() async throws {
        let (vm, _, _, _) = try await makeViewModel(texts: ["https://example.com"])

        vm.stepActionsBackward()

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

    private static func redPixelPNG() -> Data? {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )
        guard let rep else { return nil }
        rep.setColor(NSColor.red, atX: 0, y: 0)
        return rep.representation(using: .png, properties: [:])
    }
}
