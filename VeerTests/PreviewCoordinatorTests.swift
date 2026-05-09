import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct PreviewCoordinatorTests {
    private func snapshot(_ id: UUID = UUID()) -> ClipItemSnapshot {
        ClipItemSnapshot(
            id: id,
            createdAt: .init(),
            sourceBundleId: nil,
            preview: "x",
            typeRawValues: [NSPasteboard.PasteboardType.string.rawValue],
            thumbnailPNG: nil
        )
    }

    @Test func defaultsToHidden() {
        let c = PreviewCoordinator()
        #expect(c.preview == nil)
        #expect(c.isShown == false)
    }

    @Test func showSetsPreviewAndIsShown() {
        let c = PreviewCoordinator()
        let s = snapshot()
        c.show(s)
        #expect(c.preview?.id == s.id)
        #expect(c.isShown == true)
    }

    @Test func hideClearsPreview() {
        let c = PreviewCoordinator()
        c.show(snapshot())
        c.hide()
        #expect(c.preview == nil)
        #expect(c.isShown == false)
    }

    @Test func toggleSwitchesItemAcrossDifferentSnapshots() {
        let c = PreviewCoordinator()
        let a = snapshot()
        let b = snapshot()
        c.toggle(a)
        #expect(c.preview?.id == a.id)
        c.toggle(b)
        #expect(c.preview?.id == b.id)
    }

    @Test func toggleSameItemClosesPreview() {
        let c = PreviewCoordinator()
        let a = snapshot()
        c.toggle(a)
        c.toggle(a)
        #expect(c.preview == nil)
    }

    @Test func toggleNilWhileShowingClosesPreview() {
        let c = PreviewCoordinator()
        c.toggle(snapshot())
        c.toggle(nil)
        #expect(c.preview == nil)
    }

    @Test func onStateChangeFiresOnEachMutation() {
        let c = PreviewCoordinator()
        var fires = 0
        c.onStateChange = { fires += 1 }
        c.toggle(snapshot())
        c.hide()
        c.show(snapshot())
        #expect(fires == 3)
    }
}
