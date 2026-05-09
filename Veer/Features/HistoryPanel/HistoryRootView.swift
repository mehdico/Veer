import SwiftUI

struct HistoryRootView: View {
    let env: AppEnvironment
    @Bindable var coordinator: PanelCoordinator

    init(env: AppEnvironment) {
        self.env = env
        self.coordinator = env.panel
    }

    var body: some View {
        Group {
            if coordinator.effectiveHorizontal {
                HistoryCardStripView(viewModel: env.historyViewModel)
            } else {
                HistoryListView(viewModel: env.historyViewModel)
            }
        }
    }
}
