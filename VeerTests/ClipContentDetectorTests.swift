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
        // ISO dates are detected as dates, never as phone numbers.
        let actions = ClipContentDetector.actions(for: "2024-01-01")
        #expect(actions == [.copyEpochSeconds("1704067200")])
        #expect(!actions.contains { if case .callPhone = $0 { true } else { false } })
    }

    @Test func rejectsBareLongNumberAsPhoneNumber() {
        #expect(ClipContentDetector.actions(for: "123456789012345").isEmpty)
    }

    @Test func rejectsPhoneWithColonSeparators() {
        #expect(ClipContentDetector.actions(for: "415:555:2671").isEmpty)
    }

    // MARK: Git URLs

    @Test func detectsGitSSHURL() throws {
        let actions = ClipContentDetector.actions(for: "git@github.com:user/repo.git")
        #expect(actions == [
            .copyGitCloneURL("git@github.com:user/repo.git"),
            .openGitHub(try #require(URL(string: "https://github.com/user/repo.git"))),
        ])
    }

    @Test func rejectsGitSSHWithoutSlashPath() {
        #expect(ClipContentDetector.actions(for: "git@github.com:user").isEmpty)
    }

    @Test func gitHostHTTPSURLAddsCloneAction() throws {
        let actions = ClipContentDetector.actions(for: "https://github.com/user/repo")
        #expect(actions == [
            .openURL(try #require(URL(string: "https://github.com/user/repo"))),
            .copyGitCloneURL("https://github.com/user/repo"),
            .copyMarkdownLink(try #require(URL(string: "https://github.com/user/repo"))),
        ])
    }

    @Test func nonGitHostHTTPSURLHasNoCloneAction() throws {
        let actions = ClipContentDetector.actions(for: "https://example.com/repo")
        #expect(actions.count == 2)
    }

    // MARK: Coordinates

    @Test func detectsDecimalCoordinates() throws {
        let actions = ClipContentDetector.actions(for: "40.7128, -74.0060")
        #expect(actions == [.openInMaps(latitude: 40.7128, longitude: -74.0060)])
    }

    @Test func detectsHemisphereSuffixedCoordinates() throws {
        let actions = ClipContentDetector.actions(for: "51.5074 N, 0.1278 W")
        #expect(actions == [.openInMaps(latitude: 51.5074, longitude: -0.1278)])
    }

    @Test func rejectsTupleWithoutDecimalPoint() {
        #expect(ClipContentDetector.actions(for: "12, 34").isEmpty)
    }

    @Test func rejectsOutOfRangeLatitude() {
        #expect(ClipContentDetector.actions(for: "91.5, 10").isEmpty)
    }

    @Test func rejectsGarbageCoordinates() {
        #expect(ClipContentDetector.actions(for: "abc, def").isEmpty)
        #expect(ClipContentDetector.actions(for: "40.7128").isEmpty)
    }

    // MARK: Math

    @Test func detectsArithmeticExpression() {
        let actions = ClipContentDetector.actions(for: "2+2*10")
        #expect(actions == [.copyMathResult("22")])
    }

    @Test func detectsParenthesizedExpression() {
        #expect(ClipContentDetector.actions(for: "(12+8)/4") == [.copyMathResult("5")])
    }

    @Test func detectsDecimalResult() {
        #expect(ClipContentDetector.actions(for: "7/2") == [.copyMathResult("3.5")])
    }

    @Test func rejectsMalformedExpressions() {
        #expect(ClipContentDetector.actions(for: "1+").isEmpty)
        #expect(ClipContentDetector.actions(for: "()").isEmpty)
        #expect(ClipContentDetector.actions(for: "1+2)").isEmpty)
        #expect(ClipContentDetector.actions(for: "1 2").isEmpty)
    }

    @Test func rejectsDatesAndVersionsAsMath() {
        #expect(ClipContentDetector.detectMathExpression(in: "2024-01-01") == nil)
        #expect(ClipContentDetector.detectMathExpression(in: "12-30") == nil)
        #expect(ClipContentDetector.evaluateMath("2.3.4") == nil)
    }

    @Test func evaluatesOperatorPrecedence() throws {
        #expect(try #require(ClipContentDetector.evaluateMath("2+3*4")) == 14)
        #expect(try #require(ClipContentDetector.evaluateMath("(2+3)*4")) == 20)
        #expect(try #require(ClipContentDetector.evaluateMath("10-2-3")) == 5)
        #expect(try #require(ClipContentDetector.evaluateMath("10/2/5")) == 1)
        #expect(try #require(ClipContentDetector.evaluateMath("-5+3")) == -2)
        #expect(try #require(ClipContentDetector.evaluateMath("2*-3")) == -6)
    }

    @Test func mathEvaluatorRejectsDivisionByZero() {
        #expect(ClipContentDetector.evaluateMath("1/0") == nil)
    }

    // MARK: JSON

    @Test func minifiedJSONGetsPrettyPrintAction() {
        let actions = ClipContentDetector.actions(for: #"{"b":2,"a":1}"#)
        #expect(actions == [.copyPrettyJSON("{\n  \"a\" : 1,\n  \"b\" : 2\n}")])
    }

    @Test func prettyJSONGetsMinifyAction() {
        let pretty = """
        {
          "a" : 1
        }
        """
        let actions = ClipContentDetector.actions(for: pretty)
        #expect(actions == [.copyMinifiedJSON(#"{"a":1}"#)])
    }

    @Test func rejectsNonJSONBraceText() {
        #expect(ClipContentDetector.actions(for: "{not json}").isEmpty)
        #expect(ClipContentDetector.actions(for: "[1, 2").isEmpty)
    }

    // MARK: Epoch

    @Test func detectsISODateWithTime() throws {
        let actions = ClipContentDetector.actions(for: "2024-01-01T00:00:00Z")
        #expect(actions == [.copyEpochSeconds("1704067200")])
    }

    @Test func rejectsNonISODates() {
        #expect(ClipContentDetector.actions(for: "Jan 1, 2024").isEmpty)
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
