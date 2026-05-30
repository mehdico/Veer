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
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        onWrite?(pasteboard.changeCount)
    }
}
