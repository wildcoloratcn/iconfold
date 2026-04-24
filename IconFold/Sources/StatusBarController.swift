import AppKit
import Foundation

/// IconFold - Single button to fold/unfold menu bar icons to its right.
///
/// Mechanism:
/// - One NSStatusItem with variableLength
/// - When "collapsed": length = 2000 (fixed, very wide) — pushes icons off-screen
/// - When "expanded": length = NSStatusItem.variableLength (system calculates natural width)
/// - User CMD+drags to position; app quits always restore to expanded state
class StatusBarController {
    
    // MARK: - Status Item
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // MARK: - State
    
    /// Whether icons to the right are currently hidden
    private(set) var isCollapsed: Bool = false
    
    /// Estimated count of hidden icons
    private var hiddenCount: Int = 0
    
    /// Debounce
    private var isProcessing: Bool = false
    
    // MARK: - Auto-hide
    
    private var eventMonitor: Any?
    private var isAutoHideEnabled: Bool = true
    
    // MARK: - Init
    
    init() {
        setupUI()
        setupEventMonitor()
        
        // Do NOT auto-collapse on launch — start in expanded state
        // This ensures the user's icons are always restored on app launch
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Register for app termination to ensure icons are restored
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        // Restore icons on deinit as well
        restoreIcons()
        NotificationCenter.default.removeObserver(self)
        stopEventMonitor()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        guard let button = statusItem.button else { return }
        
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        updateButtonAppearance()
    }
    
    private func updateButtonAppearance() {
        guard let button = statusItem.button else { return }
        
        if isCollapsed {
            button.image = NSImage(systemSymbolName: "chevron.left.2", accessibilityDescription: "Expand")
            button.title = hiddenCount > 0 ? " \(hiddenCount)" : ""
        } else {
            button.image = NSImage(systemSymbolName: "chevron.right.2", accessibilityDescription: "Fold")
            button.title = ""
        }
        
        button.image?.isTemplate = true
        button.imagePosition = .imageLeft
        button.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    }
    
    // MARK: - Event Monitor
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return }
            guard self.isAutoHideEnabled && self.isCollapsed else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            
            let menuBarHeight: CGFloat = 25
            let menuBarRect = CGRect(
                x: 0,
                y: screen.frame.height - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            
            if !menuBarRect.contains(mouseLocation) {
                self.collapse()
            }
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    @objc private func screenParametersChanged() {
        // Screen changed — if collapsed, update length
        if isCollapsed {
            // Re-collapse with new screen dimensions
            collapse()
        }
    }
    
    // MARK: - App Lifecycle
    
    /// CRITICAL: Always restore icons before quitting
    @objc private func appWillTerminate() {
        restoreIcons()
    }
    
    /// Force restore all icons to visible state
    private func restoreIcons() {
        if isCollapsed {
            statusItem.length = NSStatusItem.variableLength
            isCollapsed = false
            updateButtonAppearance()
        }
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard !isProcessing else { return }
        isProcessing = true
        
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
        }
    }
    
    func toggle() {
        if isCollapsed {
            expand()
        } else {
            collapse()
        }
    }
    
    // MARK: - Fold / Unfold
    
    /// Collapse: make the status item wide (2000pt) to push right-side icons off-screen
    private func collapse() {
        guard !isCollapsed else { return }
        isCollapsed = true
        
        updateHiddenCount()
        
        // 2000pt is large enough to push everything off the right edge of the menu bar
        // This is the same technique as Hidden Bar
        statusItem.length = 2000
        
        updateButtonAppearance()
    }
    
    /// Expand: restore to variableLength so system calculates natural width
    private func expand() {
        guard isCollapsed else { return }
        isCollapsed = false
        
        statusItem.length = NSStatusItem.variableLength
        
        updateButtonAppearance()
    }
    
    private func updateHiddenCount() {
        let runningApps = NSWorkspace.shared.runningApplications
        var count = 0
        for app in runningApps {
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else { continue }
            count += 1
        }
        hiddenCount = max(0, count - 3)
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: isCollapsed ? "🔒 Icons Hidden" : "🔓 Icons Visible", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        if hiddenCount > 0 {
            menu.addItem(NSMenuItem(title: "  ~\(hiddenCount) icons estimated hidden", action: nil, keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: isCollapsed ? "☀️ Show Icons" : "🌙 Hide Icons", action: #selector(toggleFromMenu), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let autoItem = NSMenuItem(
            title: isAutoHideEnabled ? "✅ Auto-hide Enabled" : "☐ Auto-hide Disabled",
            action: #selector(toggleAutoHideFromMenu),
            keyEquivalent: ""
        )
        autoItem.target = self
        menu.addItem(autoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit IconFold", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func toggleFromMenu() {
        toggle()
    }
    
    @objc private func toggleAutoHideFromMenu() {
        isAutoHideEnabled.toggle()
    }
    
    @objc private func quitApp() {
        // Force restore before quitting
        restoreIcons()
        NSApplication.shared.terminate(nil)
    }
}
