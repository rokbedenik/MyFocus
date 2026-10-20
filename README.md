# My Focus

Majhna macOS aplikacija: always-on-top okence v zgornjem desnem kotu, ki kaže, na čem trenutno delaš.
Več fokusov, preklapljanje med njimi, čas na fokus, opomba "kje sem ostal" in dnevnik preklopov.

Swift + SwiftUI/AppKit, brez Xcoda. Pišeš v VS Code, gradiš s skripto.

## Zahteve

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`), kar že imaš
- VS Code z razširitvijo **Swift** (swiftlang.swift-vscode) za syntax, autocomplete in napake v urejevalniku

## Build in zagon

```sh
scripts/build-app.sh          # release build -> dist/MyFocus.app
open dist/MyFocus.app
```

Za hiter razvojni cikel: `scripts/build-app.sh debug`.

Opomba: CLT trenutno vsebujejo SDK 27.0, ki ga prevajalnik ne zna brati (neskladje verzij). Skripta zato
privzeto uporabi SDK 26.5. Ko Apple popravi CLT, lahko ta del v `scripts/build-app.sh` odstraniš.

## Uporaba

- Okno je vedno na vrhu, na vseh Spaces, ne krade fokusa. Premikaš ga z vlečenjem ozadja.
- Puščica (ali klik v okno) razširi seznam: vpiši nov fokus in pritisni Enter, klik na vrstico preklopi.
- Desni klik na fokus: opomba "kje sem ostal", označi kot končano, izbriši.
- **⌃⌥F** skrije/pokaže okno.
- Ikona v menu baru kaže trenutni fokus in omogoča preklop, pavzo in zagon ob prijavi.
- Podatki: `~/Library/Application Support/MyFocus/state.json`.

## Struktura

```
Package.swift                 SwiftPM manifest
Sources/MyFocus/
  main.swift                  zagon, AppDelegate, menu bar, hotkey
  FloatingPanel.swift         NSPanel (floating, non-activating)
  PanelView.swift             SwiftUI vsebina okna
  FocusStore.swift            stanje, preklopi, čas, JSON persistenca
  Model.swift                 Focus, SwitchEvent, AppState
  HotKey.swift                globalna bližnjica (Carbon)
Resources/Info.plist          bundle metadata (LSUIElement = brez Dock ikone)
scripts/build-app.sh          build + pakiranje .app + ad-hoc podpis
```

## Ideje za naprej

- Nudge po X min brez spremembe fokusa (utrip roba okna)
- Tedenski pregled časa po fokusih
- Pomodoro
