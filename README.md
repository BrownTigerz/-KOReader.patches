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
| [SimpleUI Tweaks](#simpleui-tweaks) | `2-simpleui-tweaks.lua` | simpleui.koplugin | 2.14.16 |
| [SimpleUI Side Panel](#simpleui-side-panel) | `2-simpleui-sidepanel.lua` | simpleui.koplugin | 1.0.32 |
| [Reading Log Tweaks](#reading-log-tweaks) | `2-readinglog-tweaks.lua` | [readinglog.koplugin](https://github.com/stevenzamora1/reading-log) 1.4+ | 2.7.0 |
| [Critter phrases](#simpleui-tweaks) | `critter-phrases.lua` | SimpleUI Tweaks, Reading Log Tweaks, Quick Shelf | 1.2.0 |
| [Add-ons menu](#add-ons-menu) | `2-tweaks-menu.lua` | none | 1.2.0 |
| [Patch Backup & Restore](#patch-backup--restore) | `2-backup-patches.lua` | zip-capable KOReader build (2024+) | 3.2.0 |
| [Debugging Menu](#debugging-menu) | `2-debugging-menu.lua` | Add-ons menu | 1.3.6 |
| [Network Tweaks](#network-tweaks) | `2-network-tweaks.lua` | Kobo or Kindle for background connect | 1.12.1 |
| [ShelfSync Tweaks](#shelfsync-tweaks) | `2-shelfsync-tweaks.lua` | ShelfSync | 1.11.20 |
| [ReadMastery Notify](#readmastery-notify) | `2-ReadMastery-notify.lua` | ReadMastery | 1.0.6 |
| [ReadMastery Quests](#readmastery-quests) | `2-ReadMastery-quests.lua` | ReadMastery (Notify optional) | 1.0.6 |
| [Kobo Style Sleep Screen Banner](#kobo-style-sleep-screen-banner) | `2-kobo-style-sleepscreen-banner.lua` | none | 1.2.2 |
| [Track Reading Location](#track-reading-location) | `2-track-reading-location.lua` | none | 1.9.6 |
| [Shortcuts Toolbar Icon Tweaks](#shortcuts-toolbar-icon-tweaks) | `2-shortcutstoolbar-icon-tweaks.lua` | shortcutstoolbar.koplugin | 1.17.0 |
| [Shortcuts Toolbar Quick Shelf](#shortcuts-toolbar-quick-shelf) | `2-shortcutstoolbar-quick-shelf.lua` | shortcutstoolbar.koplugin | 1.5.1 |
| [X-Ray Direct Lookup](#x-ray-direct-lookup) | ~~`2-xray-direct-lookup.lua`~~ | xray.koplugin | discontinued |
| [Reading Insights Tweaks](#reading-insights-tweaks) | `2-readinginsights-tweaks.lua` | readinginsights.koplugin + CoverBrowser | 2.1.1 |
| [QuickMenu Toggle State](#quickmenu-toggle-state) | `2-quickmenu-toggle-state.lua` | none | 1.0.5 |
| [List Rating Progress](#list-rating-progress) | `2-list-rating-progress.lua` | none | 1.0.0 |
| [Screenshot Timer](#screenshot-timer) | `2-screenshot-timer.lua` | none | 1.0.0 |
| [Custom Quotes for SimpleUI](#custom-quotes-for-simpleui) | `Quotes.lua` | simpleui.koplugin | 1.0.0 |
| [BookOrbit Tweaks](#bookorbit-tweaks) | `2-bookorbit-tweaks.lua` | bookorbit.koplugin | 2.15.7 |

Versioning across the patches: `1.0.x` is a fix, `1.x.0` is a new feature, and `2.0.0` is a change that affects how existing saved settings or backups work.

## Diagnostic patches

The `debug/` folder holds temporary troubleshooting companions for the main patches (`2-zz-*-diagnostics.lua`). They change nothing — each one watches its main patch and writes timestamped, tagged lines to one shared log (`koreader/diagnostics.log`) for a short window after every start, then goes quiet, and stops entirely 24 hours after install. Manage them with the Debugging Menu (toggle, view, combine, delete). See [debug/README.md](debug/README.md).

---

## SimpleUI Tweaks

![Simpleui Currently Reading](images/simpleui-currently-reading.png)
![Simpleui Currently Reading 2](images/simpleui-currently-reading-2.png)

Colour and typography control for the SimpleUI home screen, plus a Night Mode "day look" for use with a light wallpaper.

Settings: Tools → SimpleUI Tweaks (or Tools → Add-ons → SimpleUI Tweaks with the Add-ons menu installed).

- **Modules:** text colour with a separate Night Mode colour, set for all modules and overridable per module. Recolour grey text, progress bar/ring/border colours per module, bold per module or all.
- **Currently Reading:** swipe left/right to step through your most recent books still in progress (4 by default, 2-6; finished ones skipped), with dots on the cover showing where you are. Tap opens the book shown. **Open Book From Cover Only** (Modules, off by default; 2.14.14, working since 2.14.15): only a tap on the cover opens it, a tap anywhere else on the module does nothing; tap the wrong spot four times in a row and the critter tells you (cutely) to tap the cover. Keep missing and it keeps changing its tip (2.14.16).
- **Tiny Critter bubble width** (SimpleUI 3.0): Modules → Critter Bubble Width — Default, **Dynamic**, Wide, Wider or Full Row, so longer lines fit on fewer rows. Its chat answers follow the bubble. **Dynamic** keeps SimpleUI's width for short lines and grows only as much as a long one needs (the critter and bubble then sit at the start of the row, like Full Row).
- **Tiny Critter insights** (SimpleUI 3.0): Modules → Critter Insights, on by default. The critter tells you about your reading: your best reading day this month, book milestones this year (5, 10, 25, 50, 75, 100, then every 50), getting back on a roll after a break, the book you're on being 25 minutes or less from the end, the finish rate your yearly goal needs ("20 books to go, 69 days left. About one every 3 days catches you up.", worded for on pace or catching up), a gentle nudge after 3+ quiet days, and whether you read more on weekends or weekdays. They wait for the critter like its own reactions (book finished, comeback), at most 3 a day, and only when your stats back them: a milestone when you finish that book (once a year each), back on a roll once per comeback, a nudge once per quiet stretch, goal pace and weekend reading once a week (weekend reading needs 4+ weekend and 8+ weekday reading days in 8 weeks, and doesn't flip-flop). Best day is in minutes read. One statistics read a day, no timers. Its chat no longer suggests the same book twice in a day. Needs the critter's Reactions on.
- **Side panel:** moved out in 2.14.6 — see SimpleUI Side Panel below.
- **Page Turn Flash** (SimpleUI Tweaks menu): SimpleUI turns home screen pages (page 1 to 2 and back) with a quiet update, so the old page can ghost through. **Normal** adds a quick flash to each turn; **Strong** a full refresh, which also clears dark pages and night mode. **Off** (default) keeps turns as fast as they are now.
- **Early Page Turn** (Page Turns, off by default): a sideways swipe turns the page once your finger has moved 35 dp (or 50 / 80), without waiting for the lift. Books in page mode, plus full-screen lists (file browser, history, collections, TOC, bookmarks, search) with **Also In Lists**. One turn per swipe; taps aren't changed. Turns itself off if `2-earlyturn.lua` is installed.
- **Tiny Critter pep talk** (SimpleUI 3.0): Modules → **Critter Pep Talk**, on by default. SimpleUI's "minutes read today" and "pages turned today" lines grow with your reading instead of always saying "Nice work.": a nudge after a minute or two ("1 minute read today. A start is a start."), a groove at 15 minutes, a cheer at half an hour, a party past an hour ("2.2 hours read today! Marathon mode."). With a daily goal set, it counts you in once you're within 10 minutes ("Just 7 minutes to your daily goal!"). The line moves up a step next time the home screen draws as you read; the wording changes with each new phrase. No timers.
- **Donny and Blu's own voice** (2.14.9, SimpleUI 3.0.2): Donny, Blu and Donny & Blu talk in their own voice like SimpleUI's critters (Suey, Hazel...): greetings, streaks, today's reading, books this year, the current book, your goal, Mondays, weekends. The lines are in `critter-phrases.lua` (its `voices` section, edit freely) and are used on the home screen and by Reading Log Tweaks. Critter Insights (2.14.10) get their own wording too (`insight_voices`): about half the time a milestone, record, quick win, comeback, pace or weekend insight is in their voice.
- **Critter Mix** (2.14.2): Modules → **Critter Mix**, tick two or more critters (say Donny, Blu and Donny & Blu) and they take turns: the next one each time the critter picks something new to say (about every 20 minutes, a new part of the day, or a tap). Reading Log's critter takes turns too: a new remark or a tap there moves it along (Reading Log 1.10.0+). Fewer than two ticked: SimpleUI's own pick.
- **More critter moods** (2.14.1): reading, proud, hungry, cozy, sipping, dreamy, festive, spooky (Donny and Blu have them, see Tiny Critters). A critter without one shows its base pose (reading as neutral, proud as cheer...) instead of plain neutral. Party is festive in December and spooky from October 25, when the critter has those pictures.
- **Critters Say Notifications** (off by default; one setting shared by Shortcuts Toolbar Quick Shelf, SimpleUI Tweaks and Reading Log Tweaks, switch it in any of their critter menus): when a notification (a short toast like "Wi-Fi on": KOReader's own, Network Tweaks' corner notes and banners that go away by themselves, BookOrbit's little pills) comes in while a critter is on screen, that critter says it in its bubble instead of the popup. The Quick Shelf critters (book panel, Quick Shelf, library tab bar) show it until their next remark, and let the popup through if it doesn't fit. Reading Log's Dashboard critter shows it until its next remark. The home screen's critter says it as a reaction, when no other reaction is waiting or on show and SimpleUI's reactions are on. Banners you can tap, BookOrbit's loading and warning pills, questions and failures always stay popups, and nothing shows over the sleep screen.
- **Critter phrases** (`critter-phrases.lua`, optional): put it in `koreader/patches/` next to the patch (the name has no number, so KOReader doesn't run it as a patch). Critter Insights and Critter Pep Talk then take their lines from it: several times as many, a little sassier, never guilt-trippy. Edit it to make the critter your own; Reading Log's critter uses the same file, and Quick Shelf's (1.1.0: reading stats and menu remarks). Missing or broken, the built-in lines are used (crash.log says which). It's on the patch updater (Check for Patch Updates → Extras) with its own version; updating replaces the whole file, so keep a copy if you've edited it. Don't call it `phrases.lua` or put it in `sui_critters/`: that's SimpleUI's own custom phrase file, in another format.
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

## SimpleUI Side Panel

![Simpleui Sidebar](images/simpleui-sidebar.png)
![Simpleui Sidebar 2](images/simpleui-sidebar-2.png)

The edge-swipe panel for the SimpleUI home screen, split out of SimpleUI Tweaks in 2.14.6. Swipe in from the right (or left) edge for your To Be Read list, KOReader collections, newly added books, history, and BookOrbit views; tap a book to open it, hold it to remove it. Pick the edge or turn it off, and set how close to the edge the swipe has to start, so ordinary swipes don't open it by accident.

Settings: Tools → SimpleUI Side Panel.

If you used the panel inside SimpleUI Tweaks, your panel settings carry over.

**Tap a book:** a small window shows its cover, title, author, status and a short description, with **Open**, **Open In BookOrbit** (when it's a BookOrbit book) and **Cancel**, so a stray tap never opens a book. Reading Log Tweaks can use the same window (Compact Book Detail).

**BookOrbit views are instant:** opening and swiping the panel never waits on the BookOrbit server. The list shows from what's saved, and when it's more than 30 minutes old (and Wi-Fi is on) it refreshes in the background and redraws in place, at most once per panel open (the view you stop on); views you swipe to after that show their saved list. A pending refresh is cancelled when the panel closes or the device sleeps.

The header shows the view's whole name: a long one ("Book Club Anthology", "BookOrbit Newly Added") wraps onto two lines at full size (one that nearly fits gets slightly smaller text instead), so it isn't cut off.

**BookOrbit books not on the device** (1.0.31): tapping one shows its cached cover and what BookOrbit knows about it (series, year, pages, the file, description; fetched in the background the first time), with **Download** (straight from BookOrbit into its download folder and layout, hash-checked and linked so it syncs, then offers to open it) and **BookOrbit**. Once downloaded it's on the device at once (1.0.32), here and in Reading Log: the window's first button says **Read**, **Continue Reading** or **Read Again**, and a BookOrbit book on the device gets **Remove From Device** (KOReader's own delete; it stays in BookOrbit).

**Covers for books not on the device** (1.0.30): a BookOrbit book you haven't downloaded shows its cover from BookOrbit's own cover cache (`koreader/cache/bookorbit/`, filled whenever BookOrbit shows a cover). One that isn't cached yet is fetched in the background with Wi-Fi on (a few at a time, into the same folder, so BookOrbit gets it too) and appears in place; offline it keeps the plain placeholder.

Its saved BookOrbit lists are shared with Reading Log Tweaks (1.0.18+), so BookOrbit collections can be picked there too.

## Add-ons menu

![Addons Menu](images/addons-menu.png)
![Addons Menu 2](images/addons-menu-2.png)

One **Tools → Add-ons** menu for plugins and patches, so Tools stays tidy. Moved plugins work exactly the same. Each patch sits with the plugin it tweaks:

| Group | What's in it |
|---|---|
| Home & Library | SimpleUI, SimpleUI Tweaks, SimpleUI Side Panel, Bookshelf, Shortcuts Toolbar |
| Reading | X-Ray, Page Scrubber, Glimpse, Footcream, Track Reading Location |
| Stats & Progress | ReadMastery (off by default: stays in Tools until you tick it), Reading Insights, Reading Insights Tweaks, Reading Log, Reading Log Tweaks, Book Card |
| Sync & Network | ShelfSync, BookOrbit, BookOrbit Tweaks, Network Tweaks |
| System | Storefront, Backup & Restore (Device Backup & Restore + Patch Backup & Restore in one menu, 1.2.0), Menu Disabler |
| Maintenance | Check For Patch Updates, Debugging, Screenshot in 10 s |
| Other / Patches | new plugins / new patches that don't say where they go |

Only what's installed shows; empty groups are hidden.

**Tweaks inside their plugin** (on by default): Simple UI is one entry (Open Simple UI, SimpleUI Tweaks, SimpleUI Side Panel), BookOrbit Tweaks sits at the bottom of BookOrbit's menu, Reading Insights Tweaks inside Reading Insights, and Reading Log Tweaks inside Reading Log. Device Backup & Restore and Patch Backup & Restore become one **Backup & Restore** entry with both menus in it (1.2.0). The plugins' own menus aren't changed. Turn it off with **Put Tweaks Inside Their Plugin** in Arrange Add-ons; moving one of these patches to another group takes just that one out.

- **Auto-collect:** newly installed plugins and patches that add a menu show up automatically, marked "New", with a one-time notice. Turn off **New Add-ons Show Up Automatically** to have them listed unticked instead.
- **Arrange Add-ons** (bottom of the list), applied after a restart:
  - tap an item to turn it on or off (off puts it back where it was)
  - hold an item: Move Up / Down, Move To Top / Bottom, or Move To Another Group
  - tap a group name: move the group up or down, rename it, delete it (groups you added), or go back to its original name
  - **Add Group…**: your own group header; hold items to move them in
  - **Sort Items:** Custom (your order) or A To Z (inside each group)
  - **Put Tweaks Inside Their Plugin:** on or off (see above)
  - **Reset Layout:** groups, names, order and moved items back to the defaults (on/off choices stay)
  - **Reset Everything To Default:** the whole menu back to a fresh install: every item in its usual group and turned on, your own groups and names gone
- **Safe to remove:** KOReader's menu order stays untouched. Delete the file and restart and every menu goes back where it was. Only your Add-ons choices are saved, in `settings.reader.lua`. IDs that don't exist are skipped, and items hidden with Menu Disabler stay hidden.

For patch authors: register with the shared table at `package.loaded.tweaks_mods`. The format is documented at the top of the file; `group = "Reading"` picks the default group. Return an item with `sub_item_table_func` so large menus are only built when opened.

---

## Patch Backup & Restore

![Patch Backup Menu](images/patch-backup-menu.png)

One-tap backup of everything your patches are (files, settings, icons), undo for patch updates, per-patch backups, icon cleanup, and better device backups via Device Backup & Restore (`backup.koplugin`, build 26.9.29+ for icons). Tested with backup.koplugin 26.10.23; recheck after a major update to it, SimpleUI or ShelfSync, since this patch relies on how they store settings and logins.

Menu: **Tools → Patch Backup & Restore**. With the Add-ons menu (1.2.0+) it's in **Tools → Add-ons → System → Backup & Restore**, one menu with Device Backup & Restore.

```
Patch Backup & Restore
├─ Auto-Backup After Updates       toggle (off): keeps the last N Everything zips
├─ Logins In Device Backups        toggle (off)
├─ Include In Everything           Patch Files · Settings · Icons · SimpleUI Quotes
├─ Keep Last N Everything Backups
├─ Back Up Now                     Everything, or one patch or plugin
│                                   (hold a row: what goes in)
├─ Backups (N)                     every backup + every patch file an update
│                                   replaced, newest first; tap: restore / put
│                                   back / delete; hold: what's in it
├─ Copy Latest Everything          to a folder you pick
├─ Icons                           Tidy Icons (or Tidy All), Unused Icons
└─ Check for Patch Updates         (here when the Add-ons menu isn't installed)
```

**What gets saved, and what doesn't.** Everything brings your patches back the way you had them. It doesn't bring back the whole device: KOReader's own settings (fonts, gestures, refresh), other plugins, book progress, highlights and stats are Device Backup & Restore's job. Saved logins are never in a patch backup.

- **Everything:** one zip (`koreader/backups/everything/`) with every file in `patches/` and `patches/debug/` (so `critter-phrases.lua` too), SimpleUI's `sui_quotes/` folder, and every patch's and plugin's settings, settings files and icons (see the targets below). **Include In Everything** (3.2.0, all on) leaves out Patch Files, Settings, Icons or SimpleUI Quotes; safety backups always take everything. **Restore** puts it all back (patches you added since stay), after an "everything before restore" backup, then asks to restart. On a new device, the settings of patches that came back with the restore are applied on the next start, once they've loaded.
- **One patch or plugin** (Back Up Now → its name): its settings, any settings files it keeps in `koreader/settings/`, and every icon its settings point to, in `koreader/backups/<target>/<target>_<date>.zip`. Not its patch file; Everything has those.
- **Backups** (3.2.0): one list of every backup (Everything, each patch or plugin, the automatic Before Restore / Before Tidy ones) and every patch file Check for Patch Updates replaced (the last 3 of each, in `koreader/backups/patch-updates/`), newest first. Tap a backup for **Restore** (Everything also: only Patch Files, only Settings, only Icons, Settings & Icons), **What's In It** and **Delete**; tap a replaced file for **Put Back** (the version you have then is kept too) or Delete. **Hold** any row to see what's in it. **Delete All Backups** sits at the top (replaced files and Device Backup & Restore's backups aren't touched).
- **Restore:** puts settings and files back, unpacks icons into the target's icon folder and repoints settings there. Takes a "before restore" safety backup first (and stops if it can't be made or read back), then asks to restart.
- **Auto-Backup After Updates** (off by default): a quiet Everything backup after a successful patch update or Tidy. While it's on, only the newest few Everything backups are kept (**Keep Last N**, default 5); safety backups are never deleted. Off: nothing is made or deleted on its own.
- **Copy Latest Everything:** copies the newest Everything zip to a folder you pick (a USB or sync folder), for moving to another device.
- **Tidy icons:** copies every icon a target uses into its own flat folder (`koreader/icons/<target>/`; SimpleUI uses its own `sui_icons/`) and repoints settings there. Originals stay put. Takes a "before tidy" backup first.
- **Unused icons:** icons nothing points to, across `koreader/icons/` subfolders and SimpleUI's `sui_icons/` (packs included). Delete one at a time or all at once; emptied folders and packs go too. Loose files directly in `koreader/icons/` and KOReader's built-in icons are never touched.
- **Notifications:** with Network Tweaks installed, results (backed up, deleted) follow its notification style: Banner, Minimal corner note, or Normal popup. Questions, restart prompts and failures always stay popups.
- **Check for Patch Updates:** updates every patch on the device, plus `critter-phrases.lua` and `Quotes.lua` (listed under Extras; Quotes.lua in `settings/simpleui/sui_quotes/`), from this repo's `patch-versions.lua` manifest (one line per file, bumped each release) over Wi-Fi — no login, no Google Drive. Every patch is listed under Patches / Diagnostics headings as Up to Date, version → version, Installed Is Newer, Not Installed or Unknown Version; rows are tappable — tapping one pops up its actions: Update / Reinstall / Install depending on its state, plus Remove for any installed patch (except the updater itself; removing a main patch offers to also remove its paired diagnostics file). Update All is always listed (with nothing outdated it just says so). Updates never roll a patch back — they only go into `koreader/patches/` (a diagnostic updates where its copy sits: `patches/` if active, `patches/debug/` if switched off), showing each patch name as it downloads, with a success/failure summary, then asks to restart. Wi-Fi turns on automatically if off and stays on afterwards.

**Device Backup & Restore integration:** with Settings and Icons ticked, every icon a target uses is included (wherever it lives) plus a map of its old paths, so the icons work on another device too (Kobo, Kindle, Android). The Logins toggle is off by default: saved logins, session tokens and the keys that decrypt them (ShelfSync, ShelfSync tweaks, backup cloud credentials) are excluded, including from Beam. Files that mix tokens with normal settings go in with only the tokens stripped, and a restore keeps the device's own logins. Turning it on includes everything, so keep that backup file private.

Patches that register themselves: SimpleUI Tweaks, Reading Log Tweaks, BookOrbit Tweaks (saved server logins left out) and Network Tweaks. Built-in targets: Shortcuts toolbar (with Quick Shelf and Icon Tweaks), SimpleUI Side Panel, Track Reading Location, Add-ons menu, Reading Insights tweaks, ReadMastery Notify/Quests, ShelfSync tweaks (settings only, never logins), SimpleUI, **Reading Log** (3.2.0: its own settings file, so your pages, cards, tabs, theme and goals; Reading Log Tweaks' keys stay with that patch) and **BookOrbit** (3.2.0: the plugin's settings without its sign-in or caches; a restore keeps the device's own sign-in). A patch that registers the same id replaces the built-in one. Targets you don't use stay hidden.

**For patch authors, add a target:**
```lua
local BK = package.loaded.backup_patches or { targets = {} }
package.loaded.backup_patches = BK
BK.register{            -- or table.insert(BK.targets, {...}) if not loaded yet
    id = "mything", text = "My thing",
    setting_prefix = "mything",     -- optional: G_reader_settings keys
    setting_prefixes = { "a_", "b_" }, -- optional: several prefixes
    skip_keys = { "mything_cache" },   -- optional: keys left out (logins, caches)
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
- **ShelfSync All: Update Progress** (gesture), turns Wi-Fi on if needed, syncs every linked, enabled provider that tracks reading progress (one retry each — LibraryThing doesn't track progress, so it's skipped), lists providers still unlinked, then BookOrbit syncs the same book if it's installed, then turns Wi-Fi back off if it turned it on. ShelfSync's built-in "Update progress for all linked books" also turns Wi-Fi on first, chains BookOrbit the same way, and off after.
  A sync can't hold Wi-Fi on forever: a 2-minute safety net (60 s for the BookOrbit step) ends it. Going to sleep ends a sync that's still running: its timers stop and it's wrapped up right there (sleep turns Wi-Fi off itself), so nothing waits through sleep and nothing turns Wi-Fi off after you wake.
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
- **Book Panel Tap** (Shortcuts toolbar → Book Panel Tap, off by default): **Opens BookOrbit "This Book"** makes a tap on the book panel open BookOrbit's This book sheet (sync status, Sync now, progress) instead of KOReader's book details. **Hold Opens Book Details** (on by default) keeps the details a long-press away. Without BookOrbit, a tap does what it always did.
- **Critter Remarks** (Shortcuts toolbar → Critter Remarks, all off by default). It's the critter your home screen shows (SimpleUI Tweaks' Critter Mix when you've ticked two or more, else the one picked in SimpleUI), in its own voice about half the time when it has lines (Donny, Blu, Donny & Blu):
  - **While Reading:** a speech bubble in the book panel's free strip under the title, author and page line, about where you are in this book: pages and time left (at your usual pace), the chapter ending, how fast you're going this sitting against your usual ("Wow, you're flying!" / "Slow going today."), long and late sessions, a quarter / halfway / home stretch, the finish, and sweet little remarks any time ("I like reading with you."). It picks what fits right now and never the same thing twice in a row. Sized to the strip, so it never covers the text. Tap the critter for another remark.
  - **On Quick Shelf** (follows While Reading until you choose): the critter on the Quick Shelf (swipe the book row), talking about the books on it: a different one each time ("How's “Dune” going? It's at 31%."), the one nearly done, how many you have going, an empty To Be Read. Tap it for another remark. Pick how: **Under Small Covers** (covers the height of the book panel's title, author and page lines, so more fit, and the critter always shows in the row under them) or **Beside Full Covers** (full-size covers, the critter in the room they leave on the right, gone once they fill the row), or **Off**.
  - **On Library Toolbar:** the critter in the empty stretch of the file browser menu's tab bar, before the last tab icon. It notices the tab and submenu you open (fonts, Wi-Fi, the sleep screen, your Add-ons and more) and has something to say about it; on the toolbar's home view, a remark for the time of day. Tap it for another remark.
  - **Critters Say Notifications:** see SimpleUI Tweaks; one setting for every critter, also under Critter Remarks here.
  - The lines are in `critter-phrases.lua` 1.1.0+ (`reading`, `reading_voices`, `shelf`, `shelf_voices`, `menus`, `menu_voices`, `menu_words`; edit freely, it's on the updater). Without it a few built-in lines stand in. Pace remarks (fast / slow / time left) need KOReader's reading statistics on. Some lines use your name ("Bedtime, TK."): the one you gave SimpleUI's critter under **Your name** in its settings; without a name those lines are skipped.
  - Without SimpleUI 3.0's critter it's the remark alone.

---

## Reading Log Tweaks

**File:** `2-readinglog-tweaks.lua` · **Requires:** [stevenzamora1's Reading Log](https://github.com/stevenzamora1/reading-log) 1.4+ (`readinglog.koplugin`) with Simple UI · **Version:** 2.7.0

Extras for Steven's Reading Log on Simple UI. It hooks his plugin from the outside and doesn't change its files; his Bookshelf cards aren't touched.

Settings: long-press the Dashboard → **Reading Log Tweaks**, or **Tools → Add-ons → Stats & Progress → Reading Log** (with the Add-ons menu). Everything is saved in Reading Log's own settings file (keys starting `rlt_` and `critter_`; 2.0.2 moves older `tk_` settings over once).

- **Smart Cards** (2.2.0, three more in 2.5.0): cards for Pages And Cards that each show whichever card of their group matters right now. It's decided when you come back to the Dashboard (a book closed, waking, turning back onto its page), never while you're looking; the first rule that's true wins, and when none is, the next card in turn. Only the rules pick it (2.5.2): there are no dots, and a swipe on a smart card does what it does anywhere on the Dashboard (next tab with Swipe Between Tabs, or SimpleUI's other home page). Two smart cards on one page never show the same card. Continue reading is never moved. **Pages And Cards → Smart Cards On Today And Monthly** swaps Activity → Smart Activity, This week → Smart This Week (Today page) and Pages per day → Smart Month (Monthly page) in one tap; tap again to put them back.

  | Smart card | Shows | When |
  |---|---|---|
  | **Current Book** | Finish forecast | a book in progress is 2 hours or less from done |
  | | Today's timeline | after 6 PM, with 2+ sessions today |
  | | This Book | you've read today |
  | **Goals** | Finish by | its date is within 7 days, or past (left out without a book and date) |
  | | Year Goal With Covers | you finished a book in the last 3 days, or you're a book or more behind pace |
  | | Monthly challenge | the month's last 7 days, challenge not done |
  | | This week vs last | the first 2 days of your week |
  | **Shelf** | Recently finished | you finished a book in the last 3 days |
  | | Book club | the first 7 days of the month |
  | | Random pick | nothing read today or the 2 days before |
  | | TBR shelf | only one book in progress |
  | **Smart Activity** | Today's timeline | after 6 PM, with 2+ sessions today |
  | | Finish forecast | a book in progress is 2 hours or less from done |
  | | Activity | today's minutes are under your daily goal |
  | **Smart This Week** | Finish forecast | a book in progress is 2 hours or less from done |
  | | Today's timeline | after 6 PM, with 2+ sessions today |
  | | This week | the 5th day of your week or later |
  | **Smart Month** | Monthly challenge | the month's last 7 days, challenge not done |
  | | This week vs last | the first 2 days of your week |
  | | Pages per day | you've read today |

  Your own picks stay the Today Page Card's swipe spot (below).
- **This Book** (2.1.0): a card for the book you're on: time spent on it, sessions this week, pages today, your pace, and when you'll finish at the pace you've read it the last two weeks ("Done by Thu Dec 24 · 4 h 1 m left"). From KOReader's statistics, read again only when they change. Add it to any page in Pages And Cards, or pick it as the Today Page Card. Tap the cover for details, anywhere else to open the book.
- **Today Page Card:** the card under the rings on the Today tab: Year Goal With Covers, This Book, Year Goal, Book Club, Recently Finished or TBR Shelf. Or **Swipe Between 2-3 Cards**: tick up to 3, then swipe left/right on the card or tap its dots.
- **Year Goal With Covers:** the year goal on the left, this year's covers on the right, a pace bar along the bottom. Also in Pages And Cards and as its own Simple UI module.
- **Continue Reading: Buttons Only** (off by default): the Continue Reading card opens the book only from its Continue button (or the cover, in the looks where the cover is the button); Details shows the details and the dots flip books. A tap anywhere else on the card does nothing.
- **Book Club**
  - **Book Club Collections** (the card's own by default): tick one or more collections, KOReader's and BookOrbit's, and the Book Club card and its picks chooser use all their books together.
  - **Book Club Opens Picks** (Off by default, On Hold or On Tap): go straight to choosing this month's books (Reading Log's own chooser). On Hold: long-press the card, and a tap on a pick still opens that book. On Tap: any tap on the card.
- **Hold A Cover For Quick Actions** (2.1.0, on by default, under Books): long-press a book's cover on the Dashboard for **Open**, **Book Details**, its status (**Reading / On hold / Finished**, like KOReader's file browser), **Add To / Remove From To Be Read** and **Collections…**. Works on any card whose covers open a book.
- **Book Tap Opens:** what a tap on any book cover does, on every Reading Log card. **Compact Detail** (the default with SimpleUI Side Panel 1.0.26+, since 2.3.0): the same compact window as the side panel (cover, author, description, Open / BookOrbit / Cancel). **BookOrbit**: its page in BookOrbit, when BookOrbit has the file. **Reading Log's Own**: its own details or opening the book. Continue reading's cover follows it too (2.5.0); its **Details** button always shows Reading Log's own simple details (2.5.2), and its Continue button (and the hold menu's Open) always opens the book.
- **Random Pick Includes BookOrbit** (Books, 2.6.0, on): books in your BookOrbit library that aren't on this device can be the Random pick (not when the pick is limited to a collection or genres), with their BookOrbit cover. Tap one for the compact window with **Download** and **BookOrbit** (Book Tap Opens: BookOrbit goes straight to its page). Needs SimpleUI Side Panel 1.0.31 for covers and Download. The list is kept on the device and refreshed in the background with Wi-Fi on, at most every 6 hours.
- **Library Card Takes Turns With Collecting Dust** (Books, 2.7.0, on): on the Library page, the Library card swaps with **Collecting Dust**: BookOrbit books you haven't started, the ones added longest ago first, a different few each time, so you've got more to choose from. It changes when you come back (a book closed, waking, another tab or home page), never while you're looking. Tap a cover for the compact window (Download, BookOrbit). Needs Random Pick Includes BookOrbit.
- **Quote Of The Day** (Books, 2.5.0): **SimpleUI's Quotes** (the default) fills the Quote of the day card from where SimpleUI's own Quote of the Day module takes its quotes: its built-in list, or the file you picked from `settings/simpleui/sui_quotes/` (like [Quotes.lua](#custom-quotes-for-simpleui)). One a day; **Another** shows the next. When SimpleUI's module is set to your highlights, or SimpleUI isn't there, it's one of your highlights. **Your Highlights**: Reading Log's own.
- **When You Come Back**
  - **Start On Tab** (Last Viewed by default): which Dashboard tab shows when you come back to it, after a book, after sleep or turning back onto its page. When SimpleUI shows the home screen again without rebuilding it (after sleep, or after a book with Fast Book Closing), the Dashboard is rebuilt once so the tab (and the Today card's Alternate) actually changes.
  - **Start On First Page After Reading Or Sleep** (off by default): opening a book or sleeping sends SimpleUI's home screen back to page 1.
- **BookOrbit** (shown only with BookOrbit installed)
  - **BookOrbit Collections** (on by default, needs SimpleUI Side Panel 1.0.18+): your BookOrbit collections show next to KOReader's wherever Reading Log asks for a collection (the Book Club card's Collection and picks, the shelf cards), as "BookOrbit: <name>". The books come from the Side Panel's saved BookOrbit lists, so open a collection's view in the Side Panel once to fill it. Only books on this device are listed; nothing waits on the BookOrbit server.
- **Critter Remarks:** Simple UI 3.0's Tiny Critter peeks into each Dashboard page with a remark about that page's numbers and suggests books. Tap it to talk. On the first two days of the week (Reading Log's week start) it leads Today with a **weekly recap** once: last week's time, books finished and best day (2.1.0; Donny, Blu and Donny & Blu say it their own way with `critter-phrases.lua` 1.2.0). Uses `critter-phrases.lua` when it's in `patches/`. Each of these has its own switch under Critter:
  - **Critter's Own Voice** (Simple UI 3.0.2): Suey, Chonk, Tulu, Frankie, Vlad, Sholmes, Argos and Hazel say about one remark in three their own way, on the pages their lines fit. Donny, Blu and Donny & Blu join in with SimpleUI Tweaks 2.14.9+ and `critter-phrases.lua`, and since 1.1.2 the page insights (comeback, a run of days, best day this month, milestone, goal pace, weekend reading) are in their voice about half the time.
  - **Games And Quotes** (Simple UI 3.0.2): in the talk window, Let's Play (rock, paper, scissors; heads or tails; guess the author) and Read Me A Quote. The critter's last word shows in the bubble.
  - **Critter Rewards:** drawn beside the critter here and on the home screen: a stack of books at 5, 10, 25 and 50 books this year, a medal at a 7-day streak and a trophy at 30, and a balloon on your reading anniversary.
- **Fine Tuning:** Layout (In The Page or Full Screen, filling everything between the status bar and the nav bar), Bottom Space, and **Move Tab Row** (2.0.3): down moves the Today / Monthly / ... tabs away from the cards toward the page dots (into the margin, and in Full Screen into the room Bottom Space adds; past that the cards get shorter), up moves them closer. Its own setting, separate from Reading Log 2.0's Tab Bar Position. **Swipe Between Tabs** (2.1.0, off by default): swipe left or right on the Dashboard for the next or previous tab; at the first or last tab the swipe turns Simple UI's page as usual, and the Today Page Card's swipe cards still flip on their own. **Enter From The Side You Swipe From** (2.5.3, on): swiping from another Simple UI page onto the Dashboard lands on its first tab when you swipe left and its last tab when you swipe right.

Delete the file and restart to undo (Pages And Cards → Put This Page Back fixes a swipe slot left behind).

Optional diagnostic: `debug/2-zz-readinglog-tweaks-diagnostics.lua` (how long each card, tap, Random pick and cover takes; shared `diagnostics.log`).

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

It's on the patch updater (Check for Patch Updates → Extras) with its own version; updating replaces the whole file, so keep a copy if you've edited it.

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

**File:** `2-bookorbit-tweaks.lua` · **Requires:** [bookorbit.koplugin](https://github.com/bookorbit/bookorbit) · **Version:** 2.15.7

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

**Keep BookOrbit Open Through Sleep** (off by default) — BookOrbit stays open through sleep and comes straight back after wake instead of reloading. Only its menu sheets and pop-ups close on sleep; SimpleUI home is moved out of the way when you open it again.

### Library filter

Pick the library for the catalog (Books, not Comics, say) from the tweaks menu, instead of opening BookOrbit → Filter every time. **Refresh Library List** pulls the names from the server, and the active one is marked.

### Saved servers

- Save the current server, switch with a tap, **hold** for **Edit Server** (address, username, user key, display name) or **Remove**.
- Optional: show a server chooser inside BookOrbit **Settings → Account** (toggle under Server Management).
- **Enter A Different Address** from the server chooser opens the address entry on the first tap — no double chooser.
- Second swipe down on the BookOrbit settings sheet opens the tools menu.

### Flash

Flashes only fire while BookOrbit is the window on top (no stray flash on the file browser while it's loading), and the flash spacing runs on real time.

### Night mode covers

**Keep Covers Original In Night Mode** — catalog and dashboard covers keep their artwork instead of being inverted.

### Add To Collection

**Add To Collection In Book Menu** (on by default) — hold a book in a list (the sheet gets an **Add To Collection** row), or tap ⋯ at the top right of a book's page (**Add To Collection**, above Refresh from BookOrbit; 2.15.3). It lists your BookOrbit collections with ✓ on the ones the book is already in; tap one to add or remove the book, or **New Collection…** to make one with the book in it.

BookOrbit's KOReader sign-in can't change collections, so this signs in the way the web app does, with your BookOrbit **website** username and password (asked the first time). That's not your KOReader sync login: BookOrbit keeps that as a separate account, often with a different username, so the box starts empty (2.15.1) and remembers the website username after. The sign-in box has a **Save password on this device** tick (2.15.2; remembers your last choice). Only a sign-in BookOrbit accepted gets saved, AES-encrypted with a key in its own file (the way ShelfSync Tweaks keeps its logins). The saved password and its key are never in Patch Backup & Restore's backups or device backups. The encryption stops someone casually browsing your files, not someone with full access to the e-reader, since the key is on the same device. Before the password is first asked for, a notice spells all this out (also under **About The Saved Password**). **Forget Saved BookOrbit Password** clears it. Results (added, removed, saved) follow Network Tweaks' notification style; questions and failures stay popups.

### Open Book Only From Buttons

**Open Book Only From Buttons** (off by default) — on the dashboard, only the Resume / Download pill and the round play button open the book. A tap anywhere else on the Continue Reading tile (cover, title, progress) does nothing.

### Action colours

**Action Colours** — three colours, each White (BookOrbit's own look) by default:
- **Continue Reading:** the Resume / Download pill and the round Download button on the dashboard.
- **Book Detail:** the Start reading / Read again / Resume buttons on a book's page.
- **Dialogs:** the main button in BookOrbit's bottom sheets and the open-book dialog.

If you'd only set the old Resume Pill Colour, Book Detail and Dialogs start with that colour until you pick their own. Light colours keep the black icons readable; for the solid buttons Blue, Pink, Gold or Lavender read best. On a colour screen each tinted button gets a dithered refresh of its own area, so the colour looks the same on a book's page and in dialogs as on the dashboard. **Pill Colour Trace (crash.log)**, off by default, logs which buttons got a colour, for troubleshooting.

### Flash to reduce ghosting

Master **Enable Flash**, then choose what flashes:

| Option | Effect |
|---|---|
| Flash on page turns | Catalog and dashboard swipes |
| Flash on content load | Going to a new list or section (not a book's page since 2.15.5, and not redraws of the same page: download progress, sync, sheets, ratings) |
| Flash on return to dashboard | Leaving library or recent for home |
| Flash on settings menu | Pull-down menu closing (2.15.4: no flash opening it) |
| Flash on open | Single flash when BookOrbit opens |
| Flash frequency (1 / 2 / 3 / 5) | How often page turns trigger a flash |

Quick flashes are merged, and since 2.15.4 there's never more than one flash every 1.5 seconds (page turns with Flash Frequency aside), so opening the catalog, a book or the menu doesn't flash two or three times. **This book** (from a book's menu or the toolbar's book panel): Sync now doesn't redraw the sheet while it syncs, just once at the end with the result (2.15.6), and the chip shows Synced just now right away instead of after reopening it. Since 2.15.5 it also skips the redraws that show nothing new. **Downloading on a book's page** (2.15.7): the button's switch to progress and back only refreshes the button; the whole page updates once, when the book is on the device.

### Other

- Swipe south on the catalog does not close BookOrbit (top-edge pull-down still opens the menu).
- Title case labels in the tweaks menu.

Optional diagnostic: `debug/2-zz-bookorbit-diagnostics.lua` (shared `diagnostics.log` with the other debug companions).

---

## Credits

These patches wouldn't exist without the plugins they build on and the people behind them:

- **[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin)** by Doctor Hetfield — the home screen the SimpleUI Tweaks patch extends, and the Tiny Critter whose 3.0.2 voices system critter-phrases.lua builds on.
- **[Shortcut Toolbar](https://github.com/xusoo/shortcutstoolbar.koplugin)** by xusoo — the toolbar the Icon Tweaks and Quick Shelf patches customize.
- **[Reading Insights](https://github.com/peterboda236/readinginsights.koplugin)** by peterboda236 — the stats plugin the Reading Insights Tweaks patch builds on.
- **[ReadMastery](https://github.com/Lalocaballero/readmastery.koplugin)** by Lalocaballero — the gamification plugin the ReadMastery patches hook into.
- **[@sandcastles](https://discord.com)** (Discord) — co-wrote the Kobo-Style Sleepscreen Banner patch with TK.
- **[u/juancoquet](https://www.reddit.com/user/juancoquet/)** — design cues for the sleepscreen banner.

And [KOReader](https://github.com/koreader/koreader) itself, which makes all of this possible.












