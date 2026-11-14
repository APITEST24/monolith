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
                    JellyChrome(
                        skin: theme.hero(.rules),
                        shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Дисциплина")
                                .face(13, .semibold)
                                .foregroundStyle(theme.onHero)
                            Text(snapshot.ruleSummary.headline)
                                .face(40, .bold, em: -0.05)
                                .foregroundStyle(theme.ink)
                                .padding(.top, 4)
                            Text(snapshot.ruleSummary.subline)
                                .face(14, .medium)
                                .foregroundStyle(theme.onHero)
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 18)
                    }
                    ForEach(snapshot.rules) { rule in
                        ruleCard(rule)
                    }
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func ruleCard(_ rule: RuleItem) -> some View {
        JellyChrome(
            skin: theme.sheet(.rules),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(rule.title)
                            .face(16, .bold, em: -0.03)
                            .foregroundStyle(theme.ink)
                        Spacer(minLength: 10)
                        Text(rule.valueLabel)
                            .face(18, .bold, em: -0.04)
                            .foregroundStyle(rule.enabled ? theme.ink : theme.muted)
                    }
                    Text(rule.detail)
                        .face(12, .medium)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                JellyToggle(isOn: rule.enabled) { model.toggleRule(rule) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(rule.enabled ? 1 : 0.78)
        }
    }
}
