import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var detector: MenuBarDetector!
    
    // 检测结果缓存
    private var cachedHiddenItems: [MenuBarDetector.MenuBarItem] = []
    private var cachedAllItems: [MenuBarDetector.MenuBarItem] = []
    private var lastDetectionTime: Date?
    private let cacheValiditySeconds: TimeInterval = 2.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        detector = MenuBarDetector()
        
        // 检查辅助功能权限
        if !detector.hasAccessibilityPermission {
            // 首次启动，请求权限
            detector.requestAccessibilityPermission()
        }
        
        setupStatusItem()
        setupMenu()
        updateDetection()
        scheduleRefresh()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "..."
            button.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            button.imagePosition = .noImage
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.systemBlue.cgColor
            button.layer?.cornerRadius = 4
            button.contentTintColor = NSColor.white
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false
    }

    @objc private func statusItemClicked() {
        // 每次点击都刷新检测
        updateDetection()
        showMenu()
    }

    private func showMenu() {
        menu.removeAllItems()

        // Header
        let headerItem = NSMenuItem(title: "🔍 IconFold - 菜单栏图标检测", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // 权限状态
        if !detector.hasAccessibilityPermission {
            let permItem = NSMenuItem(title: "⚠️ 需要辅助功能权限", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
            
            let permDesc = NSMenuItem(title: "  点击此处授权后即可检测", action: nil, keyEquivalent: "")
            permDesc.isEnabled = false
            menu.addItem(permDesc)
            
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem.separator())

        // 被遮挡的图标
        let hiddenHeader = NSMenuItem(title: "被遮挡的图标 (\(cachedHiddenItems.count)):", action: nil, keyEquivalent: "")
        hiddenHeader.isEnabled = false
        menu.addItem(hiddenHeader)

        if cachedHiddenItems.isEmpty {
            let allGood = NSMenuItem(title: "  ✅ 没有图标被遮挡", action: nil, keyEquivalent: "")
            allGood.isEnabled = false
            menu.addItem(allGood)
        } else {
            for item in cachedHiddenItems {
                let menuItem = NSMenuItem(title: "  \(item.name ?? item.bundleId ?? "Unknown")", action: #selector(appClicked(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item
                if let name = item.name {
                    menuItem.toolTip = name
                }
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 所有检测到的图标
        let allHeader = NSMenuItem(title: "检测到的图标 (\(cachedAllItems.count)):", action: nil, keyEquivalent: "")
        allHeader.isEnabled = false
        menu.addItem(allHeader)

        if cachedAllItems.isEmpty && detector.hasAccessibilityPermission {
            let noDetect = NSMenuItem(title: "  未能检测到图标（可能需要刷新）", action: nil, keyEquivalent: "")
            noDetect.isEnabled = false
            menu.addItem(noDetect)
        } else {
            for item in cachedAllItems {
                let menuItem = NSMenuItem(title: "  \(item.name ?? item.bundleId ?? "Unknown")", action: nil, keyEquivalent: "")
                menuItem.isEnabled = false
                if let bundleId = item.bundleId {
                    menuItem.toolTip = bundleId
                }
                // 标记被遮挡的
                if cachedHiddenItems.contains(where: { $0.id == item.id }) {
                    menuItem.title = "  ⚠️ " + (item.name ?? item.bundleId ?? "Unknown")
                }
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 操作
        let refreshItem = NSMenuItem(title: "🔄 刷新检测", action: #selector(refreshDetection), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "❌ 退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func openAccessibilitySettings() {
        // 打开系统辅助功能设置
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func appClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarDetector.MenuBarItem else { return }
        
        // 尝试激活对应的应用
        if let bundleId = item.bundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc private func refreshDetection() {
        updateDetection()
        showMenu()
    }

    private func updateDetection() {
        // 缓存有效性检查
        if let lastTime = lastDetectionTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds,
           !cachedHiddenItems.isEmpty || !cachedAllItems.isEmpty {
            return
        }
        
        // 使用检测器
        if let result = detector.detect() {
            cachedHiddenItems = result.hiddenItems
            cachedAllItems = result.allItems
            lastDetectionTime = Date()
        }
        
        updateStatusItemButton()
    }
    
    private func updateStatusItemButton() {
        guard let button = statusItem.button else { return }
        
        let hiddenCount = cachedHiddenItems.count
        let hasPermission = detector.hasAccessibilityPermission
        
        if !hasPermission {
            button.title = "⚠️"
            button.layer?.backgroundColor = NSColor.systemOrange.cgColor
        } else if hiddenCount > 0 {
            button.title = "\(hiddenCount)"
            button.layer?.backgroundColor = NSColor.systemRed.cgColor
        } else {
            button.title = "✓"
            button.layer?.backgroundColor = NSColor.systemGreen.cgColor
        }
    }

    private func scheduleRefresh() {
        // 每 5 秒刷新一次检测
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateDetection()
        }
        
        // 当屏幕配置改变时也刷新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersChanged() {
        lastDetectionTime = nil  // 强制刷新
        updateDetection()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}