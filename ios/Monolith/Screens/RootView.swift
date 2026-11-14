import SwiftUI

enum Route: Hashable {
    case finance, bundles, geo, tasks, journal, rules
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .finance: FinanceView()
                    case .bundles: BundlesView()
                    case .geo: GeoView()
                    case .tasks: TasksView()
                    case .journal: JournalView()
                    case .rules: RulesView()
                    }
                }
        }
        .background(AppBackground())
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
        }
    }
}
