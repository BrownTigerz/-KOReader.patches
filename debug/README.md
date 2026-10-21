# Diagnostic Patches

Temporary troubleshooting companions for the main patches. Each `2-zz-*-diagnostics.lua` watches its main patch from the outside and writes what it sees to one shared log. They change nothing — every hook passes straight through, and a diagnostic error can never break the original.

## How they work

- **Shared log:** every diagnostic appends timestamped, tagged lines to `koreader/diagnostics.log`. Tags are the patch's short name (`[network-tweaks]`, `[simpleui]`, …). The log rotates at 2 MB to `diagnostics.log.old`.
- **Self-limiting:** each diagnostic logs for its own window after every KOReader start (15–30 minutes for most; ReadMastery and Track Reading Location run a 5-day watch), then goes quiet. Each has a hard expiry counted from first install (24 hours to 10 days — 10 days for those two long-watch ones), after which it's one line per start, then nothing. Re-copy the file for a fresh window. (The Debugging Menu's "Delete all logs" also restarts the windows.)
- **State files:** `<name>-diagnostics.state` in the KOReader data dir holds the first-run stamp the expiry is counted from.
- **Load order:** the `zz` in the name makes each diagnostic load after its main patch.
- The debugging diagnostic (`2-zz-debugging-diagnostics.lua`) keeps its own separate log, because it watches the Debugging Menu itself.

## Install

Copy the diagnostics you want into KOReader's patches folder (the same place as the main patches) and restart. Delete the file and restart to remove one completely.

## Managing them

Use the Debugging Menu (`2-debugging-menu.lua` in the repo root, Add-ons → Debugging in the file browser): one master toggle plus a checkbox per diagnostic, view the shared log, combine everything into `koreader/debug-all.log` for sending, or delete one diagnostic's lines — or everything.

## The files

| Diagnostic | Watches | Version |
|---|---|---|
| `2-zz-backup-patches-diagnostics.lua` | Patch Backup & Restore | 1.2.0 |
| `2-zz-debugging-diagnostics.lua` | Debugging Menu | 1.1.7 |
| `2-zz-network-tweaks-diagnostics.lua` | Network Tweaks | 1.2.4 |
| `2-zz-readinginsights-tweaks-diagnostics.lua` | Reading Insights Tweaks | 2.0.0 |
| `2-zz-readmastery-diagnostics.lua` | ReadMastery Notify | 1.0.8 |
| `2-zz-shelfsync-tweaks-diagnostics.lua` | ShelfSync Tweaks | 1.0.6 |
| `2-zz-shortcutstoolbar-diagnostics-2.lua` | Shortcuts Toolbar Icon Tweaks | 1.0.10 |
| `2-zz-shortcutstoolbar-quick-shelf-diagnostics.lua` | Shortcuts Toolbar Quick Shelf | 1.1.0 |
| `2-zz-simpleui-diagnostics.lua` | SimpleUI Tweaks | 2.8.3 |
| `2-zz-sleepscreen-banner-diagnostics.lua` | Sleep Screen Banner | 1.0.7 |
| `2-zz-track-reading-location-diagnostics.lua` | Track Reading Location | 1.1.6 |
| `2-zz-tweaks-menu-diagnostics.lua` | Add-ons menu | 1.0.5 |
| `2-zz-xray-direct-lookup-diagnostics.lua` | X-Ray Direct Lookup | 1.2.5 |
