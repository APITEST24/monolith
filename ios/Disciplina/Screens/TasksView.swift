import SwiftUI

struct TasksView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Задачи", trailing: "plus", onBack: { dismiss() }) {
                showCreate = true
            }
            ScreenColumn {
                if let snapshot = model.snapshot {
                    JellyChrome(palette: theme.palette(.tasks), shape: RoundedRectangle(cornerRadius: 28, style: .continuous)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.taskSummary.dateLine)
                                .font(ManropeFont.font(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                            Text(snapshot.taskSummary.headline)
                                .font(ManropeFont.font(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                            Text(snapshot.taskSummary.subline)
                                .font(ManropeFont.font(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                    }
                    if snapshot.tasks.isEmpty {
                        Text("На сегодня задач нет")
                            .font(ManropeFont.font(size: 15, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                    ForEach(snapshot.tasks) { task in
                        taskCard(task)
                    }
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { TaskForm() }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        JellyChrome(palette: JellyPalette.ink, shape: RoundedRectangle(cornerRadius: 26, style: .continuous), glow: false) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    model.toggleTask(task)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(task.done ? theme.palette(.tasks).mid : Color.clear)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(task.done ? Color.clear : Color.white.opacity(0.28), lineWidth: 1.4)
                        if task.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(ManropeFont.font(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(task.detail)
                        .font(ManropeFont.font(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !task.note.isEmpty {
                        Text(task.note)
                            .font(ManropeFont.font(size: 14, weight: .semibold))
                            .foregroundStyle(theme.tone(task.noteTone))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}
