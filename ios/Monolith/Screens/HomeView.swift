import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController

    private let cardRadius: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            header
            if let note = model.note, model.serverConfigured {
                Text(note)
                    .face(13, .medium, em: -0.01)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            if let snapshot = model.snapshot {
                ViewThatFits(in: .vertical) {
                    fitted(snapshot)
                    ScreenColumn {
                        financeCard(snapshot)
                        peeks(snapshot)
                    }
                }
            } else if model.loading {
                Spacer()
                ProgressView().tint(theme.ink)
                Spacer()
            } else {
                Spacer()
                Text("Нет сохранённых данных")
                    .face(16, .medium)
                    .foregroundStyle(theme.muted)
                Button("Повторить") { Task { await model.refresh() } }
                    .face(16, .semibold)
                    .foregroundStyle(theme.ink)
                    .padding(.top, 12)
                Spacer()
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Дисциплина")
                    .face(22, .bold, em: -0.04)
                    .foregroundStyle(theme.ink)
                Text(model.snapshot?.dateLabel ?? "")
                    .face(14, .medium, em: -0.01)
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            DotButton { model.showSettings = true }
        }
        .padding(.leading, 24)
        .padding(.trailing, 22)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func fitted(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 14) {
            financeCard(snapshot).frame(height: 358)
            peeks(snapshot)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func peeks(_ snapshot: Snapshot) -> some View {
        sectionLink(.bundles, "Связки", snapshot.home.bundlesLabel, Route.bundles, monoIndex: 0)
        sectionLink(.geo, "Гео", snapshot.home.geosLabel, Route.geo, monoIndex: 1)
        sectionLink(.tasks, "Задачи", snapshot.home.tasksLabel, Route.tasks, monoIndex: 2)
        sectionLink(.journal, "Журнал решений", snapshot.home.journalLabel, Route.journal, monoIndex: 3)
        sectionLink(.rules, "Правила", snapshot.home.rulesLabel, Route.rules, monoIndex: 4)
    }

    private func financeCard(_ snapshot: Snapshot) -> some View {
        let display = snapshot.finance.display
        let fraction = snapshot.finance.stopLimit > 0 ? snapshot.finance.stopSpent / snapshot.finance.stopLimit : 0
        return NavigationLink(value: Route.finance) {
            JellyChrome(
                skin: theme.hero(.finance),
                shape: RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
            ) {
                VStack(spacing: 0) {
                    Text("Финансы")
                        .face(15, .bold, em: -0.02)
                        .foregroundStyle(theme.ink)
                    Text("Сегодня")
                        .face(13, .semibold)
                        .foregroundStyle(theme.onHero)
                        .padding(.top, 22)
                    Text(display.profitToday)
                        .face(64, .bold, em: -0.05)
                        .foregroundStyle(theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.top, 4)
                        .shadow(color: .black.opacity(0.10), radius: 0, y: 2)
                    Text("прибыль за день")
                        .face(15, .medium)
                        .foregroundStyle(theme.onHero)
                        .padding(.top, 8)
                    Spacer(minLength: 12)
                    Well {
                        HStack(spacing: 0) {
                            metric("Расход", display.spendToday)
                            metric("Доход", display.incomeToday, divider: true)
                            metric("ROI", display.roiToday, divider: true)
                        }
                    }
                    HStack {
                        Text("Стоп-лосс дня")
                            .face(12, .semibold)
                            .foregroundStyle(theme.onHero)
                        Spacer()
                        Text(display.stopRatio)
                            .face(13, ManropeFont.demi, em: -0.02)
                            .foregroundStyle(theme.ink)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    HairlineProgress(fraction: fraction, tint: theme.bar(.bundles))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
        }
        .buttonStyle(.plain)
    }

    private func metric(_ title: String, _ value: String, divider: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .face(12, .semibold)
                .foregroundStyle(theme.onHero)
            Text(value)
                .face(18, .bold, em: -0.03)
                .foregroundStyle(theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .overlay(alignment: .leading) {
            if divider {
                Rectangle().fill(theme.ink.opacity(0.16)).frame(width: 1).padding(.vertical, 14)
            }
        }
    }

    private func sectionLink(
        _ section: SectionKind,
        _ title: String,
        _ meta: String,
        _ route: Route,
        monoIndex: Int
    ) -> some View {
        let paint = theme.monochrome ? theme.monoPeek(monoIndex) : theme.hero(section)
        return NavigationLink(value: route) {
            JellyChrome(skin: paint, shape: RoundedRectangle(cornerRadius: cardRadius, style: .continuous)) {
                HStack {
                    Text(title)
                        .face(17, .bold, em: -0.03)
                        .foregroundStyle(theme.peekInk(section))
                    Spacer()
                    Text(meta)
                        .face(13, ManropeFont.meta, em: -0.01)
                        .foregroundStyle(theme.peekMuted(section))
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 64, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}
