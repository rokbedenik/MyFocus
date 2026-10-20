# My Focus

Majhna macOS aplikacija: always-on-top okence v zgornjem desnem kotu, ki kaže, na čem trenutno delaš.
Več fokusov, preklapljanje med njimi, čas na fokus, opomba "kje sem ostal" in dnevnik preklopov.

Swift + SwiftUI/AppKit, brez Xcoda. Pišeš v VS Code, gradiš s skripto.

Repo: https://github.com/rokbedenik/MyFocus

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

- Okno je vedno na vrhu, na vseh Spaces, ne krade fokusa. Premikaš ga z vlečenjem za ročaj (≡) v glavi.
  Višina se samodejno prilagodi številu fokusov. Skriješ in pokažeš ga z ⌃⌥F ali prek menu bara.
- **+** doda nov fokus (vpiši in Enter, Esc prekliče). Privzeto največ 3 fokusi hkrati, nastavljivo 1–50 v Nastavitvah.
- Vsak fokus ima svojo barvo (samodejno dodeljena, zamenjaš jo z desnim klikom → Barva).
- Vsi fokusi so vedno vidni; klik na vrstico preklopi, aktivni ima obarvano podlago.
- Prehod z miško čez vrstico pokaže gumba ✓ (končano) in 🗑 (izbriši). Isto in opomba "kje sem ostal" je v meniju na desni klik.
- Zaklep zaslona ali spanje sproži pavzo; ob odklepu se zadnji fokus samodejno nadaljuje.
- **⌃⌥F** skrije/pokaže okno.
- Ikona v menu baru kaže trenutni fokus in omogoča preklop, pavzo, razveljavitev izbrisa, nastavitve, skrivanje okna in zagon ob prijavi.
- Podatki: `~/Library/Application Support/MyFocus/state.json`, nastavitve v UserDefaults (`com.rbedenik.myfocus`).

## Struktura

```
Package.swift                 SwiftPM manifest
Sources/MyFocus/
  main.swift                  zagon, AppDelegate, menu bar, hotkey
  FloatingPanel.swift         NSPanel (floating, non-activating)
  PanelView.swift             SwiftUI vsebina okna
  FocusStore.swift            stanje, preklopi, čas, JSON persistenca
  Model.swift                 Focus, SwitchEvent, AppState, barvna paleta
  AppSettings.swift           nastavitve (UserDefaults)
  SettingsView.swift          okno z nastavitvami
  DragHandle.swift            ročaj za premikanje okna
  HotKey.swift                globalna bližnjica (Carbon)
Resources/Info.plist          bundle metadata (LSUIElement = brez Dock ikone)
scripts/build-app.sh          build + pakiranje .app + ad-hoc podpis
```

## Ideje za naprej

- Nudge po X min brez spremembe fokusa (utrip roba okna)
- Tedenski pregled časa po fokusih
- Pomodoro
