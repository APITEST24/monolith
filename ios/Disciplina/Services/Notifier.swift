import Foundation
import UserNotifications

final class Notifier {
    static let shared = Notifier()

    func requestAccess() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func schedule(title: String, body: String, after: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, after), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendTest() {
        schedule(
            title: "Дисциплина",
            body: "Проверка уведомлений: стоп-лосс дня, осталось $12.",
            after: 2
        )
    }
}
