import Foundation
import NaturalLanguage

/// Detects what a text clip *is* — a URL, email address, phone number, hex
/// color, coordinate pair, JSON document, arithmetic expression, ISO date, or
/// git URL — so the UI can offer smart actions for it.
///
/// Detection is deliberately conservative: the entire trimmed text must be one
/// recognizable value. Mixed text (a sentence containing a URL, a multi-line
/// copy, …) produces no actions, so we never offer "open in browser" on prose.
enum ClipContentDetector {
    static func actions(for text: String) -> [ClipAction] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let url = detectURL(in: trimmed) {
            var actions = [ClipAction.openURL(url)]
            if isGitHost(url) {
                actions.append(.copyGitCloneURL(url.absoluteString))
            }
            actions.append(.copyMarkdownLink(url))
            return actions
        }
        if let git = detectGitSSH(in: trimmed) {
            return [.copyGitCloneURL(git.clone), .openGitHub(git.httpsURL)]
        }
        if detectEmail(in: trimmed) != nil {
            return [.composeEmail(trimmed)]
        }
        if detectPhone(in: trimmed) {
            return [.callPhone(trimmed)]
        }
        if let hex = detectHex(in: trimmed) {
            return [.copySwiftColor(hex: hex)]
        }
        if let coordinates = detectCoordinates(in: trimmed) {
            return [.openInMaps(latitude: coordinates.latitude, longitude: coordinates.longitude)]
        }
        if let json = detectJSONReformat(in: trimmed) {
            let minified = !trimmed.contains("\n")
            return [minified ? .copyPrettyJSON(json) : .copyMinifiedJSON(json)]
        }
        if let result = detectMathExpression(in: trimmed) {
            return [.copyMathResult(result)]
        }
        if let epoch = detectISODateEpochSeconds(in: trimmed) {
            return [.copyEpochSeconds(epoch)]
        }
        return []
    }

    static func detectURL(in text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            guard let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host, !host.isEmpty
            else { return nil }
            return url
        }
        if lower.hasPrefix("www.") {
            guard let url = URL(string: "https://\(text)"), url.host?.isEmpty == false else { return nil }
            return url
        }
        return nil
    }

    /// Whether a host commonly runs git-over-https, so the clip can also be
    /// copied as a `git clone` command.
    static func isGitHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
            || host == "gitlab.com" || host == "bitbucket.org"
    }

    /// SCP-style git URLs (`git@github.com:user/repo.git`), which the URL
    /// detector intentionally ignores. Returns the clone string and the
    /// equivalent https URL for opening in a browser.
    static func detectGitSSH(in text: String) -> (clone: String, httpsURL: URL)? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let pattern = #"^[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+):(.+)$"#
        guard let regex = try? Regex(pattern),
              let match = text.wholeMatch(of: regex)
        else { return nil }
        let parts = Array(match.output)
        guard parts.count == 3,
              let host = parts[1].substring.map(String.init),
              let path = parts[2].substring.map(String.init),
              host.contains("."),
              path.contains("/"),
              let httpsURL = URL(string: "https://\(host)/\(path)")
        else { return nil }
        return (text, httpsURL)
    }

    static func detectEmail(in text: String) -> String? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard let regex = try? Regex(pattern) else { return nil }
        return text.wholeMatch(of: regex) != nil ? text : nil
    }

    static func detectPhone(in text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        guard (7...15).contains(digits.count) else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789+(). -")
        guard text.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        // Bare digit runs need a country code or parentheses to qualify;
        // otherwise require separators and enough digits so dates like
        // 2024-01-01 (8 digits) and version strings don't register as phones.
        if text.hasPrefix("+") || text.contains("(") || text.contains(")") {
            return true
        }
        let hasSeparator = text.contains { "- .".contains($0) }
        return hasSeparator && digits.count >= 9
    }

    static func detectHex(in text: String) -> String? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let core = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard [3, 6, 8].contains(core.count) else { return nil }
        guard core.allSatisfy(\.isHexDigit) else { return nil }
        return core
    }

    /// Decimal latitude/longitude pairs, optionally with a hemisphere suffix
    /// (`40.7128, -74.0060`, `51.5074 N, 0.1278 W`). Requires a decimal point
    /// so plain tuples like `12, 34` don't open Maps.
    static func detectCoordinates(in text: String) -> (latitude: Double, longitude: Double)? {
        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        guard let latitude = parseCoordinate(
                parts[0], positive: "Nn", negative: "Ss", range: -90...90
              ),
              let longitude = parseCoordinate(
                parts[1], positive: "Ee", negative: "Ww", range: -180...180
              )
        else { return nil }
        guard parts[0].contains(".") || parts[1].contains(".") else { return nil }
        return (latitude, longitude)
    }

    /// When the clip is a JSON object or array, returns the reformatted text
    /// (pretty when minified, minified when pretty). Returns nil when the
    /// formatting already matches the canonical shape.
    static func detectJSONReformat(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first == "{" || first == "[" else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is NSDictionary || object is NSArray
        else { return nil }
        guard let prettyData = try? JSONSerialization.data(
                withJSONObject: object, options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8),
              let minifiedData = try? JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys]
              ),
              let minified = String(data: minifiedData, encoding: .utf8)
        else { return nil }
        if trimmed.contains("\n") {
            return trimmed == minified ? nil : minified
        }
        return trimmed == pretty ? nil : pretty
    }

    /// Pure arithmetic (+, -, *, /, parentheses, decimal numbers) that can be
    /// evaluated safely. Returns the formatted result, or nil when the text is
    /// not a well-formed expression (dates, versions, prose, …).
    static func detectMathExpression(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }
        // Date-like shapes ("2024-01-01", "12-30") aren't arithmetic.
        let datePattern = #"^\d{2,4}-\d{1,2}(-\d{1,2})?$"#
        if let regex = try? Regex(datePattern), trimmed.wholeMatch(of: regex) != nil {
            return nil
        }
        guard trimmed.contains(where: { "+-*/".contains($0) }) else { return nil }
        guard trimmed.contains(where: \.isNumber) else { return nil }
        var depth = 0
        for char in trimmed {
            switch char {
            case "(": depth += 1
            case ")": depth -= 1
            default: break
            }
            guard depth >= 0 else { return nil }
        }
        guard depth == 0 else { return nil }
        guard let value = evaluateMath(trimmed), value.isFinite else { return nil }
        return Self.formatMathResult(value)
    }

    /// Renders a math result compactly: whole numbers without a decimal point,
    /// others with up to 10 significant digits (`4`, `-18`, `2.333333333`).
    static func formatMathResult(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// Evaluates a restricted arithmetic expression. Returns nil on any syntax
    /// error; never touches anything outside digits, `+-*/().` and spaces, so
    /// it cannot evaluate keypaths, functions, or string content.
    static func evaluateMath(_ expression: String) -> Double? {
        enum Token {
            case number(Double)
            case operator_(Character)
        }
        var tokens: [Token] = []
        var index = expression.startIndex
        while index < expression.endIndex {
            let char = expression[index]
            if char.isWhitespace {
                index = expression.index(after: index)
                continue
            }
            if char.isNumber || char == "." {
                var number = ""
                while index < expression.endIndex,
                      expression[index].isNumber || expression[index] == "."
                {
                    number.append(expression[index])
                    index = expression.index(after: index)
                }
                guard let value = Double(number) else { return nil }
                tokens.append(.number(value))
            } else if "+-*/()".contains(char) {
                tokens.append(.operator_(char))
                index = expression.index(after: index)
            } else {
                return nil
            }
        }
        guard !tokens.isEmpty else { return nil }

        var position = 0
        func peek() -> Token? { position < tokens.count ? tokens[position] : nil }
        func take() -> Token? {
            defer { position += 1 }
            return position < tokens.count ? tokens[position] : nil
        }
        func parsePrimary() -> Double? {
            guard let token = take() else { return nil }
            switch token {
            case .number(let value):
                return value
            case .operator_("-"):
                guard let operand = parsePrimary() else { return nil }
                return -operand
            case .operator_("("):
                guard let value = parseAdditive() else { return nil }
                guard case .operator_(")") = take() else { return nil }
                return value
            default:
                return nil
            }
        }
        func parseMultiplicative() -> Double? {
            guard var value = parsePrimary() else { return nil }
            while let token = peek() {
                guard case .operator_(let op) = token, op == "*" || op == "/" else { break }
                _ = take()
                guard let rhs = parsePrimary() else { return nil }
                if op == "*" {
                    value *= rhs
                } else {
                    guard rhs != 0 else { return nil }
                    value /= rhs
                }
            }
            return value
        }
        func parseAdditive() -> Double? {
            guard var value = parseMultiplicative() else { return nil }
            while let token = peek() {
                guard case .operator_(let op) = token, op == "+" || op == "-" else { break }
                _ = take()
                guard let rhs = parseMultiplicative() else { return nil }
                if op == "+" {
                    value += rhs
                } else {
                    value -= rhs
                }
            }
            return value
        }
        guard let result = parseAdditive(), position == tokens.count else { return nil }
        return result
    }

    /// ISO-8601 dates (with or without time, with or without fractional
    /// seconds) as epoch seconds, e.g. `2024-01-01` → `1704067200`.
    static func detectISODateEpochSeconds(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let internet = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        for formatter in [internet, fractional, dateOnly] {
            if let date = formatter.date(from: trimmed) {
                return String(Int(date.timeIntervalSince1970))
            }
        }
        return nil
    }

    /// The ISO language code when the text is clearly not English — used to
    /// offer translation. Returns nil for English, empty, or ambiguous text.
    static func nonEnglishLanguageCode(in text: String) -> String? {
        let sample = text.count <= 4000 ? text : String(text.prefix(4000))
        guard sample.contains(where: \.isLetter) else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let language = recognizer.dominantLanguage, language != .english else {
            return nil
        }
        return language.rawValue
    }

    private static func parseCoordinate(
        _ raw: String,
        positive: String,
        negative: String,
        range: ClosedRange<Double>
    ) -> Double? {
        var s = raw
        var sign = 1.0
        if let last = s.last {
            if positive.contains(last) {
                s = String(s.dropLast())
            } else if negative.contains(last) {
                sign = -1
                s = String(s.dropLast())
            }
        }
        guard let value = Double(s), value.isFinite, range.contains(value) else { return nil }
        return value * sign
    }
}
