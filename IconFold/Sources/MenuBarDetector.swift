import AppKit
import ApplicationServices

/// 检测被刘海/灵动岛遮挡的菜单栏图标
/// 使用 Accessibility API 获取菜单栏图标位置信息
class MenuBarDetector {
    
    // MARK: - Types
    
    struct MenuBarItem: Identifiable {
        let id = UUID()
        let element: AXUIElement
        let position: CGPoint
        let size: CGSize
        let bundleId: String?
        let name: String?
        
        var frame: CGRect {
            CGRect(origin: position, size: size)
        }
    }
    
    struct DetectionResult {
        let hiddenItems: [MenuBarItem]
        let allItems: [MenuBarItem]
        let notchRegion: CGRect
        let availableRegion: CGRect
    }
    
    // MARK: - System App Bundle IDs (not considered "hidden")
    
    private let systemAppBundleIds: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.SystemUIServer",
        "com.apple.dock",
        "com.apple.menuextra.bluetooth",
        "com.apple.menuextra.battery",
        "com.apple.menuextra.wifi",
        "com.apple.menuextra.volume",
        "com.apple.menuextra.clock",
        "com.apple.Spotlight",
        "com.apple.Siri",
        "com.apple.keyboardui.KeyboardViewer",
        "com.apple.menuextra.notificationcenter",
        "com.apple.menuextra.focus",
    ]
    
    // MARK: - Public Methods
    
    /// 检测菜单栏图标是否被遮挡
    /// - Returns: 检测结果，包含被遮挡的图标列表
    func detect() -> DetectionResult? {
        guard let systemUIServer = findSystemUIServer() else {
            print("IconFold: Cannot find SystemUIServer")
            return nil
        }
        
        let menuBarItems = getMenuBarItems(from: systemUIServer)
        let notchRegion = getNotchRegion()
        let availableRegion = getAvailableMenuBarRegion()
        
        // 过滤掉系统图标，计算哪些被遮挡
        let hiddenItems = menuBarItems.filter { item in
            // 跳过系统图标
            if let bundleId = item.bundleId, systemAppBundleIds.contains(bundleId) {
                return false
            }
            // 检查是否在刘海区域内或之外
            return isItemHidden(item, notchRegion: notchRegion, availableRegion: availableRegion)
        }
        
        return DetectionResult(
            hiddenItems: hiddenItems,
            allItems: menuBarItems,
            notchRegion: notchRegion,
            availableRegion: availableRegion
        )
    }
    
    /// 检查辅助功能权限是否已获取
    var hasAccessibilityPermission: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// 请求辅助功能权限（会触发系统弹窗）
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Private Methods
    
    /// 查找 SystemUIServer 进程
    private func findSystemUIServer() -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let uiServer = runningApps.first(where: { $0.bundleIdentifier == "com.apple.SystemUIServer" }) else {
            return nil
        }
        
        return AXUIElementCreateApplication(uiServer.processIdentifier)
    }
    
    /// 从 SystemUIServer 获取菜单栏图标列表
    private func getMenuBarItems(from appElement: AXUIElement) -> [MenuBarItem] {
        var items: [MenuBarItem] = []
        
        // 获取菜单栏
        guard let menuBar = getMenuBar(from: appElement) else {
            return items
        }
        
        // 获取菜单栏下的所有元素
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef)
        
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return items
        }
        
        for child in children {
            if let item = createMenuBarItem(from: child) {
                items.append(item)
            }
        }
        
        return items
    }
    
    /// 获取菜单栏
    private func getMenuBar(from appElement: AXUIElement) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef)
        
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        // 遍历查找 MenuBar
        for child in children {
            if let role = getStringAttribute(child, attribute: kAXRoleAttribute), role == "AXMenuBar" {
                return child
            }
            
            // 递归查找子元素
            if let found = findMenuBarRecursively(in: child) {
                return found
            }
        }
        
        return nil
    }
    
    private func findMenuBarRecursively(in element: AXUIElement) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        for child in children {
            if let role = getStringAttribute(child, attribute: kAXRoleAttribute), role == "AXMenuBar" {
                return child
            }
            if let found = findMenuBarRecursively(in: child) {
                return found
            }
        }
        
        return nil
    }
    
    /// 从 AXUIElement 创建 MenuBarItem
    private func createMenuBarItem(from element: AXUIElement) -> MenuBarItem? {
        // 获取位置
        var positionRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        
        var position = CGPoint.zero
        if posResult == .success, let posValue = positionRef {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        }
        
        // 获取大小
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        var size = CGSize.zero
        if sizeResult == .success, let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }
        
        // 获取名称
        let name = getStringAttribute(element, attribute: kAXTitleAttribute)
            ?? getStringAttribute(element, attribute: kAXDescriptionAttribute)
            ?? getStringAttribute(element, attribute: kAXValueAttribute)
        
        // 尝试获取 bundleId（通过父级进程信息推断）
        let bundleId = getBundleIdFromElement(element)
        
        // 过滤掉很小的分隔符等非图标元素
        if size.width < 5 || size.height < 5 {
            return nil
        }
        
        return MenuBarItem(
            element: element,
            position: position,
            size: size,
            bundleId: bundleId,
            name: name
        )
    }
    
    /// 从元素尝试获取 bundle ID（通过 pid 关联）
    private func getBundleIdFromElement(_ element: AXUIElement) -> String? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        
        guard pid != 0 else { return nil }
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            return app.bundleIdentifier
        }
        
        return nil
    }
    
    /// 获取刘海区域
    private func getNotchRegion() -> CGRect {
        guard let screen = NSScreen.main else {
            return .zero
        }
        
        // MacBook Pro 刘海区域通常是 (0, 0) 到 (screenWidth/2, menuBarHeight)
        // 实际上刘海在屏幕顶部中央
        let screenFrame = screen.frame
        let menuBarHeight: CGFloat = 25 // 菜单栏高度
        
        // 检测是否有刘海（通过 visibleFrame 的 origin 来判断）
        let visibleFrame = screen.visibleFrame
        
        // 如果 visibleFrame.origin.y > 0，说明有刘海
        let notchStart = visibleFrame.origin.x
        let notchEnd = screenFrame.width - visibleFrame.width - visibleFrame.origin.x
        
        if visibleFrame.origin.y > 0 || notchStart > 0 || notchEnd > 0 {
            // 有刘海/灵动岛
            return CGRect(
                x: notchStart,
                y: screenFrame.height - menuBarHeight,
                width: screenFrame.width - notchStart - notchEnd,
                height: menuBarHeight
            )
        }
        
        // 无刘海的情况（刘海区域为空）
        return .zero
    }
    
    /// 获取可用的菜单栏区域（不包含刘海）
    private func getAvailableMenuBarRegion() -> CGRect {
        guard let screen = NSScreen.main else {
            return .zero
        }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight: CGFloat = 25
        
        // 计算右侧系统区域（时钟等）的起始位置
        // 系统区域通常占约 200-300 像素
        let rightSystemRegionWidth: CGFloat = 250
        let rightEdge = screenFrame.width - rightSystemRegionWidth
        
        return CGRect(
            x: visibleFrame.origin.x,
            y: screenFrame.height - menuBarHeight,
            width: rightEdge - visibleFrame.origin.x,
            height: menuBarHeight
        )
    }
    
    /// 判断图标是否被遮挡
    private func isItemHidden(_ item: MenuBarItem, notchRegion: CGRect, availableRegion: CGRect) -> Bool {
        let itemCenterX = item.position.x + item.size.width / 2
        let itemCenterY = item.position.y + item.size.height / 2
        
        // 检查是否在刘海区域内
        if notchRegion != .zero && notchRegion.contains(CGPoint(x: itemCenterX, y: itemCenterY)) {
            return true
        }
        
        // 检查是否在可用区域左侧（被刘海挡住）
        if item.position.x < availableRegion.origin.x {
            return true
        }
        
        // 检查是否在可用区域右侧之外
        if item.position.x + item.size.width > availableRegion.origin.x + availableRegion.width {
            return true
        }
        
        return false
    }
    
    // MARK: - Helper
    
    private func getStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        
        guard result == .success, let value = valueRef as? String, !value.isEmpty else {
            return nil
        }
        
        return value
    }
}