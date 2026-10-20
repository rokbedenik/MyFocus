# My Focus

A small macOS app: an always-on-top window that shows what you are working on right now.
Several focuses, switching between them, time per focus, a "where did I leave off" note, a switch log,
an inactivity nudge and optional Do Not Disturb while a focus runs.

Swift + SwiftUI/AppKit, no Xcode. Edit in VS Code, build with a script.

Repo: https://github.com/rokbedenik/MyFocus

## Install (prebuilt)

A ready-to-run build is in the repo: [`release/MyFocus.zip`](release/MyFocus.zip) (Apple Silicon, macOS 14+).

1. Download and unzip; drag `MyFocus.app` into `/Applications`.
2. The app is ad-hoc signed (no Apple developer account), so on the first launch of a *downloaded* copy macOS
   will refuse it. Either right-click → Open → Open, or clear the quarantine flag once:
   ```sh
   xattr -dr com.apple.quarantine /Applications/MyFocus.app
   ```
3. Launch it from Spotlight or Launchpad as "My Focus". It lives in the menu bar (no Dock icon). For autostart,
   enable "Launch at login" in the menu bar menu.

## Build from source

Requirements: macOS 14+, Xcode Command Line Tools (`xcode-select --install`). No Xcode, no SwiftPM build.

```sh
scripts/build-app.sh            # release build -> dist/MyFocus.app
scripts/build-app.sh debug      # debug build (-Onone -g)
scripts/build-app.sh install    # build, replace /Applications/MyFocus.app, relaunch
scripts/build-app.sh release    # build + refresh release/MyFocus.zip
```

The script compiles `Sources/MyFocus/*.swift` with `swiftc`, assembles the `.app` bundle, copies the icon and
`Info.plist`, and ad-hoc signs it.

Note: the Command Line Tools currently ship SDK 27.0, which the bundled compiler cannot read (version mismatch).
The script therefore defaults to SDK 26.5. Once Apple fixes the CLT you can remove that part of
`scripts/build-app.sh` (or set `SDKROOT` yourself).

## Development workflow

1. Open the folder in VS Code with the **Swift** extension (swiftlang.swift-vscode); `Package.swift` is there so the
   extension gives you completion and inline errors.
2. Edit code under `Sources/MyFocus/`.
3. `scripts/build-app.sh install` – compiles, replaces the installed app and relaunches it. Compile errors are
   printed; nothing is replaced if the build fails.
4. When you want to ship the result: `scripts/build-app.sh release`, then commit `release/MyFocus.zip` with the code.

Optional VS Code task (`.vscode/tasks.json`) so ⌘⇧B does step 3:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build & install My Focus",
      "type": "shell",
      "command": "scripts/build-app.sh install",
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": []
    }
  ]
}
```

## Usage

- The window stays on top, on all Spaces, and never steals focus. Drag it by the handle (≡) in the header.
  Its height follows the number of focuses. The position is remembered across launches; the default is the
  bottom-left corner. Hide and show it with ⌃⌥F or from the menu bar.
- The header shows the state: a colored dot + "Working · 12 min", or a pause icon. The ⏸ button pauses, **+** adds
  a focus (type, Enter; Esc cancels). At most 3 focuses by default, configurable 1–50 in Settings.
- Each focus has its own color (assigned automatically, change it via right-click → Color).
- All focuses are always visible; click a row to switch, the active one has a tinted background.
- Hovering a row shows 💬 (note: where did I leave off), ✓ (done) and 🗑 (delete). The same actions are in the
  right-click menu. Delete/done can be undone from the menu bar.
- **Global shortcuts** (Settings → Shortcuts): show/hide window (default ⌃⌥F), new focus (off by default) and
  note on the active focus (off by default). Click the field, press the combination; ⌫ turns it off.
- **Inactivity nudge**: after N minutes on the same focus (default 45, 0 = off) the window border turns orange and asks
  "Still working on this?" with Yes / ⏸.
- **Idle dimming**: the window fades after N seconds without the mouse over it (default 10, 0 = never) and comes back
  on hover, on a switch, or when a nudge is due.
- **Do Not Disturb** (off by default): while a focus runs, DND is on; it goes off on pause, screen lock, sleep and
  quit. See below for the one-time setup.
- Locking the screen or sleeping pauses; unlocking resumes the last focus.
- **Log** (menu bar → Log …, ⌘L) opens a window with today's switches; the text is selectable and there is a Copy button.
- The menu bar item shows the current focus and offers switching, pause, undo (delete/done), log, settings, show/hide
  and launch at login.
- Language: English or Slovenian, in Settings (defaults to the system language).
- Data: `~/Library/Application Support/MyFocus/state.json`; settings in UserDefaults (`com.rbedenik.myfocus`).

### Do Not Disturb setup

macOS has no public API for Focus modes, so the app runs two shortcuts through the `shortcuts` command line tool.
Create them once in the **Shortcuts** app (Settings → Do Not Disturb → "Open Shortcuts"):

| Shortcut name (exact) | Action |
|---|---|
| `MyFocus DND On`  | Set Focus → Do Not Disturb → **On** (until turned off) |
| `MyFocus DND Off` | Set Focus → Do Not Disturb → **Off** |

Then enable "Turn on Do Not Disturb while a focus is running" in Settings. The first run may ask you to allow
My Focus to run shortcuts. Failures are logged to the system log (`log stream --predicate 'process == "MyFocus"'`).

## Layout

```
Package.swift                 SwiftPM manifest (for the VS Code Swift extension only)
Sources/MyFocus/
  main.swift                  entry point, AppDelegate, menu bar, hotkey, lock/sleep observers
  FloatingPanel.swift         NSPanel (floating, non-activating, auto-sized, position memory, idle dimming)
  PanelView.swift             SwiftUI content of the panel
  FocusStore.swift            state, switching, timing, undo, nudge, JSON persistence
  Model.swift                 Focus, SwitchEvent, AppState, color palette
  AppSettings.swift           settings (UserDefaults)
  SettingsView.swift          settings window
  LogWindow.swift             log window
  DoNotDisturb.swift          DND on/off via Shortcuts
  L10n.swift                  string table (en/sl)
  DragHandle.swift            window drag handle
  HotKey.swift                KeyShortcut model + HotKeyCenter (Carbon global shortcuts)
  ShortcutRecorder.swift      "press keys" control used in Settings
Resources/Info.plist          bundle metadata (LSUIElement = no Dock icon)
Resources/AppIcon.icns        app icon (generated, committed)
release/MyFocus.zip           prebuilt app (refresh with scripts/build-app.sh release)
scripts/build-app.sh          build + package .app + ad-hoc sign (+ install / release)
scripts/make-icon.swift       regenerates AppIcon.icns from the "scope" SF Symbol
```

## App icon

`Resources/AppIcon.icns` is generated and committed. To change it, edit `scripts/make-icon.swift` and run:

```sh
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk scripts/make-icon.swift -o /tmp/make-icon \
  && /tmp/make-icon Resources/AppIcon.icns
```

macOS caches icons aggressively; after replacing the app in `/Applications` you may need to run
`killall Finder Dock` or log out to see the new icon.

## Ideas for later

- Weekly report: time per focus, number of switches per day, longest uninterrupted stretch
- Keyboard switching: ⌃⌥1 … ⌃⌥5 jump straight to the n-th focus
- Pomodoro mode: optional 25/5 cycle on the active focus with the nudge bar as the break prompt
- Calendar awareness: when a calendar event starts, offer to switch to a focus with the event's title
- Export: today's/this week's log as CSV or Markdown for a timesheet
- Focus templates: recurring focuses (e.g. "Mail", "Standup") re-added with one click
- Interruption counter: a quick "I got interrupted" button that logs the moment without switching
- Multi-display: remember the position per display arrangement
- Sync `state.json` via iCloud Drive for use on a second Mac
