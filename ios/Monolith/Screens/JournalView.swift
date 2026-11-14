import SwiftUI

struct JournalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Журнал решений", trailing: "plus", onBack: { dismiss() }) {
                showCreate = true
            }
            ScreenColumn {
                if let snapshot = model.snapshot {
                    JellyChrome(
                        skin: theme.hero(.journal),
                        shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Журнал")
                                .face(13, .semibold)
                                .foregroundStyle(theme.onHero)
                            Text(snapshot.journalSummary.headline)
                                .face(40, .bold, em: -0.05)
                                .foregroundStyle(theme.ink)
                                .padding(.top, 4)
                            Text(snapshot.journalSummary.subline)
                                .face(14, .medium)
                                .foregroundStyle(theme.onHero)
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 18)
                    }
                    if snapshot.journal.isEmpty {
                        Text("Журнал пуст")
                            .face(15, .medium)
                            .foregroundStyle(theme.muted)
                    }
                    ForEach(snapshot.journal) { entry in
                        entryCard(entry)
                    }
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { JournalForm() }
    }

    private func entryCard(_ entry: JournalItem) -> some View {
        JellyChrome(
            skin: theme.sheet(.journal),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.dateLabel)
                    .face(12, .semibold)
                    .foregroundStyle(theme.monochrome ? theme.muted : Color(hex: 0xE6928B))
                Text(entry.title)
                    .face(16, .bold, em: -0.03)
                    .foregroundStyle(theme.ink)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Причина: \(entry.reason)")
                    .face(12.5, .medium)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Результат: \(entry.result)")
                    .face(13, ManropeFont.demi, em: -0.02)
                    .foregroundStyle(resultColor(entry.resultTone))
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
    }

    private func resultColor(_ tone: String) -> Color {
        switch tone {
        case "positive": return theme.positive
        case "negative": return theme.negative
        default: return theme.ink
        }
    }
}
