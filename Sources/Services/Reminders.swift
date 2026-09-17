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
        content.title = "Uzbelia"
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

    private static func body(language: Language, streak: Int) -> String {
        switch (language, streak) {
        case (.it, 0):
            return "Cinque minuti di uzbeko? Anorcha ti aspetta 🍅"
        case (.it, _):
            return "Hai una serie di \(streak) giorni: non perderla! 🔥"
        case (.uz, 0):
            return "Besh daqiqa italyancha? Anorcha kutyapti 🍅"
        case (.uz, _):
            return "\(streak) kunlik seriyangiz bor — uzilib qolmasin! 🔥"
        }
    }
}
