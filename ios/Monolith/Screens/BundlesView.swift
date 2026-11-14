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
                        .face(15, .medium)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                ForEach(rows) { bundle in
                    bundleCard(bundle)
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { BundleForm() }
    }

    private func filterChip(_ key: String, _ title: String) -> some View {
        let selected = model.bundleFilter == key
        return Button {
            model.bundleFilter = key
        } label: {
            Text(title)
                .face(13, ManropeFont.demi, em: -0.02)
                .foregroundStyle(selected ? Color(hex: 0x1A1408) : theme.muted)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background {
                    if selected {
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hex: 0xF0D078), Color(hex: 0xD4A038)],
                                startPoint: UnitPoint(x: 0.2, y: 0),
                                endPoint: UnitPoint(x: 0.8, y: 1)
                            )
                        )
                    } else {
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hex: 0x222126), Color(hex: 0x161518)],
                                startPoint: UnitPoint(x: 0.2, y: 0),
                                endPoint: UnitPoint(x: 0.8, y: 1)
                            )
                        )
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 2.5, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func bundleCard(_ bundle: BundleItem) -> some View {
        JellyChrome(
            skin: theme.bundleSkin(bundle.status),
            shape: RoundedRectangle(cornerRadius: 28, style: .continuous)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bundle.title)
                            .face(18, .bold, em: -0.03)
                            .foregroundStyle(theme.ink)
                        Text(bundle.subtitle)
                            .face(13, .medium)
                            .foregroundStyle(theme.muted)
                    }
                    Spacer(minLength: 8)
                    StatusPill(title: bundle.statusLabel, status: bundle.status)
                        .padding(.top, 2)
                }
                Well(radius: 14) {
                    HStack(spacing: 0) {
                        figure("ROI", bundle.roiLabel, roiColor(bundle), divider: false)
                        figure("Прибыль", bundle.profitLabel, profitColor(bundle), divider: true)
                        figure("Расход", bundle.spendLabel, theme.ink, divider: true)
                    }
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .overlay(alignment: .leading) {
                LinearGradient(colors: rail(bundle.status), startPoint: .top, endPoint: .bottom)
                    .frame(width: 8)
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 2)
            }
        }
    }

    private func roiColor(_ bundle: BundleItem) -> Color {
        if bundle.roiPct < 0 { return theme.negative }
        if bundle.status == "profit" { return theme.positive }
        return theme.ink
    }

    private func profitColor(_ bundle: BundleItem) -> Color {
        bundle.profit < 0 ? theme.negative : theme.positive
    }

    private func rail(_ status: String) -> [Color] {
        switch status {
        case "profit": return [Color(hex: 0x2CB8A8), Color(hex: 0x0E6A61)]
        case "test": return [Color(hex: 0xE0B65A), Color(hex: 0x8A6A18)]
        default: return [Color(hex: 0xE06A62), Color(hex: 0x6A1E1C)]
        }
    }

    private func figure(_ title: String, _ value: String, _ color: Color, divider: Bool) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .face(11, .semibold)
                .foregroundStyle(theme.muted)
            Text(value)
                .face(15, .bold, em: -0.03)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .overlay(alignment: .leading) {
            if divider {
                Rectangle().fill(theme.line).frame(width: 1).padding(.vertical, 8)
            }
        }
    }
}
