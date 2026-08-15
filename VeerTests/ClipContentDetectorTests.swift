import Foundation
import Testing
@testable import Veer

struct ClipContentDetectorTests {
    // MARK: URLs

    @Test func detectsHTTPSURLWithActions() throws {
        let actions = ClipContentDetector.actions(for: "https://example.com/path?q=1")
        #expect(actions.count == 2)
        #expect(actions[0] == .openURL(try #require(URL(string: "https://example.com/path?q=1"))))
        #expect(actions[1] == .copyMarkdownLink(try #require(URL(string: "https://example.com/path?q=1"))))
    }

    @Test func detectsPlainHTTPURL() throws {
        let actions = ClipContentDetector.actions(for: "http://example.com")
        #expect(actions.first == .openURL(try #require(URL(string: "http://example.com"))))
    }

    @Test func wwwPrefixBecomesHTTPSURL() throws {
        let actions = ClipContentDetector.actions(for: "www.example.com")
        #expect(actions.first == .openURL(try #require(URL(string: "https://www.example.com"))))
    }

    @Test func rejectsNonURLScheme() {
        let actions = ClipContentDetector.actions(for: "ftp://example.com")
        #expect(actions.isEmpty)
    }

    @Test func rejectsSentenceContainingURL() {
        let actions = ClipContentDetector.actions(for: "Check out https://example.com today")
        #expect(actions.isEmpty)
    }

    @Test func rejectsBareDomainWithoutScheme() {
        #expect(ClipContentDetector.actions(for: "example.com").isEmpty)
    }

    @Test func trimsWhitespaceBeforeDetecting() {
        #expect(!ClipContentDetector.actions(for: "  https://example.com\n").isEmpty)
    }

    // MARK: Email

    @Test func detectsEmail() {
        let actions = ClipContentDetector.actions(for: "hello@example.com")
        #expect(actions == [.composeEmail("hello@example.com")])
    }

    @Test func rejectsEmailMissingTLD() {
        #expect(ClipContentDetector.actions(for: "user@localhost").isEmpty)
    }

    @Test func rejectsEmailEmbeddedInText() {
        #expect(ClipContentDetector.actions(for: "mail me at hello@example.com please").isEmpty)
    }

    // MARK: Phone

    @Test func detectsFormattedPhoneNumber() {
        let actions = ClipContentDetector.actions(for: "(415) 555-2671")
        #expect(actions == [.callPhone("(415) 555-2671")])
    }

    @Test func detectsPhoneWithCountryCode() {
        let actions = ClipContentDetector.actions(for: "+1 415 555 2671")
        #expect(actions == [.callPhone("+1 415 555 2671")])
    }

    @Test func rejectsShortBareNumber() {
        #expect(ClipContentDetector.actions(for: "12345").isEmpty)
    }

    @Test func rejectsISODateAsPhoneNumber() {
        #expect(ClipContentDetector.actions(for: "2024-01-01").isEmpty)
    }

    @Test func rejectsPhoneWithColonSeparators() {
        #expect(ClipContentDetector.actions(for: "415:555:2671").isEmpty)
    }

    // MARK: Hex color

    @Test func detectsSixDigitHex() {
        let actions = ClipContentDetector.actions(for: "#FF5733")
        #expect(actions == [.copySwiftColor(hex: "FF5733")])
    }

    @Test func detectsBareHexWithoutHash() {
        let actions = ClipContentDetector.actions(for: "FF5733")
        #expect(actions == [.copySwiftColor(hex: "FF5733")])
    }

    @Test func detectsShortHex() {
        let actions = ClipContentDetector.actions(for: "fff")
        #expect(actions == [.copySwiftColor(hex: "fff")])
    }

    @Test func detectsEightDigitHex() {
        let actions = ClipContentDetector.actions(for: "FF573380")
        #expect(actions == [.copySwiftColor(hex: "FF573380")])
    }

    @Test func rejectsNonHexText() {
        #expect(ClipContentDetector.actions(for: "zzz").isEmpty)
        #expect(ClipContentDetector.actions(for: "12345").isEmpty)
    }

    // MARK: Fallthrough

    @Test func plainProseYieldsNoActions() {
        #expect(ClipContentDetector.actions(for: "Plain text fixture").isEmpty)
        #expect(ClipContentDetector.actions(for: "").isEmpty)
        #expect(ClipContentDetector.actions(for: "   ").isEmpty)
    }
}
