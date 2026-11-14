import Charts
import SwiftUI

struct FinanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @State private var showRange = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Финансы", trailing: "clock", onBack: { dismiss() }) {
                showRange = true
            }
            ScreenColumn {
                if let snapshot = model.snapshot {
                    balanceCard(snapshot)
                    detailCard(snapshot)
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRange) {
            rangeSheet
        }
    }

    private func balanceCard(_ snapshot: Snapshot) -> some View {
        let display = snapshot.finance.display
        return JellyChrome(palette: theme.palette(.finance), shape: RoundedRectangle(cornerRadius: 30, style: .continuous)) {
            VStack(spacing: 0) {
                Text("Баланс")
                    .font(ManropeFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(display.balance)
                    .font(ManropeFont.font(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 6)
                HStack(spacing: 0) {
                    column("Резерв", display.reserve)
                    column("На холде", display.onHold)
                    column("Свободно", display.free)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
    }

    private func column(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(ManropeFont.font(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailCard(_ snapshot: Snapshot) -> some View {
        let finance = snapshot.finance
        return JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 28, style: .continuous), glow: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    statTile("Вложено", finance.display.invested)
                    statTile("Вернулось", finance.display.returned)
                }
                HStack {
                    Text("До безубыточности")
                        .font(ManropeFont.font(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text(finance.display.breakEven)
                        .font(ManropeFont.font(size: 14, weight: .bold))
                        .foregroundStyle(theme.positive)
                }
                HairlineProgress(fraction: finance.breakEvenRatio, tint: theme.positive)
                Text("Прибыль за 14 дней")
                    .font(ManropeFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                chart(finance.series)
                Text("Операции")
                    .font(ManropeFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                VStack(spacing: 14) {
                    ForEach(snapshot.transactions) { item in
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(theme.amountColor(item.amount))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(ManropeFont.font(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(item.subtitle)
                                    .font(ManropeFont.font(size: 12, weight: .medium))
                                    .foregroundStyle(theme.tertiary)
                            }
                            Spacer(minLength: 8)
                            Text(item.amountLabel)
                                .font(ManropeFont.font(size: 15, weight: .bold))
                                .foregroundStyle(theme.amountColor(item.amount))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(theme.tertiary)
            Text(value)
                .font(ManropeFont.font(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private func chart(_ series: [SeriesPoint]) -> some View {
        Chart(series) { point in
            AreaMark(
                x: .value("День", point.date),
                y: .value("Прибыль", point.profit)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [theme.positive.opacity(0.35), theme.positive.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("День", point.date),
                y: .value("Прибыль", point.profit)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(theme.positive)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            if point.id == series.last?.id {
                PointMark(
                    x: .value("День", point.date),
                    y: .value("Прибыль", point.profit)
                )
                .foregroundStyle(theme.positive)
                .symbolSize(50)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 120)
    }

    private var rangeSheet: some View {
        let total = model.snapshot?.finance.series.reduce(0) { $0 + $1.profit } ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Прибыль за 14 дней")
                .font(ManropeFont.font(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Сумма дневной прибыли на графике — \(RuCopy.money(total, signed: true)).")
                .font(ManropeFont.font(size: 15, weight: .medium))
                .foregroundStyle(theme.secondary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.height(220)])
    }
}
