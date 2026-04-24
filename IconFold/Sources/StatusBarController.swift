import AppKit
import Foundation

/// Controls the menu bar status items that fold/unfold icons to the right.
///
/// Mechanism (inspired by Hidden Bar):
/// - btnSeparate: a thin separator (1pt normal, 2000+pt when collapsed)
/// - When collapsed, btnSeparate takes up all space to its right,
///   effectively pushing all icons beyond the screen edge
/// - User drags both items to position them; autosaveName preserves position
class StatusBarController {
    
    // MARK: - Status Items
    
    /// Expand/collapse button with arrow icon
    private let btnExpandCollapse = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    /// Thin separator that acts as the "fold line"
    private let btnSeparate = NSStatusBar.system.statusItem(withLength: 1)
    
    // MARK: - Length Constants
    
    /// Normal (expanded) length of the separator
    private let btnNormalLength: CGFloat = 1
    
    /// Collapsed length — pushes all icons to the right off-screen
    private var btnCollapsedLength: CGFloat = 2000
    
    // MARK: - State
    
    private var isCollapsed: Bool {
        return btnSeparate.length == btnCollapsedLength
    }
    
    /// Debounce rapid clicks
    private var isToggle = false
    
    // MARK: - Event Monitor (for auto-collapse on outside click)
    
    private var eventMonitor: Any?
    
    /// Auto-collapse preference (default: on)
    private var isAutoCollapseEnabled = true
    
    // MARK: - Init
    
    init() {
        updateCollapsedLength()
        setupUI()
        setupEventMonitor()
        
        // Auto-collapse after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.collapse()
        }
        
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
        // Separator button
        if let sepButton = btnSeparate.button {
            sepButton.image = NSImage(systemSymbolName: "line.horizontal.3", accessibilityDescription: "Separator")
            sepButton.image?.isTemplate = true
        }
        btnSeparate.menu = getContextMenu()
        btnSeparate.autosaveName = "iconfold_separate"
        
        // Expand/collapse button
        if let btn = btnExpandCollapse.button {
            btn.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Fold")
            btn.image?.isTemplate = true
            btn.target = self
            btn.action = #selector(expandCollapsePressed)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        btnExpandCollapse.autosaveName = "iconfold_expandcollapse"
    }
    
    // MARK: - Event Monitor (auto-collapse on outside click)
    
    private func setupEventMonitor() {
        // Monitor for left mouse clicks outside the menu bar area
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self, self.isAutoCollapseEnabled else { return }
            guard self.isCollapsed else { return }
            
            // Check if the click was in the menu bar area
            let mouseLocation = NSEvent.mouseLocation
            guard let screen = NSScreen.main else { return }
            
            // Menu bar is at the top of the screen
            let menuBarHeight: CGFloat = 25
            let menuBarRect = CGRect(
                x: 0,
                y: screen.frame.height - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            
            // If click is outside the menu bar, collapse
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
    
    // MARK: - Collapsed Length
    
    /// Bound collapsed length to avoid memory issues on newer macOS
    private func updateCollapsedLength() {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1728
        btnCollapsedLength = max(500, min(screenWidth + 200, 4000))
    }
    
    @objc private func screenParametersChanged() {
        updateCollapsedLength()
    }
    
    // MARK: - Actions
    
    @objc private func expandCollapsePressed(_ sender: NSStatusBarButton) {
        guard !isToggle else { return }
        isToggle = true
        
        let event = NSApp.currentEvent
        
        if event?.modifierFlags.contains(.option) == true {
            // Option+click: toggle auto-collapse
            toggleAutoCollapse()
        } else if event?.type == .rightMouseUp {
            // Right-click: show context menu
            btnSeparate.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: btnSeparate.button)
        } else {
            // Left-click: expand or collapse
            isCollapsed ? expand() : collapse()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isToggle = false
        }
    }
    
    func expandCollapse() {
        guard !isToggle else { return }
        isToggle = true
        isCollapsed ? expand() : collapse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isToggle = false
        }
    }
    
    // MARK: - Fold / Unfold
    
    private func collapse() {
        guard !isCollapsed else { return }
        
        btnSeparate.length = btnCollapsedLength
        if let btn = btnExpandCollapse.button {
            btn.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Unfold")
            btn.image?.isTemplate = true
        }
    }
    
    private func expand() {
        guard isCollapsed else { return }
        
        btnSeparate.length = btnNormalLength
        if let btn = btnExpandCollapse.button {
            btn.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Fold")
            btn.image?.isTemplate = true
        }
    }
    
    // MARK: - Auto Collapse Toggle
    
    private func toggleAutoCollapse() {
        isAutoCollapseEnabled.toggle()
    }
    
    // MARK: - Context Menu
    
    private func getContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let infoItem = NSMenuItem(title: "IconFold", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Toggle Fold", action: #selector(toggleFromMenu), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let autoCollapseItem = NSMenuItem(
            title: isAutoCollapseEnabled ? "✓ Auto Collapse" : "Auto Collapse",
            action: #selector(toggleAutoCollapseFromMenu),
            keyEquivalent: ""
        )
        autoCollapseItem.target = self
        menu.addItem(autoCollapseItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit IconFold", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc private func toggleFromMenu() {
        expandCollapse()
    }
    
    @objc private func toggleAutoCollapseFromMenu() {
        toggleAutoCollapse()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
