import SwiftUI

struct GeoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Гео", trailing: "plus", onBack: { dismiss() }) {
                showCreate = true
            }
            ScreenColumn {
                if let snapshot = model.snapshot {
                    hero(snapshot)
                    ForEach(snapshot.geos) { geo in
                        geoCard(geo)
                    }
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { GeoForm() }
    }

    private func hero(_ snapshot: Snapshot) -> some View {
        let summary = snapshot.geoSummary
        return JellyChrome(
            skin: theme.hero(.geo),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Живые гео")
                        .face(13, .semibold)
                        .foregroundStyle(theme.onHero)
                    Text("\(summary.liveCount)")
                        .face(44, .bold, em: -0.05)
                        .foregroundStyle(theme.ink)
                        .padding(.top, 4)
                    Text(summary.stoppedLine)
                        .face(14, .medium)
                        .foregroundStyle(theme.onHero)
                        .padding(.top, 6)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 10) {
                    rate("Средний CPC", summary.avgCpcLabel)
                    rate("Средний EPC", summary.avgEpcLabel)
                }
                .frame(minWidth: 132, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 18)
        }
    }

    private func rate(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .face(11, .semibold)
                .foregroundStyle(theme.onHero)
            Spacer(minLength: 14)
            Text(value)
                .face(16, .bold, em: -0.03)
                .foregroundStyle(theme.ink)
        }
    }

    private func geoCard(_ geo: GeoItem) -> some View {
        let trendColor = geo.trendPct < 0 ? theme.negative : (abs(geo.trendPct) < 0.5 ? theme.ink : theme.positive)
        let spark = geo.trendPct < 0 ? theme.negative : theme.positive
        return JellyChrome(
            skin: theme.sheet(geo.status == "stop" ? .geoStop : .geo),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    badge(geo)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(geo.name)
                            .face(17, .bold, em: -0.03)
                            .foregroundStyle(theme.ink)
                        Text(geo.subtitle)
                            .face(12, .medium)
                            .foregroundStyle(theme.muted)
                    }
                    Spacer(minLength: 8)
                    StatusPill(title: geo.statusLabel, status: geo.status)
                }
                Well(radius: 14) {
                    HStack(spacing: 0) {
                        cell("CPC", geo.cpcLabel, theme.ink, divider: false)
                        cell("EPC", geo.epcLabel, theme.ink, divider: true)
                        trendCell(geo, color: trendColor, spark: spark)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
    }

    private func badge(_ geo: GeoItem) -> some View {
        let stopped = geo.status == "stop"
        return Text(geo.code)
            .face(15, ManropeFont.blackish, em: -0.04)
            .foregroundStyle(stopped ? AppColor.ink.opacity(0.70) : AppColor.ink)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: stopped
                                ? [Color(hex: 0x3A3A42), Color(hex: 0x1C1C22)]
                                : theme.hero(.geo).stops,
                            startPoint: UnitPoint(x: 0.2, y: 0),
                            endPoint: UnitPoint(x: 0.75, y: 1)
                        )
                    )
            )
            .shadow(color: .black.opacity(0.28), radius: 2, y: 2)
    }

    private func cell(_ title: String, _ value: String, _ color: Color, divider: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .face(10, .semibold)
                .foregroundStyle(theme.muted)
            Text(value)
                .face(14, .bold, em: -0.03)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .overlay(alignment: .leading) {
            if divider { Rectangle().fill(theme.line).frame(width: 1).padding(.vertical, 8) }
        }
    }

    private func trendCell(_ geo: GeoItem, color: Color, spark: Color) -> some View {
        VStack(spacing: 2) {
            Text("Тренд")
                .face(10, .semibold)
                .foregroundStyle(theme.muted)
            HStack(spacing: 5) {
                TrendSpark(trend: geo.trendPct, color: spark)
                Text(geo.trendLabel)
                    .face(14, .bold, em: -0.03)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.line).frame(width: 1).padding(.vertical, 8)
        }
    }
}
