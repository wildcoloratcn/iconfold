# CLAUDE.md — IconFold 开发指南

## 项目概述

**IconFold** — Mac菜单栏图标折叠器，解决MacBook Pro刘海遮挡图标的问题。

## 核心功能

1. 检测被遮挡的菜单栏图标
2. 显示折叠数字（+N）
3. 点击展开下拉菜单
4. 系统图标豁免

## 技术栈

- Swift + AppKit
- NSStatusItem 菜单栏App
- XcodeGen 生成项目

## 当前状态

✅ 已完成MVP：
- 菜单栏数字按钮
- 基本的图标折叠逻辑
- 下拉菜单展开App列表
- 系统图标豁免

⚠️ 待改进：
- 当前实现只是简单计算屏幕宽度，没有真正隐藏任何图标
- 需要使用Accessibility API或Menu Bar Extra来真正隐藏其他App的图标
- 这是概念验证，需要重新设计实现方式

## 实现方式讨论

### 方式1: 第三方菜单栏管理（不推荐）
- 无法真正控制其他App的图标

### 方式2: Accessibility API（需要权限）
- 可以获取菜单栏上所有图标的位置
- 需要用户授权辅助功能

### 方式3: MenuBar Extra（SwiftUI推荐）
- 可以在菜单栏添加自己的状态项
- 使用系统API显示/隐藏

### 方式4: 观察者模式
- 作为菜单栏App运行，检测新App的图标
- 通过某种方式隐藏（可能需要系统权限）

## 下一步

需要重新设计实现方式，可能需要：
1. 研究Bartender/Dozer是如何实现图标隐藏的
2. 使用更底层的macOS API
3. 考虑使用SwiftUI的MenuBarExtra

## 文件结构

```
IconFold/
├── project.yml           # XcodeGen配置
├── Sources/
│   ├── main.swift        # 入口
│   └── AppDelegate.swift  # 主逻辑
├── Resources/
│   ├── Info.plist
│   └── Assets.xcassets/
└── IconFold.xcodeproj/    # 生成的项目
```