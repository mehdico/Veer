import AppKit
import Foundation
import SwiftData
import Testing
@testable import Veer

@MainActor
struct ClipRepositoryTests {
    private func makeRepo(maxItems: Int = 500) throws -> ClipRepositoryLive {
        let container = try VeerStore.inMemory()
        return ClipRepositoryLive(container: container, maxItems: maxItems)
    }

    private func textPayload(_ s: String) -> ClipPayload {
        ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data(s.utf8)])
    }

    @Test func insertsTextItemWithPreview() throws {
        let repo = try makeRepo()
        let outcome = try repo.insert(payload: textPayload("hello world"), sourceBundleId: "com.test")
        if case .inserted = outcome {} else { Issue.record("Expected inserted"); return }
        let items = try repo.fetchAll(limit: nil)
        #expect(items.count == 1)
        #expect(items.first?.preview == "hello world")
        #expect(items.first?.sourceBundleId == "com.test")
        #expect(items.first?.blobs.count == 1)
    }

    @Test func fetchAllReturnsNewestFirst() async throws {
        let repo = try makeRepo()
        _ = try repo.insert(payload: textPayload("first"), sourceBundleId: nil)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try repo.insert(payload: textPayload("second"), sourceBundleId: nil)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try repo.insert(payload: textPayload("third"), sourceBundleId: nil)
        let items = try repo.fetchAll(limit: nil)
        #expect(items.map(\.preview) == ["third", "second", "first"])
    }

    @Test func emptyPayloadIsRejected() throws {
        let repo = try makeRepo()
        let outcome = try repo.insert(payload: ClipPayload(typed: [:]), sourceBundleId: nil)
        #expect(outcome == .rejectedEmpty)
        #expect(try repo.fetchAll(limit: nil).isEmpty)
    }

    @Test func denylistedTypeIsRejected() throws {
        let repo = try makeRepo()
        let payload = ClipPayload(typed: [
            "com.agilebits.onepassword": Data([0x01]),
            NSPasteboard.PasteboardType.string.rawValue: Data("secret".utf8),
        ])
        let outcome = try repo.insert(payload: payload, sourceBundleId: nil)
        #expect(outcome == .rejectedDenyListed)
        #expect(try repo.fetchAll(limit: nil).isEmpty)
    }

    @Test func transientMarkerWithTextIsStored() throws {
        let repo = try makeRepo()
        let payload = ClipPayload(typed: [
            "org.nspasteboard.TransientType": Data([0x01]),
            NSPasteboard.PasteboardType.string.rawValue: Data("visible".utf8),
        ])
        let outcome = try repo.insert(payload: payload, sourceBundleId: nil)
        if case .inserted = outcome {} else { Issue.record("Expected inserted"); return }
        #expect(try repo.fetchAll(limit: nil).first?.preview == "visible")
    }

    @Test func duplicateOfMostRecentIsRejected() throws {
        let repo = try makeRepo()
        _ = try repo.insert(payload: textPayload("same"), sourceBundleId: nil)
        let outcome = try repo.insert(payload: textPayload("same"), sourceBundleId: nil)
        #expect(outcome == .rejectedDuplicate)
        #expect(try repo.fetchAll(limit: nil).count == 1)
    }

    @Test func nonAdjacentDuplicateIsAllowed() throws {
        let repo = try makeRepo()
        _ = try repo.insert(payload: textPayload("a"), sourceBundleId: nil)
        _ = try repo.insert(payload: textPayload("b"), sourceBundleId: nil)
        let outcome = try repo.insert(payload: textPayload("a"), sourceBundleId: nil)
        if case .inserted = outcome {} else { Issue.record("Expected inserted"); return }
        #expect(try repo.fetchAll(limit: nil).count == 3)
    }

    @Test func moveToFrontBringsItemToFirstPosition() async throws {
        let repo = try makeRepo()
        var ids: [UUID] = []
        for i in 0..<3 {
            guard case let .inserted(id) = try repo.insert(payload: textPayload("item-\(i)"), sourceBundleId: nil) else {
                Issue.record("Insert failed"); return
            }
            ids.append(id)
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(try repo.fetchAll(limit: nil).map(\.preview) == ["item-2", "item-1", "item-0"])

        try repo.moveToFront(id: ids[0])

        let items = try repo.fetchAll(limit: nil)
        #expect(items.map(\.preview) == ["item-0", "item-2", "item-1"])
        #expect(items.first?.id == ids[0])
    }

    @Test func moveToFrontEmitsChange() async throws {
        let repo = try makeRepo()
        guard case let .inserted(id) = try repo.insert(payload: textPayload("a"), sourceBundleId: nil) else {
            Issue.record("Insert failed"); return
        }
        var iterator = repo.changes.makeAsyncIterator()
        _ = await iterator.next() // consume insert notification

        try repo.moveToFront(id: id)
        let change: Void? = await iterator.next()
        #expect(change != nil)
    }

    @Test func capEvictsOldestOnInsert() async throws {
        let repo = try makeRepo(maxItems: 3)
        for i in 0..<5 {
            _ = try repo.insert(payload: textPayload("item-\(i)"), sourceBundleId: nil)
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let items = try repo.fetchAll(limit: nil)
        #expect(items.count == 3)
        #expect(items.map(\.preview) == ["item-4", "item-3", "item-2"])
    }

    @Test func setMaxItemsTrimsExisting() async throws {
        let repo = try makeRepo(maxItems: 10)
        for i in 0..<6 {
            _ = try repo.insert(payload: textPayload("x\(i)"), sourceBundleId: nil)
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try repo.setMaxItems(2)
        let items = try repo.fetchAll(limit: nil)
        #expect(items.count == 2)
        #expect(items.map(\.preview) == ["x5", "x4"])
    }

    @Test func deleteRemovesItem() throws {
        let repo = try makeRepo()
        guard case let .inserted(id) = try repo.insert(payload: textPayload("doomed"), sourceBundleId: nil) else {
            Issue.record("Insert failed"); return
        }
        try repo.delete(id: id)
        #expect(try repo.fetchAll(limit: nil).isEmpty)
    }

    @Test func clearEmptiesStore() throws {
        let repo = try makeRepo()
        _ = try repo.insert(payload: textPayload("a"), sourceBundleId: nil)
        _ = try repo.insert(payload: textPayload("b"), sourceBundleId: nil)
        try repo.clear()
        #expect(try repo.fetchAll(limit: nil).isEmpty)
    }

    @Test func thumbnailComputedForImagePayload() throws {
        let repo = try makeRepo()
        let pngData = Self.makeSolidPNG(size: 80)
        let payload = ClipPayload(typed: [NSPasteboard.PasteboardType.png.rawValue: pngData])
        let thumb = payload.thumbnailPNG()
        _ = try repo.insert(payload: payload, sourceBundleId: nil, thumbnailPNG: thumb)
        let item = try repo.fetchAll(limit: 1).first
        #expect(item?.thumbnailPNG != nil)
        #expect((item?.thumbnailPNG?.count ?? 0) > 0)
    }

    @Test func thumbnailGeneratedFromJpegData() throws {
        let pngData = Self.makeSolidPNG(size: 32)
        guard let rep = NSBitmapImageRep(data: pngData),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            Issue.record("jpeg encode failed")
            return
        }
        let payload = ClipPayload(typed: ["public.jpeg": jpeg])
        #expect(payload.thumbnailPNG() != nil)
    }

    @Test func changesStreamEmitsOnInsertDeleteAndClear() async throws {
        let repo = try makeRepo()
        var iterator = repo.changes.makeAsyncIterator()

        _ = try repo.insert(payload: textPayload("a"), sourceBundleId: nil)
        let first: Void? = await iterator.next()
        #expect(first != nil)

        guard case let .inserted(id) = try repo.insert(payload: textPayload("b"), sourceBundleId: nil) else {
            Issue.record("Insert failed"); return
        }
        let second: Void? = await iterator.next()
        #expect(second != nil)

        try repo.delete(id: id)
        let third: Void? = await iterator.next()
        #expect(third != nil)

        try repo.clear()
        let fourth: Void? = await iterator.next()
        #expect(fourth != nil)
    }

    static func makeSolidPNG(size: Int) -> Data {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let rep = NSBitmapImageRep(data: tiff)!
        return rep.representation(using: .png, properties: [:])!
    }
}
