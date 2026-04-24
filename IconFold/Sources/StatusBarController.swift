import AppKit
import Foundation

/// IconFold - Single button to fold/unfold menu bar icons.
///
/// How it works:
/// - One NSStatusItem with variableLength acts as both the divider and the toggle
/// - When "collapsed": length = screenWidth (pushes ALL icons to the right off-screen)
/// - When "expanded": length = auto (system default, icons visible)
/// - Shows a count badge of how many icons are hidden
///
/// User CMD+drags this button to position it to the left of icons they want to hide.
class StatusBarController {
    
    // MARK: - Status Item
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // MARK: - State
    
    /// Whether icons to the right are currently hidden (pushed off-screen)
    private(set) var isCollapsed: Bool = false
    
    /// Count of hidden icons (estimated based on position)
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopEventMonitor()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        guard let button = statusItem.button else { return }
        
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Enable CMD+drag positioning
        statusItem.autosaveName = "iconfold_main"
        
        updateButtonAppearance()
    }
    
    private func updateButtonAppearance() {
        guard let button = statusItem.button else { return }
        
        if isCollapsed {
            // Collapsed: show chevron-left + count, icon pushes right
            button.image = NSImage(systemSymbolName: "chevron.left.2", accessibilityDescription: "Expand")
            button.title = hiddenCount > 0 ? " \(hiddenCount)" : ""
        } else {
            // Expanded: show chevron-right
            button.image = NSImage(systemSymbolName: "chevron.right.2", accessibilityDescription: "Fold")
            button.title = ""
        }
        
        button.image?.isTemplate = true
        button.imagePosition = .imageLeft
        button.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    }
    
    // MARK: - Event Monitor (auto-collapse on outside click)
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return }
            guard self.isAutoHideEnabled && self.isCollapsed else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            
            // Menu bar is at top of screen
            let menuBarHeight: CGFloat = 25
            let menuBarRect = CGRect(
                x: 0,
                y: screen.frame.height - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            
            // If click is outside menu bar area, auto-collapse
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
        // Screen config changed, re-calculate if needed
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard !isProcessing else { return }
        isProcessing = true
        
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            // Right-click: show context menu
            showContextMenu()
        } else {
            // Left-click: toggle
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
    
    /// Collapse: make the status item very wide, pushing all right-side icons off-screen
    private func collapse() {
        guard !isCollapsed else { return }
        isCollapsed = true
        
        // Estimate how many icons might be hidden based on screen position
        updateHiddenCount()
        
        // Set length to screen width + buffer to push everything right off-screen
        let screenWidth = NSScreen.main?.frame.width ?? 1728
        statusItem.length = screenWidth + 500
        
        updateButtonAppearance()
    }
    
    /// Expand: restore normal length
    private func expand() {
        guard isCollapsed else { return }
        isCollapsed = false
        
        // Restore to variableLength (system auto-calculates)
        statusItem.length = NSStatusItem.variableLength
        
        updateButtonAppearance()
    }
    
    private func updateHiddenCount() {
        // Estimate: count running apps that likely have menu bar icons
        // This is approximate - we can't get exact positions without Accessibility API
        let runningApps = NSWorkspace.shared.runningApplications
        var count = 0
        
        for app in runningApps {
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else { continue }
            count += 1
        }
        
        // Subtract system icons and estimate based on position
        hiddenCount = max(0, count - 3) // Assume ~3 icons are always visible
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
        NSApplication.shared.terminate(nil)
    }
}
