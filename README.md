# IconFold

A lightweight macOS menu bar utility that **folds** menu bar icons to the right of a divider — inspired by [Hidden Bar](https://github.com/dwarvesf/hidden).

## What It Does

IconFold adds a divider and a collapse/expand button to your menu bar. Position them to the left of the icons you want to hide, then click the button to fold them away from the notch or Dynamic Island.

```
[📍] [→] | [🔔] [📧] [💬] ...
           ↑ divider + fold button
```

- **Fold/Unfold**: Click the arrow button to hide/show icons to its right
- **Drag to position**: CMD+drag to reorder; position is remembered
- **Auto-collapse**: Folds automatically when you click outside the menu bar
- **System icons protected**: The divider sits between your icons; system icons on the far right stay visible

## Usage

1. Launch IconFold — two items appear in your menu bar: a divider (`|||`) and a fold button (`→`)
2. **CMD+drag** both items to the left of the icons you want to hide
3. Click the `→` button to fold (hide) icons to its right
4. Click `←` to unfold

### Click Actions

| Action | Result |
|--------|--------|
| Left click | Toggle fold/unfold |
| Right click | Show context menu |
| Option + left click | Toggle auto-collapse |

### Context Menu

- **Toggle Fold** — manually fold/unfold
- **Auto Collapse** (checkmark on/off) — auto-collapse when clicking outside menu bar
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

IconFold uses the same technique as Hidden Bar:

1. Two `NSStatusItem` objects with `variableLength` are inserted into the menu bar
2. The **divider** (`btnSeparate`) has length `1pt` normally and `2000+pt` when collapsed
3. When collapsed, the divider occupies all space to the right, effectively pushing all icons off-screen
4. `autosaveName` lets the system remember the items' positions across restarts

## Requirements

- macOS 12.0 (Monterey) or later
- No special permissions required (unlike the detection-only approach)

## Tech Stack

- Swift + AppKit
- NSStatusItem with `variableLength`
- NSEvent global monitor for auto-collapse
- XcodeGen for project generation

## See Also

- [Hidden Bar](https://github.com/dwarvesf/hidden) — the original, more full-featured implementation
- [Bartender](https://www.macbartender.com) — commercial menu bar icon organizer
- [Dozer](https://github.com/MortenGregersen/Dozer) — another open-source alternative
