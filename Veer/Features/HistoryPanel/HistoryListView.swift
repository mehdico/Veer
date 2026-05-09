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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: Constants.UI.glassBorderWidth)
        )
    }

    @Namespace private var animation

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
            .onChange(of: viewModel.panel.isShown) { _, shown in
                if shown, let firstID = viewModel.filteredItems.first?.id {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
        }
    }
}
