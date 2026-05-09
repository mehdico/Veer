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
            typeRawValues: types.map(\.rawValue),
            thumbnailPNG: nil
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
}
