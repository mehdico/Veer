import Foundation

/// Detects what a text clip *is* — a URL, email address, phone number, or hex
/// color — so the UI can offer smart actions for it.
///
/// Detection is deliberately conservative: the entire trimmed text must be one
/// recognizable value. Mixed text (a sentence containing a URL, a multi-line
/// copy, …) produces no actions, so we never offer "open in browser" on prose.
enum ClipContentDetector {
    static func actions(for text: String) -> [ClipAction] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let url = detectURL(in: trimmed) {
            return [.openURL(url), .copyMarkdownLink(url)]
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
}
