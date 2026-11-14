import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController

    var body: some View {
        ScreenColumn {
            header
            if let note = model.note, model.serverConfigured {
                Text(note)
                    .font(ManropeFont.font(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let snapshot = model.snapshot {
                NavigationLink(value: Route.finance) {
                    financeCard(snapshot)
                }
                .buttonStyle(.plain)
                sectionLink(.bundles, "Связки", snapshot.home.bundlesLabel, Route.bundles)
                sectionLink(.geo, "Гео", snapshot.home.geosLabel, Route.geo)
                sectionLink(.tasks, "Задачи", snapshot.home.tasksLabel, Route.tasks)
                sectionLink(.journal, "Журнал решений", snapshot.home.journalLabel, Route.journal)
                sectionLink(.rules, "Правила", snapshot.home.rulesLabel, Route.rules)
            } else if model.loading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 80)
            } else {
                Text("Нет сохранённых данных")
                    .font(ManropeFont.font(size: 16, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .padding(.top, 80)
                Button("Повторить") { Task { await model.refresh() } }
                    .font(ManropeFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Дисциплина")
                    .font(ManropeFont.font(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text(model.snapshot?.dateLabel ?? "")
                    .font(ManropeFont.font(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            CircleIconButton(system: "ellipsis") { model.showSettings = true }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func financeCard(_ snapshot: Snapshot) -> some View {
        let display = snapshot.finance.display
        let fraction = snapshot.finance.stopLimit > 0 ? snapshot.finance.stopSpent / snapshot.finance.stopLimit : 0
        return JellyChrome(palette: theme.palette(.finance), shape: RoundedRectangle(cornerRadius: 30, style: .continuous)) {
            VStack(spacing: 0) {
                Text("Финансы")
                    .font(ManropeFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                Text("Сегодня")
                    .font(ManropeFont.font(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 12)
                Text(display.profitToday)
                    .font(ManropeFont.font(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 2)
                Text("прибыль за день")
                    .font(ManropeFont.font(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                HStack(spacing: 0) {
                    metric("Расход", display.spendToday)
                    divider
                    metric("Доход", display.incomeToday)
                    divider
                    metric("ROI", display.roiToday)
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.16)))
                .padding(.top, 18)
                HStack {
                    Text("Стоп-лосс дня")
                        .font(ManropeFont.font(size: 14, weight: .medium))
                    Spacer()
                    Text(display.stopRatio)
                        .font(ManropeFont.font(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 14)
                HairlineProgress(fraction: fraction, tint: theme.gold)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(ManropeFont.font(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.16)).frame(width: 1, height: 28)
    }

    private func sectionLink(_ section: SectionKind, _ title: String, _ meta: String, _ route: Route) -> some View {
        NavigationLink(value: route) {
            JellyChrome(palette: theme.palette(section), shape: Capsule()) {
                HStack {
                    Text(title)
                        .font(ManropeFont.font(size: 18, weight: .semibold))
                    Spacer()
                    Text(meta)
                        .font(ManropeFont.font(size: 15, weight: .medium))
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .buttonStyle(.plain)
    }
}
