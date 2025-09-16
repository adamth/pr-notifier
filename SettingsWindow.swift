import Cocoa
import Foundation

protocol SettingsDelegate: AnyObject {
    func tokenDidChange()
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
    weak var delegate: SettingsDelegate?
    
    func show() {
        if window == nil {
            setupWindow()
        }
        
        // Load current token
        tokenField.stringValue = GitHubTokenManager.shared.token ?? ""
        
        updateStatus()
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure the token field is focused and can handle keyboard shortcuts
        window?.makeFirstResponder(tokenField)
    }
    
    private func setupWindow() {
        // Create a smaller, more focused window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Settings"
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.level = .floating

        // Create content view with padding
        let contentView = NSView(frame: window!.contentRect(forFrameRect: window!.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        window?.contentView = contentView

        let margin: CGFloat = 24
        var yPos: CGFloat = contentView.bounds.height - margin

        // Header section
        let headerLabel = NSTextField(labelWithString: "GitHub Token")
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        headerLabel.frame = NSRect(x: margin, y: yPos - 22, width: 200, height: 22)
        contentView.addSubview(headerLabel)
        yPos -= 32

        // Instructions with better formatting
        let instructions = """
        Enter your GitHub Personal Access Token to monitor PR reviews.

        Required permissions: repo • read:user
        """
        let instructionsLabel = NSTextField(wrappingLabelWithString: instructions)
        instructionsLabel.font = NSFont.systemFont(ofSize: 13)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.frame = NSRect(x: margin, y: yPos - 44, width: contentView.bounds.width - (margin * 2), height: 44)
        contentView.addSubview(instructionsLabel)
        yPos -= 60

        // Token input section
        let tokenLabel = NSTextField(labelWithString: "Personal Access Token")
        tokenLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        tokenLabel.frame = NSRect(x: margin, y: yPos - 16, width: 200, height: 16)
        contentView.addSubview(tokenLabel)
        yPos -= 24

        // Token field with modern styling
        tokenField = TokenSecureTextField(frame: NSRect(x: margin, y: yPos - 28, width: 340, height: 28))
        tokenField.placeholderString = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        tokenField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tokenField.delegate = self
        tokenField.wantsLayer = true
        tokenField.layer?.cornerRadius = 6
        tokenField.layer?.borderWidth = 1
        tokenField.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.addSubview(tokenField)

        // Save button next to token field
        let saveButton = NSButton(frame: NSRect(x: margin + 350, y: yPos - 28, width: 70, height: 28))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .regular
        saveButton.target = self
        saveButton.action = #selector(saveToken)
        contentView.addSubview(saveButton)
        yPos -= 40

        // Status section with visual indicator
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: margin, y: yPos - 16, width: contentView.bounds.width - (margin * 2), height: 16)
        contentView.addSubview(statusLabel)
        yPos -= 32

        // Action buttons section
        let buttonY: CGFloat = 20

        // Test connection button
        let testButton = NSButton(frame: NSRect(x: margin, y: buttonY, width: 120, height: 32))
        testButton.title = "Test Connection"
        testButton.bezelStyle = .rounded
        testButton.controlSize = .regular
        testButton.target = self
        testButton.action = #selector(testConnection)
        contentView.addSubview(testButton)

        // Create token link
        let createTokenButton = NSButton(frame: NSRect(x: margin + 130, y: buttonY, width: 140, height: 32))
        createTokenButton.title = "Create Token..."
        createTokenButton.bezelStyle = .rounded
        createTokenButton.controlSize = .regular
        createTokenButton.target = self
        createTokenButton.action = #selector(openGitHubTokenPage)
        contentView.addSubview(createTokenButton)

        // Close button (right-aligned)
        let closeButton = NSButton(frame: NSRect(x: contentView.bounds.width - margin - 70, y: buttonY, width: 70, height: 32))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .regular
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
    
    @objc private func openGitHubTokenPage() {
        if let url = URL(string: "https://github.com/settings/tokens") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func closeWindow() {
        print("🚪 Close button clicked")
        window?.close()
        window = nil
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