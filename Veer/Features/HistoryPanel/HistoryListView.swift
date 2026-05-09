import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: HistoryListViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Divider()
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            viewModel.quickPasteBase = 0
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.panel.isShown) { _, shown in
            if shown {
                focused = true
                viewModel.resetForShow()
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            PanelKeyHandler.handle(press, viewModel: viewModel)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(viewModel.searchText.isEmpty ? "Type to search" : viewModel.searchText)
                .foregroundStyle(viewModel.searchText.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("panelSearchField")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                            .id(snapshot.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.selectedIndex = index
                                Task { await viewModel.pasteSelected() }
                            }
                            .onTapGesture {
                                viewModel.selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.yippyTableView)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                let items = viewModel.filteredItems
                guard newIndex >= 0, newIndex < items.count else { return }
                proxy.scrollTo(items[newIndex].id, anchor: .center)
            }
            .onChange(of: viewModel.panel.isShown) { _, shown in
                if shown, let firstID = viewModel.filteredItems.first?.id {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
        }
    }
}
