import SwiftUI

struct LockView: View {
    @EnvironmentObject private var lock: LockStore
    @EnvironmentObject private var theme: ThemeController
    @State private var code = ""
    @State private var first = ""
    @State private var phase: Phase = .enter
    @State private var askBiometry = false

    enum Phase {
        case enter, confirm
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            JellyChrome(skin: theme.hero(.finance), shape: Circle()) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
            }
            Text("Дисциплина")
                .font(ManropeFont.font(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 22)
            Text(prompt)
                .font(ManropeFont.font(size: 15, weight: .medium))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 32)
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < code.count ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 22)
            if let error = lock.errorText {
                Text(error)
                    .font(ManropeFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(theme.negative)
                    .padding(.top, 10)
            }
            Spacer()
            pad
            if lock.hasPasscode && lock.faceIDOn {
                Button(lock.biometryName) { lock.tryBiometrics() }
                    .font(ManropeFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 28)
            } else {
                Color.clear.frame(height: 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .onAppear {
            if lock.hasPasscode {
                lock.tryBiometrics()
            }
        }
        .confirmationDialog("Включить \(lock.biometryName)?", isPresented: $askBiometry, titleVisibility: .visible) {
            Button("Включить") { lock.savePasscode(first, enableBiometry: true) }
            Button("Только код") { lock.savePasscode(first, enableBiometry: false) }
        }
    }

    private var prompt: String {
        if !lock.hasPasscode {
            return phase == .enter ? "Задайте код из 4 цифр" : "Повторите код"
        }
        return "Введите код"
    }

    private var pad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 16) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                if key.isEmpty {
                    Color.clear.frame(height: 64)
                } else {
                    Button {
                        tap(key)
                    } label: {
                        Text(key)
                            .font(ManropeFont.font(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(Circle().fill(Color.white.opacity(key == "⌫" ? 0 : 0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 12)
    }

    private func tap(_ key: String) {
        lock.errorText = nil
        if key == "⌫" {
            if !code.isEmpty { code.removeLast() }
            return
        }
        guard code.count < 4 else { return }
        code.append(key)
        guard code.count == 4 else { return }
        if lock.hasPasscode {
            let entered = code
            code = ""
            lock.unlockWithCode(entered)
            if lock.errorText != nil {
                code = ""
            }
            return
        }
        if phase == .enter {
            first = code
            code = ""
            phase = .confirm
            return
        }
        if code == first {
            code = ""
            askBiometry = true
        } else {
            lock.errorText = "Код не совпал"
            code = ""
            first = ""
            phase = .enter
        }
    }
}
