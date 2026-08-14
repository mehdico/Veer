import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct CellKindTests {
    private func snapshot(types: [NSPasteboard.PasteboardType]) -> ClipItemSnapshot {
        ClipItemSnapshot(
            id: UUID(),
            createdAt: .init(),
            sourceBundleId: nil,
            preview: nil,
            typeRawValues: types.map(\.rawValue)
        )
    }

    @Test func imageHasHighestPriority() {
        let s = snapshot(types: [.png, .string, .rtf])
        #expect(s.kind == .image)
    }

    @Test func tiffMapsToImage() {
        #expect(snapshot(types: [.tiff]).kind == .image)
    }

    @Test func pdfBeatsColorAndFileAndRtf() {
        let s = snapshot(types: [.pdf, .color, .fileURL, .rtf, .string])
        #expect(s.kind == .pdf)
    }

    @Test func colorBeatsFileAndRtf() {
        let s = snapshot(types: [.color, .fileURL, .rtf])
        #expect(s.kind == .color)
    }

    @Test func fileBeatsRtf() {
        let s = snapshot(types: [.fileURL, .rtf, .string])
        #expect(s.kind == .file)
    }

    @Test func rtfBeatsPlainText() {
        let s = snapshot(types: [.rtf, .string])
        #expect(s.kind == .richText)
    }

    @Test func plainStringIsText() {
        #expect(snapshot(types: [.string]).kind == .text)
    }

    @Test func unknownDefaultsToText() {
        let s = snapshot(types: [])
        #expect(s.kind == .text)
    }

    @Test func textOnlyPayloadsAreTextual() {
        #expect(ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("hi".utf8)]).isTextOnly)
        #expect(ClipPayload(typed: [NSPasteboard.PasteboardType.rtf.rawValue: Data("rtf".utf8)]).isTextOnly)
        #expect(ClipPayload(typed: [NSPasteboard.PasteboardType.html.rawValue: Data("html".utf8)]).isTextOnly)
        #expect(ClipPayload(typed: [NSPasteboard.PasteboardType.rtfd.rawValue: Data("rtfd".utf8)]).isTextOnly)
        #expect(ClipPayload(typed: [NSPasteboard.PasteboardType.URL.rawValue: Data("https://example.com".utf8)]).isTextOnly)
    }

    @Test func nonTextPayloadsAreNotTextOnly() {
        #expect(!ClipPayload(typed: [NSPasteboard.PasteboardType.png.rawValue: Data([0x89, 0x50])]).isTextOnly)
        #expect(!ClipPayload(typed: [NSPasteboard.PasteboardType.pdf.rawValue: Data([0x25, 0x50])]).isTextOnly)
        #expect(!ClipPayload(typed: [NSPasteboard.PasteboardType.color.rawValue: Data([0x00])]).isTextOnly)
        #expect(!ClipPayload(typed: [NSPasteboard.PasteboardType.fileURL.rawValue: Data("file:///tmp/a.txt".utf8)]).isTextOnly)
    }

    @Test func textFileIsNotTextOnly() {
        // A copied file is skipped even when it is a text file.
        let payload = ClipPayload(typed: [
            NSPasteboard.PasteboardType.fileURL.rawValue: Data("file:///tmp/a.txt".utf8),
            NSPasteboard.PasteboardType.string.rawValue: Data("hello".utf8),
        ])
        #expect(!payload.isTextOnly)
    }
}
