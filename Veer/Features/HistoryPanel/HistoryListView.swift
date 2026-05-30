import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: HistoryListViewModel
    @Bindable var coordinator: PanelCoordinator
    @FocusState private var focused: Bool

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
                        Text(viewModel.searchText.isEmpty ? "No clips yet" : "No matches")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, snapshot in
                            clipCellView(
                                snapshot: snapshot,
                                isSelected: index == viewModel.selectedIndex,
                                viewModel: viewModel
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 4)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98))
                                )
                            )
                            .id(snapshot.id)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                TapGesture(count: 2).onEnded {
                                    Task { await viewModel.selectAndPaste(quickIndex: index) }
                                }
                            )
                            .onTapGesture {
                                viewModel.selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .animation(viewModel.searchText.isEmpty ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: viewModel.filteredIDs)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.yippyTableView)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let items = viewModel.filteredItems
                guard items.indices.contains(newIndex) else { return }
                proxy.scrollTo(items[newIndex].id, anchor: .center)
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if let firstID = viewModel.filteredItems.first?.id {
                    if newValue.isEmpty {
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
}
