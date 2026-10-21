import Foundation

enum Language: String, CaseIterable, Identifiable {
    case en, sl
    var id: String { rawValue }

    var label: String {
        switch self {
        case .en: return "English"
        case .sl: return "Slovenscina"
        }
    }

    // Slovenian if the system prefers it, English otherwise
    static var system: Language {
        Locale.preferredLanguages.first?.hasPrefix("sl") == true ? .sl : .en
    }
}

// Minimal string table. Keys are the English strings; Slovenian is looked up.
enum L {
    nonisolated(unsafe) static var current: Language = .system

    static func t(_ key: String) -> String {
        current == .en ? key : (sl[key] ?? key)
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static let sl: [String: String] = [
        // Panel
        "Working": "Delam",
        "Paused": "Pavza",
        "Click + and type what you are working on.": "Klikni + in vpiši, na čem delaš.",
        "New focus ...": "Nov fokus ...",
        "Drag to move the window, right-click for the menu": "Povleci za premik okna, desni klik za meni",
        "Add focus": "Dodaj fokus",
        "At most %d focuses; finish or delete one": "Največ %d fokusov; enega zaključi ali izbriši",
        "Log": "Dnevnik",
        "Pause": "Pavza",
        "Today: %d switches": "Danes: %d preklopov",
        "Copy": "Kopiraj",
        "Copy today's log to the clipboard": "Kopiraj cel dnevnik na odložišče",
        "Back": "Nazaj",
        "No switches yet today.": "Danes še ni preklopov.",
        "Done (removes from the list, time stays in the log)": "Končano (umakne s seznama, čas ostane v dnevniku)",
        "Delete": "Izbriši",
        "Where did I leave off?": "Kje sem ostal?",
        "Note: where did I leave off ...": "Opomba: kje sem ostal ...",
        "Color": "Barva",
        "Rename …": "Preimenuj …",
        "Save as template": "Shrani kot predlogo",
        "Templates": "Predloge",
        "New from template": "Nov iz predloge",
        "Template": "Predloga",
        "Recently finished; × removes it from the suggestions": "Nedavno zaključen; × ga odstrani iz predlogov",
        "Do not suggest again": "Ne predlagaj več",
        "New template": "Nova predloga",
        "Add template": "Dodaj predlogo",
        "Reusable focuses: one click creates a focus with that name and color, or switches to it if it is already open. They show up as chips when you press + and in the menu under \"New from template\".":
            "Ponovno uporabni fokusi: en klik ustvari fokus s tem imenom in barvo ali preklopi nanj, če je že odprt. Prikažejo se kot gumbki ob pritisku na + in v meniju pod \"Nov iz predloge\".",
        "Double-click to rename": "Dvojni klik za preimenovanje",
        "Done": "Končano",
        "Still working on this?": "Še vedno delaš na tem?",
        "Yes": "Da",
        // Log labels (stored in the log at write time)
        "(paused)": "(pavza)",
        "(locked)": "(zaklenjeno)",
        "deleted \"%@\"": "izbris \"%@\"",
        "finished \"%@\"": "koncano \"%@\"",
        // Colors
        "Green": "Zelena", "Blue": "Modra", "Orange": "Oranžna", "Pink": "Roza",
        "Purple": "Vijolična", "Teal": "Turkizna", "Yellow": "Rumena", "Red": "Rdeča",
        // Menu bar
        "Undo": "Razveljavi",
        "Undo: %@": "Razveljavi: %@",
        "Launch at login": "Zaženi ob prijavi",
        "Settings …": "Nastavitve …",
        "Quit MyFocus": "Zapri MyFocus",
        // Settings
        "MyFocus – Settings": "MyFocus – nastavitve",
        "Focuses": "Fokusi",
        "Maximum focuses at once": "Največ fokusov hkrati",
        "Allowed %d–%d. If the limit is below the number of open focuses, existing ones stay but you cannot add new ones.":
            "Dovoljeno %d–%d. Če je omejitev manjša od števila odprtih fokusov, obstoječi ostanejo, novih pa ne moreš dodati.",
        "Inactivity nudge": "Opozorilo po neaktivnosti",
        "Ask \"still on this?\" after": "Vprašaj \"še vedno na tem?\" po",
        "minutes (0 = off)": "minutah (0 = izklopljeno)",
        "Language": "Jezik",
        "Window": "Okno",
        "Show only the active focus until the window is clicked": "Pokaži samo aktivni fokus, dokler okna ne klikneš",
        "A click on the row or the chevron shows all focuses; they fold away again once the mouse leaves. While paused the last active one stays visible.":
            "Klik na vrstico ali puščico pokaže vse fokuse; ko miška zapusti okno, se spet skrijejo. Med pavzo ostane viden zadnji aktivni.",
        "Show all focuses": "Pokaži vse fokuse",
        "Show only the active focus": "Pokaži samo aktivni fokus",
        "While paused, dim the window after": "Med pavzo zatemni okno po",
        "seconds (0 = never)": "sekundah (0 = nikoli)",
        "Only while no focus is running. The window fades when the mouse is not over it and comes back on a click, when a focus starts, or when a nudge is due.":
            "Samo ko ne teče noben fokus. Okno zbledi, ko miška ni nad njim, in se vrne ob kliku, ob zagonu fokusa ali ko je na vrsti opozorilo.",
        "Log …": "Dnevnik …",
        "Do Not Disturb": "Ne moti",
        "Turn on Do Not Disturb while a focus is running": "Vklopi Ne moti, dokler teče fokus",
        "Turned off on pause, screen lock, sleep and quit. macOS has no API for Focus modes, so this needs two shortcuts in the Shortcuts app, named exactly \"%@\" and \"%@\", each with a single \"Set Focus\" action (Do Not Disturb → On / Off).":
            "Izklopi se ob pavzi, zaklepu zaslona, spanju in izhodu. macOS nima API-ja za načine Focus, zato sta potrebni dve bližnjici v aplikaciji Shortcuts (Bližnjice), poimenovani točno \"%@\" in \"%@\", vsaka z enim dejanjem \"Set Focus\" (Do Not Disturb → On / Off).",
        "Open Shortcuts": "Odpri Shortcuts",
        "Fastest: run scripts/make-dnd-shortcuts.sh from the repo and click \"Add Shortcut\" twice.":
            "Najhitreje: v repu poženi scripts/make-dnd-shortcuts.sh in dvakrat klikni \"Add Shortcut\".",
        "Shortcuts": "Bližnjice",
        "Show/hide window": "Pokaži/skrij okno",
        "New focus": "Nov fokus",
        "Note: where did I leave off": "Opomba: kje sem ostal",
        "Click a field and press the keys. Use ⌘, ⌃ or ⌥ with the key. Esc cancels, ⌫ turns the shortcut off.":
            "Klikni polje in pritisni tipke. Uporabi ⌘, ⌃ ali ⌥ skupaj s tipko. Esc prekliče, ⌫ bližnjico izklopi.",
        "Press keys …": "Pritisni tipke …",
        "Appearance": "Videz",
        "General": "Splošno",
        "Behavior": "Vedenje",
        "Size": "Velikost",
        "Reset": "Ponastavi",
        "Scales the whole panel: text, icons, spacing and width.": "Skalira celotno okno: besedilo, ikone, razmike in širino.",
        "Calendar": "Koledar",
        "Suggest a focus when a calendar event starts": "Ob začetku dogodka v koledarju predlagaj fokus",
        "Checks your calendars once a minute. Declined and all-day events are ignored. The first time, macOS asks for calendar access.":
            "Koledarje preveri enkrat na minuto. Zavrnjeni in celodnevni dogodki se ne upoštevajo. Prvič macOS vpraša za dostop do koledarja.",
        "Calendar access was denied. Allow it in System Settings → Privacy & Security → Calendars.":
            "Dostop do koledarja je zavrnjen. Dovoli ga v System Settings → Privacy & Security → Calendars.",
        "Open System Settings": "Odpri sistemske nastavitve",
        "Starting now: %@": "Zdaj se začenja: %@",
        "Switch": "Preklopi",
        "Dismiss": "Zavrni",
        "Sync": "Sinhronizacija",
        "Keep data in a cloud folder (for a second Mac)": "Hrani podatke v oblačni mapi (za drugi Mac)",
        "Folder": "Mapa",
        "Choose …": "Izberi …",
        "state.json moves into that folder; use the same folder on the other Mac. The last Mac that writes wins, so do not run a focus on both at the same time. For iCloud Drive keep the folder downloaded (turn off \"Optimize Mac Storage\" or mark it \"Keep Downloaded\").":
            "state.json se preseli v to mapo; na drugem Macu uporabi isto mapo. Zmaga zadnji Mac, ki zapiše, zato ne poganjaj fokusa na obeh hkrati. Pri iCloud Drive naj mapa ostane prenesena (izklopi \"Optimize Mac Storage\" ali označi \"Keep Downloaded\").",
        "Off": "Izklopljeno",
        "Show/hide window (%@)": "Pokaži/skrij okno (%@)",
        "MyFocus – Log": "MyFocus – dnevnik",
        "Durations use min and h in both languages.": "Trajanja uporabljajo min in h v obeh jezikih.",
    ]
}
