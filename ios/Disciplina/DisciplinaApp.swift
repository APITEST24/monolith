import SwiftUI

@main
struct DisciplinaApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var theme = ThemeController()
    @StateObject private var lock = LockStore()

    init() {
        ManropeFont.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if lock.isUnlocked {
                    RootView()
                } else {
                    LockView()
                }
            }
            .environmentObject(model)
            .environmentObject(theme)
            .environmentObject(lock)
            .preferredColorScheme(.dark)
            .tint(.white)
            .task { model.boot() }
        }
    }
}

#Preview("Главный") {
    NavigationStack { HomeView() }
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
        .environmentObject(LockStore())
}

#Preview("Финансы") {
    FinanceView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Связки") {
    BundlesView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Гео") {
    GeoView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Задачи") {
    TasksView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Журнал") {
    JournalView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Правила") {
    RulesView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
}

#Preview("Замок") {
    LockView()
        .environmentObject(AppModel.preview)
        .environmentObject(ThemeController())
        .environmentObject(LockStore())
}
