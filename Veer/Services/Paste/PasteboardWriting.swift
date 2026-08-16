import AppKit

@MainActor
protocol PasteboardWriting: AnyObject {
    func write(typed: [String: Data])
}

@MainActor
final class LivePasteboardWriter: PasteboardWriting {
    private let pasteboard: NSPasteboard
    var onWrite: ((Int) -> Void)?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func write(typed: [String: Data]) {
        let item = NSPasteboardItem()
        for (type, data) in typed {
            item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
        }
        let before = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        // A single write session bumps the change count by exactly one. A
        // larger delta means another app wrote between our reads; acknowledging
        // only `before` leaves that foreign change visible to the monitor
        // instead of silently swallowing the user's copy.
        let after = pasteboard.changeCount
        onWrite?(after == before + 1 ? after : before)
    }
}
