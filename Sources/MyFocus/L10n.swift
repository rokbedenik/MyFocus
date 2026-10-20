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
        "Drag to move the window": "Povleci za premik okna",
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
        "Quit My Focus": "Zapri My Focus",
        // Settings
        "My Focus – Settings": "My Focus – nastavitve",
        "Focuses": "Fokusi",
        "Maximum focuses at once": "Največ fokusov hkrati",
        "Allowed %d–%d. If the limit is below the number of open focuses, existing ones stay but you cannot add new ones.":
            "Dovoljeno %d–%d. Če je omejitev manjša od števila odprtih fokusov, obstoječi ostanejo, novih pa ne moreš dodati.",
        "Inactivity nudge": "Opozorilo po neaktivnosti",
        "Ask \"still on this?\" after": "Vprašaj \"še vedno na tem?\" po",
        "minutes (0 = off)": "minutah (0 = izklopljeno)",
        "Language": "Jezik",
        "Window": "Okno",
        "Dim the window when idle after": "Zatemni okno pri neaktivnosti po",
        "seconds (0 = never)": "sekundah (0 = nikoli)",
        "The window fades when the mouse is not over it and comes back on hover, on a switch, or when a nudge is due.":
            "Okno zbledi, ko miška ni nad njim, in se vrne ob prehodu z miško, ob preklopu ali ko je na vrsti opozorilo.",
        "Log …": "Dnevnik …",
        "Do Not Disturb": "Ne moti",
        "Turn on Do Not Disturb while a focus is running": "Vklopi Ne moti, dokler teče fokus",
        "Turned off on pause, screen lock, sleep and quit. macOS has no API for Focus modes, so this needs two shortcuts in the Shortcuts app, named exactly \"%@\" and \"%@\", each with a single \"Set Focus\" action (Do Not Disturb → On / Off).":
            "Izklopi se ob pavzi, zaklepu zaslona, spanju in izhodu. macOS nima API-ja za načine Focus, zato sta potrebni dve bližnjici v aplikaciji Shortcuts (Bližnjice), poimenovani točno \"%@\" in \"%@\", vsaka z enim dejanjem \"Set Focus\" (Do Not Disturb → On / Off).",
        "Open Shortcuts": "Odpri Shortcuts",
        "Shortcuts": "Bližnjice",
        "Show/hide window": "Pokaži/skrij okno",
        "New focus": "Nov fokus",
        "Note: where did I leave off": "Opomba: kje sem ostal",
        "Click a field and press the keys. Use ⌘, ⌃ or ⌥ with the key. Esc cancels, ⌫ turns the shortcut off.":
            "Klikni polje in pritisni tipke. Uporabi ⌘, ⌃ ali ⌥ skupaj s tipko. Esc prekliče, ⌫ bližnjico izklopi.",
        "Press keys …": "Pritisni tipke …",
        "Off": "Izklopljeno",
        "Show/hide window (%@)": "Pokaži/skrij okno (%@)",
        "My Focus – Log": "My Focus – dnevnik",
        "Durations use min and h in both languages.": "Trajanja uporabljajo min in h v obeh jezikih.",
    ]
}
