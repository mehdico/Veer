import AppKit
import SwiftUI

/// Translates pure-vertical scroll-wheel and trackpad deltas over the
/// horizontal card strip into card-by-card movement — a plain vertical wheel
/// otherwise can't scroll a horizontal SwiftUI ScrollView. Horizontal
/// trackpad swipes pass through untouched: only events with no horizontal
/// component are translated.
@MainActor
final class WheelScroller {
    /// Whether translation is currently wanted (panel shown, horizontal strip).
    var isEnabled = false
    /// Whether the strip is laying out vertically (left/right edge positions),
    /// where the wheel already scrolls natively and must be left alone.
    var isVerticalLayout = true
    var step: (Int) -> Void = { _ in }

    private var monitor: Any?
    private var accumulator: CGFloat = 0
    private static let threshold: CGFloat = 24

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event) ?? event
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        accumulator = 0
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isEnabled, !isVerticalLayout, event.window is PanelWindow else { return event }
        let vertical = event.scrollingDeltaY
        guard abs(vertical) > 0.5, abs(event.scrollingDeltaX) < 0.5 else { return event }
        accumulator += vertical
        var safety = 0
        while abs(accumulator) >= Self.threshold {
            // Positive vertical delta = scroll up = toward earlier clips.
            let direction = accumulator > 0 ? -1 : 1
            step(direction)
            accumulator -= (accumulator > 0 ? Self.threshold : -Self.threshold)
            safety += 1
            if safety > 8 {
                accumulator = 0
                break
            }
        }
        return nil
    }
}

struct HistoryCardStripView: View {
    @Bindable var viewModel: HistoryListViewModel
    @Bindable var coordinator: PanelCoordinator
    @FocusState private var searchFocused: Bool
    @State private var firstVisibleID: UUID?
    /// The card actually at the leading (left/top) edge of the viewport, kept
    /// in sync with native scrolling via scroll geometry. `firstVisibleID` only
    /// reflects programmatic scrolls (wheel/keyboard/search), so a plain
    /// trackpad swipe would otherwise leave the ⌘N base and click-to-scroll
    /// math anchored to a card that's long since scrolled off — badges then
    /// stick to the wrong cards and eventually vanish, and clicking a visible
    /// card is mistaken for an off-window selection and snapped to the edge.
    @State private var leadingID: UUID?
    @State private var wheelScroller = WheelScroller()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PanelSearchChrome(searchText: $viewModel.searchText, focused: $searchFocused)
            cardScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            searchFocused = true
            configureWheelScroller()
            wheelScroller.start()
        }
        .onDisappear {
            wheelScroller.stop()
        }
        .onChange(of: coordinator.isShown) { _, shown in
            wheelScroller.isEnabled = shown && !wheelScroller.isVerticalLayout
            if shown {
                searchFocused = true
                firstVisibleID = viewModel.filteredItems.first?.id
                leadingID = viewModel.filteredItems.first?.id
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            PanelKeyHandler.handle(press, viewModel: viewModel)
        }
    }

    private func configureWheelScroller() {
        let idBinding = $firstVisibleID
        let leadingBinding = $leadingID
        wheelScroller.step = { [weak viewModel] direction in
            guard let viewModel else { return }
            let items = viewModel.filteredItems
            // Step from the card actually at the leading edge (kept in sync with
            // native scrolling via geometry), not `firstVisibleID`, which only
            // reflects programmatic scrolls and would otherwise jump the strip
            // back to a stale position after a trackpad swipe.
            guard let currentID = leadingBinding.wrappedValue,
                  let index = items.firstIndex(where: { $0.id == currentID })
            else { return }
            let next = min(max(index + direction, 0), items.count - 1)
            guard next != index else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                idBinding.wrappedValue = items[next].id
            }
        }
        wheelScroller.isEnabled = coordinator.isShown && !wheelScroller.isVerticalLayout
    }

    private var cardScroll: some View {
        GeometryReader { geo in
            let isVertical = geo.size.height > geo.size.width
            let padding: CGFloat = 16
            let side = isVertical
                ? max(80, geo.size.width - padding)
                : max(80, geo.size.height - padding)
            let visibleCount = isVertical
                ? max(1, Int(geo.size.height / max(side + 8, 1)))
                : max(1, Int(geo.size.width / max(side + 8, 1)))

            ScrollView(isVertical ? .vertical : .horizontal, showsIndicators: false) {
                cardStack(isVertical: isVertical, side: side)
                    .padding(isVertical ? .horizontal : .vertical, padding / 2)
                    .scrollTargetLayout()
                    .animation(
                        viewModel.searchText.isEmpty || reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                        value: viewModel.filteredIDs
                    )
            }
            .contentMargins(isVertical ? .vertical : .horizontal, 6, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $firstVisibleID, anchor: isVertical ? .top : .leading)
            .accessibilityIdentifier(AccessibilityIdentifiers.veerTableView)
            .onAppear {
                if firstVisibleID == nil {
                    firstVisibleID = viewModel.filteredItems.first?.id
                }
                if leadingID == nil {
                    leadingID = viewModel.filteredItems.first?.id
                }
                wheelScroller.isVerticalLayout = isVertical
                wheelScroller.isEnabled = coordinator.isShown && !isVertical
            }
            .onChange(of: isVertical) { _, vertical in
                wheelScroller.isVerticalLayout = vertical
                wheelScroller.isEnabled = coordinator.isShown && !vertical
            }
            // Keep the leading-edge card in sync with native (trackpad) scrolls
            // so the ⌘N base and click-to-scroll math track what's actually on
            // screen. `scrollPosition` only reports programmatic scrolls.
            .onScrollGeometryChange(for: UUID?.self) { geometry in
                leadingVisibleID(from: geometry, isVertical: isVertical, side: side)
            } action: { _, newID in
                if let newID, newID != leadingID {
                    leadingID = newID
                }
            }
            .onChange(of: leadingID) { _, newID in
                guard let newID,
                      let idx = viewModel.filteredItems.firstIndex(where: { $0.id == newID })
                else { return }
                viewModel.quickPasteBase = idx
            }
            .onChange(of: viewModel.filteredIDs) { _, _ in
                let items = viewModel.filteredItems
                if let anchor = leadingID,
                   let idx = items.firstIndex(where: { $0.id == anchor })
                {
                    viewModel.quickPasteBase = idx
                } else {
                    // The anchor scrolled out of the new results (deleted or
                    // filtered away): re-anchor to the first item instead of
                    // leaving scrollPosition — and wheel scrolling, which keys
                    // off this ID — pointing at a card that no longer exists.
                    firstVisibleID = items.first?.id
                    leadingID = items.first?.id
                    viewModel.quickPasteBase = 0
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let items = viewModel.filteredItems
                guard newIndex >= 0, newIndex < items.count else { return }
                let firstIdx = items.firstIndex(where: { $0.id == leadingID }) ?? 0
                if newIndex < firstIdx {
                    firstVisibleID = items[newIndex].id
                } else if newIndex >= firstIdx + visibleCount {
                    let target = max(0, newIndex - visibleCount + 1)
                    firstVisibleID = items[target].id
                }
            }
            .onChange(of: viewModel.resultsResetToken) { _, _ in
                // The debounced search rebuilt the list for a new query: reset
                // to the first result. Keying off the token (not searchText)
                // guarantees filteredItems is fresh — searchText fires ~80ms
                // before the debounce lands, and resetting then anchored the
                // strip to the previous query's first match.
                viewModel.quickPasteBase = 0
                let firstID = viewModel.filteredItems.first?.id
                leadingID = firstID
                if viewModel.searchText.isEmpty || reduceMotion {
                    // Reset scroll instantly to prevent jumping
                    firstVisibleID = firstID
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        firstVisibleID = firstID
                    }
                }
            }
        }
    }

    /// The id of the card sitting at the leading (left, or top when vertical)
    /// edge of the viewport, derived from scroll geometry rather than the
    /// `scrollPosition` binding — which on macOS only reflects programmatic
    /// scrolls and never updates during a native trackpad swipe. Cards are
    /// uniformly sized with a fixed `8pt` gap, so the leading index is the
    /// viewport's leading edge projected onto the regular card stride; the
    /// content origin is solved from the known content size so no margin
    /// constant is hard-coded.
    private func leadingVisibleID(from geometry: ScrollGeometry, isVertical: Bool, side: CGFloat) -> UUID? {
        let items = viewModel.filteredItems
        guard items.count > 1 else { return items.first?.id }
        let contentLength = isVertical ? geometry.contentSize.height : geometry.contentSize.width
        let visibleLeading = isVertical ? geometry.visibleRect.minY : geometry.visibleRect.minX
        let idx = CardStripScrollMath.leadingIndex(
            contentLength: contentLength,
            side: side,
            count: items.count,
            visibleLeading: visibleLeading
        )
        return items[idx].id
    }

    @ViewBuilder
    private func cardStack(isVertical: Bool, side: CGFloat) -> some View {
        if isVertical {
            LazyVStack(alignment: .center, spacing: 8) { cardItems(side: side) }
        } else {
            LazyHStack(alignment: .center, spacing: 8) { cardItems(side: side) }
        }
    }

    @ViewBuilder
    private func cardItems(side: CGFloat) -> some View {
        let items = viewModel.filteredItems
        if items.isEmpty {
            cardEmptyState(side: side)
        } else {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, snapshot in
                cardCell(index: index, snapshot: snapshot, side: side)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 4)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private func cardCell(index: Int, snapshot: ClipItemSnapshot, side: CGFloat) -> some View {
        let shortcut = index - viewModel.quickPasteBase
        ClipRowInteraction(
            index: index,
            onSelect: { viewModel.selectedIndex = index },
            onDoublePaste: { Task { await viewModel.selectAndPaste(quickIndex: index) } }
        ) {
            clipCardView(
                snapshot: snapshot,
                isSelected: index == viewModel.selectedIndex,
                viewModel: viewModel
            )
            .frame(width: side, height: side)
            .overlay(alignment: .topTrailing) {
                if (0...8).contains(shortcut) {
                    shortcutBadge(shortcut + 1)
                }
            }
            .overlay(alignment: .bottomLeading) {
                // Discoverability cue mirroring the list layout's chevron:
                // the selected card has smart actions under ↓.
                if index == viewModel.selectedIndex,
                   !viewModel.actionsExpanded,
                   !viewModel.actions(for: snapshot).isEmpty
                {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .help("Smart actions — press ↓")
                        .accessibilityIdentifier(AccessibilityIdentifiers.actionHintCue)
                }
            }
            .overlay(alignment: .bottom) {
                if index == viewModel.selectedIndex && viewModel.actionsExpanded {
                    ClipActionStripView(
                        actions: viewModel.actions(for: snapshot),
                        compact: true,
                        highlightedIndex: viewModel.actionIndex
                    ) { viewModel.run($0) }
                }
            }
            .contextMenu {
                clipContextMenu(snapshot: snapshot, viewModel: viewModel)
            }
            .id(snapshot.id)
            .accessibilityIdentifier("cardCell_\(index)")
        }
    }

    private func shortcutBadge(_ number: Int) -> some View {
        Text("⌘\(number)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.9))
            .clipShape(Capsule())
            .padding(8)
            .accessibilityIdentifier("cardShortcut_\(number)")
    }

    private func cardEmptyState(side: CGFloat) -> some View {
        let searching = !viewModel.searchText.isEmpty
        return VStack(spacing: 6) {
            Text(searching ? "No matches" : "Nothing copied yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(searching
                 ? "Press Esc to clear the search."
                 : "Copy anything in any app — text, images, files, colors — and it'll appear here.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(width: side, height: side)
    }
}
