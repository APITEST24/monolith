import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Правила", trailing: "ellipsis", onBack: { dismiss() }) {
                model.showSettings = true
            }
            ScreenColumn {
                if let snapshot = model.snapshot {
                    JellyChrome(palette: theme.palette(.rules), shape: RoundedRectangle(cornerRadius: 28, style: .continuous)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Дисциплина")
                                .font(ManropeFont.font(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                            Text(snapshot.ruleSummary.headline)
                                .font(ManropeFont.font(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                            Text(snapshot.ruleSummary.subline)
                                .font(ManropeFont.font(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                    }
                    ForEach(snapshot.rules) { rule in
                        ruleCard(rule)
                    }
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func ruleCard(_ rule: RuleItem) -> some View {
        JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 24, style: .continuous), glow: false) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.title)
                        .font(ManropeFont.font(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(rule.detail)
                        .font(ManropeFont.font(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(rule.valueLabel)
                    .font(ManropeFont.font(size: 16, weight: .bold))
                    .foregroundStyle(rule.valueMuted ? theme.tertiary : .white)
                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { _ in model.toggleRule(rule) }
                ))
                .labelsHidden()
                .tint(theme.monochrome ? Color.white.opacity(0.7) : Color(hex: 0x3CBF6A))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
