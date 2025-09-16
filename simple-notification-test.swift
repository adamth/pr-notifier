#!/usr/bin/env swift

import Foundation
import UserNotifications

print("🧪 Simple notification test...")

// Request permission and send test notification
let center = UNUserNotificationCenter.current()

center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    if let error = error {
        print("❌ Permission error: \(error)")
        exit(1)
    }

    if granted {
        print("✅ Permission granted")

        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Hello from Swift!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Notification sent")
            }
            exit(0)
        }
    } else {
        print("❌ Permission denied")
        exit(1)
    }
}

// Keep the script running
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))