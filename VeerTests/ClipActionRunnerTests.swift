import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct ClipActionRunnerTests {
    @Test func copyMarkdownLinkWritesLinkToPasteboard() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)
        let url = try #require(URL(string: "https://example.com/veer"))

        runner.run(.copyMarkdownLink(url))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "[https://example.com/veer](https://example.com/veer)")
    }

    @Test func copySwiftColorRendersFullHexSnippet() {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copySwiftColor(hex: "FF5733"))

        let written = writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "Color(red: 1.000, green: 0.341, blue: 0.200)")
    }

    @Test func copySwiftColorExpandsShortHex() {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copySwiftColor(hex: "fff"))

        let written = writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "Color(red: 1.000, green: 1.000, blue: 1.000)")
    }

    @Test func copySwiftColorIncludesOpacityForEightDigitHex() {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copySwiftColor(hex: "FF573380"))

        let written = writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "Color(red: 1.000, green: 0.341, blue: 0.200, opacity: 0.502)")
    }

    @Test func swiftColorSnippetFallsBackToRawHexWhenMalformed() {
        #expect(LiveClipActionRunner.swiftColorSnippet(hex: "12345") == "12345")
    }
}
