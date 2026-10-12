import Foundation
import UserNotifications

/// A single daily "come and practise" local notification.
enum Reminders {
    static let identifier = "uzbelia.daily"

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { c in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    c.resume(returning: granted)
                }
        }
    }

    static func schedule(hour: Int, minute: Int, language: Language, streak: Int) async {
        guard await requestAuthorization() else { return }
        cancel()

        let content = UNMutableNotificationContent()
        content.title = "Lingora"
        content.body = body(language: language, streak: streak)
        content.sound = .default

        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// `language` is the course: the reminder names what she is learning.
    private static func body(language: Language, streak: Int) -> String {
        streak == 0
            ? "Five minutes of \(language.name)? Anorcha is waiting 🍅"
            : "You're on a \(streak)-day streak: don't lose it! 🔥"
    }
}
