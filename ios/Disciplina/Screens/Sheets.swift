import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeController
    @EnvironmentObject private var lock: LockStore
    @State private var url: String = ""
    @State private var apiKey: String = ""
    @State private var alerts = false
    @State private var showPasscode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Тема")
                        .font(ManropeFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(theme.tertiary)
                    Picker("Тема", selection: $theme.monochrome) {
                        Text("Цветная").tag(false)
                        Text("Монохром").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Text("Сервер")
                        .font(ManropeFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(theme.tertiary)
                    field("https://имя.tailnet.ts.net", text: $url)
                    SecureField("API-ключ телефона", text: $apiKey)
                        .font(ManropeFont.font(size: 16, weight: .medium))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
                    Button("Сохранить сервер") {
                        model.baseURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        KeychainStore.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), account: "api-key")
                        Task { await model.refresh() }
                    }
                    .buttonStyle(JellyButtonStyle(palette: theme.palette(.finance)))

                    Toggle("Локальные уведомления", isOn: $alerts)
                        .font(ManropeFont.font(size: 16, weight: .semibold))
                        .tint(theme.monochrome ? .white : Color(hex: 0x3CBF6A))
                        .onChange(of: alerts) { _, enabled in
                            UserDefaults.standard.set(enabled, forKey: "disciplina.alerts")
                            if enabled {
                                Task { _ = await Notifier.shared.requestAccess() }
                            }
                        }
                    Button("Проверить уведомление") {
                        Task {
                            if await Notifier.shared.requestAccess() {
                                Notifier.shared.sendTest()
                            }
                        }
                    }
                    .font(ManropeFont.font(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                    Button("Сменить код") { showPasscode = true }
                        .font(ManropeFont.font(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Button("Заблокировать") {
                        dismiss()
                        lock.lock()
                    }
                    .font(ManropeFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    Button("Вернуть пример") { model.restoreDemo() }
                        .font(ManropeFont.font(size: 16, weight: .semibold))
                        .foregroundStyle(theme.secondary)

                    Text("Пока адрес сервера пустой, телефон показывает пример с бюджетом $1 000 и копит правки локально. Когда связь с сервером появится, очередь уйдёт сама.")
                        .font(ManropeFont.font(size: 13, weight: .medium))
                        .foregroundStyle(theme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Меню")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            url = model.baseURL
            apiKey = KeychainStore.get("api-key") ?? ""
            alerts = UserDefaults.standard.bool(forKey: "disciplina.alerts")
        }
        .sheet(isPresented: $showPasscode) {
            PasscodeChangeView()
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(ManropeFont.font(size: 16, weight: .medium))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            .foregroundStyle(.white)
    }
}

struct JellyButtonStyle: ButtonStyle {
    var palette: JellyPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ManropeFont.font(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(JellyBackground(palette: palette))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct PasscodeChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lock: LockStore
    @State private var current = ""
    @State private var fresh = ""
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Новый код")
                .font(ManropeFont.font(size: 24, weight: .bold))
                .foregroundStyle(.white)
            SecureField("Текущий код", text: $current)
            SecureField("Новый код, 4 цифры", text: $fresh)
            if !message.isEmpty {
                Text(message)
                    .foregroundStyle(AppColor.negative)
            }
            Button("Сохранить") {
                guard lock.verify(current) else {
                    message = "Текущий код неверный"
                    return
                }
                guard fresh.count == 4, fresh.allSatisfy(\.isNumber) else {
                    message = "Нужны 4 цифры"
                    return
                }
                lock.savePasscode(fresh, enableBiometry: lock.faceIDOn)
                dismiss()
            }
            .buttonStyle(JellyButtonStyle(palette: JellyPalette.ink))
            Spacer()
        }
        .padding(24)
        .background(AppColor.background.ignoresSafeArea())
    }
}

struct TaskForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var title = ""
    @State private var detail = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "Новая задача", canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty) {
            model.addTask(title: title.trimmed, detail: detail.trimmed, note: note.trimmed)
        } fields: {
            formField("Название", text: $title)
            formField("Подробности", text: $detail)
            formField("Пометка", text: $note)
        }
    }
}

struct JournalForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var title = ""
    @State private var reason = ""
    @State private var result = ""

    var body: some View {
        FormSheet(title: "Запись в журнал", canSave: !title.trimmed.isEmpty && !reason.trimmed.isEmpty) {
            model.addJournal(title: title.trimmed, reason: reason.trimmed, result: result.trimmed)
        } fields: {
            formField("Решение", text: $title)
            formField("Причина", text: $reason)
            formField("Результат", text: $result)
        }
    }
}

struct BundleForm: View {
    @EnvironmentObject private var model: AppModel
    @State private var title = ""
    @State private var vertical = ""
    @State private var geo = ""
    @State private var source = ""
    @State private var network = ""
    @State private var modelName = "CPA"

    var body: some View {
        FormSheet(title: "Новая связка", canSave: !title.trimmed.isEmpty && !geo.trimmed.isEmpty) {
            model.addBundle(
                title: title.trimmed,
                vertical: vertical.trimmed.isEmpty ? title.trimmed : vertical.trimmed,
                geoCode: geo.trimmed,
                source: source.trimmed,
                network: network.trimmed,
                model: modelName.trimmed.isEmpty ? "CPA" : modelName.trimmed
            )
        } fields: {
            formField("Название, например VPN · Польша", text: $title)
            formField("Вертикаль", text: $vertical)
            formField("Код гео, PL", text: $geo)
            formField("Источник трафика", text: $source)
            formField("Партнёрка", text: $network)
            formField("Модель, CPA", text: $modelName)
        }
    }
}

struct GeoForm: View {
    @EnvironmentObject private var model: AppModel
    @State private var code = ""
    @State private var name = ""
    @State private var subtitle = ""

    var body: some View {
        FormSheet(title: "Новое гео", canSave: !code.trimmed.isEmpty && !name.trimmed.isEmpty) {
            model.addGeo(code: code.trimmed, name: name.trimmed, subtitle: subtitle.trimmed)
        } fields: {
            formField("Код, DE", text: $code)
            formField("Страна", text: $name)
            formField("Подпись", text: $subtitle)
        }
    }
}

private struct FormSheet<Fields: View>: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var canSave: Bool
    var save: () -> Void
    @ViewBuilder var fields: () -> Fields

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(ManropeFont.font(size: 24, weight: .bold))
                .foregroundStyle(.white)
            fields()
            Button("Сохранить") {
                save()
                dismiss()
            }
            .buttonStyle(JellyButtonStyle(palette: JellyPalette(
                top: Color(hex: 0x3ED4B6),
                mid: Color(hex: 0x14967E),
                bottom: Color(hex: 0x0C6B59),
                glow: Color(hex: 0x0A4F43),
                gloss: 0.5
            )))
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
            Spacer()
        }
        .padding(24)
        .background(AppColor.background.ignoresSafeArea())
    }
}

private func formField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text, axis: .vertical)
        .font(ManropeFont.font(size: 16, weight: .medium))
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        .foregroundStyle(.white)
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
