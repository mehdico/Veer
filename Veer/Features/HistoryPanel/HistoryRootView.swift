import SwiftUI

struct HistoryRootView: View {
    let env: AppEnvironment
    @Bindable var coordinator: PanelCoordinator

    init(env: AppEnvironment) {
        self.env = env
        self.coordinator = env.panel
    }

    @State private var isVisible = false

    var body: some View {
        Group {
            if coordinator.effectiveHorizontal {
                HistoryCardStripView(viewModel: env.historyViewModel, coordinator: coordinator)
            } else {
                HistoryListView(viewModel: env.historyViewModel, coordinator: coordinator)
            }
        }
        .onChange(of: coordinator.isShown) { _, shown in
            if shown {
                env.historyViewModel.resetForShow()
                coordinator.syncSearchChromeHeight(isSearching: false)
            }
        }
        .onChange(of: env.historyViewModel.searchText.isEmpty) { _, isEmpty in
            coordinator.syncSearchChromeHeight(isSearching: !isEmpty)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .blur(radius: isVisible ? 0 : 10)
        .onAppear {
            coordinator.syncSearchChromeHeight(isSearching: !env.historyViewModel.searchText.isEmpty)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}
