import UserNotifications

/// The daily study reminder on the phone ("Tekrar hatırlatıcısı" at "Bildirim saati" in Settings). It is a local
/// notification: it works without internet and needs no push server. Off when the reminder switch is off.
enum ReminderService {
    private static let id = "kavis.dailyReminder"

    /// Schedules (or removes) the reminder for the settings. Asks for permission the first time it is switched on.
    static func refresh(_ settings: Settings, lang: Lang) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard settings.reviewReminder, settings.pushNotifications else { return }
        let state = await center.notificationSettings().authorizationStatus
        if state == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if state == .denied {
            return
        }
        let parts = settings.notifyTime.split(separator: ":").compactMap { Int($0) }
        var when = DateComponents()
        when.hour = parts.first ?? 9
        when.minute = parts.dropFirst().first ?? 0
        let content = UNMutableNotificationContent()
        content.title = Strings.text("remindTitle", lang)
        content.body = Strings.text("remindBody", lang)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// After logging out: no reminder for the next person on this phone.
    static func clear() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
