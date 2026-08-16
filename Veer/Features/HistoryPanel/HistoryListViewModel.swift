import AppKit
import Foundation
import Observation
import Translation

@MainActor
@Observable
final class HistoryListViewModel {
    var items: [ClipItemSnapshot] = []
    var searchText: String = "" {
        didSet {
            guard oldValue != searchText else { return }
            scheduleSearch()
        }
    }
    /// Reveals the inline action strip for the selected clip. Closed whenever
    /// the selection moves, so it always belongs to the visible card.
    var selectedIndex: Int = 0 {
        didSet {
            if oldValue != selectedIndex { closeActionStrip() }
        }
    }
    var actionsExpanded = false
    /// Index of the highlighted action while the strip is open.
    var actionIndex = 0
    var quickPasteBase: Int = 0
    private(set) var filteredIDs: [UUID] = []
    private(set) var filteredItems: [ClipItemSnapshot] = []

    @ObservationIgnored private var highlightsByID: [UUID: [Range<String.Index>]] = [:]
    /// Debounces search re-runs while the user types.
    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?

    /// Detected actions per clip, so strip rendering and context menus don't
    /// re-run content detection on every body evaluation. Validated against
    /// the snapshot (replaced on insert/move) and the web-search setting.
    @ObservationIgnored private var actionsCache: [UUID: (snapshot: ClipItemSnapshot, webSearch: Bool, actions: [ClipAction])] = [:]
    /// Full plain text of rich-text clips, computed off the hot path.
    @ObservationIgnored private var fullPlainTextCache: [UUID: String] = [:]
    @ObservationIgnored private var fullPlainTextPending: Set<UUID> = []

    /// Whether the system's translation pack for a language code is installed
    /// (`true`) or known not to be (`false`). Populated lazily by async checks;
    /// mutations re-render the action strip, so a translate action can appear
    /// a moment after the clip is selected.
    private var translationAvailabilityCache: [String: Bool] = [:]
    /// Language codes with an availability check still in flight, so repeated
    /// `actions(for:)` calls during body evaluations don't pile up tasks.
    @ObservationIgnored private var translationChecksInFlight: Set<String> = []

    /// Whether on-card content previews (image/PDF/file thumbnails, color
    /// swatches) are enabled. Off → icons and labels only.
    var previewsEnabled: Bool { settings?.showPreviews ?? true }

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
    @ObservationIgnored let actionRunner: any ClipActionRunning
    /// Answers whether a language pack is installed for translation; injected
    /// so tests can stub it. Defaults to the real `LanguageAvailability` check.
    @ObservationIgnored let translationAvailabilityCheck: (String) async -> Bool
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
        alerter: (any Alerting)? = nil,
        actionRunner: any ClipActionRunning,
        translationAvailabilityCheck: ((String) async -> Bool)? = nil
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
        self.actionRunner = actionRunner
        self.translationAvailabilityCheck = translationAvailabilityCheck
            ?? { await Self.systemTranslationAvailability($0) }
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
        alerter: (any Alerting)? = nil,
        actionRunner: (any ClipActionRunning)? = nil,
        translationAvailabilityCheck: ((String) async -> Bool)? = nil
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
            alerter: alerter,
            actionRunner: actionRunner ?? LiveClipActionRunner(pasteboardWriter: pasteboardWriter),
            translationAvailabilityCheck: translationAvailabilityCheck
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
        flushPendingSearch()
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        let limit = repository.maxItems
        let fetched = (try? repository.fetchSnapshots(limit: limit)) ?? []
        items = fetched
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        actionsCache.removeAll()
        runSearch(preservingSelection: true)
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
            runSearch(preservingSelection: true)
        case .movedToFront(let id):
            guard let item = try? repository.fetchOne(id: id) else { return }
            let snapshot = ClipItemSnapshot(item)
            itemsByID[id] = snapshot
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items.remove(at: index)
            items.insert(snapshot, at: 0)
            runSearch(preservingSelection: true)
        case .deleted(let id):
            guard itemsByID[id] != nil else { return }
            let wasSelected = currentSnapshot()?.id == id
            itemsByID[id] = nil
            items.removeAll { $0.id == id }
            runSearch(preservingSelection: true)
            if wasSelected {
                // Selection landed on a different clip; the strip belongs to
                // the deleted one and must close.
                closeActionStrip()
            }
        case .cleared:
            items = []
            itemsByID = [:]
            actionsCache.removeAll()
            runSearch(preservingSelection: true)
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
        flushPendingSearch()
        selectedIndex = 0
        quickPasteBase = 0
        closeActionStrip()
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

    /// Smart actions for a clip, detected from its content. Text clips are
    /// detected from the preview string; files, images, PDFs, colors and rich
    /// text get actions derived from their payload blobs. Cached per snapshot
    /// so strip rendering, context menus, and ⌘↩ don't re-run detection.
    func actions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        let webSearch = settings?.alwaysSearchWeb == true
        if let cached = actionsCache[snapshot.id],
           cached.snapshot == snapshot, cached.webSearch == webSearch {
            return cached.actions
        }
        let detected = detectActions(for: snapshot)
        actionsCache[snapshot.id] = (snapshot, webSearch, detected)
        return detected
    }

    private func detectActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        switch snapshot.kind {
        case .text, .richText: return textActions(for: snapshot)
        case .file: return fileActions(for: snapshot)
        case .image: return imageActions(for: snapshot)
        case .pdf: return pdfActions(for: snapshot)
        case .color: return colorActions(for: snapshot)
        }
    }

    // MARK: - Action builders

    private func textActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        let text = snapshot.preview ?? ""
        var actions = ClipContentDetector.actions(for: text)
        if actions.isEmpty {
            // Prose or an absolute path: nothing machine-recognizable matched.
            if let path = Self.detectExistingPath(in: text) {
                actions = Self.fileActions(for: URL(fileURLWithPath: path))
            } else {
                if settings?.alwaysSearchWeb == true {
                    actions.append(.searchWeb(text))
                }
                if #available(macOS 26.0, *) {
                    // Only offer translation when the system's pack for that
                    // language is actually installed — otherwise the action
                    // would silently do nothing.
                    if let language = ClipContentDetector.nonEnglishLanguageCode(in: text),
                       isTranslationReady(language)
                    {
                        actions.append(.translate(text: text, sourceLanguage: language))
                    }
                }
            }
        }
        if snapshot.kind == .richText, let plain = cachedFullPlainText(for: snapshot) {
            actions.append(.copyPlainText(plain))
        }
        return actions
    }

    private func fileActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        guard let url = fileURL(for: snapshot) else { return [] }
        return Self.fileActions(for: url)
    }

    private func imageActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        guard let (data, fileExtension) = imageData(for: snapshot) else { return [] }
        return [
            .saveToDownloads(source: .data(data), fileExtension: fileExtension, suggestedName: nil),
            .copyAsPNG(source: .data(data)),
        ]
    }

    private func pdfActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        guard let data = blob(for: snapshot.id, type: NSPasteboard.PasteboardType.pdf.rawValue),
              !data.isEmpty
        else { return [] }
        return [.saveToDownloads(source: .data(data), fileExtension: "pdf", suggestedName: nil)]
    }

    private func colorActions(for snapshot: ClipItemSnapshot) -> [ClipAction] {
        guard let data = blob(for: snapshot.id, type: NSPasteboard.PasteboardType.color.rawValue),
              let color = NSColor.decodePasteboardColor(from: data),
              let rgb = color.usingColorSpace(.sRGB)
        else { return [] }
        let red = Int((rgb.redComponent * 255).rounded())
        let green = Int((rgb.greenComponent * 255).rounded())
        let blue = Int((rgb.blueComponent * 255).rounded())
        return [
            .copyHexColor(Self.hexString(red: red, green: green, blue: blue, alpha: rgb.alphaComponent)),
            .copyCSSRGB(red: red, green: green, blue: blue),
            .copyUIColor(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent), alpha: Double(rgb.alphaComponent)),
        ]
    }

    /// File actions shared by `.file` clips and text clips that are an
    /// existing absolute path.
    static func fileActions(for url: URL) -> [ClipAction] {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
            ?? url.hasDirectoryPath
        var actions: [ClipAction] = [.revealInFinder(url), .openFile(url)]
        if isDirectory {
            actions.append(.openInTerminal(url))
        }
        actions.append(contentsOf: [.copyPath(url), .copyFile(url), .copyMarkdownLink(url)])
        if !isDirectory {
            let ext = url.pathExtension.lowercased()
            if Self.xcodeExtensions.contains(ext) {
                actions.append(.openInXcode(url))
            }
            if Self.imageExtensions.contains(ext) {
                let source = ClipContentSource.file(url)
                actions.append(.saveToDownloads(
                    source: source,
                    fileExtension: ext,
                    suggestedName: url.deletingPathExtension().lastPathComponent
                ))
                actions.append(.copyAsPNG(source: source))
            }
        }
        return actions
    }

    /// Absolute path text that still exists on disk, so a path copied as plain
    /// text can be opened or revealed like a file clip.
    static func detectExistingPath(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace),
              trimmed.hasPrefix("/"),
              FileManager.default.fileExists(atPath: trimmed)
        else { return nil }
        return trimmed
    }

    /// The file URL of a `.file` clip, decoded like the file cells do.
    private func fileURL(for snapshot: ClipItemSnapshot) -> URL? {
        guard let data = blob(for: snapshot.id, type: NSPasteboard.PasteboardType.fileURL.rawValue),
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        if str.hasPrefix("file://") {
            return URL(string: str)
        }
        if str.hasPrefix("/") {
            return URL(fileURLWithPath: str)
        }
        return URL(string: str)
    }

    /// The full plain text of a rich-text clip — richer than the truncated
    /// preview, so "Copy as Plain Text" copies everything. The cheap plain
    /// blob path is synchronous; RTF/HTML imports run off the main actor and
    /// the action appears once the parse lands.
    private func cachedFullPlainText(for snapshot: ClipItemSnapshot) -> String? {
        if let cached = fullPlainTextCache[snapshot.id] { return cached }
        if let data = blob(for: snapshot.id, type: Self.plainTextRawValue),
           let text = String(data: data, encoding: .utf8),
           !text.isEmpty
        {
            fullPlainTextCache[snapshot.id] = text
            return text
        }
        guard !fullPlainTextPending.contains(snapshot.id) else { return nil }
        fullPlainTextPending.insert(snapshot.id)
        let rtfData = blob(for: snapshot.id, type: NSPasteboard.PasteboardType.rtf.rawValue)
        let htmlData = blob(for: snapshot.id, type: NSPasteboard.PasteboardType.html.rawValue)
        Task { @MainActor [weak self] in
            let plain = await Self.parsePlainText(rtf: rtfData, html: htmlData)
            guard let self else { return }
            self.fullPlainTextPending.remove(snapshot.id)
            if let plain {
                self.fullPlainTextCache[snapshot.id] = plain
                self.actionsCache.removeAll()
            }
        }
        return nil
    }

    private static func parsePlainText(rtf: Data?, html: Data?) async -> String? {
        await Task.detached(priority: .utility) {
            if let rtf,
               let attr = try? NSAttributedString(data: rtf, options: [:], documentAttributes: nil),
               !attr.string.isEmpty
            {
                return attr.string
            }
            if let html,
               let attr = try? NSAttributedString(
                data: html,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
               ),
               !attr.string.isEmpty
            {
                return attr.string
            }
            return nil
        }.value
    }

    private func imageData(for snapshot: ClipItemSnapshot) -> (data: Data, fileExtension: String)? {
        for key in ClipPayload.imageTypeKeys {
            if let data = blob(for: snapshot.id, type: key), !data.isEmpty {
                return (data, Self.imageTypeExtensions[key] ?? "png")
            }
        }
        return nil
    }

    static func hexString(red: Int, green: Int, blue: Int, alpha: Double) -> String {
        if alpha < 0.995 {
            return String(format: "#%02X%02X%02X%02X", red, green, blue, Int((alpha * 255).rounded()))
        }
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static let xcodeExtensions: Set<String> = [
        "swift", "xcodeproj", "xcworkspace", "playground",
    ]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif", "webp", "bmp", "ico",
    ]

    private static let imageTypeExtensions: [String: String] = [
        "public.png": "png",
        "public.tiff": "tiff",
        "public.jpeg": "jpg",
        "public.heic": "heic",
        "public.webp": "webp",
    ]

    /// Whether translation to English is possible for a language code: true
    /// once the system confirms the pack is installed. Unknown languages kick
    /// off an async check (cached per language) and return false until it
    /// lands, so a translate action can appear a moment after selection.
    private func isTranslationReady(_ languageCode: String) -> Bool {
        if let cached = translationAvailabilityCache[languageCode] { return cached }
        guard !translationChecksInFlight.contains(languageCode) else { return false }
        translationChecksInFlight.insert(languageCode)
        Task { @MainActor [weak self] in
            let ready = await self?.translationAvailabilityCheck(languageCode) ?? false
            guard let self else { return }
            self.translationChecksInFlight.remove(languageCode)
            self.translationAvailabilityCache[languageCode] = ready
            // Cached actions were built without knowing this; rebuild so the
            // translate action can appear.
            self.actionsCache.removeAll()
        }
        return false
    }

    /// The real availability check: is the source language's pack installed
    /// for translation into English?
    private static func systemTranslationAvailability(_ languageCode: String) async -> Bool {
        let source = Locale.Language(identifier: languageCode)
        let target = Locale.Language(identifier: "en")
        return await LanguageAvailability().status(from: source, to: target) == .installed
    }

    /// Runs the first detected action for the selected clip (⌘↩ in the panel).
    func runPrimaryAction() {
        guard let snapshot = currentSnapshot() else { return }
        guard let action = actions(for: snapshot).first else { return }
        run(action)
    }

    /// Runs the action currently highlighted in the open strip (Return).
    func runHighlightedAction() {
        guard let snapshot = currentSnapshot() else { return }
        let detected = actions(for: snapshot)
        guard detected.indices.contains(actionIndex) else { return }
        run(detected[actionIndex])
    }

    /// Opens the strip on the first action, or — while open — steps the
    /// highlight forward through the detected actions, wrapping to the first.
    /// Clips without detected actions never expand, and selection never moves.
    func stepActions() {
        guard let snapshot = currentSnapshot() else { return }
        let detected = actions(for: snapshot)
        guard !detected.isEmpty else { return }
        if !actionsExpanded {
            actionsExpanded = true
            actionIndex = 0
        } else {
            actionIndex = (actionIndex + 1) % detected.count
        }
    }

    /// Steps the highlight backward through the detected actions, wrapping to
    /// the last one. When the strip is closed, opens it on the first action.
    func stepActionsBackward() {
        guard let snapshot = currentSnapshot() else { return }
        let detected = actions(for: snapshot)
        guard !detected.isEmpty else { return }
        if !actionsExpanded {
            actionsExpanded = true
            actionIndex = 0
        } else {
            actionIndex = (actionIndex - 1 + detected.count) % detected.count
        }
    }

    func closeActionStrip() {
        actionsExpanded = false
        actionIndex = 0
    }

    func run(_ action: ClipAction) {
        actionRunner.run(action)
        preview?.hide()
        panel.hide()
        if action.dismissal == .restorePreviousApp {
            // Copy actions leave the value on the pasteboard; hand back to the
            // previous app so the user's next ⌘V lands there, not in the panel.
            panel.restorePreviousApp()
        }
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
        let blobs = (try? repository.fetchBlobs(id: snapshot.id)) ?? []
        try? repository.moveToFront(id: snapshot.id)
        let typed = Self.pasteboardPayload(for: blobs, pastesRichText: settings?.pastesRichText ?? true)
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

    /// Character ranges of the search query inside a clip's preview, for
    /// highlighting why it matched. Computed lazily per clip (only rows the
    /// lazy stacks actually render ask) and cached until the query changes.
    func highlights(for snapshot: ClipItemSnapshot) -> [Range<String.Index>] {
        guard !searchText.isEmpty else { return [] }
        if let cached = highlightsByID[snapshot.id] { return cached }
        let ranges = searchEngine.highlightRanges(query: searchText, in: snapshot.preview ?? "")
        highlightsByID[snapshot.id] = ranges
        return ranges
    }

    /// Debounce typing: intermediate queries for a 1000-item history are
    /// wasted work once the next keystroke lands.
    private func scheduleSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            runSearch()
        }
    }

    /// Runs a pending debounced search now (panel show/reset/teardown paths,
    /// and tests that need synchronous filtering).
    func flushPendingSearch() {
        let hadPending = searchDebounceTask != nil
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        if hadPending {
            runSearch()
        }
    }

    /// Rebuilds the filtered list. When `preservingSelection` is set (repository
    /// mutations, refreshes), the selected clip stays selected by identity so
    /// background ingestion doesn't yank the user back to the top; only real
    /// search-text changes reset to the first result.
    private func runSearch(preservingSelection: Bool = false) {
        let selectedID = preservingSelection ? currentSnapshot()?.id : nil
        if searchText.isEmpty {
            filteredItems = items
            highlightsByID = [:]
        } else {
            let query = searchText
            // Candidates come from each snapshot's pre-folded preview, so a
            // keystroke never re-lowercases the whole corpus.
            let candidates = items.map { SearchCandidate(id: $0.id, preFolded: $0.foldedPreview ?? "") }
            let ids = searchEngine.search(query: query, in: candidates)
            filteredItems = ids.compactMap { itemsByID[$0] }
            // Highlight ranges are computed lazily per visible row.
            highlightsByID = [:]
        }
        filteredIDs = filteredItems.map(\.id)
        if let selectedID, let index = filteredIDs.firstIndex(of: selectedID) {
            selectedIndex = index
        } else if !preservingSelection {
            selectedIndex = 0
        }
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
