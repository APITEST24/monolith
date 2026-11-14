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
                    JellyChrome(palette: theme.palette(.journal), shape: RoundedRectangle(cornerRadius: 28, style: .continuous)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Журнал")
                                .font(ManropeFont.font(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                            Text(snapshot.journalSummary.headline)
                                .font(ManropeFont.font(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                            Text(snapshot.journalSummary.subline)
                                .font(ManropeFont.font(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                    }
                    if snapshot.journal.isEmpty {
                        Text("Журнал пуст")
                            .font(ManropeFont.font(size: 15, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                    ForEach(snapshot.journal) { entry in
                        entryCard(entry)
                    }
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { JournalForm() }
    }

    private func entryCard(_ entry: JournalItem) -> some View {
        JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 26, style: .continuous), glow: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.dateLabel)
                    .font(ManropeFont.font(size: 12, weight: .medium))
                    .foregroundStyle(theme.tertiary)
                Text(entry.title)
                    .font(ManropeFont.font(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Причина: \(entry.reason)")
                    .font(ManropeFont.font(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Результат: \(entry.result)")
                    .font(ManropeFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(theme.tone(entry.resultTone))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}
