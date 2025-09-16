import Cocoa
import Foundation
import UserNotifications

protocol SettingsDelegate: AnyObject {
    func tokenDidChange()
    func notificationsDidChange(_ enabled: Bool)
}

// Custom secure text field that properly handles keyboard shortcuts
class TokenSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+V (paste)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            print("📋 Custom secure paste handling")
            if let pasteboard = NSPasteboard.general.string(forType: .string) {
                self.stringValue = pasteboard
                // Notify delegate of the change
                if let delegate = self.delegate as? NSTextFieldDelegate {
                    let notification = Notification(name: NSControl.textDidChangeNotification, object: self)
                    delegate.controlTextDidChange?(notification)
                }
                print("📝 Pasted \(pasteboard.count) characters (secure)")
                return true
            }
        }
        
        // Handle Cmd+A (select all)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            print("🔤 Custom secure select all handling")
            self.selectText(nil)
            return true
        }
        
        // Handle Cmd+C (copy) - copy the actual token value
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            print("📄 Custom secure copy handling")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(self.stringValue, forType: .string)
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

class SettingsWindow: NSObject, NSTextFieldDelegate {
    private var window: NSWindow?
    private var tokenField: NSTextField!
    private var statusLabel: NSTextField!
    private var notificationsCheckbox: NSButton!
    weak var delegate: SettingsDelegate?
    
    func show() {
        if window == nil {
            setupWindow()
        }
        
        // Load current token
        tokenField.stringValue = GitHubTokenManager.shared.token ?? ""
        
        // Load current notification setting
        notificationsCheckbox.state = UserDefaults.standard.bool(forKey: "notificationsEnabled") ? .on : .off

        updateStatus()
        updateNotificationStatus()
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure the token field is focused and can handle keyboard shortcuts
        window?.makeFirstResponder(tokenField)
    }
    
    private func setupWindow() {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "PR Review Light Settings"
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.level = .floating
        
        // Create content view
        let contentView = NSView(frame: window!.contentRect(forFrameRect: window!.frame))
        window?.contentView = contentView
        
        // Title label
        let titleLabel = NSTextField(labelWithString: "PR Review Light Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 290, width: 460, height: 25)
        contentView.addSubview(titleLabel)
        
        // Instructions
        let instructionsLabel = NSTextField(wrappingLabelWithString: """
        To use PR Review Light, you need a GitHub Personal Access Token with the following permissions:
        • repo (Full control of private repositories)
        • read:user (Read access to profile info)
        
        Create one at: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
        """)
        instructionsLabel.frame = NSRect(x: 20, y: 190, width: 460, height: 90)
        instructionsLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(instructionsLabel)
        
        // Token field label
        let tokenLabel = NSTextField(labelWithString: "GitHub Personal Access Token:")
        tokenLabel.frame = NSRect(x: 20, y: 160, width: 200, height: 20)
        contentView.addSubview(tokenLabel)
        
        // Token field (secure)
        tokenField = TokenSecureTextField(frame: NSRect(x: 20, y: 135, width: 350, height: 25))
        tokenField.placeholderString = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        tokenField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tokenField.delegate = self
        
        // Make the field properly handle keyboard shortcuts
        tokenField.wantsLayer = true
        contentView.addSubview(tokenField)
        
        
        // Save button
        let saveButton = NSButton(frame: NSRect(x: 380, y: 135, width: 80, height: 25))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveToken)
        contentView.addSubview(saveButton)
        
        // Notifications section
        let notificationLabel = NSTextField(labelWithString: "Notifications:")
        notificationLabel.frame = NSRect(x: 20, y: 125, width: 100, height: 17)
        notificationLabel.font = NSFont.boldSystemFont(ofSize: 13)
        contentView.addSubview(notificationLabel)

        notificationsCheckbox = NSButton(frame: NSRect(x: 20, y: 105, width: 300, height: 20))
        notificationsCheckbox.title = "Enable notifications for new PR review requests"
        notificationsCheckbox.setButtonType(.switch)
        notificationsCheckbox.state = .on // Default enabled
        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(notificationsToggled)
        contentView.addSubview(notificationsCheckbox)

        // Notification status label
        let notificationStatusLabel = NSTextField(labelWithString: "")
        notificationStatusLabel.frame = NSRect(x: 40, y: 85, width: 420, height: 15)
        notificationStatusLabel.font = NSFont.systemFont(ofSize: 11)
        notificationStatusLabel.textColor = .secondaryLabelColor
        notificationStatusLabel.identifier = NSUserInterfaceItemIdentifier("notificationStatus")
        contentView.addSubview(notificationStatusLabel)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: 55, width: 460, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(statusLabel)

        // Test connection button
        let testButton = NSButton(frame: NSRect(x: 20, y: 15, width: 120, height: 25))
        testButton.title = "Test Connection"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testConnection)
        contentView.addSubview(testButton)

        // Test notifications button
        let testNotificationButton = NSButton(frame: NSRect(x: 150, y: 15, width: 140, height: 25))
        testNotificationButton.title = "Test Notification"
        testNotificationButton.bezelStyle = .rounded
        testNotificationButton.target = self
        testNotificationButton.action = #selector(testNotification)
        contentView.addSubview(testNotificationButton)

        // Close button
        let closeButton = NSButton(frame: NSRect(x: 380, y: 15, width: 80, height: 25))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        contentView.addSubview(closeButton)
    }
    
    @objc private func saveToken() {
        print("💾 Save button clicked")
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if token.isEmpty {
            GitHubTokenManager.shared.token = nil
            statusLabel.stringValue = "❌ Token cleared"
            statusLabel.textColor = .systemRed
            print("🗑️ Token cleared")
        } else {
            GitHubTokenManager.shared.token = token
            statusLabel.stringValue = "✅ Token saved successfully"
            statusLabel.textColor = .systemGreen
            print("🔐 GitHub token saved to settings")
            
            // Notify the main app to check for reviews immediately
            delegate?.tokenDidChange()
        }
    }
    
    @objc private func testConnection() {
        print("🧪 Test connection button clicked")
        
        // Save the current token first
        saveToken()
        
        guard let token = GitHubTokenManager.shared.token, !token.isEmpty else {
            statusLabel.stringValue = "❌ No token configured"
            statusLabel.textColor = .systemRed
            print("❌ No token to test")
            return
        }
        
        statusLabel.stringValue = "🔄 Testing connection..."
        statusLabel.textColor = .systemBlue
        print("🔄 Testing GitHub connection...")
        
        Task {
            let githubService = GitHubService()
            do {
                let username = try await githubService.getCurrentUser()
                print("✅ GitHub connection successful: \(username)")
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "✅ Connected as \(username)"
                    self.statusLabel.textColor = .systemGreen
                }
            } catch {
                print("❌ GitHub connection failed: \(error)")
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "❌ Connection failed: \(error.localizedDescription)"
                    self.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    @objc private func closeWindow() {
        print("🚪 Close button clicked")
        window?.close()
        window = nil
    }
    
    @objc private func notificationsToggled() {
        let enabled = notificationsCheckbox.state == .on
        print("🔔 Notifications toggled: \(enabled)")
        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
        delegate?.notificationsDidChange(enabled)
        updateNotificationStatus()
    }

    @objc private func testNotification() {
        print("🧪 Testing notification...")

        // First check and request permissions if needed
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // Need to request permission first
                    print("🔔 Requesting notification permissions...")
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if granted {
                                print("✅ Permission granted, sending test notification")
                                // Force registration with system by sending a notification immediately
                                self.forceSystemRegistration {
                                    self.sendTestNotification()
                                }
                            } else {
                                print("❌ Permission denied")
                                self.showAlert(title: "Permission Denied",
                                             message: """
                                             Notification permissions were denied.

                                             To enable notifications:
                                             1. Quit this app completely
                                             2. Restart the app
                                             3. Go to System Settings > Notifications
                                             4. Look for 'PR Review Light' and enable notifications

                                             Note: It may take 2-3 restarts for unsigned apps to appear in Settings.
                                             """)
                            }
                        }
                    }

                case .denied:
                    self.showAlert(title: "Notifications Disabled",
                                 message: """
                                 Notifications are disabled for this app.

                                 To enable:
                                 1. Try clicking 'Test Notification' again (this may register the app)
                                 2. Go to System Settings > Notifications
                                 3. Look for 'PR Review Light' in the list
                                 4. If not there, quit and restart the app, then try again

                                 Note: Unsigned apps may need multiple attempts to register with the system.
                                 """)

                case .authorized, .provisional, .ephemeral:
                    // Permission granted, send test notification
                    self.sendTestNotification()

                @unknown default:
                    self.showAlert(title: "Unknown Status",
                                 message: "Unable to determine notification status. Please check System Settings.")
                }
            }
        }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "PR Review Light notifications are working!"
        content.subtitle = "This is a test notification"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    print("❌ Test notification failed: \(error.localizedDescription) (Code: \(nsError.code))")

                    var message = "Could not send test notification: \(error.localizedDescription)"

                    // Provide specific guidance for common errors
                    switch nsError.code {
                    case 1: // UNErrorCodeNotificationsNotAllowed
                        message = """
                        Notifications are not allowed for this app.

                        To fix this:
                        1. Go to System Settings > Notifications
                        2. Look for 'PR Review Light' in the app list
                        3. If you don't see it, quit this app completely and restart it
                        4. Try the test notification again (may take 2-3 attempts)
                        5. Once it appears in Settings, enable notifications

                        This happens because unsigned apps need to register with the system first.
                        """
                    case 2: // UNErrorCodeAttachmentInvalidURL
                        message = "Invalid notification attachment."
                    case 3: // UNErrorCodeAttachmentUnrecognizedType
                        message = "Unrecognized attachment type."
                    default:
                        message = "Notification error (code \(nsError.code)): \(error.localizedDescription)"
                    }

                    self.showAlert(title: "Test Failed", message: message)
                } else {
                    print("✅ Test notification sent successfully")
                    self.showAlert(title: "Test Sent",
                                 message: "Test notification sent! You should see it in Notification Center. If not, check System Settings > Notifications > PR Review Light.")
                }
            }
        }
    }

    private func updateNotificationStatus() {
        guard let statusLabel = window?.contentView?.viewWithTag(1001) as? NSTextField ??
              window?.contentView?.subviews.first(where: { $0.identifier?.rawValue == "notificationStatus" }) as? NSTextField else {
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let appEnabled = self.notificationsCheckbox.state == .on
                let systemEnabled = settings.authorizationStatus == .authorized

                if !appEnabled {
                    statusLabel.stringValue = "App notifications disabled"
                    statusLabel.textColor = .secondaryLabelColor
                } else if !systemEnabled {
                    statusLabel.stringValue = "⚠️ Enable in System Settings > Notifications > PR Review Light"
                    statusLabel.textColor = .systemOrange
                } else {
                    statusLabel.stringValue = "✅ Notifications enabled and authorized"
                    statusLabel.textColor = .systemGreen
                }
            }
        }
    }

    private func forceSystemRegistration(completion: @escaping () -> Void) {
        // Send a silent notification to force the app to register with the system
        print("🔧 Forcing system registration...")

        let content = UNMutableNotificationContent()
        content.title = "Registration"
        content.body = "Setting up notifications..."
        content.sound = nil // Silent

        let request = UNNotificationRequest(
            identifier: "force-registration-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Remove the registration notification immediately
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
                completion()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func updateStatus() {
        if GitHubTokenManager.shared.token != nil {
            statusLabel.stringValue = "✅ Token configured"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "⚠️ No token configured"
            statusLabel.textColor = .systemOrange
        }
    }
    
    // MARK: - NSTextFieldDelegate
    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField == tokenField {
            print("📝 Token field text changed: \(tokenField.stringValue.count) characters")
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control == tokenField {
            print("🎹 Key command: \(commandSelector)")
        }
        return false // Always let the system handle commands
    }
}

// Token manager to persist settings
class GitHubTokenManager {
    static let shared = GitHubTokenManager()
    private let tokenKey = "github_token"
    
    var token: String? {
        get {
            // First try environment variable (for backward compatibility)
            if let envToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !envToken.isEmpty {
                return envToken
            }
            
            // Then try keychain
            return getFromKeychain()
        }
        set {
            if let newValue = newValue {
                saveToKeychain(token: newValue)
            } else {
                deleteFromKeychain()
            }
        }
    }
    
    private func saveToKeychain(token: String) {
        let data = Data(token.utf8)
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecAttrService: "PRReviewLight",
            kSecValueData: data
        ] as [String: Any]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Failed to save token to keychain: \(status)")
        }
    }
    
    private func getFromKeychain() -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecAttrService: "PRReviewLight",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let data = result as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    private func deleteFromKeychain() {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecAttrService: "PRReviewLight"
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}