# IconFold

A lightweight macOS menu bar utility with a single button that **folds all icons to its right** — click to hide, click again to show.

## What It Does

```
[→ 3] | [🔔] [📧] [💬] ...
 ↑
 fold button (shows hidden count)
```

IconFold places a single fold button in your menu bar. Position it to the left of the icons you want to hide (CMD+drag), then click to toggle.

- **Click to fold** — hides all icons to the right (pushes them off-screen)
- **Click to unfold** — reveals them again
- **Shows hidden count** — displays a badge with the estimated number of hidden icons
- **Auto-hide** — automatically folds when you click outside the menu bar

## Usage

1. Launch IconFold — a button `→` appears in the menu bar
2. **CMD+drag** it to the left of the icons you want to hide
3. Click `→ 3` to fold (hides icons, shows `← N` with count)
4. Click `←` to unfold

### Click Actions

| Action | Result |
|--------|--------|
| Left click | Toggle fold/unfold |
| Right click | Show context menu |

### Context Menu

- **Show Icons / Hide Icons** — toggle manually
- **Auto-hide Enabled / Disabled** — auto-collapse when clicking outside menu bar
- **Quit IconFold**

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

## How It Works

IconFold uses a single `NSStatusItem` with `variableLength`:

- **Folded**: `length = screenWidth + 500` — occupies the full width, pushing all other icons off the right edge of the screen
- **Expanded**: `length = NSStatusItem.variableLength` — system calculates natural width, all icons visible

`autosaveName` lets the system remember the item's position across restarts.

## Requirements

- macOS 12.0 (Monterey) or later
- No special permissions required

## Tech Stack

- Swift + AppKit
- NSStatusItem with `variableLength`
- NSEvent global monitor for auto-collapse
- XcodeGen for project generation
