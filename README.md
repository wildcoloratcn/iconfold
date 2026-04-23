# IconFold

Mac菜单栏图标折叠器 — 把被遮挡的图标折叠成一个数字，点击展开。

## 功能

- **自动检测**被MacBook Pro刘海遮挡的菜单栏图标
- **折叠显示**为一个数字按钮（如 "+3"）
- **点击展开**下拉菜单，显示所有被折叠的App
- **系统图标豁免**：日期、时间、电池、无线网、蓝牙、音量等永远不被折叠

## 技术

- Swift + AppKit
- NSStatusItem 菜单栏App
- 菜单栏UI元素（无窗口）

## 构建

```bash
cd IconFold
xcodegen generate
xcodebuild -project IconFold.xcodeproj -scheme IconFold -configuration Debug build
```

## 运行

构建完成后，App位于:
```
IconFold.app/Contents/MacOS/IconFold
```

或者直接运行:
```bash
open IconFold.app
```

## 定价

- **免费版**：限制最多折叠5个图标
- **Pro版**：$5买断，无限制

## 参考

- [RunningCat](https://runningcat.app) — 类似风格的菜单栏小工具