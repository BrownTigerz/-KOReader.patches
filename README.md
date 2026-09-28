# -KOReader.patches

# SimpleUI Mod

A KOReader user patch for SimpleUI that adds colour control for the home screen and makes Night Mode readable over a light wallpaper.

Features
Module text colour: set the text colour for home screen modules (Currently Reading, Quote, Reading Goals, Reading Stats, etc.), with a separate colour for Night Mode.
Progress and border colours: recolour progress bars, rings, borders and stat icons for the modules you choose.
Section titles: set a colour for module headers, and optionally keep their day look in Night Mode.
Nav bar in Night Mode: keep labels black, and keep colour icons in their original colours instead of inverted.
Status bar: keep its day look in Night Mode, and use bold text for easier reading.
In-app settings: everything is under Tools → SimpleUI Mod and saved in KOReader's settings.
Install
Copy 2-simpleui-mod.lua into koreader/patches/. Create the folder if it doesn't exist. On Kobo it's .adds/koreader/patches/.
Restart KOReader.
Open Tools → SimpleUI Mod to configure.

Requires SimpleUI installed and enabled. Patches don't work on the F-Droid build of KOReader.

Settings
Setting	Applies
Module text colour (normal / Night Mode)	After restart
Also recolour grey text	After restart
Section title colour	After restart
Section titles: day look in Night Mode	Instantly
Progress & border colour, Progress track colour	After restart
Modules using progress colours	After restart
Nav labels black in Night Mode	Instantly
Nav icons in Night Mode (Original / Solid black / Off)	Instantly
Status bar: day look in Night Mode	Instantly
Status bar: bold text	Instantly
Show status popup on startup	Next start

Colours are picked as they should look on screen. The patch handles Night Mode inversion for you.

Notes
Wallpaper inversion: turn off SimpleUI's wallpaper Night Mode inversion. Black text needs a light background.
Module backdrop: set module backdrop/fill to 0 on light wallpapers, or text can disappear in Night Mode.
Colour nav icons: these need a non-Framed nav bar style. Framed style draws all icons in one colour.
Icon formats: use SVG icons with transparency. Opaque icons are left alone in "Original colours" mode.
Per-module text colours: edit PER_MODULE near the top of the file. This one isn't in the menu.
Troubleshooting

Turn on Show status popup on startup and restart. The popup lists each hook as ok, FAILED or error <module>, along with your SimpleUI version. Include it when reporting an issue.

Uninstall

Delete 2-simpleui-mod.lua from patches/ and restart. Saved settings live under the simpleui_mod key in settings.reader.lua and can be removed with Reset to defaults before uninstalling.

# ShelfSync Tweaks

Put 2-shelfsync-tweaks.lua in koreader/patches/ and restart. It survives ShelfSync updates.

Goodreads login on device — adds a Log in button (email + password) to ShelfSync > Providers > Goodreads > Account, same as StoryGraph's. No more copying cookies from a browser. The login code is bundled from goodreadskosync (MIT, license included in the file), so that plugin isn't needed. Remember login — Goodreads and StoryGraph can both save your email and password so you can sign in with one tap ("Log in as..."). Long-press to edit, or use "Forget saved login". Stored encrypted with a device-local key when possible. Goodreads WAF fix — ShelfSync's Goodreads search and security-token requests get blocked by Amazon's bot check. The patch uses the same endpoints goodreadskosync uses (/book/auto_complete and /review/list) so auto-linking and manual linking work, and falls back to the original if they fail. New toggles in ShelfSync > Settings, above Verbose logging: Exclude WikiReader articles (on by default) — stops articles opened with WikiReader (saved in koreader/cache/wikireader/) from being auto-linked to random books. Hide StoryGraph / Goodreads / Hardcover / Fable (off by default) — removes that provider from the Providers menu and stops it from running. Reopen the book or file browser to update the menu.

# ReadMastery Notify

A KOReader patch that adds a customizable notification system to ReadMastery. It provides visual feedback for events such as earning XP, completing quests, leveling up, and making reading progress.

The goal is to make ReadMastery's progression system feel more rewarding while keeping notifications clean, lightweight, and unobtrusive during reading.

# ReadMastery Quests

A KOReader patch that adds a quest and challenge system to ReadMastery. It introduces daily reading goals, progress-based quests, seasonal challenges, and special reading challenges that reward XP when completed.

The goal is to give reading more structure and variety while encouraging consistent reading without making the system overly complicated or distracting.

# Kobo Style Sleep Screen Banner

Download and ADD Famous Quotes.txt to file_path = "/mnt/onboard/.adds/Famous Quotes.txt"

Changes from the original
Custom quote fallback — if the current book has no eligible highlights, the patch automatically displays a random quote from a custom txt file.
No-repeat system — highlights and custom quotes have separate no-repeat windows to avoid seeing the same ones repeatedly.
Seeded randomization — improves random selection between KOReader restarts.
Automatic quote reloading — changes to quotes.txt are detected and the file is reloaded without needing to restart KOReader.
Removed unnecessary Sidecar:flush() — the patch only reads highlight data, so it no longer performs a flush every time the sleep screen appears.

# 2 Track Reading Location

Forward popup now auto-dismisses after a configurable delay (Off/15s/20s/30s/50s, default 20s) if you never act on it — new setting, right after "Show shadow." The next real page turn after it dismisses becomes the new anchor. Backward popup is untouched — still persistent, no timeout.
Several quick forward taps in a row (skimming ahead) now trigger the popup even when no single tap was a big jump — a "burst" of 3+ pages within 1.5s counts as one jump.
Button now docks above KOReader's own footer bar instead of potentially overlapping it (and correctly skips that offset when you have "Overlap status bar" on).

Correctness fixes (silent — nothing to notice, just fewer edge-case bugs)

Reflowable docs (EPUB/FB2) track position by xpointer, not just raw page number, so a font-size/margin change mid-session can't leave "go back" pointing at the wrong page.
Anchor and popup visibility now always resolve through that xpointer, everywhere they're checked — not just right after a page turn.
Stale on-disk xpointer data gets cleared instead of lingering and getting wrongly reloaded later.
A bug where the forward-dismiss timer stopped rescheduling itself after the first cycle (only fixed itself once, then silently broke) — fixed.

Reliability / resource use

Anchor is saved immediately (not just on KOReader's periodic autosave) when you explicitly accept a page, and on device suspend.
Suspend no longer writes to disk if nothing's actually changed since the last save.
Pending timers get cleaned up on document close and when you disable the floating button, so nothing fires against a closed book or a feature you've turned off.

Untouched: menu structure, dispatcher/gesture actions, the core anchor concept, and every other existing setting.

# Shortcutstoolbar Patch

Create custom icons for the original icons and choose between how it behave on night/daymode.

# Custom Quotes for SimpleUI

300 famous quotes to use with simple ui, add it to <KOReader settings dir>/simpleui/sui_quotes/
then set Source → Custom on the module

