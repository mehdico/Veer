import Foundation
import Testing
@testable import Veer

struct RelativeTimeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func label(secondsAgo seconds: TimeInterval) -> String {
        RelativeTime.label(for: now.addingTimeInterval(-seconds), now: now)
    }

    @Test func subMinuteIsJustNow() {
        #expect(label(secondsAgo: 0) == "just now")
        #expect(label(secondsAgo: 59) == "just now")
    }

    @Test func minutesHoursAndDays() {
        #expect(label(secondsAgo: 60) == "1m ago")
        #expect(label(secondsAgo: 5 * 60) == "5m ago")
        #expect(label(secondsAgo: 3600) == "1h ago")
        #expect(label(secondsAgo: 3 * 3600) == "3h ago")
        #expect(label(secondsAgo: 86400) == "1d ago")
        #expect(label(secondsAgo: 3 * 86400) == "3d ago")
    }

    @Test func weekOrOlderFallsBackToAbbreviatedDate() {
        let label = label(secondsAgo: 30 * 86400)
        let abbreviated = now.addingTimeInterval(-30 * 86400)
            .formatted(date: .abbreviated, time: .omitted)
        #expect(label == abbreviated)
    }
}
