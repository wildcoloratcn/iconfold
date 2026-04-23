# IconFold

A lightweight macOS menu bar utility that **detects** which icons are blocked by the MacBook Pro notch or Dynamic Island.

## What It Does

IconFold uses the macOS Accessibility API to detect menu bar icon positions and identify which icons fall within the notch region. It displays a count in your menu bar so you know at a glance if any icons are being hidden.

- **Detects** blocked menu bar icons using Accessibility API
- **Status bar indicator** shows count of hidden icons (red) or "OK" (green)
- **Click to expand** — see which apps' icons are in the blocked zone
- **System icons exempt** — Control Center, Clock, Battery, WiFi, Bluetooth, Volume, etc. are never flagged

## Requirements

- macOS 12.0 (Monterey) or later
- **Accessibility permission** — required for detecting menu bar icon positions

On first launch, the app will prompt you to grant Accessibility access in **System Settings → Privacy & Security → Accessibility**.

## Build

```bash
cd IconFold
xcodegen generate
xcodebuild -project IconFold.xcodeproj -scheme IconFold -configuration Debug build
```

The built app will be in:
```
~/Library/Developer/Xcode/DerivedData/IconFold-*/Build/Products/Debug/IconFold.app
```

## Usage

1. Launch IconFold — it appears as a small indicator in your menu bar
2. Grant Accessibility permission when prompted
3. The menu bar shows:
   - A **red number** — count of icons detected in the notch/Dynamic Island region
   - A **green checkmark** — no icons blocked
   - An **orange warning** — needs permission
4. Click the indicator to see the list of affected apps

## Limitations

- **Detection, not hiding** — this app detects and reports which icons may be blocked, but cannot actually hide them. For true hiding behavior, see [Hidden Bar](https://github.com/dwarvesf/hidden).
- Accessibility API access is required and cannot be bypassed
- Detection is approximate — the notch region is estimated based on screen geometry

## Tech Stack

- Swift + AppKit
- NSStatusItem (LSUIElement — no dock icon)
- Accessibility API (ApplicationServices.framework)
- XcodeGen for project generation
