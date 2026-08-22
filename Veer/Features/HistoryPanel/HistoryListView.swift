import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: HistoryListViewModel
    @Bindable var coordinator: PanelCoordinator
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PanelSearchChrome(searchText: $viewModel.searchText, focused: $searchFocused)
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            searchFocused = true
            viewModel.quickPasteBase = 0
        }
        .onChange(of: coordinator.isShown) { _, shown in
            if shown {
                searchFocused = true
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            PanelKeyHandler.handle(press, viewModel: viewModel)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    let items = viewModel.filteredItems
                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, snapshot in
                            let isSelected = index == viewModel.selectedIndex
                            ClipRowInteraction(
                                index: index,
                                onSelect: { viewModel.selectedIndex = index },
                                onDoublePaste: { Task { await viewModel.selectAndPaste(quickIndex: index) } }
                            ) {
                                VStack(spacing: 0) {
                                    clipCellView(
                                        snapshot: snapshot,
                                        isSelected: isSelected,
                                        viewModel: viewModel
                                    )
                                    .safeAreaInset(edge: .trailing, spacing: 4) {
                                        // Uniform trailing rail: dim ⌘N quick-paste
                                        // badges on the first nine rows, and a
                                        // chevron cue on the selected row when it
                                        // has smart actions to reveal.
                                        trailingRail(
                                            index: index,
                                            snapshot: snapshot,
                                            isSelected: isSelected
                                        )
                                        .frame(width: 24)
                                    }
                                    if isSelected && viewModel.actionsExpanded {
                                        ClipActionStripView(
                                            actions: viewModel.actions(for: snapshot),
                                            compact: false,
                                            highlightedIndex: viewModel.actionIndex
                                        ) { viewModel.run($0) }
                                    }
                                }
                                .contextMenu {
                                    clipContextMenu(snapshot: snapshot, viewModel: viewModel)
                                }
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 4)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98))
                                    )
                                )
                                .id(snapshot.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .animation(
                    viewModel.searchText.isEmpty || reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                    value: viewModel.filteredIDs
                )
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.veerTableView)
            .onChange(of: viewModel.selectedIndex) { oldIndex, newIndex in
                let items = viewModel.filteredItems
                guard items.indices.contains(newIndex) else { return }
                // Only scroll if this is a keyboard navigation (small incremental change)
                // Mouse clicks typically jump to arbitrary indices and the item is already visible
                let isKeyboardNavigation = abs(newIndex - (oldIndex ?? newIndex)) <= 1
                guard isKeyboardNavigation else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(items[newIndex].id, anchor: .center)
                }
            }
            .onChange(of: viewModel.resultsResetToken) { _, _ in
                // The debounced search rebuilt the list for a new query: jump
                // to the first result. Keying off the token (not searchText)
                // guarantees filteredItems is fresh — searchText fires ~80ms
                // before the debounce lands, and scrolling then anchored the
                // list to the previous query's first match.
                guard let firstID = viewModel.filteredItems.first?.id else { return }
                if viewModel.searchText.isEmpty || reduceMotion {
                    proxy.scrollTo(firstID, anchor: .top)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(firstID, anchor: .top)
                    }
                }
            }
            .onChange(of: coordinator.isShown) { _, shown in
                if shown {
                    // Delay scroll slightly to ensure filteredItems are updated after resetForShow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        guard let firstID = viewModel.filteredItems.first?.id else { return }
                        proxy.scrollTo(firstID, anchor: .top)
                    }
                }
            }
        }
    }

    /// Content of the uniform trailing rail every list row reserves: the ⌘N
    /// quick-paste number on the first nine rows, replaced by a chevron on
    /// the selected row while it has an unopened smart-action strip.
    @ViewBuilder
    private func trailingRail(index: Int, snapshot: ClipItemSnapshot, isSelected: Bool) -> some View {
        let quickNumber = index - viewModel.quickPasteBase + 1
        if isSelected, !viewModel.actionsExpanded,
           !viewModel.actions(for: snapshot).isEmpty
        {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .help("Smart actions — press →")
                .accessibilityIdentifier(AccessibilityIdentifiers.actionHintCue)
        } else if (1...9).contains(quickNumber) {
            Text("⌘\(quickNumber)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .secondary : .tertiary)
                .accessibilityIdentifier("\(AccessibilityIdentifiers.quickPasteBadge)_\(quickNumber)")
        }
    }

    private var emptyState: some View {
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
}
