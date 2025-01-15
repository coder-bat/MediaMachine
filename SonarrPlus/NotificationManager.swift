//
//  NotificationManager.swift
//  SonarrPlus
//
//  Created by Coder Bat on 12/1/2025.
//

import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    func scheduleNotification(for episode: Episode, airDate: Date) {
        guard let showTitle = episode.showTitle else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Episode: \(showTitle)"
        content.body = "\(episode.title) airs on \(formatDate(airDate))!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: airDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(episode.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(showTitle) - \(episode.title)")
            }
        }
    }


    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
