import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (accessory app)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
