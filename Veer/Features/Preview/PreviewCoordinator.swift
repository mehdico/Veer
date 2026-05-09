import Foundation
import Observation

@MainActor
@Observable
final class PreviewCoordinator {
    private(set) var preview: ClipItemSnapshot?

    @ObservationIgnored
    var onStateChange: (() -> Void)?

    var isShown: Bool { preview != nil }

    func toggle(_ snapshot: ClipItemSnapshot?) {
        if let candidate = snapshot, preview?.id != candidate.id {
            preview = candidate
        } else {
            preview = nil
        }
        onStateChange?()
    }

    func show(_ snapshot: ClipItemSnapshot) {
        preview = snapshot
        onStateChange?()
    }

    func hide() {
        guard preview != nil else { return }
        preview = nil
        onStateChange?()
    }
}
