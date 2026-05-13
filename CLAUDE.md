# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

A macOS menu-bar teleprompter ("Telesouffleur" — user-facing name; bundle id `org.Tele-Prompter`). It paints a small overlay panel pinned under the MacBook notch that auto-scrolls a script while you look at the camera. The overlay is hidden from screen capture by default so it doesn't show up in QuickTime, screen sharing, or screenshots.

- Single Xcode project, Swift 5, SwiftUI + AppKit interop, macOS deployment target **15.6**.
- No package dependencies.

## Build, run, test

Use `xcodebuild` from the repo root. The scheme name contains a space — quote it.

```bash
# Build the app
xcodebuild -project "Tele Prompter.xcodeproj" -scheme "Tele Prompter" -configuration Debug build

# Run the unit tests (Tele PrompterTests target, Swift Testing framework)
xcodebuild -project "Tele Prompter.xcodeproj" -scheme "Tele Prompter" \
  -destination 'platform=macOS' test

# Run a single Swift Testing test by name
xcodebuild -project "Tele Prompter.xcodeproj" -scheme "Tele Prompter" \
  -destination 'platform=macOS' test \
  -only-testing:"Tele PrompterTests/Tele_PrompterTests/example"

# Launch the app after build (Debug build path)
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/"Tele Prompter.app"
```

The `Tele PrompterTests` target uses **Swift Testing** (`import Testing`, `@Test`), not XCTest. UI tests in `Tele PrompterUITests` use XCTest.

## Architecture

The app has no `ContentView` / SwiftUI `WindowGroup` — `Tele_PrompterApp.swift` only declares an `NSApplicationDelegateAdaptor`. **All UI is constructed by `AppDelegate`.** Read [AppDelegate.swift](Tele%20Prompter/AppDelegate.swift) first when orienting.

### Core wiring (set up in `applicationDidFinishLaunching`)

1. **`PrompterController`** ([Prompter/PrompterController.swift](Tele%20Prompter/Prompter/PrompterController.swift)) — `@Observable` singleton, single source of truth for every persisted setting and runtime UI state (script, fonts, colors, speed, panel size, lock state, scroll offset, play state). Every persisted property has a `didSet` that writes through to `UserDefaults` via the [Defaults](Tele%20Prompter/Settings/SettingsStore.swift) helper. There is no separate "store" layer — mutate the controller and persistence happens automatically.
2. **`PrompterPanel`** ([Prompter/PrompterPanel.swift](Tele%20Prompter/Prompter/PrompterPanel.swift)) — borderless `NSPanel` at `.statusBar` level, joins all spaces, hosts a SwiftUI `PrompterView`. `sharingType = .none` is the privacy guarantee that excludes the panel from screen recording; flipping `controller.debugCaptureVisible` switches it to `.readOnly` so screenshots of the prompter become possible.
3. **`HotKeyMonitor`** ([HotKeys/HotKeyMonitor.swift](Tele%20Prompter/HotKeys/HotKeyMonitor.swift)) — fixed v1 hotkey set on `⌥⌘` (Space, ↑/↓, ←/→, H, L). Uses `NSEvent.addGlobalMonitorForEvents` (needs Input Monitoring) with a local-monitor fallback that fires only when a Telesouffleur window is key. `AXIsProcessTrusted()` is used as a proxy permission check.
4. **`StatusBarItem`** ([StatusBar/StatusBarItem.swift](Tele%20Prompter/StatusBar/StatusBarItem.swift)) — `NSStatusBar` menu (Show/Hide, Play/Pause, Lock, Settings, Quit). Rebuilds on `menuWillOpen` so titles reflect current controller state.
5. **`SettingsWindowController`** ([Settings/SettingsWindow.swift](Tele%20Prompter/Settings/SettingsWindow.swift)) — AppKit window hosting a SwiftUI `SettingsView`. Bindings write directly into the controller. Auto-opens on first launch (gated by `telesouffleur.hasLaunched` in `UserDefaults`).

### State propagation

SwiftUI views observe the `@Observable` controller normally. The AppKit-side panel can't, so `AppDelegate.observePanelState()` uses a self-rearming `withObservationTracking` block to call `panel.applyControllerState()` whenever `panelWidth/Height`, `isLocked`, `isVisible`, or `debugCaptureVisible` change. **If you add a new controller property that affects the `NSPanel` itself (frame, sharingType, ignoresMouseEvents, ordering), add it to that tracking block.**

### Notch geometry

The panel is sized and centered under the camera notch via [`NotchGeometry`](Tele%20Prompter/Settings/SettingsStore.swift) (uses `NSScreen.safeAreaInsets.top` and `auxiliaryTopLeft/RightArea`). The visible body is drawn by [`NotchExtendedShape`](Tele%20Prompter/Prompter/NotchShape.swift), which slides up `topOverlap` points into the notch to hide the seam and rounds only the bottom-left/bottom-right corners. Notch height is `safeAreaInsets.top` and is 0 on notch-less screens — code paths must handle both.

### Scrolling

[`ScrollingTextView`](Tele%20Prompter/Prompter/ScrollingTextView.swift) is an `NSViewRepresentable` wrapping `NSScrollView` + `NSTextView`. A 60Hz `Timer` advances `controller.scrollOffset` by `speed * dt` while `isPlaying`. Manual scroll posts `boundsDidChange` notifications that sync the offset back to the controller — `suppressBoundsObserver` prevents feedback loops when applying offsets programmatically. `scrollResetToken` is a monotonically incremented sentinel used to force a re-apply (reset to start / skip to end).

### UserDefaults migrations

`PrompterController.runMigrations()` is the one place to add idempotent UserDefaults migrations. Each migration is gated by its own `telesouffleur.migration.<name>.vN` key. Don't reuse keys.

## Conventions specific to this codebase

- All UI mutation goes through `PrompterController`. Don't read or write `UserDefaults` directly from views — go through the controller (which uses `Defaults` + `DefaultsKey`).
- Colors are persisted as `ColorRGBA` (Codable, sRGB) and bridged into both `NSColor` and SwiftUI `Color`. New color settings should follow the same pattern.
- The product directory is named `Tele Prompter` (with a space), so paths must be quoted in shell commands. The user-facing brand string is **Telesouffleur** — keep that in UI/copy strings even though the bundle/target is `Tele Prompter`.
- `@MainActor` is used liberally on AppKit-bridge classes (`AppDelegate`, `HotKeyMonitor`, `StatusBarItem`, `SettingsWindowController`, the scrolling coordinator). Preserve isolation; the timer in `ScrollingTextView` uses `MainActor.assumeIsolated` from the `Timer` callback.
