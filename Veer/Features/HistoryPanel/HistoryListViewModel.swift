import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class HistoryListViewModel {
    var items: [ClipItemSnapshot] = []
    var searchText: String = "" {
        didSet { runSearch() }
    }
    var selectedIndex: Int = 0
    var quickPasteBase: Int = 0
    private(set) var filteredIDs: [UUID] = []
    private(set) var filteredItems: [ClipItemSnapshot] = []

    @ObservationIgnored private var itemsByID: [UUID: ClipItemSnapshot] = [:]
    @ObservationIgnored private let blobDataCache = NSCache<NSString, NSData>()

    @ObservationIgnored let repository: any ClipRepository
    @ObservationIgnored let paster: any PasteSimulating
    @ObservationIgnored let pasteboardWriter: any PasteboardWriting
    @ObservationIgnored let panel: PanelCoordinator
    @ObservationIgnored weak var preview: PreviewCoordinator?
    @ObservationIgnored let searchEngine: any SearchEngine
    @ObservationIgnored let settings: SettingsStore?
    @ObservationIgnored let pasteDelay: Duration
    @ObservationIgnored let access: (any AccessChecking)?
    @ObservationIgnored let alerter: (any Alerting)?
    @ObservationIgnored private var didWarnAccessibility = false

    private static let plainTextRawValue = "public.utf8-plain-text"
    private static let textFamilyRawValues: Set<String> = [
        plainTextRawValue,
        "public.utf16-plain-text",
        "public.text",
        "public.plain-text",
        "public.utf8-tab-separated-values-text",
        "public.rtf",
        "public.html",
        "public.rtfd",
        "com.apple.flat-rtfd",
        "com.apple.rtfd",
        "com.apple.webarchive",
        "com.apple.WebKit.custom-pasteboard-data",
        "Apple HTML pasteboard type",
        "Apple RTF pasteboard type",
        "Apple Web Archive pasteboard type",
        "NeXT RTFD pasteboard type",
        "NeXT Rich Text Format v1.0 pasteboard type",
        "NeXT HTML pasteboard type",
        "RichTextPboardType",
        "NSStringPboardType",
        "NSHTMLPboardType",
        "NSRTFPboardType",
        "NSRTFDPboardType",
        "WebURLsWithTitlesPboardType",
        "WebKitPasteboardType",
        "CorePasteboardFlavorType 0x52544620",
        "CorePasteboardFlavorType 0x52544664",
        "CorePasteboardFlavorType 0x48544D4C",
    ]

    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(
        repository: any ClipRepository,
        paster: any PasteSimulating,
        pasteboardWriter: any PasteboardWriting,
        panel: PanelCoordinator,
        searchEngine: any SearchEngine,
        settings: SettingsStore? = nil,
        pasteDelay: Duration = .milliseconds(50),
        access: (any AccessChecking)? = nil,
        alerter: (any Alerting)? = nil
    ) {
        self.repository = repository
        self.paster = paster
        self.pasteboardWriter = pasteboardWriter
        self.panel = panel
        self.searchEngine = searchEngine
        self.settings = settings
        self.pasteDelay = pasteDelay
        self.access = access
        self.alerter = alerter
        self.blobDataCache.countLimit = 256
    }

    convenience init(
        repository: any ClipRepository,
        paster: any PasteSimulating,
        pasteboardWriter: any PasteboardWriting,
        panel: PanelCoordinator,
        settings: SettingsStore? = nil,
        pasteDelay: Duration = .milliseconds(50),
        access: (any AccessChecking)? = nil,
        alerter: (any Alerting)? = nil
    ) {
        self.init(
            repository: repository,
            paster: paster,
            pasteboardWriter: pasteboardWriter,
            panel: panel,
            searchEngine: BasicFuzzySearchEngine(),
            settings: settings,
            pasteDelay: pasteDelay,
            access: access,
            alerter: alerter
        )
    }

    func start() {
        refresh()
        refreshTask?.cancel()
        let stream = repository.changes
        refreshTask = Task { @MainActor [weak self] in
            for await change in stream {
                self?.applyRepositoryChange(change)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        let limit = repository.maxItems
        let fetched = (try? repository.fetchAll(limit: limit)) ?? []
        items = fetched.map(ClipItemSnapshot.init)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        runSearch()
    }

    private func applyRepositoryChange(_ change: RepositoryChange) {
        switch change {
        case .inserted(let id):
            guard let item = try? repository.fetchOne(id: id) else { return }
            let snapshot = ClipItemSnapshot(item)
            items.removeAll { $0.id == id }
            items.insert(snapshot, at: 0)
            itemsByID[id] = snapshot
            trimToLimit()
            runSearch()
        case .movedToFront(let id):
            guard let item = try? repository.fetchOne(id: id) else { return }
            let snapshot = ClipItemSnapshot(item)
            itemsByID[id] = snapshot
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items.remove(at: index)
            items.insert(snapshot, at: 0)
            runSearch()
        case .deleted(let id):
            guard itemsByID[id] != nil else { return }
            itemsByID[id] = nil
            items.removeAll { $0.id == id }
            runSearch()
        case .cleared:
            items = []
            itemsByID = [:]
            runSearch()
        case .capped:
            refresh()
        }
    }

    private func trimToLimit() {
        let limit = repository.maxItems
        guard items.count > limit else { return }
        for evicted in items.dropFirst(limit) {
            itemsByID[evicted.id] = nil
        }
        items.removeLast(items.count - limit)
    }

    func resetForShow() {
        searchText = ""
        selectedIndex = 0
        quickPasteBase = 0
    }

    func navigateUp(by step: Int = 1) {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - step)
    }

    func navigateDown(by step: Int = 1) {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = min(filteredItems.count - 1, selectedIndex + step)
    }

    func deleteSelected() {
        guard let snapshot = currentSnapshot() else { return }
        delete(snapshot)
    }

    /// Deletes a specific clip after asking for confirmation.
    func delete(_ snapshot: ClipItemSnapshot) {
        guard confirmDelete(snapshot) else { return }
        try? repository.delete(id: snapshot.id)
    }

    private func confirmDelete(_ snapshot: ClipItemSnapshot) -> Bool {
        guard let alerter else { return true }
        let what = snapshot.preview.map { "“\($0)”" } ?? "this clip"
        return alerter.presentConfirmation(
            message: "Delete clip?",
            informativeText: "This removes \(what) from your history. This can't be undone.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel"
        )
    }

    func togglePreview() {
        preview?.toggle(currentSnapshot())
    }

    func pasteSelected() async {
        guard let snapshot = currentSnapshot() else { return }
        await paste(snapshot)
    }

    func selectAndPaste(quickIndex: Int) async {
        guard quickIndex >= 0, quickIndex < filteredItems.count else { return }
        selectedIndex = quickIndex
        await paste(filteredItems[quickIndex])
    }

    private func paste(_ snapshot: ClipItemSnapshot) async {
        guard let item = try? repository.fetchOne(id: snapshot.id) else { return }
        try? repository.moveToFront(id: item.id)
        let typed = Self.pasteboardPayload(for: item.blobs, pastesRichText: settings?.pastesRichText ?? true)
        pasteboardWriter.write(typed: typed)
        panel.hide()
        panel.restorePreviousApp()
        if let access, !access.isTrusted() {
            warnAccessibilityOnce()
            return
        }
        if pasteDelay > .zero {
            try? await Task.sleep(for: pasteDelay)
        }
        paster.simulatePaste()
    }

    private func warnAccessibilityOnce() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true
        access?.requestTrust()
        alerter?.presentWarning(
            message: "Accessibility permission required",
            informativeText: "Veer needs Accessibility access to paste automatically. The clipboard has been updated — press ⌘V to paste manually. Grant access in System Settings → Privacy & Security → Accessibility."
        )
    }

    static func pasteboardPayload(for blobs: [PayloadBlob], pastesRichText: Bool) -> [String: Data] {
        if pastesRichText {
            return Dictionary(uniqueKeysWithValues: blobs.map { ($0.typeRawValue, $0.data) })
        }
        let nonText = blobs.filter { !textFamilyRawValues.contains($0.typeRawValue) }
        var result = Dictionary(uniqueKeysWithValues: nonText.map { ($0.typeRawValue, $0.data) })
        if let plainBlob = blobs.first(where: { $0.typeRawValue == plainTextRawValue }) {
            result[plainTextRawValue] = plainBlob.data
        } else if let derived = derivePlainText(from: blobs) {
            result[plainTextRawValue] = Data(derived.utf8)
        }
        return result
    }

    private static func derivePlainText(from blobs: [PayloadBlob]) -> String? {
        for raw in ["public.rtf", "public.html"] {
            guard let blob = blobs.first(where: { $0.typeRawValue == raw }) else { continue }
            let docType: NSAttributedString.DocumentType = (raw == "public.rtf") ? .rtf : .html
            if let attr = try? NSAttributedString(data: blob.data, options: [.documentType: docType], documentAttributes: nil) {
                return attr.string
            }
        }
        return nil
    }

    func blob(for id: UUID, type: String) -> Data? {
        let key = Self.blobCacheKey(id: id, type: type)
        if let cached = blobDataCache.object(forKey: key) { return cached as Data }
        guard let data = try? repository.fetchBlob(id: id, type: type) else { return nil }
        blobDataCache.setObject(data as NSData, forKey: key)
        return data
    }

    func thumbnailPNG(for id: UUID) -> Data? {
        let key = Self.blobCacheKey(id: id, type: "thumbnail")
        if let cached = blobDataCache.object(forKey: key) { return cached as Data }
        guard let data = try? repository.fetchThumbnail(id: id) else { return nil }
        blobDataCache.setObject(data as NSData, forKey: key)
        return data
    }

    private static func blobCacheKey(id: UUID, type: String) -> NSString {
        "\(id.uuidString)|\(type)" as NSString
    }

    private func runSearch() {
        if searchText.isEmpty {
            filteredItems = items
        } else {
            let candidates = items.map { SearchCandidate(id: $0.id, text: $0.preview ?? "") }
            let ids = searchEngine.search(query: searchText, in: candidates)
            filteredItems = ids.compactMap { itemsByID[$0] }
        }
        filteredIDs = filteredItems.map(\.id)
        selectedIndex = 0
        clampSelection()
    }

    private func currentSnapshot() -> ClipItemSnapshot? {
        let list = filteredItems
        guard !list.isEmpty, selectedIndex >= 0, selectedIndex < list.count else { return nil }
        return list[selectedIndex]
    }

    private func clampSelection() {
        let list = filteredItems
        if list.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= list.count {
            selectedIndex = list.count - 1
        }
    }
}
