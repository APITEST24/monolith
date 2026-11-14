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
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRange) { rangeSheet }
    }

    private func balanceCard(_ snapshot: Snapshot) -> some View {
        let display = snapshot.finance.display
        return JellyChrome(
            skin: theme.hero(.finance),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Баланс")
                    .face(13, .semibold)
                    .foregroundStyle(theme.onHero)
                Text(display.balance)
                    .face(60, .bold, em: -0.05)
                    .foregroundStyle(theme.ink)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .padding(.top, 8)
                HStack(alignment: .top, spacing: 24) {
                    chip("Резерв", display.reserve)
                    chip("На холде", display.onHold)
                    chip("Свободно", display.free)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .face(12, .semibold)
                .foregroundStyle(theme.onHero)
            Text(value)
                .face(16, .bold, em: -0.03)
                .foregroundStyle(theme.ink)
        }
    }

    private func detailCard(_ snapshot: Snapshot) -> some View {
        let finance = snapshot.finance
        return JellyChrome(
            skin: theme.sheet(.financeBook),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    statTile("Вложено", finance.display.invested)
                    statTile("Вернулось", finance.display.returned)
                }
                HStack {
                    Text("До безубыточности")
                        .face(13, .semibold)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    Text(finance.display.breakEven)
                        .face(13, ManropeFont.demi, em: -0.02)
                        .foregroundStyle(theme.ink)
                }
                .padding(.top, 14)
                .padding(.bottom, 10)
                HairlineProgress(fraction: finance.breakEvenRatio, tint: theme.bar(.finance))
                Text("Прибыль за 14 дней")
                    .face(13, .semibold)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                chart(finance.series)
                Text("Операции")
                    .face(13, .semibold)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.transactions.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(item.amount < 0 ? Color(hex: 0xE06A62) : theme.positive)
                                .frame(width: 8, height: 8)
                                .shadow(color: .white.opacity(0.04), radius: 0)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .face(15, ManropeFont.demi, em: -0.02)
                                    .foregroundStyle(theme.ink)
                                Text(item.subtitle)
                                    .face(12, .medium)
                                    .foregroundStyle(theme.muted)
                            }
                            Spacer(minLength: 8)
                            Text(item.amountLabel)
                                .face(15, .bold, em: -0.03)
                                .foregroundStyle(item.amount < 0 ? theme.negative : theme.positive)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Rectangle().fill(theme.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .face(12, .semibold)
                .foregroundStyle(theme.muted)
            Text(value)
                .face(26, .bold, em: -0.04)
                .foregroundStyle(theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.30), Color.white.opacity(0.025)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
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
                    colors: [Color(hex: 0x2CB8A8).opacity(0.38), Color(hex: 0x2CB8A8).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("День", point.date),
                y: .value("Прибыль", point.profit)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(theme.chart)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            if point.id == series.last?.id {
                PointMark(
                    x: .value("День", point.date),
                    y: .value("Прибыль", point.profit)
                )
                .foregroundStyle(theme.ink)
                .symbolSize(36)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 80)
    }

    private var rangeSheet: some View {
        let total = model.snapshot?.finance.series.reduce(0) { $0 + $1.profit } ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Прибыль за 14 дней")
                .face(22, .bold, em: -0.04)
                .foregroundStyle(theme.ink)
            Text("Сумма дневной прибыли на графике — \(RuCopy.money(total, signed: true)).")
                .face(15, .medium)
                .foregroundStyle(theme.muted)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppBackground())
        .presentationDetents([.height(220)])
    }
}
