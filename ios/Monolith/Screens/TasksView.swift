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
                    JellyChrome(
                        skin: theme.hero(.tasks),
                        shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snapshot.taskSummary.dateLine)
                                .face(13, .semibold)
                                .foregroundStyle(theme.onHero)
                            Text(snapshot.taskSummary.headline)
                                .face(52, .bold, em: -0.05)
                                .foregroundStyle(theme.ink)
                                .padding(.top, 6)
                            Text(snapshot.taskSummary.subline)
                                .face(15, .medium)
                                .foregroundStyle(theme.onHero)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 20)
                    }
                    if snapshot.tasks.isEmpty {
                        Text("На сегодня задач нет")
                            .face(15, .medium)
                            .foregroundStyle(theme.muted)
                    }
                    ForEach(snapshot.tasks) { task in
                        taskCard(task)
                    }
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) { TaskForm() }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        JellyChrome(
            skin: theme.sheet(.tasks),
            shape: RoundedRectangle(cornerRadius: 32, style: .continuous)
        ) {
            HStack(alignment: .center, spacing: 14) {
                Button { model.toggleTask(task) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: task.done
                                        ? [Color(hex: 0xA07CBC), Color(hex: 0x5C3870), Color(hex: 0x321C42)]
                                        : [Color(hex: 0x2A2A32), Color(hex: 0x16161C)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        if task.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(task.done ? 0.40 : 0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title)
                        .face(17, .bold, em: -0.03)
                        .foregroundStyle(task.done ? theme.ink.opacity(0.72) : theme.ink)
                    Text(task.detail)
                        .face(13, .medium)
                        .foregroundStyle(theme.muted)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    if !task.note.isEmpty {
                        Text(task.note)
                            .face(12, ManropeFont.demi, em: -0.01)
                            .foregroundStyle(task.done ? theme.positive : theme.tone("accent"))
                            .padding(.top, 10)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .opacity(task.done ? 0.88 : 1)
        }
    }
}
