import CryptoKit
import Foundation
import LocalAuthentication

@MainActor
final class LockStore: ObservableObject {
    @Published var isUnlocked = false
    @Published var hasPasscode = false
    @Published var faceIDOn = false
    @Published var biometryName = "Face ID"
    @Published var errorText: String?

    init() {
        hasPasscode = KeychainStore.get("passcode-hash") != nil
        faceIDOn = UserDefaults.standard.bool(forKey: "monolith.face")
        refreshBiometryName()
    }

    func refreshBiometryName() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometryName = "Face ID"
            return
        }
        switch context.biometryType {
        case .touchID: biometryName = "Touch ID"
        case .faceID: biometryName = "Face ID"
        default: biometryName = "Face ID"
        }
    }

    func savePasscode(_ code: String, enableBiometry: Bool) {
        let salt = UUID().uuidString
        KeychainStore.set(salt, account: "passcode-salt")
        KeychainStore.set(hash(code, salt: salt), account: "passcode-hash")
        hasPasscode = true
        faceIDOn = enableBiometry
        UserDefaults.standard.set(enableBiometry, forKey: "monolith.face")
        isUnlocked = true
        errorText = nil
    }

    func verify(_ code: String) -> Bool {
        guard let salt = KeychainStore.get("passcode-salt"),
              let stored = KeychainStore.get("passcode-hash")
        else { return false }
        return hash(code, salt: salt) == stored
    }

    func unlockWithCode(_ code: String) {
        if verify(code) {
            isUnlocked = true
            errorText = nil
        } else {
            errorText = "Неверный код"
        }
    }

    func lock() {
        isUnlocked = false
        errorText = nil
    }

    func tryBiometrics() {
        guard faceIDOn, hasPasscode else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Открыть Дисциплину") { ok, _ in
            Task { @MainActor in
                if ok {
                    self.isUnlocked = true
                    self.errorText = nil
                }
            }
        }
    }

    private func hash(_ code: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data("\(salt):\(code)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
