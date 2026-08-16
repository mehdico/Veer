import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: HistoryListViewModel
    @Bindable var coordinator: PanelCoordinator
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PanelSearchChrome(searchText: viewModel.searchText)
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            viewModel.quickPasteBase = 0
        }
        .onChange(of: coordinator.isShown) { _, shown in
            if shown {
                focused = true
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
            .accessibilityIdentifier(AccessibilityIdentifiers.yippyTableView)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let items = viewModel.filteredItems
                guard items.indices.contains(newIndex) else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(items[newIndex].id, anchor: .center)
                }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if let firstID = viewModel.filteredItems.first?.id {
                    if newValue.isEmpty || reduceMotion {
                        proxy.scrollTo(firstID, anchor: .top)
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(firstID, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: coordinator.isShown) { _, shown in
                if shown, let firstID = viewModel.filteredItems.first?.id {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
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
