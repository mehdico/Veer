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
            for await _ in stream {
                self?.applyRepositoryChange()
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
        runSearch()
    }

    private func applyRepositoryChange() {
        let limit = repository.maxItems
        guard let fetched = try? repository.fetchAll(limit: limit) else { return }
        let snapshots = fetched.map(ClipItemSnapshot.init)
        if snapshots.count == items.count + 1,
           let newFirst = snapshots.first,
           items.first?.id != newFirst.id
        {
            items.insert(newFirst, at: 0)
            if items.count > limit {
                items.removeLast(items.count - limit)
            }
        } else if snapshots != items {
            items = snapshots
        } else {
            return
        }
        runSearch()
    }

    func resetForShow() {
        searchText = ""
        selectedIndex = 0
        quickPasteBase = 0
    }

    var filteredItems: [ClipItemSnapshot] {
        if searchText.isEmpty { return items }
        let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return filteredIDs.compactMap { lookup[$0] }
    }

    var filteredItemsLookup: [UUID: ClipItemSnapshot] {
        Dictionary(uniqueKeysWithValues: filteredItems.map { ($0.id, $0) })
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
        try? repository.delete(id: snapshot.id)
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
        guard let item = try? repository.fetchOne(id: id) else { return nil }
        return item.blobs.first { $0.typeRawValue == type }?.data
    }

    private func runSearch() {
        if searchText.isEmpty {
            filteredIDs = items.map(\.id)
        } else {
            let candidates = items.map { SearchCandidate(id: $0.id, text: $0.preview ?? "") }
            filteredIDs = searchEngine.search(query: searchText, in: candidates)
        }
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
