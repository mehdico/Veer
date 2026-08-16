import Foundation

/// Tracks how many clipboard events have been yielded by the monitor but not
/// yet consumed by the ingestor. The event stream is deliberately unbounded
/// (dropping events would lose user copies), so a stalled consumer would grow
/// it silently — this makes the stall visible in logs instead.
@MainActor
final class MonitorEventDepthGauge {
    private var depth = 0
    private var warned = false
    private let logger = VeerLogger(category: .pasteboard)

    func eventYielded() {
        depth += 1
    }

    func eventConsumed() {
        depth = max(0, depth - 1)
        if depth > 8 && !warned {
            warned = true
            logger.warning("Clipboard events backing up: \(depth) unconsumed — is the main actor stalled?")
        } else if depth == 0 {
            warned = false
        }
    }
}
