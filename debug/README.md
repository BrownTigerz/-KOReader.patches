# Diagnostic Patches

Temporary troubleshooting companions for the main patches. Each `2-zz-*-diagnostics.lua` watches its main patch from the outside and writes what it sees to one shared log. They change nothing — every hook passes straight through, and a diagnostic error can never break the original.

## How they work

- **Shared log:** every diagnostic appends timestamped, tagged lines to `koreader/diagnostics.log`. Tags are the patch's short name (`[network-tweaks]`, `[simpleui]`, …). The log rotates at 2 MB to `diagnostics.log.old`.
- **Self-limiting:** each diagnostic logs for its own window after every KOReader start (15–30 minutes for most; ReadMastery and Track Reading Location run a 5-day watch), then goes quiet. Each has a hard expiry counted from first install (24 hours to 10 days — 10 days for those two long-watch ones), after which it's one line per start, then nothing. Re-copy the file for a fresh window. (The Debugging Menu's "Delete all logs" also restarts the windows.)
- **State files:** `<name>-diagnostics.state` in the KOReader data dir holds the first-run stamp the expiry is counted from.
- **Load order:** the `zz` in the name makes each diagnostic load after its main patch.
- **Shared perf core:** diagnostics that include it share one copy of KOReader's timer loop and one watch on screen updates, sleep, slow taps and warnings (the first one loaded installs it, the rest plug in, so they never replace each other's). Each reports only its own patch's files: timers timed (slow ones named), flashes and who asked, timers left waiting at sleep, and a once-a-minute perf line with Lua memory. No timers of its own. In: SimpleUI, ShelfSync Tweaks, Network Tweaks, Track Reading Location, ReadMastery, Reading Insights Tweaks, Shortcuts Toolbar Icon Tweaks, Quick Shelf, Add-ons menu, Patch Backup & Restore, Debugging menu, Sleep Screen Banner, BookOrbit (more to follow).
- **Who was slow:** with SimpleUI diagnostics 2.13.0+, a slow tap or swipe line names the window on top and the patch or plugin it comes from. With BookOrbit diagnostics 1.4.0+ too, every BookOrbit server call says who made it (a patch and line, or BookOrbit itself), and a slow tap or swipe lists the server calls it waited on.
- **Drawing time:** a screen paint of 80 ms or more is split by part, building a screen of 80 ms or more is logged, and the once-a-minute line adds paint and build totals. BookOrbit 1.5.0+: covers, catalog cover images, art, snapshots, each dashboard tile type. SimpleUI 2.14.0+: SimpleUI home by module (Currently Reading, Cover Deck, critter, ...), plus covers and text, and the side panel (covers, text, and its build time from the swipe or tap).
- The debugging diagnostic (`2-zz-debugging-diagnostics.lua`) keeps its own separate log, because it watches the Debugging Menu itself.

## Install

Copy the diagnostics you want into KOReader's patches folder (the same place as the main patches) and restart. Delete the file and restart to remove one completely.

## Managing them

Use the Debugging Menu (`2-debugging-menu.lua` in the repo root, Add-ons → Debugging in the file browser): one master toggle plus a checkbox per diagnostic, view the shared log, combine everything into `koreader/debug-all.log` for sending, or delete one diagnostic's lines — or everything.

## The files

| Diagnostic | Watches | Version |
|---|---|---|
| `2-zz-backup-patches-diagnostics.lua` | Patch Backup & Restore | 1.3.2 |
| `2-zz-bookorbit-diagnostics.lua` | BookOrbit Tweaks | 1.5.1 |
| `2-zz-debugging-diagnostics.lua` | Debugging Menu | 1.2.1 |
| `2-zz-network-tweaks-diagnostics.lua` | Network Tweaks | 1.3.1 |
| `2-zz-readinginsights-tweaks-diagnostics.lua` | Reading Insights Tweaks | 2.1.2 |
| `2-zz-readmastery-diagnostics.lua` | ReadMastery Notify | 1.1.0 |
| `2-zz-shelfsync-tweaks-diagnostics.lua` | ShelfSync Tweaks | 1.1.0 |
| `2-zz-shortcutstoolbar-diagnostics.lua` | Shortcuts Toolbar Icon Tweaks | 1.1.0 |
| `2-zz-shortcutstoolbar-quick-shelf-diagnostics.lua` | Shortcuts Toolbar Quick Shelf | 1.3.0 |
| `2-zz-simpleui-diagnostics.lua` | SimpleUI Tweaks | 2.14.1 |
| `2-zz-sleepscreen-banner-diagnostics.lua` | Sleep Screen Banner | 1.1.0 |
| `2-zz-track-reading-location-diagnostics.lua` | Track Reading Location | 1.2.1 |
| `2-zz-tweaks-menu-diagnostics.lua` | Add-ons menu | 1.1.1 |
