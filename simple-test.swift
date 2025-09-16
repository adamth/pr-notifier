import Cocoa
import Foundation

print("🎯 Simple Cocoa test starting...")

class SimpleApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ App delegate method called!")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.title = "●"
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.target = self
        
        print("📍 Status item should be visible in menu bar now")
        print("🔄 App is running... Press Ctrl+C to quit")
    }
    
    @objc func statusItemClicked() {
        print("👆 Status item clicked!")
    }
}

let app = NSApplication.shared
let delegate = SimpleApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)

print("🚀 About to call app.run()...")
app.run()