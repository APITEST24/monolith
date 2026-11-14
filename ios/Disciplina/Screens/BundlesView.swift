import SwiftUI

struct BundlesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @State private var showCreate = false

    private let filters: [(String, String)] = [
        ("all", "Все"),
        ("test", "Тест"),
        ("profit", "Прибыль"),
        ("stop", "Стоп"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Связки", trailing: "plus", onBack: { dismiss() }) {
                showCreate = true
            }
            ScreenColumn {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.0) { key, title in
                            filterChip(key, title)
                        }
                    }
                }
                let rows = model.filteredBundles()
                if rows.isEmpty {
                    Text("Нет связок в этом статусе")
                        .font(ManropeFont.font(size: 15, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }
                ForEach(rows) { bundle in
                    bundleCard(bundle)
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) {
            BundleForm()
        }
    }

    private func filterChip(_ key: String, _ title: String) -> some View {
        let selected = model.bundleFilter == key
        return Button {
            model.bundleFilter = key
        } label: {
            Text(title)
                .font(ManropeFont.font(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: 0x1A140C) : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule().fill(theme.monochrome ? Color.white.opacity(0.85) : Color(hex: 0xE2B043))
                    } else {
                        Capsule().fill(Color.white.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func bundleCard(_ bundle: BundleItem) -> some View {
        let accent = theme.amountColor(bundle.profit)
        return JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 26, style: .continuous), glow: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bundle.title)
                            .font(ManropeFont.font(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text(bundle.subtitle)
                            .font(ManropeFont.font(size: 13, weight: .medium))
                            .foregroundStyle(theme.tertiary)
                    }
                    Spacer(minLength: 8)
                    StatusPill(title: bundle.statusLabel, status: bundle.status)
                }
                HStack(alignment: .top) {
                    figure("ROI", bundle.roiLabel, accent)
                    figure("Прибыль", bundle.profitLabel, accent)
                    figure("Расход", bundle.spendLabel, .white)
                }
            }
            .padding(16)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, 18)
                    .shadow(color: accent.opacity(0.7), radius: 6)
            }
        }
    }

    private func figure(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ManropeFont.font(size: 12, weight: .medium))
                .foregroundStyle(theme.tertiary)
            Text(value)
                .font(ManropeFont.font(size: 18, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
