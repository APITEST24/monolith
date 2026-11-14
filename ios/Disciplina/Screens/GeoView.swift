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
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { GeoForm() }
    }

    private func hero(_ snapshot: Snapshot) -> some View {
        let summary = snapshot.geoSummary
        return JellyChrome(palette: theme.palette(.geo), shape: RoundedRectangle(cornerRadius: 28, style: .continuous)) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Живые гео")
                        .font(ManropeFont.font(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("\(summary.liveCount)")
                        .font(ManropeFont.font(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    Text(summary.stoppedLine)
                        .font(ManropeFont.font(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    rate("Средний CPC", summary.avgCpcLabel)
                    rate("Средний EPC", summary.avgEpcLabel)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func rate(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(ManropeFont.font(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func geoCard(_ geo: GeoItem) -> some View {
        let trendColor = geo.trendPct < 0 ? theme.negative : (geo.trendPct > 0 ? theme.positive : theme.secondary)
        return JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 26, style: .continuous), glow: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text(geo.code)
                        .font(ManropeFont.font(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(geo.name)
                            .font(ManropeFont.font(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text(geo.subtitle)
                            .font(ManropeFont.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.tertiary)
                    }
                    Spacer(minLength: 8)
                    StatusPill(title: geo.statusLabel, status: geo.status)
                }
                HStack(alignment: .bottom) {
                    figure("CPC", geo.cpcLabel)
                    figure("EPC", geo.epcLabel)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Тренд")
                            .font(ManropeFont.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.tertiary)
                        HStack(spacing: 6) {
                            TrendSpark(trend: geo.trendPct, color: trendColor)
                            Text(geo.trendLabel)
                                .font(ManropeFont.font(size: 15, weight: .bold))
                                .foregroundStyle(trendColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(theme.tertiary)
            Text(value)
                .font(ManropeFont.font(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
