#!/usr/bin/env bash
# Creates the two Shortcuts that MyFocus uses to toggle Do Not Disturb:
#   "MyFocus DND On"  = Set Focus -> Do Not Disturb -> On (until turned off)
#   "MyFocus DND Off" = Set Focus -> Do Not Disturb -> Off
# The `shortcuts` CLI cannot create shortcuts, so this writes .shortcut files, signs them
# and opens them; Shortcuts then shows an import dialog where you click "Add Shortcut".
set -euo pipefail

OUT="$(mktemp -d)"

write_shortcut() {   # name, enabled (1/0)
    local name="$1" enabled="$2"
    cat > "$OUT/$name.unsigned.shortcut" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WFWorkflowName</key>
    <string>$name</string>
    <key>WFWorkflowMinimumClientVersion</key>
    <integer>900</integer>
    <key>WFWorkflowMinimumClientVersionString</key>
    <string>900</string>
    <key>WFWorkflowClientVersion</key>
    <string>2605.0.5</string>
    <key>WFWorkflowIcon</key>
    <dict>
        <key>WFWorkflowIconStartColor</key>
        <integer>463140863</integer>
        <key>WFWorkflowIconGlyphNumber</key>
        <integer>59511</integer>
    </dict>
    <key>WFWorkflowTypes</key>
    <array/>
    <key>WFWorkflowInputContentItemClasses</key>
    <array/>
    <key>WFWorkflowHasShortcutInputVariables</key>
    <false/>
    <key>WFWorkflowActions</key>
    <array>
        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>is.workflow.actions.dnd.set</string>
            <key>WFWorkflowActionParameters</key>
            <dict>
                <key>Enabled</key>
                <integer>$enabled</integer>
                <key>AssertionType</key>
                <string>Until Turned Off</string>
                <key>FocusModes</key>
                <dict>
                    <key>Identifier</key>
                    <string>com.apple.donotdisturb.mode.default</string>
                    <key>DisplayString</key>
                    <string>Do Not Disturb</string>
                </dict>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF
    # Shortcuts refuses unsigned files; "anyone" signing needs no Apple ID
    shortcuts sign --mode anyone --input "$OUT/$name.unsigned.shortcut" --output "$OUT/$name.shortcut"
    echo "Prepared: $name"
}

write_shortcut "MyFocus DND On" 1
write_shortcut "MyFocus DND Off" 0

echo "Opening in Shortcuts; click \"Add Shortcut\" in each import dialog."
open "$OUT/MyFocus DND On.shortcut"
sleep 2
open "$OUT/MyFocus DND Off.shortcut"
echo
echo "Verify with: shortcuts list | grep 'MyFocus DND'"
