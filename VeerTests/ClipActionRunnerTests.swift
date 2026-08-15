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

    @Test func copyMarkdownLinkFormatsFileURLsWithNameAndPath() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)
        let url = URL(fileURLWithPath: "/Users/test/Report.pdf")

        runner.run(.copyMarkdownLink(url))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "[Report.pdf](/Users/test/Report.pdf)")
    }

    @Test func copyPathWritesPOSIXPath() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)
        let url = URL(fileURLWithPath: "/Users/test/Report.pdf")

        runner.run(.copyPath(url))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "/Users/test/Report.pdf")
    }

    @Test func copyFileWritesFileURLAndPathTypes() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)
        let url = URL(fileURLWithPath: "/Users/test/Report.pdf")

        runner.run(.copyFile(url))

        let typed = try #require(writer.lastWrite)
        #expect(typed[NSPasteboard.PasteboardType.fileURL.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) } == "file:///Users/test/Report.pdf")
        #expect(typed[NSPasteboard.PasteboardType.string.rawValue]
            .flatMap { String(data: $0, encoding: .utf8) } == "/Users/test/Report.pdf")
    }

    @Test func copyMathResultWritesValue() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyMathResult("22"))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "22")
    }

    @Test func copyGitCloneURLWritesCloneCommand() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyGitCloneURL("git@github.com:user/repo.git"))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "git@github.com:user/repo.git")
    }

    @Test func copyPlainTextWritesString() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyPlainText("hello"))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "hello")
    }

    @Test func copyHexColorWritesHashPrefixedHex() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyHexColor("#FF5733"))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "#FF5733")
    }

    @Test func copyCSSRGBWritesCSSTriplet() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyCSSRGB(red: 255, green: 87, blue: 51))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "rgb(255, 87, 51)")
    }

    @Test func copyUIColorRendersSnippet() throws {
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyUIColor(red: 1.0, green: 0.341, blue: 0.2, alpha: 0.5))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.string.rawValue])
            .flatMap { String(data: $0, encoding: .utf8) }
        #expect(written == "UIColor(red: 1.000, green: 0.341, blue: 0.200, alpha: 0.500)")
    }

    @Test func saveToDownloadsWritesFileWithUniqueName() throws {
        let writer = MockPasteboardWriter()
        let downloads = FileManager.default.temporaryDirectory
            .appendingPathComponent("veer-runner-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: downloads) }
        let runner = LiveClipActionRunner(pasteboardWriter: writer, downloadsDirectory: downloads)

        runner.run(.saveToDownloads(source: .data(Data("png-bytes".utf8)), fileExtension: "png", suggestedName: "Clip"))
        runner.run(.saveToDownloads(source: .data(Data("png-bytes".utf8)), fileExtension: "png", suggestedName: "Clip"))

        let first = downloads.appendingPathComponent("Clip.png")
        let second = downloads.appendingPathComponent("Clip 2.png")
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test func copyAsPNGReencodesImageData() throws {
        // A 1x1 red PNG.
        let png = try #require(Self.redPixelPNG())
        let writer = MockPasteboardWriter()
        let runner = LiveClipActionRunner(pasteboardWriter: writer)

        runner.run(.copyAsPNG(source: .data(png)))

        let written = try #require(writer.lastWrite?[NSPasteboard.PasteboardType.png.rawValue])
        #expect(!written.isEmpty)
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
