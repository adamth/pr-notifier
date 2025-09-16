import Cocoa
import Foundation
import QuartzCore

@main
class PRReviewLightApp: NSObject, NSApplicationDelegate, SettingsDelegate, @unchecked Sendable {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private var githubService: GitHubService!
    private var pendingReviews: [PullRequest] = []
    private var snoozedReviews: Set<Int> = []
    private var lastCheckTime: Date = Date()
    private var settingsWindow: SettingsWindow?
    
    static func main() {
        // Set up logging to application support directory (no permission needed)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("PRReviewLight")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let logFile = appDir.appendingPathComponent("pr-review-light.log").path
        
        freopen(logFile.cString(using: .utf8)!, "a+", stdout)
        freopen(logFile.cString(using: .utf8)!, "a+", stderr)
        
        print("🎬 Starting PR Review Light application...")
        print("📋 Logging to: \(logFile)")
        
        let app = NSApplication.shared
        let delegate = PRReviewLightApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // This makes it a menu bar only app
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 PR Review Light starting up...")
        
        setupStatusItem()
        setupMenu()
        
        githubService = GitHubService()
        print("📡 GitHub service initialized")
        
        
        // Check for pending reviews immediately and then every minute
        print("🔍 Starting initial check for pending reviews...")
        checkForPendingReviews()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            print("⏰ Periodic check: Looking for pending reviews...")
            self.checkForPendingReviews()
        }
        print("⏲️  Timer set to check every minute")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "PR Review Light")
        statusItem.button?.imagePosition = .imageOnly
        
        // Configure for maximum icon size with minimal padding
        statusItem.button?.imageScaling = .scaleProportionallyUpOrDown
        statusItem.button?.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        
        // Make sure the status item is always visible
        statusItem.isVisible = true
        statusItem.button?.appearsDisabled = false
        
        print("📍 Status item created and visible in menu bar")
        updateStatusItemAppearance()
    }
    
    private func setupMenu() {
        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PR Review Light", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Now", action: #selector(checkNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func updateStatusItemAppearance() {
        let hasActivePendingReviews = pendingReviews.contains { pr in
            !snoozedReviews.contains(pr.id)
        }
        
        let activeCount = pendingReviews.filter { !snoozedReviews.contains($0.id) }.count
        
        // Always use the same badged icon, but show count only when there are reviews
        statusItem.button?.image = createBadgedIcon(count: activeCount)
        statusItem.button?.contentTintColor = nil // Don't tint the badged image
        
        if hasActivePendingReviews {
            // Enable and animate when there are reviews
            statusItem.button?.appearsDisabled = false
            
            // Add subtle pulsing animation - pulse 5 times then stop
            statusItem.button?.layer?.removeAllAnimations()
            let pulseAnimation = CABasicAnimation(keyPath: "opacity")
            pulseAnimation.fromValue = 1.0
            pulseAnimation.toValue = 0.6
            pulseAnimation.duration = 1.0
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = 5 // Pulse 5 times then stop
            statusItem.button?.layer?.add(pulseAnimation, forKey: "pulse")
        } else {
            // Disable appearance when no reviews (grayed out)
            statusItem.button?.appearsDisabled = true
            
            // Remove any animations
            statusItem.button?.layer?.removeAllAnimations()
        }
        
        let status = hasActivePendingReviews ? "🚨 REVIEWS NEEDED" : "✅ ALL CLEAR"
        print("💡 Light status: \(status) (\(activeCount) active reviews, \(snoozedReviews.count) snoozed)")
    }
    
    private func updateMenu() {
        // Remove all PR-related menu items
        while menu.numberOfItems > 6 {
            menu.removeItem(at: 2)
        }
        
        if pendingReviews.isEmpty {
            let noReviewsItem = NSMenuItem(title: "No pending reviews", action: nil, keyEquivalent: "")
            noReviewsItem.isEnabled = false
            menu.insertItem(noReviewsItem, at: 2)
            menu.insertItem(NSMenuItem.separator(), at: 3)
        } else {
            var insertIndex = 2
            
            for pr in pendingReviews {
                let isSnoozed = snoozedReviews.contains(pr.id)
                let title = isSnoozed ? "💤 \(pr.title)" : "🔍 \(pr.title)"
                
                let prItem = NSMenuItem(title: title, action: #selector(openPR(_:)), keyEquivalent: "")
                prItem.representedObject = pr
                prItem.target = self
                menu.insertItem(prItem, at: insertIndex)
                insertIndex += 1
                
                if !isSnoozed {
                    let snoozeItem = NSMenuItem(title: "   Snooze for 1 hour", action: #selector(snoozePR(_:)), keyEquivalent: "")
                    snoozeItem.representedObject = pr
                    snoozeItem.target = self
                    snoozeItem.isAlternate = true
                    snoozeItem.keyEquivalentModifierMask = .option
                    menu.insertItem(snoozeItem, at: insertIndex)
                    insertIndex += 1
                }
            }
            
            menu.insertItem(NSMenuItem.separator(), at: insertIndex)
        }
        
        // Update last check time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        menu.item(at: 0)?.title = "Last check: \(formatter.string(from: lastCheckTime))"
    }
    
    private func checkForPendingReviews() {
        lastCheckTime = Date()
        print("🔍 Checking GitHub for pending review requests...")
        
        Task {
            let reviews = await githubService.fetchPendingReviews()
            print("✅ GitHub API call completed - found \(reviews.count) pending reviews")

            if !reviews.isEmpty {
                for (index, pr) in reviews.enumerated() {
                    print("  \(index + 1). \(pr.title) (#\(pr.id))")
                }
            }

            DispatchQueue.main.async {

                // Remove snoozed reviews that are no longer pending
                let currentPRIds = Set(reviews.map(\.id))
                let removedSnoozes = self.snoozedReviews.subtracting(currentPRIds)
                if !removedSnoozes.isEmpty {
                    print("🧹 Removed \(removedSnoozes.count) snoozes for completed/closed PRs")
                }
                self.snoozedReviews = self.snoozedReviews.intersection(currentPRIds)

                self.pendingReviews = reviews
                self.updateStatusItemAppearance()
                self.updateMenu()

            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "PR Review Light Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    @objc private func checkNow() {
        print("👆 Manual check requested by user")
        checkForPendingReviews()
    }
    
    @objc private func openPR(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? PullRequest else { return }
        print("🌐 Opening PR in browser: \(pr.title)")
        NSWorkspace.shared.open(URL(string: pr.htmlURL)!)
    }
    
    @objc private func snoozePR(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? PullRequest else { return }
        print("💤 Snoozing PR for 1 hour: \(pr.title)")
        snoozedReviews.insert(pr.id)
        
        // Auto-unsnooze after 1 hour
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) {
            print("⏰ Auto-unsnoozing PR: \(pr.title)")
            self.snoozedReviews.remove(pr.id)
            self.updateStatusItemAppearance()
            self.updateMenu()
        }
        
        updateStatusItemAppearance()
        updateMenu()
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.delegate = self
        }
        settingsWindow?.show()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    
    // MARK: - Badge Creation
    private func createBadgedIcon(count: Int) -> NSImage {
        let baseIcon = NSImage(systemSymbolName: "curlybraces.square.fill", accessibilityDescription: "GitHub Reviews")!
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium) // Even larger base icon
        let configuredIcon = baseIcon.withSymbolConfiguration(config) ?? baseIcon
        
        // Create a new image sized for full icon + badge space
        let size = NSSize(width: 26, height: 22)
        let badgedImage = NSImage(size: size)
        
        badgedImage.lockFocus()
        
        // Draw the base icon using maximum available space
        NSColor.systemOrange.setFill()
        let iconRect = NSRect(x: 0, y: 0, width: 20, height: 20) // Even larger, no padding
        configuredIcon.draw(in: iconRect)
        
        // Only show badge if count > 0
        if count > 0 {
            let badgeText = count > 99 ? "99+" : String(count)
            let badgeSize = badgeText.count <= 2 ? 12.0 : 14.0
            // Position badge at top-right (same location as before)
            let badgeX = size.width - badgeSize - 2
            let badgeY = size.height - badgeSize - 1
            
            // Draw red badge background
            NSColor.systemRed.setFill()
            let badgePath = NSBezierPath(ovalIn: NSRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize))
            badgePath.fill()
            
            // Draw white text on badge
            let fontSize: CGFloat = badgeText.count <= 2 ? 8 : 7
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            
            let textSize = badgeText.size(withAttributes: textAttributes)
            let textX = badgeX + (badgeSize - textSize.width) / 2
            let textY = badgeY + (badgeSize - textSize.height) / 2
            
            badgeText.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)
        }
        
        badgedImage.unlockFocus()
        badgedImage.isTemplate = false
        
        return badgedImage
    }
    
    
    // MARK: - SettingsDelegate
    func tokenDidChange() {
        print("🔄 Token changed, checking for reviews immediately...")
        checkForPendingReviews()
    }
    
}