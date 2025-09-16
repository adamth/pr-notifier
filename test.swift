import Foundation
print("🧪 Basic Swift test - this should print!")
print("Environment variables:")
for (key, value) in ProcessInfo.processInfo.environment {
    if key.contains("GITHUB") {
        print("  \(key): \(value)")
    }
}