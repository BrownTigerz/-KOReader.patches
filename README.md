# KOReader Patches

User patches for KOReader, mostly tested for Kobo Clara Color. Each one is a single file that patches KOReader or a plugin in memory. Nothing on disk is modified, so deleting a file and restarting fully reverts it.

If these patches are useful to you, you can [support my work on Ko-fi](https://ko-fi.com/browntigerz).

## Install

Copy the `2-*.lua` files you want into KOReader's patches folder and restart KOReader.

- Kobo: `.adds/koreader/patches/`
- Kindle: `koreader/patches/`
- Android: `koreader/patches/`

Create the folder if it doesn't exist. The `2-` prefix is required: KOReader only loads patches whose names start with a supported priority number (`0`, `1`, `2`, `8`, `9`), and `2-` is the one that runs after the UI is ready, which is what these patches need. Patches don't work on the F-Droid build of KOReader.

All patches work independently and together. If one fails to attach (for example, after a plugin update), it logs to `koreader/crash.log` and leaves things as they were. Each patch logs its version to `crash.log` on startup.

**Upgrading from SimpleUI Mod:** the patch is now `2-simpleui-tweaks.lua`. Delete `2-simpleui-mod.lua` (a leftover copy is skipped, but there's no reason to keep it). Your saved settings carry over.

| Patch | File | Requires | Version |
|---|---|---|---|
| [SimpleUI Tweaks](#simpleui-tweaks) | `2-simpleui-tweaks.lua` | simpleui.koplugin | 2.14.3 |
| [Critter phrases](#simpleui-tweaks) | `critter-phrases.lua` | SimpleUI Tweaks, Reading Log | n/a |
| [Add-ons menu](#add-ons-menu) | `2-tweaks-menu.lua` | none | 1.0.7 |
| [Patch Backup & Restore](#patch-backup--restore) | `2-backup-patches.lua` | zip-capable KOReader build (2024+) | 2.4.8 |
| [Debugging Menu](#debugging-menu) | `2-debugging-menu.lua` | Add-ons menu | 1.3.6 |
| [Network Tweaks](#network-tweaks) | `2-network-tweaks.lua` | Kobo or Kindle for background connect | 1.12.0 |
| [ShelfSync Tweaks](#shelfsync-tweaks) | `2-shelfsync-tweaks.lua` | ShelfSync | 1.11.15 |
| [ReadMastery Notify](#readmastery-notify) | `2-ReadMastery-notify.lua` | ReadMastery | 1.0.6 |
| [ReadMastery Quests](#readmastery-quests) | `2-ReadMastery-quests.lua` | ReadMastery (Notify optional) | 1.0.6 |
| [Kobo Style Sleep Screen Banner](#kobo-style-sleep-screen-banner) | `2-kobo-style-sleepscreen-banner.lua` | none | 1.2.2 |
| [Track Reading Location](#track-reading-location) | `2-track-reading-location.lua` | none | 1.9.5 |
| [Shortcuts Toolbar Icon Tweaks](#shortcuts-toolbar-icon-tweaks) | `2-shortcutstoolbar-icon-tweaks.lua` | shortcutstoolbar.koplugin | 1.17.0 |
| [Shortcuts Toolbar Quick Shelf](#shortcuts-toolbar-quick-shelf) | `2-shortcutstoolbar-quick-shelf.lua` | shortcutstoolbar.koplugin | 1.2.2 |
| [X-Ray Direct Lookup](#x-ray-direct-lookup) | ~~`2-xray-direct-lookup.lua`~~ | xray.koplugin | discontinued |
| [Reading Insights Tweaks](#reading-insights-tweaks) | `2-readinginsights-tweaks.lua` | readinginsights.koplugin + CoverBrowser | 2.1.1 |
| [QuickMenu Toggle State](#quickmenu-toggle-state) | `2-quickmenu-toggle-state.lua` | none | 1.0.4 |
| [List Rating Progress](#list-rating-progress) | `2-list-rating-progress.lua` | none | 1.0.0 |
| [Screenshot Timer](#screenshot-timer) | `2-screenshot-timer.lua` | none | 1.0.0 |
| [Custom Quotes for SimpleUI](#custom-quotes-for-simpleui) | `Quotes.lua` | simpleui.koplugin | n/a |
| [BookOrbit Tweaks](#bookorbit-tweaks) | `2-bookorbit-tweaks.lua` | bookorbit.koplugin | 2.14.0 |

Versioning across the patches: `1.0.x` is a fix, `1.x.0` is a new feature, and `2.0.0` is a change that affects how existing saved settings or backups work.

## Diagnostic patches

The `debug/` folder holds temporary troubleshooting companions for the main patches (`2-zz-*-diagnostics.lua`). They change nothing — each one watches its main patch and writes timestamped, tagged lines to one shared log (`koreader/diagnostics.log`) for a short window after every start, then goes quiet, and stops entirely 24 hours after install. Manage them with the Debugging Menu (toggle, view, combine, delete). See [debug/README.md](debug/README.md).

---

## SimpleUI Tweaks

![Simpleui Currently Reading](images/simpleui-currently-reading.png)
![Simpleui Currently Reading 2](images/simpleui-currently-reading-2.png)
![Simpleui Sidebar](images/simpleui-sidebar.png)
![Simpleui Sidebar 2](images/simpleui-sidebar-2.png)

Colour and typography control for the SimpleUI home screen, plus a Night Mode "day look" for use with a light wallpaper.

Settings: Tools → SimpleUI Tweaks (or Tools → Add-ons → SimpleUI Tweaks with the Add-ons menu installed).

- **Modules:** text colour with a separate Night Mode colour, set for all modules and overridable per module. Recolour grey text, progress bar/ring/border colours per module, bold per module or all.
- **Currently Reading:** swipe left/right to step through your most recent books still in progress (4 by default, 2-6; finished ones skipped), with dots on the cover showing where you are. Tap opens the book shown.
- **Tiny Critter bubble width** (SimpleUI 3.0): Modules → Critter Bubble Width — Default, **Dynamic**, Wide, Wider or Full Row, so longer lines fit on fewer rows. Its chat answers follow the bubble. **Dynamic** keeps SimpleUI's width for short lines and grows only as much as a long one needs (the critter and bubble then sit at the start of the row, like Full Row).
- **Tiny Critter insights** (SimpleUI 3.0): Modules → Critter Insights, on by default. The critter tells you about your reading: your best reading day this month, book milestones this year (5, 10, 25, 50, 75, 100, then every 50), getting back on a roll after a break, the book you're on being 25 minutes or less from the end, the finish rate your yearly goal needs ("20 books to go, 69 days left. About one every 3 days catches you up.", worded for on pace or catching up), a gentle nudge after 3+ quiet days, and whether you read more on weekends or weekdays. They wait for the critter like its own reactions (book finished, comeback), at most 3 a day, and only when your stats back them: a milestone when you finish that book (once a year each), back on a roll once per comeback, a nudge once per quiet stretch, goal pace and weekend reading once a week (weekend reading needs 4+ weekend and 8+ weekday reading days in 8 weeks, and doesn't flip-flop). Best day is in minutes read. One statistics read a day, no timers. Its chat no longer suggests the same book twice in a day. Needs the critter's Reactions on.
- **To Be Read side panel**: swipe in from the right (or left) edge of the home screen for your To Be Read list; tap a book to open it, hold it to remove it. Modules → **To Be Read Side Panel** picks the edge or turns it off, and **Side Panel Swipe Zone** sets how close to the edge the swipe has to start: **Narrow** (default) or **Edge Only**, so ordinary swipes don't open it by accident, or **Wide** (KOReader's edge zone, an eighth of the screen).
- **Page Turn Flash** (SimpleUI Tweaks menu): SimpleUI turns home screen pages (page 1 to 2 and back) with a quiet update, so the old page can ghost through. **Normal** adds a quick flash to each turn; **Strong** a full refresh, which also clears dark pages and night mode. **Off** (default) keeps turns as fast as they are now.
- **Tiny Critter pep talk** (SimpleUI 3.0): Modules → **Critter Pep Talk**, on by default. SimpleUI's "minutes read today" and "pages turned today" lines grow with your reading instead of always saying "Nice work.": a nudge after a minute or two ("1 minute read today. A start is a start."), a groove at 15 minutes, a cheer at half an hour, a party past an hour ("2.2 hours read today! Marathon mode."). With a daily goal set, it counts you in once you're within 10 minutes ("Just 7 minutes to your daily goal!"). The line moves up a step next time the home screen draws as you read; the wording changes with each new phrase. No timers.
- **Critter Mix** (2.14.2): Modules → **Critter Mix**, tick two or more critters (say Donny, Blu and Donny & Blu) and they take turns: the next one each time the critter picks something new to say (about every 20 minutes, a new part of the day, or a tap). Reading Log's critter takes turns too: a new remark or a tap there moves it along (Reading Log 1.10.0+). Fewer than two ticked: SimpleUI's own pick.
- **More critter moods** (2.14.1): reading, proud, hungry, cozy, sipping, dreamy, festive, spooky (Donny and Blu have them, see Tiny Critters). A critter without one shows its base pose (reading as neutral, proud as cheer...) instead of plain neutral. Party is festive in December and spooky from October 25, when the critter has those pictures.
- **Critter phrases** (`critter-phrases.lua`, optional): put it in `koreader/patches/` next to the patch (the name has no number, so KOReader doesn't run it as a patch). Critter Insights and Critter Pep Talk then take their lines from it: several times as many, a little sassier, never guilt-trippy. Edit it to make the critter your own; Reading Log's critter uses the same file. Missing or broken, the built-in lines are used (Debugging logs which). Don't call it `phrases.lua` or put it in `sui_critters/`: that's SimpleUI's own custom phrase file, in another format.
- **Tiny Critter text colour** (SimpleUI 3.0): Modules → **Critter Text Colour** — **Auto** (default) keeps the text standing out on the bubble: white on the dark bubble in night mode, black on the white one by day. **White** or **Black** always, as they look (night mode included). The module text colours (Text Colour / Night Text Colour, made for text on the page or wallpaper) no longer reach inside the bubble. The bubble's outline follows. Reading Log's critter follows too.
- **Tiny Critter position** (SimpleUI 3.0): Modules → **Critter Position** — **Left**, **Right** or **Left or Right** (one of the two ends each time, never the middle) for the critter and its speech bubble, so the middle of the row (and your wallpaper behind it) stays clear. Works with or without Critter Wanders; the first choice keeps SimpleUI's Alignment (or wanders with Critter Wanders on).
- **Tiny Critter side** (SimpleUI 3.0): Modules → **Critter Side** — **Left of Text** or **Right of Text** keeps the critter on that side of its speech bubble, whatever the bubble width and with or without Critter Wanders (the row can still wander). The third choice uses SimpleUI's own Side (random while wandering).
- **Tiny Critter wanders** (SimpleUI 3.0, Dynamic width): Modules → Critter Wanders (Dynamic), on by default. Each time the home screen draws the row, the critter and its bubble move to the left, centre or right, with the critter on either side of the bubble (never the same spot twice in a row). SimpleUI's own Side and Alignment come back when it's off.
- **Tiny Critter row height** (SimpleUI 3.0): Modules → Critter Row Height — Default, Taller (+30%) or Tallest (+60%), so the bubble has room for its full lines. The row keeps that height for every phrase, so nothing below it moves. The critter keeps its size; Critter Size → Fill Height grows it to the taller row.
- **Tiny Critter size** (SimpleUI 3.0): Modules → Critter Size — Default (SimpleUI's whole pixel steps, often shorter than the bubble), Fill Height (matches the bubble's height) or Smaller. Its moods and the decorations next to it follow.
- **Section titles:** defaults for all sections, then per-module colour, bold and size (preset or custom 50-300%). A `•` marks customised sections.
- **Nav bar:** bold labels, day look in Night Mode, colour icons keep their original colours in Night Mode.
- **Status bar:** bold, and day look in Night Mode.
- **KOReader's own icons in Night Mode:** menu tab icons (chosen one by one), menu arrows and Quick Actions icons can keep their original colours (each a toggle, off by default). Useful for colour icons swapped in via `koreader/icons/`.

Colours are picked as they should look on screen; Night Mode inversion is handled for you. Night Mode switches and status bar bold apply instantly, and everything else asks for a restart. Settings are saved to disk straight away, so they survive a crash, power-off or patch update. Works with SimpleUI's own "Don't Invert Colored Icons in Night Mode" (no double flip) and with its custom tab icons.

**Notes**
- Wallpaper: turn off SimpleUI's own wallpaper Night Mode inversion, since black text needs a light background.
- Module fill: with a light wallpaper, set module backdrop/fill to 0, or text can disappear in Night Mode.
- Colour nav icons need a non-Framed nav bar style (Framed draws icons in one colour but still gets the day look).
- Icon files: use SVG icons with transparency.
- Section title sizes multiply SimpleUI's own label scale (Scale → Labels).

**Uninstall:** use Reset to defaults if you want the saved settings (`simpleui_mod` in `settings.reader.lua`) removed, then delete the file and restart.

---

### Tiny Critters

Custom pixel art critters for SimpleUI's Tiny Critter feature — Donny (tabby), Blu (Siamese), and both together. All 12 of SimpleUI's moods, plus 8 more: **reading** (an open book), **proud** (a crown), **hungry** (a fish), **cozy** (a mug of tea), **sipping** (a glass of water), **dreamy** (moon and stars), **festive** (a Santa hat) and **spooky** (a pumpkin). SimpleUI Tweaks (2.14.1+) and Reading Log use them: the phrase bank's lines show them, party turns festive in December and spooky in the last week of October. Another critter without them shows the pose they're drawn from.

![Critters](images/critters-showcase.png)

![The extra moods: reading, proud, hungry, cozy, sipping, dreamy, festive, spooky](images/critters-moods.png)

Download: [critters.zip](critters.zip) — extract to `koreader/settings/simpleui/sui_critters/` on your Kobo.

## Add-ons menu

![Addons Menu](images/addons-menu.png)
![Addons Menu 2](images/addons-menu-2.png)

One **Tools → Add-ons** menu for plugins and patches. It pulls plugin menus (grouped, in an order you can edit near the top of the file) and patch settings into one place, so Tools stays tidy. Moved plugins work exactly the same.

- **Auto-collect:** newly installed plugins and patches that add a menu get picked up automatically. You get a one-time notice and they show up marked "New" under "Other" in "Choose What's In Add-ons".
- **Choose What's In Add-ons** (bottom of the list): tap an item to turn it on or off (off puts it back where it was), hold it to move it to another group. Both apply after a restart.
- **Safe to remove:** KOReader's menu order stays untouched. Delete the file and restart and every menu goes back where it was. Only your Add-ons choices are saved, in `settings.reader.lua`. IDs that don't exist are skipped, and items hidden with Menu Disabler stay hidden.

For patch authors: register with the shared table at `package.loaded.tweaks_mods`. The format is documented at the top of the file. Return an item with `sub_item_table_func` so large menus are only built when opened.

---

## Patch Backup & Restore

![Patch Backup Menu](images/patch-backup-menu.png)

Per-patch backups, icon cleanup, and better device backups via Device Backup & Restore (`backup.koplugin`, build 26.9.29+ for icons). Tested with backup.koplugin 26.10.23; recheck after a major update to it, SimpleUI or ShelfSync, since this patch relies on how they store settings and logins.

Menu: **Tools → Patch Backup & Restore** (or **Tools → Add-ons → Patches** once `backup_patches` is in the Add-ons menu's `PATCH_MENUS` list).

```
Patch Backup & Restore
├─ Shortcuts toolbar, SimpleUI, …   one entry per target you use
│  ├─ Back up now
│  ├─ Restore latest
│  └─ History                      every backup: restore or delete,
│                                   or delete all of this target's
├─ Delete all backups              every target's, safety backups too
├─ Icons
│  ├─ Tidy icons
│  └─ Unused icons
├─ Logins in device backups        off by default
└─ Check for Patch Updates         update patches on the device
```

- **Back up now:** the target's settings, any settings files it keeps in `koreader/settings/`, and every icon its settings point to, in one zip at `koreader/backups/<target>/<target>_<date>.zip`.
- **Restore:** puts settings and files back, unpacks icons into the target's icon folder and repoints settings there. Takes a "before restore" safety backup first (and stops if it can't), then asks to restart. "Restore latest" skips those automatic safety backups.
- **Tidy icons:** copies every icon a target uses into its own flat folder (`koreader/icons/<target>/`; SimpleUI uses its own `sui_icons/`) and repoints settings there. Originals stay put. Takes a "before tidy" backup first.
- **Unused icons:** icons nothing points to, across `koreader/icons/` subfolders and SimpleUI's `sui_icons/` (packs included). Delete one at a time or all at once; emptied folders and packs go too. Loose files directly in `koreader/icons/` and KOReader's built-in icons are never touched.
- **Notifications:** with Network Tweaks installed, results (backed up, deleted) follow its notification style: Banner, Minimal corner note, or Normal popup. Questions, restart prompts and failures always stay popups.
- **Check for Patch Updates:** updates all 26 patches on the device from this repo's `patch-versions.lua` manifest (14 main patches + 12 diagnostics, maintained one line per release) over Wi-Fi — no login, no Google Drive. Every patch is listed under Patches / Diagnostics headings as Up to Date, version → version, Installed Is Newer, Not Installed or Unknown Version; rows are tappable — tapping one pops up its actions: Update / Reinstall / Install depending on its state, plus Remove for any installed patch (except the updater itself; removing a main patch offers to also remove its paired diagnostics file). Update All is always listed (with nothing outdated it just says so). Updates never roll a patch back — they only go into `koreader/patches/` (a diagnostic updates where its copy sits: `patches/` if active, `patches/debug/` if switched off), showing each patch name as it downloads, with a success/failure summary, then asks to restart. Wi-Fi turns on automatically if off and stays on afterwards.

**Device Backup & Restore integration:** with Settings and Icons ticked, every icon a target uses is included (wherever it lives) plus a map of its old paths, so the icons work on another device too (Kobo, Kindle, Android). The Logins toggle is off by default: saved logins, session tokens and the keys that decrypt them (ShelfSync, ShelfSync tweaks, backup cloud credentials) are excluded, including from Beam. Files that mix tokens with normal settings go in with only the tokens stripped, and a restore keeps the device's own logins. Turning it on includes everything, so keep that backup file private.

Built-in targets: Shortcuts toolbar, Track Reading Location, Add-ons menu, Reading Insights tweaks, ReadMastery Notify/Quests, ShelfSync tweaks (settings only, never logins), and SimpleUI. Targets you don't use stay hidden.

**For patch authors, add a target:**
```lua
local BK = package.loaded.backup_patches or { targets = {} }
package.loaded.backup_patches = BK
BK.register{            -- or table.insert(BK.targets, {...}) if not loaded yet
    id = "mything", text = "My thing",
    setting_prefix = "mything",     -- optional: G_reader_settings keys
    files = { "mything.lua" },      -- optional: files in koreader/settings/
    store = function(from_disk)     -- optional: settings kept in your own
        return data_table, flush_fn --   file (every key, or those
    end,                            --   matching setting_prefix)
    icon_dir = "/abs/folder",       -- optional: where Tidy puts icons
    library_dirs = { "/abs/dir" },  -- optional: icon folders Unused cleans fully
}
```
and declare secrets kept out of device backups (names relative to `koreader/settings/`):
```lua
BK.addSecrets{ files = { "x_login.lua" }, folders = { "x_session" },
               keys = { ["x_settings.lua"] = { "api_token" } } }
```

Needs a KOReader build with zip support (`ffi/archiver`, 2024+).

---

## Debugging Menu

![Debug Menu](images/debug-menu.png)

Adds **Add-ons → Debugging** (file browser only): one place to switch diagnostic patches on and off and tidy their logs. Your diagnostic patches are never edited.

- One master toggle plus a checkbox per diagnostic. Turning one off moves it to `patches/debug/`, so KOReader doesn't load it and it costs nothing. Changes apply after a restart (asked once).
- All diagnostics write to one shared log (`koreader/diagnostics.log`), each line tagged with the diagnostic's short name, so a whole test run reads in order in one file.
- **Combine logs for sending:** writes the shared log plus the end of `crash.log` into one file: `koreader/debug-all.log`.
- **Delete all logs:** clears every .log except version.log and crash.log, plus the diagnostics' stamp/state files (including orphaned ones from removed patches), which restarts their time windows. Asks first. Hold a diagnostic to filter its lines out of the shared log, or delete its log lines and the patch itself.
- Shows `crash.log` size, with "Clear crash.log" to empty it. `version.log` (KOReader's update history) is never touched.

---

## Network Tweaks

![Network Tweaks](images/network-tweaks.png)

Wi-Fi, SSH and Calibre, handled the same way. Menu: Settings (gear) → Network → Network Tweaks (or Tools → Add-ons with the Add-ons menu installed).

- **Stop SSH Server On Sleep** (on): stops KOReader's SSH server when the device sleeps, like Wi-Fi, and doesn't restart it on wake. Without this, SSH quietly becomes reachable again as soon as Wi-Fi reconnects.
- **SSH Follows Wi-Fi** (off): SSH starts when you turn Wi-Fi on and stops whenever Wi-Fi goes off, however that happens. It isn't started by the automatic reconnect after waking, so SSH stays off after sleep. Handy for pushing patches.
- **Choose Network…:** scans (tap the scanning message to cancel) and lists networks as Connected, Saved, Saved · away, or Open. Tap one for Reconnect / Edit password / Forget, or Disconnect when connected. It never connects by itself: with Wi-Fi off (Kobo) the radio comes up just for the scan, and closing the list without picking puts Wi-Fi back off.
- **Forget on the device too:** the device keeps its own Wi-Fi list (on Kobo, the stock reader's), and background reconnects use it, so a network forgotten only in KOReader still comes back. When the device has it too, Forget and Forget all ask **KOReader Only** or **Device + KOReader**. The device's old list is kept as `wpa_supplicant.conf.bak`. A network you connect to from the list is saved on the device too, so background reconnects work for it; with nothing saved on the device, tapping Wi-Fi opens the list instead of KOReader's flow that freezes the screen for ~5 s.
- **Bluetooth…** (only with kobo.koplugin, on devices it supports): the plugin's Bluetooth menu — on/off, scan, paired devices, settings — moved here from Settings → Network. On MTK Kobos Bluetooth shares the Wi-Fi chip, so the patch also keeps the hand-off sane: one Wi-Fi restore at a time, and Wi-Fi on/off taps during Bluetooth start-up are applied once it's up.
- **Storefront** (no menu, only with storefront.koplugin): its short self-closing messages use the note style above (Normal leaves them as they are; progress messages like "Checking plugin updates…" and anything with buttons stay as Storefront shows them), and its sleep step skips the full memory clean-ups it runs (four per sleep, about 0.85 s).
- **Notifications** (default Banner): one style for Wi-Fi on/off, SSH on/off and the Calibre wireless connection, however you trigger them.
  - **Normal:** stock KOReader popups; Wi-Fi waits until connected.
  - **Minimal:** Wi-Fi connects in the background, with small corner notes (top right) like "Wi-Fi connected", "SSH on", "Calibre connected".
  - **Banner:** Wi-Fi connects in the background with a banner at the top ("Connecting to Wi-Fi… tap here to cancel", then "Connected to <network>"). SSH shows what you need to connect, for example `SSH on · 192.168.1.23:2222`, and Calibre shows the server it connected to.
  - **Calibre's own messages** follow the style too (Minimal and Banner): "Connecting to calibre… tap here to cancel" stays up until it connects (tap it to cancel; while it searches for a server, a tap anywhere still cancels), "No calibre server found" / "Can't connect to calibre · <reason>", "Receiving 2/5 · <book>" one note at a time then "5 books received", and "Calibre · deleted <book>". Prompts with buttons (password, low disk space) stay as they are.
- **Shared notification style:** every patch's status notes use this style when Network Tweaks is installed — Banner, Minimal corner note, or Normal (the patch shows its own popup). Without Network Tweaks, patches fall back to ReadMastery Notify's style when that's installed, otherwise their own default. Nothing ever shows over the sleep screen.
- **Cancel Wi-Fi Connection** (only shown while connecting): stops a background connect. You can also tap the banner, or tap the Wi-Fi toggle again. Going to sleep cancels a connect in progress too.

A failed Wi-Fi connect always shows a note at the top; tap it to choose a network. Long-press the Wi-Fi toggle in the network menu for the normal flow with the network list.

**Notes**
- Background connect uses the device's own Wi-Fi config, the same one the automatic reconnect on wake uses. On Kobo that means networks joined in Kobo's own Wi-Fi settings; networks joined only in KOReader aren't in it. If that config has no networks, the Normal flow is used instead. Background connect needs Kobo or Kindle.
- Shortcuts Toolbar Icon Tweaks' SSH and Calibre indicators update the moment they change with Network Tweaks 1.4.0+.

---

## ShelfSync Tweaks

![Shelfsync Tweaks](images/shelfsync-tweaks.png)

Checked against ShelfSync 1.8.1; the bundled Goodreads login code is a goodreadskosync 1.15.0 snapshot (MIT, license in the file). Notifications match Network Tweaks or ReadMastery Notify if you have one installed.

- **Goodreads login on device:** a Log In button (email + password) in ShelfSync → Providers → Goodreads → Account, same as StoryGraph's. Login code is bundled from `goodreadskosync` (MIT, license in the file), so that plugin isn't needed.
- **Remember login** for Goodreads and StoryGraph: tap "Log In As…" to sign in with the saved login, long-press to edit, "Forget Saved Login" to remove it.
- **Goodreads WAF fix:** search and security-token requests use `/book/auto_complete` and `/review/list` to get around Amazon's bot check, and fall back to the normal ones if those fail.
- **New toggles in ShelfSync → Settings** (above Verbose logging):
  - Auto Re-login When Session Expires (on).
  - Retry Autolink When Wi-Fi Connects (on).
  - Hide Providers: Fable, Hardcover, Goodreads, Pagebound, StoryGraph, LibraryThing (all off). Hiding a provider also stops it from syncing. Menu changes show after reopening the book / file browser.
- **Link & Update:** every enabled provider's Link Book and Update Status in one menu, with three gesture actions that jump straight to them (Link & Update Menu, Link Book (All Providers), Update Status (All Providers)).
- **ShelfSync All: Update Progress** (gesture), turns Wi-Fi on if needed, syncs every linked, enabled provider that tracks reading progress (one retry each — LibraryThing doesn't track progress, so it's skipped), lists providers still unlinked, then turns Wi-Fi back off if it turned it on. ShelfSync's built-in "Update progress for all linked books" also turns Wi-Fi on first and off after.
- **Autolink retry on connect:** books opened offline get linked when Wi-Fi connects.
- **Auto re-login:** if a saved-login session expires, it signs in again and sends the open book's progress again, at most once per provider per 30 minutes. You'll still be asked for a Goodreads verification code or captcha.
- **Security:** logins stay on the device (`koreader/settings/shelfsync_*_login.lua`), encrypted with a device-local key. That protects against casual browsing, not full device access.

---

## ReadMastery Notify

![Readmastery Notify](images/readmastery-notify.png)

Notification styles for ReadMastery: XP, quests, level-ups and reading progress, without getting in the way while reading. Doesn't edit any ReadMastery file; settings live in their own file (`settings/ReadMastery_notify.lua`).

Three top-level toggles above the settings menu:
- **Notifications:** master ON/OFF for everything below.
- **Nudges:** 80%/90% "almost there" notices from the quest patch (informational only, no XP). Greyed out whenever Notifications is off.
- **Critter Reacts (SimpleUI):** see below. Default ON; works whether Notifications is on or off.

Everything else lives under ReadMastery → Settings → Notification Settings:
- **Style:** Full is ReadMastery's original popup (tap to dismiss). Compact is a small centered box, auto-dismiss or tap, that can mix your chosen font with a monospace font for achievement art. Banner is a corner or full-width toast that auto-dismisses and never blocks reading or page turns.
- **Banner Position:** Top Left, Top Right, Bottom Left, Bottom Right, Full Width (Top), Full Width (Bottom).
- **Duration:** how long Compact and Banner stay up.
- **Font:** a grouped list of fonts already on your device, or KOReader's default.
- **Preview Notification:** fires a real Level 1 level-up using your current settings, so you can check changes without waiting for a real one.

Level-ups show a cosmetic title badge at certain milestone levels (for example "Established Reader" at 10). Achievements show their own pixel-art icon in Compact and Banner. Several notifications close together queue and show one at a time.

**SimpleUI Critter (SimpleUI 3.0's Tiny Critter Companion):**
- **Reactions:** level-ups, achievements (tier-ups too), streak milestones and completed quests queue up for the Critter, which comments on the most important one the next time the home screen shows it ("Level 12!", "Quest done: Deep Dive."). A finished book still comes first; a level-up comes before the Critter's own daily challenge. Each one also makes the Critter a little happier.
- **Daily quests in its chat** (needs ReadMastery Quests 1.0.6+ with Quests (Enhanced) on): the Critter can offer one of today's daily quests, with your progress so far: **I'll Do It**, **Not Today**, or **What's In It For Me?** (the XP). Once you've said yes, it asks how that quest is going, and finishing it gets its own line. Time-window quests whose window is over for the day aren't offered.
- **End of the week / month:** in the last 2 days of the week, last 5 of the month, or last 7 of a seasonal quest's month, the Critter nudges once a day toward a quest still in reach: a "finish N books" quest one book short, naming your closest-to-done book ("4 days left for Bibliophile. “The Hobbit” is 91% done. Finish it?"), the seasonal book quest, or pages / minutes still to go. It shows in its bubble and as a chat: **Let's Finish It**, **Which Book?**, **Not This Time**.
- Uses SimpleUI's own Critter reactions, lines, chat and mood, so the Critter's own toggles (reactions on/off per screen) still apply. Nothing runs on a timer. Without the Critter it does nothing, and ReadMastery's popups are the same either way.

---

## ReadMastery Quests

![Readmastery Quests](images/readmastery-quests.png)
![Readmastery Menu](images/readmastery-menu-path.png)

Drop this alongside ReadMastery Notify and restart. Independent, optional add-on: without Notify, quest-complete popups fall back to a plain default box.

Adds one top-level menu toggle, **Quests (Enhanced)**.

- **OFF (default):** zero overhead. The tracking hooks do nothing extra and "View Quests" is greyed out.
- **ON:** tracks quests using ReadMastery's own live session data (pages, minutes, streak, book events), with no separate tracking system. Awards XP through ReadMastery's own `addXP()`, so it shows up in your real XP and level, and fires a "Quest Complete" popup through the same styled, queued notification pipeline as achievements.

"View Quests" shows a live list with a progress bar per quest; tap any quest to see what it needs.

- **Daily** (resets 3 AM): Daily Chapter and Focused Reader are always active, plus one quest rotating in from a pool (Deep Dive, Night Owl, First Light, Literary Lunch Break, Evening Escape).
- **Weekly** (resets Monday): includes Page Turner, Consistency Engine, Reading Marathon, Iron Reader, tag-based page quests, Genre Explorer, The Final Stretch and Second Look.
- **Monthly** (resets the 1st): includes Bibliophile, The Endurance Trial, book-length tiers (Brick Slayer / The Long Haul / Leviathan; only the highest tier a book qualifies for pays out), Change of Scenery, Genre Hopper and Return Visit.
- **Seasonal and yearly** quests are included as well.
- **Second Look** (weekly, 300 XP): go back, set an earlier page as your reading location with Track Reading Location's gesture, and re-read 20 pages up to where you'd been.
- **Return Visit** (monthly): re-read a book you've finished before and finish it again. Coming back soon pays more: 1500 XP within a month, 1000 within 3 months, 700 within 6, 400 after that, for the whole book. Re-reading part of it pays that share (half the book, half the XP); under a quarter doesn't count. A book already marked finished in KOReader counts from that date.

**Page guard (always on):** only pages you haven't read yet count. ReadMastery on its own counts every page turn, back or forward, so paging back and reading forward again paid XP, pages and quest progress twice. Back turns and re-reads now count no pages (the time still counts as reading time), and a turn that's partly new counts just the new pages. Flipping ahead doesn't count either: a new page you leave in under 4 seconds counts nothing and stays unread, so reading it properly later still counts. With Track Reading Location, using **Set Current Page As Reading Location** makes the pages after it unread again, so reading forward from your anchor always pays. It resets each time you open a book, so re-reading a book another day still counts.

Turning it OFF just pauses tracking and keeps progress. To reset quest progress, use ReadMastery's own **Settings → Reset Progress**, which also clears quest state and Quest Stats. This patch never opens or writes ReadMastery's `data.json` directly.

---

## Kobo Style Sleep Screen Banner

![Sleepscreen Banner](images/sleepscreen-banner.jpg)

Redesigns KOReader's banner-type sleep screen message to look like the Kobo lock screen tag, showing a random highlight from the current book.

- **Quote fallback:** books with no highlights show a random quote from a text file. Put `Famous Quotes.txt` at `/mnt/onboard/Famous Quotes.txt`, or change `file_path` at the top of the patch.
- **No repeats:** highlights and quotes each have their own no-repeat window, and the highlight window is per book — one book's highlights don't bleed into another's.
- **Seeded randomness:** a restart doesn't replay the same highlight order.
- **Live quote file:** edits to the quote file are picked up without restarting.
- **Nothing written on sleep:** it only reads highlights, so there's no settings flush each time the device sleeps.
- **Screenshot Next Sleep Screen:** a one-shot toggle at the end of Settings → Screen → Sleep screen. The next sleep screen is saved to KOReader's screenshots folder, then the toggle turns itself off.

Fonts, sizes, border, margin and max width are all set in the tables at the top of the file.

Credits: written with Discord user @sandcastles, with design cues from a patch by u/juancoquet.

---

## Track Reading Location

![Track Reading Location](images/track-reading-location.png)

Remembers the furthest page you've actually read. If you page back, or jump ahead through the table of contents, a small floating button takes you back. The button is drawn as an overlay, so it never blocks taps elsewhere.

- Backward: paging back more than one page (one at a time or in a single jump) shows a button at the bottom right. It stays up until you tap it or dismiss it.
- Forward: jumping ahead more than two pages at once, or skimming 4+ pages in quick succession, shows the same button at the bottom left. It hides itself after Off/15/20 (default)/30/50 seconds if you don't tap it. After it times out, the page you were on becomes the anchor, and a big jump after that (search, TOC, progress bar) gets the usual go-back button.
- Dismiss: tap the 'X' (or hold the button if the X is hidden) to make your current page the new saved spot.
- Layout: sits above KOReader's footer when the footer has its own space on screen.
- Position: on EPUB/FB2, position is tracked by xpointer, so font or margin changes don't point 'go back' at the wrong page.
- Saving: per book. It saves when you accept a page and when the device sleeps.

Menu: Reader menu → Navigation → Reading Location, with 'Go To Furthest Reading Location', 'Set Current Page As Reading Location' (both bindable to gestures), and Settings: Show Button On Screen, Show Full Text, Show Location/Page Number, Show Dismiss Button, Mode, Show Shadow, Bottom Offset, Side Offset, Button Radius, and Forward Popup Auto-Dismiss.

---

## Shortcuts Toolbar Icon Tweaks

![Shortcutstoolbar Icon Tweaks](images/shortcutstoolbar-icon-tweaks.png)
![Shortcutstoolbar Icon Tweaks 2](images/shortcutstoolbar-icon-tweaks-2.png)

Adds **Shortcuts toolbar → Icon tweaks** for the shortcutstoolbar plugin. Works in the reader menu, file-browser bar/persistent bar and the SimpleUI home-screen module, and doesn't modify any plugin files.

- **Custom icons:** swap any icon for your own SVG/PNG, or restore the original.
- **Colour mode**, globally or per icon: Default (follows Night Mode), Keep original (true colours in Night Mode), or Inverted.
- **On/off indicators**, per icon: follow Wi-Fi, frontlight, Night Mode, SSH server, Calibre connection, or a remembered tap toggle. Off/on styles: dim when off, inverted tile when off or on, or an alternate "off" icon.
- **Menu Toggle and Bluetooth indicators:** a custom shortcut set to a menu action follows that item's own checkmark, and Bluetooth follows the Kobo plugin's Bluetooth state.
- **Live network state:** the Wi-Fi icon and any Wi-Fi/SSH/Calibre indicator follow the real state, including background connects, failures, cancels, auto-disconnect and sleep.
- **Toolbar stays open** after tapping custom SSH, Wi-Fi, Calibre or Night Mode shortcuts, so you see the icon change. Other actions still close it.
- **Hold actions:** hold the built-in Wi-Fi button for the network list (Network Tweaks' picker when installed); hold the built-in Restart or Search button for Restart / Exit KOReader / Reboot / Power off; hold a custom SSH shortcut for Bluetooth from the Kobo plugin (turn it on or off, scan, paired devices); hold a custom Calibre shortcut to open BookOrbit directly; hold a custom Bookshelf shortcut to open BookOrbit directly. Tap does what it always did, unless flipped. Each hold action is its own group in Icon Tweaks → Hold Actions, with its own on/off and its own Flip Tap And Hold (tap runs the hold action, hold runs the button's normal tap). Off gives the plugin's own hold back; for a shortcut, that's its edit dialog.
- **Bluetooth notes:** the Kobo plugin's Bluetooth messages (scanning, on / off, failed to connect) show in Network Tweaks' note style (Banner / Minimal), like its Wi-Fi notes. With Normal, or without Network Tweaks, they stay as they are.
- **Sleep:** an open reader or library top menu closes when the device goes to sleep, so you wake to the page, not the menu.

Cost: icons you leave untouched get no hooks. Nothing runs in the background or while asleep.

---

## Shortcuts Toolbar Quick Shelf

![Shortcutstoolbar Quick Shelf](images/shortcutstoolbar-quick-shelf.png)

For the shortcutstoolbar plugin (reader menu only). Swipe left or right on the toolbar's top row to flip between the book info panel and a Quick Shelf strip of up to 5 books. Tap a cover to switch to that book. Two dots show which page you're on. Every menu open starts on the book panel.
- **Quick Shelf Shows:** Books In Progress (started and not finished, most recent first — the open book left out, progress under each cover) or the To Be Read collection. Switch it in Shortcuts toolbar → Quick Shelf Shows.
- Covers come from thumbnails SimpleUI or CoverBrowser already keeps. A book is never opened to pull its cover. A book with no saved thumbnail gets a title tile.
- **Cost:** nothing until you swipe. The strip builds on the first swipe of a menu open and is reused after that. Covers are kept already sized between menu opens, up to 10. A swipe redraws only the top row. No timers. Works alongside Shortcuts Toolbar Icon Tweaks.

---

## X-Ray Direct Lookup

**Discontinued.** xray.koplugin 26.10.23-beta and later includes this natively as "Auto-Popup on Highlight" (Settings → X-Ray Mode Settings). Delete `2-xray-direct-lookup.lua` and `debug/2-zz-xray-direct-lookup-diagnostics.lua` from your patches folder and restart.
---

## Reading Insights Tweaks

![Reading Insights Tweaks](images/reading-insights-tweaks.png)

Adds covers and goal shading to Reading Insights and the built-in Statistics calendar. Each feature has its own toggle, and toggles apply without a restart. Reading Insights 8.1+ already does streak covers, tap-a-day and the sleep screen itself, so this patch only adds what it doesn't.

1. **Book calendar header:** cover, title and author under the month title of the Book progress calendar.
2. **Heatmap goal shading:** heatmap shaded against your daily goal (darkest = goal met) instead of your busiest day.
3. **Record covers:** cover art for your records (most time in a day, most pages in a day, best streak). Tap one for book details or to open the book.
4. **Statistics calendar:** KOReader's built-in Statistics calendar gets covers instead of title bars and a time badge shaded by your daily goal. Tapping a day still opens its day view.
5. **Close on sleep** (on by default): Reading Insights and everything it opened (its popup, day lists, Achievements) close when the device sleeps, so waking shows your home screen or your book. Reading Insights' own sleep screen still shows.

**With Simple UI:** Reading Insights' full-screen pages (a day's books, Achievements, a year's books) keep Simple UI's home open under them, so closing them drops you back on the home screen, not the stock library.

**2.0.0 removed** the streak calendar covers, taller cover cells, tap-a-day and the sleep screen card (all native in Reading Insights 8.1+ now); their saved settings are cleared once on first start.

**Install:** copy `2-readinginsights-tweaks.lua` into `koreader/patches/` and restart once. Replaces `2-readinginsights-covers.lua` and `2-cover-calendar.lua` if you have them (delete those).

**Requirements:** Reading Insights plugin ([peterboda236/readinginsights.koplugin](https://github.com/peterboda236/readinginsights.koplugin)) 8.1 or newer installed, and CoverBrowser enabled. Covers come from CoverBrowser's cache; an uncached cover shows its title and appears the next time the view is drawn.

**Configuration:** Tools → Add-ons → Reading Insights Tweaks (with the Add-ons menu installed), otherwise Tools → Reading Insights Tweaks. Daily Reading Goal is adjustable in the same menu.

**How it works:** Reading Insights loads its files through the global `loadfile`. This patch wraps that for three of its view files: the book calendar gets a small source addition routing one function through here, while the heatmap and records views are patched on the module table they return. The Statistics calendar is patched when KOReader's Statistics plugin loads. Update-safe: every addition looks for exact source lines first, and if a Reading Insights update changes them, that feature is skipped (logged as `RI tweaks:`) and the stock view is used. Any error while drawing falls back to stock too.

**Cost:** nothing runs in the background. Work happens only when you open one of these views. Scaled covers are kept for the session (max 150), and the only timer is a one-shot 30s retry window after a missing cover was sent for extraction. Opening a window costs one quick check (to know Reading Insights' own), and at sleep only Reading Insights' open windows are closed.
## QuickMenu Toggle State

![Quickmenu Toggle](images/quickmenu-toggle.jpg)

When a multi-action gesture is set to "Show as QuickMenu", toggle actions get a checkbox in front — "✓" when on, "▢" when off (the same glyphs KOReader's own menus use, rendered as text so they always display). The marker goes first on purpose: the popup truncates long labels from the end.

- **Style tweaks:** any `style_tweak_*` toggle action (stock tweaks and custom CSS files) reads its live state from the current book. The `style_tweak_set_*` setter actions are left alone.
- **X-Ray Direct Lookup:** the `xray_direct_lookup_toggle` action reads the toggle's settings mirror.
- Renamed actions (custom names via "Rename QuickMenu actions") get marked too. With "keep menu open" on, checkboxes show the state from when the menu opened — reopen the menu to refresh. In the file browser (no book open), style tweak entries show without a checkbox.

---

## List Rating Progress

![List Rating Progress](images/list-rating-progress.png)

Adds a star rating and reading progress bar to CoverBrowser's list ("detailed list") view in the File Manager, History, and Collections. Drawn in the bottom-right of each book row, left of the dogear. Nothing is drawn for books that have never been opened.

- **Config:** show/hide stars, progress bar, and percentage; star size, bar height/width, and margins adjustable in the CFG table at the top of the file.
- Ratings and progress are read from each book's sidecar file. Books marked complete show 100%.

---

## Custom Quotes for SimpleUI

`Quotes.lua` has 300 famous quotes for SimpleUI's Quote of the Day module.

1. Copy it to `koreader/settings/simpleui/sui_quotes/`, creating the folders if needed.
2. In the module's settings, set Source → Custom and pick the file.

`Famous Quotes.txt` is a separate file for the sleep screen banner's quote fallback (see above).

---

## Screenshot Timer

![Screenshot Timer](images/screenshot-timer.jpg)

`2-screenshot-timer.lua` — tap a menu entry, and 10 seconds later the screen is saved to KOReader's screenshots folder. One shot per tap.

- **Menu:** Tools → Add-ons → Screenshot in 10 s (or Tools → Screenshot in 10 s without the Tweaks Menu).
- Tap it and the menu closes. 10 seconds later the screen is saved as `Screenshot_YYYY-MM-DD_HHMMSS.png`.
- Tap it again before the 10 s are up to cancel (shows a check mark while waiting).
- Going to sleep cancels it, so no timer waits through sleep.
- Nothing runs until you tap it. Temporary helper — delete the file when you're done.

---

## BookOrbit Tweaks

**File:** `2-bookorbit-tweaks.lua` · **Requires:** [bookorbit.koplugin](https://github.com/bookorbit/bookorbit) · **Version:** 2.11.0

Settings live under **Tools → BookOrbit Tweaks** (or **Tools → Add-ons → BookOrbit Tweaks** when the Add-ons menu patch is installed).

![BookOrbit Tweaks menu](images/bookorbit-tweaks-menu.png)
![BookOrbit Library Filter submenu](images/bookorbit-library-filter.png)
![BookOrbit Server Management submenu](images/bookorbit-server-management.png)
![BookOrbit Recently Added catalog, night mode covers](images/bookorbit-recently-added.png)
![BookOrbit Home dashboard, night mode covers](images/bookorbit-home.png)

### Navigation

- **Loop pages** — swipe past the last catalog or dashboard page to wrap to the first (and the other way). When looping is off, a swipe at either end does nothing and does not flash.
- **Reopen BookOrbit at** — *Where I Left Off* or *BookOrbit Home* when bringing an already-open catalog back (for example after sleep).
- Closing BookOrbit goes back to **SimpleUI home** if that's your start screen, instead of flashing the stock library. Works best with SimpleUI Tweaks 2.14.3+.

### After sleep / SimpleUI nav

BookOrbit closes cleanly when the device sleeps and when it wakes, so SimpleUI home can't leave a catalog stuck underneath it. Opening it from the SimpleUI nav bar or Shortcuts Toolbar after wake opens it fresh, on top.

### Library filter

Pick the library for the catalog (Books, not Comics, say) from the tweaks menu, instead of opening BookOrbit → Filter every time. **Refresh Library List** pulls the names from the server, and the active one is marked.

### Saved servers

- Save the current server, switch with a tap, **hold** for **Edit Server** (address, username, user key, display name) or **Remove**.
- Optional: show a server chooser inside BookOrbit **Settings → Account** (toggle under Server Management).

### Night mode covers

**Keep Covers Original In Night Mode** — catalog and dashboard covers keep their artwork instead of being inverted.

### Flash to reduce ghosting

Master **Enable Flash**, then choose what flashes:

| Option | Effect |
|---|---|
| Flash on page turns | Catalog and dashboard swipes |
| Flash on content load | Library / recent / section rebuilds |
| Flash on return to dashboard | Leaving library or recent for home |
| Flash on settings menu | Pull-down menu open and close |
| Flash on open | Single flash when BookOrbit opens |
| Flash frequency (1 / 2 / 3 / 5) | How often page turns trigger a flash |

Quick flashes are merged, so opening the catalog doesn't flash two or three times.

### Other

- Swipe south on the catalog does not close BookOrbit (top-edge pull-down still opens the menu).
- Title case labels in the tweaks menu.

Optional diagnostic: `debug/2-zz-bookorbit-diagnostics.lua` (shared `diagnostics.log` with the other debug companions).

---

## Credits

These patches wouldn't exist without the plugins they build on and the people behind them:

- **[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin)** by Doctor Hetfield — the home screen the SimpleUI Tweaks patch extends.
- **[Shortcut Toolbar](https://github.com/xusoo/shortcutstoolbar.koplugin)** by xusoo — the toolbar the Icon Tweaks and Quick Shelf patches customize.
- **[Reading Insights](https://github.com/peterboda236/readinginsights.koplugin)** by peterboda236 — the stats plugin the Reading Insights Tweaks patch builds on.
- **[ReadMastery](https://github.com/Lalocaballero/readmastery.koplugin)** by Lalocaballero — the gamification plugin the ReadMastery patches hook into.
- **[@sandcastles](https://discord.com)** (Discord) — co-wrote the Kobo-Style Sleepscreen Banner patch with TK.
- **[u/juancoquet](https://www.reddit.com/user/juancoquet/)** — design cues for the sleepscreen banner.

And [KOReader](https://github.com/koreader/koreader) itself, which makes all of this possible.











