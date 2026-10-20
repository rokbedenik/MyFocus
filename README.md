# My Focus

A small macOS app: an always-on-top window in the top-right corner that shows what you are working on right now.
Several focuses, switching between them, time per focus, a "where did I leave off" note, a switch log and
an inactivity nudge.

Swift + SwiftUI/AppKit, no Xcode. Edit in VS Code, build with a script.

Repo: https://github.com/rokbedenik/MyFocus

## Requirements

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)
- VS Code with the **Swift** extension (swiftlang.swift-vscode) for syntax, completion and inline errors

## Build and run

```sh
scripts/build-app.sh          # release build -> dist/MyFocus.app
open dist/MyFocus.app
```

For a quick dev cycle: `scripts/build-app.sh debug`.

Note: the Command Line Tools currently ship SDK 27.0, which the bundled compiler cannot read (version mismatch).
The build script therefore defaults to SDK 26.5. Once Apple fixes the CLT you can remove that part of
`scripts/build-app.sh`.

## Usage

- The window stays on top, on all Spaces, and never steals focus. Drag it by the handle (≡) in the header.
  Its height follows the number of focuses. Hide and show it with ⌃⌥F or from the menu bar.
- **+** adds a focus (type, Enter; Esc cancels). At most 3 focuses by default, configurable 1–50 in Settings.
- Each focus has its own color (assigned automatically, change it via right-click → Color).
- All focuses are always visible; click a row to switch, the active one has a tinted background.
- Hovering a row shows ✓ (done) and 🗑 (delete). The same actions plus the "where did I leave off" note are in the
  right-click menu.
- **Inactivity nudge**: after N minutes on the same focus (default 45, 0 = off) the window border turns orange and asks
  "Still working on this?" with Yes / Pause.
- Locking the screen or sleeping pauses; unlocking resumes the last focus.
- **Log** shows today's switches with timestamps; the text is selectable and there is a Copy button.
- The menu bar item shows the current focus and offers switching, pause, undo (delete/done), settings, show/hide
  and launch at login.
- Language: English or Slovenian, in Settings (defaults to the system language).
- Data: `~/Library/Application Support/MyFocus/state.json`; settings in UserDefaults (`com.rbedenik.myfocus`).

## Layout

```
Package.swift                 SwiftPM manifest
Sources/MyFocus/
  main.swift                  entry point, AppDelegate, menu bar, hotkey, lock/sleep observers
  FloatingPanel.swift         NSPanel (floating, non-activating, auto-sized to content)
  PanelView.swift             SwiftUI content of the panel
  FocusStore.swift            state, switching, timing, undo, nudge, JSON persistence
  Model.swift                 Focus, SwitchEvent, AppState, color palette
  AppSettings.swift           settings (UserDefaults)
  SettingsView.swift          settings window
  L10n.swift                  string table (en/sl)
  DragHandle.swift            window drag handle
  HotKey.swift                global shortcut (Carbon)
Resources/Info.plist          bundle metadata (LSUIElement = no Dock icon)
scripts/build-app.sh          build + package .app + ad-hoc sign
```

## Ideas for later

- Weekly time report per focus
- Dim the window when idle
- App icon
