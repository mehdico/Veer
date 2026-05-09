import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct PastesRichTextSettingTests {
    private func blob(_ raw: String, _ data: Data) -> PayloadBlob {
        PayloadBlob(typeRawValue: raw, data: data)
    }

    private func makeRTF(_ string: String) -> Data {
        let attr = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        return (try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )) ?? Data()
    }

    @Test func pastesRichTextOnIncludesAllBlobs() {
        let blobs = [
            blob("public.utf8-plain-text", Data("hello".utf8)),
            blob("public.rtf", makeRTF("hello")),
            blob("public.html", Data("<b>hello</b>".utf8)),
        ]
        let payload = HistoryListViewModel.pasteboardPayload(for: blobs, pastesRichText: true)
        #expect(payload.count == 3)
        #expect(payload["public.rtf"] != nil)
        #expect(payload["public.html"] != nil)
    }

    @Test func pastesRichTextOffStripsRtfAndHtml() {
        let blobs = [
            blob("public.utf8-plain-text", Data("hello".utf8)),
            blob("public.rtf", makeRTF("hello")),
            blob("public.html", Data("<b>hello</b>".utf8)),
        ]
        let payload = HistoryListViewModel.pasteboardPayload(for: blobs, pastesRichText: false)
        #expect(payload["public.rtf"] == nil)
        #expect(payload["public.html"] == nil)
        #expect(payload["public.utf8-plain-text"] == Data("hello".utf8))
    }

    @Test func pastesRichTextOffPreservesNonTextBlobs() {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let blobs = [
            blob(NSPasteboard.PasteboardType.png.rawValue, png),
            blob("public.utf8-plain-text", Data("alt".utf8)),
        ]
        let payload = HistoryListViewModel.pasteboardPayload(for: blobs, pastesRichText: false)
        #expect(payload[NSPasteboard.PasteboardType.png.rawValue] == png)
    }

    @Test func pastesRichTextOffOnRtfOnlyItemDerivesPlainText() {
        let rtf = makeRTF("Hello world")
        let payload = HistoryListViewModel.pasteboardPayload(
            for: [blob("public.rtf", rtf)],
            pastesRichText: false
        )
        let plain = payload["public.utf8-plain-text"].flatMap { String(data: $0, encoding: .utf8) }
        #expect(plain == "Hello world")
        #expect(payload["public.rtf"] == nil)
    }

    @Test func pasteFlowHonorsPastesRichTextSettingEndToEnd() async throws {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container)
        let writer = MockPasteboardWriter()
        let panel = PanelCoordinator()
        let defaults = UserDefaults(suiteName: "veer.test.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.pastesRichText = false

        let vm = HistoryListViewModel(
            repository: repo,
            paster: MockPaster(),
            pasteboardWriter: writer,
            panel: panel,
            settings: settings,
            pasteDelay: .zero
        )

        let payload = ClipPayload(typed: [
            "public.utf8-plain-text": Data("hello".utf8),
            "public.rtf": makeRTF("hello"),
            "public.html": Data("<b>hello</b>".utf8),
        ])
        _ = try repo.insert(payload: payload, sourceBundleId: nil)
        vm.refresh()

        await vm.pasteSelected()

        let written = writer.lastWrite ?? [:]
        #expect(written["public.rtf"] == nil)
        #expect(written["public.html"] == nil)
        #expect(written["public.utf8-plain-text"] == Data("hello".utf8))
    }
}
