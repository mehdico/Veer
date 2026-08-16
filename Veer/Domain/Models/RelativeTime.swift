import Foundation

/// Compact relative-time labels for clip cells ("just now", "5m ago", …),
/// falling back to an abbreviated date once a clip is a week old.
enum RelativeTime {
    /// Cached style: constructing a DateFormatter-backed format style per call
    /// was measurable when long histories render many old-clip rows.
    private static let olderClipStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    static func label(for date: Date, now: Date = .init()) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 60 { return "just now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(interval / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = Int(interval / 86400)
        if days < 7 { return "\(days)d ago" }
        return date.formatted(Self.olderClipStyle)
    }
}
