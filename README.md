# KOReader Patches

User patches for KOReader, mostly tested for Kobo Clara Color. Each one is a single file that patches KOReader or a plugin in memory. Nothing on disk is modified, so deleting a file and restarting fully reverts it.

## Install

Copy the `2-*.lua` files you want into KOReader's patches folder and restart KOReader.

- Kobo: `.adds/koreader/patches/`
- Kindle: `koreader/patches/`
- Android: `koreader/patches/`

Create the folder if it doesn't exist. The `2-` prefix is required — KOReader only loads patches whose names start with a supported priority number (`0`, `1`, `2`, `8`, `9`); `2-` is the one that runs after the UI is ready, which is what these patches need. Patches don't work on the F-Droid build of KOReader.

All patches work independently and together. If one fails to attach (for example, after a plugin update), it logs to `koreader/crash.log` and leaves things as they were.

| Patch | Requires | Version |
|---|---|---|
| [SimpleUI Mod](#simpleui-mod) | simpleui.koplugin | — |
| [Tweaks & Mods menu](#tweaks--mods-menu) | — | — |
| [Patch Backup & Restore](#patch-backup--restore) | zip-capable KOReader build (2024+) | — |
| [ShelfSync Tweaks](#shelfsync-tweaks) | ShelfSync | — |
| [ReadMastery Notify](#readmastery-notify) | ReadMastery | — |
| [ReadMastery Quests](#readmastery-quests) | ReadMastery (+ Notify optional) | — |
| [Kobo Style Sleep Screen Banner](#kobo-style-sleep-screen-banner) | — | v2.2.0 |
| [Track Reading Location](#track-reading-location) | — | v1.7.2 |
| [Shortcuts Toolbar Icon Tweaks](#shortcuts-toolbar-icon-tweaks) | shortcutstoolbar.koplugin | — |
| [Custom Quotes for SimpleUI](#custom-quotes-for-simpleui) | simpleui.koplugin | — |
| [Reading Insights Tweaks](#reading-insights-tweaks) | readinginsights.koplugin + CoverBrowser | v1.3.0 |

---

## SimpleUI Mod

Colour and typography control for the SimpleUI home screen, plus a Night Mode "day look" for use with a light wallpaper.

Settings: Tools → SimpleUI Mod (or Tools → Tweaks & Mods → SimpleUI Mod with the Tweaks menu installed).

- **Modules:** text colour (with a separate Night Mode colour), recolour grey text, progress bar/ring/border colours per module, bold per module or all.
- **Section titles:** defaults for all sections, then per-module colour, bold and size (preset or custom 50–300%). A `•` marks customised sections.
- **Nav bar:** bold labels, day look in Night Mode, colour icons keep their original colours in Night Mode.
- **Status bar:** bold, and day look in Night Mode.

Colours are picked as they should look on screen; Night Mode inversion is handled for you. Night Mode switches and status bar bold apply instantly — everything else asks for a restart.

**Notes**
- Wallpaper: turn off SimpleUI's own wallpaper Night Mode inversion, since black text needs a light background.
- Module fill: with a light wallpaper, set module backdrop/fill to 0, or text can disappear in Night Mode.
- Colour nav icons need a non-Framed nav bar style (Framed draws icons in one colour but still gets the day look).
- Icon files: use SVG icons with transparency.
- Section title sizes multiply SimpleUI's own label scale (Scale → Labels).

**Uninstall:** use Reset to defaults if you want the saved settings (`simpleui_mod` in `settings.reader.lua`) removed, then delete the file and restart.

---

## Tweaks & Mods menu

Declutters Tools by gathering plugin menus and patch settings into one **Tools → Tweaks & Mods** submenu.

For patch authors: register with the shared table at `package.loaded.tweaks_mods`. The format is documented at the top of the file. Return an item with `sub_item_table_func` so large menus are only built when opened.

---

## Patch Backup & Restore

Per-patch backups, icon cleanup, and better device backups via Device Backup & Restore (`backup.koplugin`, build 26.9.29+ for icons).

Menu: **Tools → Patch Backup & Restore** (or **Tools → Add-ons → Patches** with the Tweaks & Mods patch installed, once `backup_patches` is in its `PATCH_MENUS` list).

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
└─ Logins in device backups        off by default
```

- **Back up now:** the target's settings, any settings files it keeps in `koreader/settings/`, and every icon its settings point to, in one zip at `koreader/backups/<target>/<target>_<date>.zip`.
- **Restore:** puts settings and files back, unpacks icons into the target's icon folder and repoints settings there. Takes a "before restore" safety backup first, then asks to restart. "Restore latest" skips those automatic safety backups.
- **Tidy icons:** copies every icon a target uses into its own flat folder (`koreader/icons/<target>/`; SimpleUI uses its own `sui_icons/`) and repoints settings there. Originals stay put. Takes a "before tidy" backup first.
- **Unused icons:** icons nothing points to, across `koreader/icons/` subfolders and SimpleUI's `sui_icons/` (packs included). Delete one at a time or all at once; emptied folders and packs go too. Loose files directly in `koreader/icons/` and KOReader's built-in icons are never touched.

**Device Backup & Restore integration:** with Settings and Icons ticked, every icon a target uses is included (wherever it lives) plus a map of its old paths, so restoring on another device (Kobo, Kindle, Android) re-links correctly. Logins toggle is off by default — saved logins, session tokens, and the keys that decrypt them (ShelfSync, ShelfSync tweaks) are excluded, including from Beam; files that mix tokens with normal settings go in with only the tokens stripped, and a restore keeps the device's own logins. Turning it on includes everything, so keep that backup file private.

Built-in targets: Shortcuts toolbar, Track Reading Location, Add-ons menu, Reading Insights tweaks, ReadMastery Notify/Quests, ShelfSync tweaks (settings only, never logins), and SimpleUI. Targets you don't use stay hidden.

**For patch authors — add a target:**
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

## ShelfSync Tweaks

- **Goodreads login on device:** a Log in button (email + password) in ShelfSync → Providers → Goodreads → Account, same as StoryGraph's. Login code is bundled from `goodreadskosync` (MIT, license in the file), so that plugin isn't needed.
- **Remember login** for Goodreads and StoryGraph: tap "Log in as…" to sign in with the saved login, long-press to edit, "Forget saved login" to remove it.
- **Goodreads WAF fix:** search and security-token requests use `/book/auto_complete` and `/review/list` to get around Amazon's bot check, falling back to the originals if they fail.
- **New toggles in ShelfSync → Settings:**
  - Exclude WikiReader articles (on): stops `koreader/cache/wikireader/` articles being auto-linked to random books.
  - Hide providers (Fable, Hardcover, Goodreads, StoryGraph; all off): removes a provider from the menu and stops it running.
- **Link & Update:** every enabled provider's Link book and Update status in one menu, with gesture actions for each.
- **ShelfSync All: Update progress** (gesture), in order: turns Wi-Fi on if needed → syncs to every linked, enabled provider (one retry each) → lists providers still unlinked → turns Wi-Fi back off if it turned it on.
- **Autolink retry on connect:** books opened offline get linked when Wi-Fi connects.
- **Auto re-login:** if a saved-login session expires, it signs in again and re-sends progress, at most once per provider per 30 minutes.
- **Security:** logins stay on the device (`koreader/settings/shelfsync_*_login.lua`), encrypted with a device-local key. That protects against casual browsing, not full device access.

---

## ReadMastery Notify

A customizable notification system for ReadMastery: XP, quests, level-ups and reading progress. Offers full, compact or banner styles, a position and duration setting, and an optional custom font. Designed to feel rewarding without getting in the way while reading.

Two top-level toggles above the settings menu:
- **Notifications** — master ON/OFF for everything below.
- **Nudges** — 80%/90% "almost there" notices from the quest patch (informational only, no XP). Greyed out whenever Notifications is off, since nudges are delivered through the same render pipeline.

Everything else lives under ReadMastery → Settings → Notification Settings (greyed out while Notifications is off):
- **Full / Compact / Banner** — notification style. Full is ReadMastery's original popup (tap to dismiss). Compact is a small centered box, auto-dismiss or tap — a custom widget that mixes your chosen font for text with a monospace font for achievement art. Banner is a corner or full-width toast that auto-dismisses and never blocks reading/page-turns.

---

## ReadMastery Quests

Drop this alongside ReadMastery Notify and restart. Independent, optional add-on — if Notify isn't installed, quest-complete popups fall back to a plain default box instead of your styled notifications.

Adds one new top-level menu toggle: **Quests (Enhanced)**.

- **OFF (default):** zero overhead — the tracking hooks do nothing extra, "View Quests" is greyed out. ReadMastery behaves exactly like stock.
- **ON:** tracks Daily / Weekly / Monthly / Seasonal quests using ReadMastery's own live session data (pages/minutes/streak/book events) — no separate tracking system, no duplicate bookkeeping. Awards XP through ReadMastery's own `addXP()`, so it shows up in your real XP/level, and fires a "Quest Complete" popup using the same styled + queued notification pipeline as achievements (Full/Compact/Banner, your font, position, duration, queuing so completions don't overlap). A level-up triggered this way fires the normal Level Up notification too.

Turning it back OFF just pauses tracking — progress is kept, so turning it back on resumes where you left off. To reset quest progress, use ReadMastery's own **Settings → Reset Progress**: that action also clears quest state and Quest Stats in the same confirmed reset, alongside level/XP/streak/achievements. This patch never opens or writes ReadMastery's `data.json` directly — only through that existing, confirmed path.

---

## Kobo Style Sleep Screen Banner

Redesigns KOReader's banner-type sleep screen message to look like the Kobo lock screen tag, showing a random highlight from the current book.

- **Quote fallback:** books with no highlights show a random quote from a text file. Put `Famous Quotes.txt` at `/mnt/onboard/.adds/Famous Quotes.txt`, or change `file_path` at the top of the patch.
- **No repeats:** highlights and quotes each have their own no-repeat window.
- **Seeded randomness:** picks stay varied across restarts.
- **Live quote file:** edits to the quote file are picked up without restarting.
- **Lighter sleep:** only reads highlights, so there's no settings flush on every sleep.

Credits: written with Discord user @sandcastles, with design cues from a patch by u/juancoquet.

---

## Track Reading Location

Remembers the furthest page you've actually read. If you page back, or jump ahead through the table of contents, a small floating button takes you back. Settings: Reader menu → Navigation → Reading location → Settings.

- **Backward:** paging back more than one page (one page at a time, or in a single jump) shows a persistent button.
- **Forward:** jumping ahead more than two pages at once, or skimming 3+ pages within 1.5s, shows a mirrored button. Auto-dismisses after Off/15/20 (default)/30/50s; your next page turn becomes the new anchor.
- **Layout:** the button docks above KOReader's footer.
- **Position:** EPUB/FB2 track position by xpointer, so font or margin changes don't point "go back" at the wrong page.
- **Saving:** saves when you accept a page and on suspend; skips the disk write when nothing changed; cleans up timers on close.

---

## Shortcuts Toolbar Icon Tweaks

Adds **Shortcuts toolbar → Icon tweaks** for the shortcutstoolbar plugin:

- **Custom icons:** swap any icon for your own SVG/PNG, or restore the original.
- **Colour mode**, globally or per icon: Default (follows Night Mode), Keep original (true colours in Night Mode), or Inverted.
- **On/off indicators:** optional per icon, following Wi-Fi, frontlight or Night Mode.

Works in the reader menu, file-browser bar/persistent bar, and the SimpleUI home-screen module. Does not modify any plugin files.

---

## Custom Quotes for SimpleUI

`Quotes.lua` has 300 famous quotes for SimpleUI's Quote of the Day module.

1. Copy it to `koreader/settings/simpleui/sui_quotes/`, creating the folders if needed.
2. In the module's settings, set Source → Custom and pick the file.

---

## Reading Insights Tweaks

Enhances Reading Insights and the built-in Statistics calendar with cover art, goal-shaded badges, interactive day views and sleep screen overlays. Each feature has its own toggle.

1. **Streak calendar covers** — each read day shows that day's top book cover, a time badge shaded by daily goal progress (black = goal met), a second cover stacked behind for 2+ books (+N for 3+).
2. **Taller cover cells** — 2:3 cells so covers fill them; the popup shrinks to fit the screen (Reading Insights' own landscape fit, also run in portrait).
3. **Tap a day** — in the streak calendar: that day's books, time and pages; tap a book to open it.
4. **Book calendar header** — cover, title and author under the month title of the Book progress calendar.
5. **Heatmap goal shading** — calendar heatmap shaded against your daily goal (darkest = goal met) instead of your busiest day.
6. **Record covers** — cover art for your reading achievements (most time in a day, most pages in a day, best streak).
7. **Sleep screen card** — "Now reading" overlay (cover, progress, today vs goal) above the Reading Insights sleep screen.
8. **Statistics calendar** — KOReader's built-in Statistics calendar: covers instead of title bars, same time badge. Tap a day still opens its day view.

**Install:** copy `2-readinginsights-tweaks.lua` into `koreader/patches/` and restart.

**Requirements:** Reading Insights plugin (`peterboda236/readinginsights.koplugin`) installed; CoverBrowser enabled (covers are cached and rendered through it — an uncached cover shows its title until CoverBrowser's background fetch catches up).

**Configuration:** Tools → Tweaks & Mods → Reading Insights tweaks (with the Tweaks menu installed), or Tools → Reading Insights tweaks standalone. Every feature toggles without restarting; Daily Reading Goal is adjustable in the same menu.

**How it works:** Reading Insights loads its files through the global `loadfile`. This patch wraps that for four of its view files — two get small source additions routing a function through here, the other two are patched on the module table they return. The sleep card hooks the plugin's suspend/resume. Toggles are checked every time something is drawn, so turning one off reverts to the stock view immediately. Update-safe: every addition looks for exact source lines first — if a Reading Insights update changes them, that feature is skipped (logged as `RI tweaks:`) and the stock view is used. Any error while drawing falls back to stock too.
