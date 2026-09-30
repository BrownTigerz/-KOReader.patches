# KOReader Patches

User patches for KOReader, mostly tested for Kobo Clara Color.  Each one is a single file that patches KOReader or a plugin in memory. Nothing on disk is modified, so deleting a file and restarting fully reverts it.

Patch	For	What it does
2-simpleui-mod.lua	SimpleUI	Home screen colours, bold, per-section titles, Night Mode day look
2-tweaks-menu.lua	KOReader	One Tools menu for plugin and patch settings
2-shelfsync-tweaks.lua	ShelfSync	Goodreads login, saved logins, WAF fix, one-tap sync
2-ReadMastery-notify.lua	ReadMastery	Custom notification styles
2-ReadMastery-quests.lua	ReadMastery	Quests and challenges
2-kobo-style-sleepscreen-banner.lua	KOReader	Kobo-style sleep screen banner with highlights or quotes
2-track-reading-location.lua	KOReader	"Go back to where you were" button
2-shortcutstoolbar-icon-tweaks.lua	Shortcuts Toolbar	Custom icons and Night Mode colour modes
Quotes.lua / Famous Quotes.txt	SimpleUI / sleep screen	Quote collections

Install

Copy the 2-*.lua files you want into KOReader's patches folder and restart KOReader.

	•	Kobo: .adds/koreader/patches/
	•	Kindle: koreader/patches/
	•	Android: koreader/patches/

Create the folder if it doesn't exist. The 2- prefix is required, because KOReader only loads patches whose names start with a priority number. Patches don't work on the F-Droid build of KOReader.

All patches work independently and together. If one fails to attach (for example, after a plugin update), it logs to koreader/crash.log and leaves things as they were.

# SimpleUI Mod

Colour and typography control for the SimpleUI home screen, plus a Night Mode "day look" for use with a light wallpaper.

Settings are in Tools → SimpleUI Mod, or Tools → Tweaks & Mods → SimpleUI Mod with the Tweaks menu installed.

	•	Modules:
	•	text colour, with a separate Night Mode colour
	•	recolour grey text
	•	progress bar, ring and border colours (per module)
	•	bold (per module or all)
	•	Section titles: defaults for all sections, then per-module colour, bold and size. Size is a preset or a custom 50–300%. A • marks customised sections.
	•	Nav bar: bold labels, day look in Night Mode, and colour icons keep their original colours in Night Mode.
	•	Status bar: bold, and day look in Night Mode.

Colours are picked as they should look on screen, and Night Mode inversion is handled for you. Night Mode switches and status bar bold apply instantly. Everything else asks for a restart.

Notes

	•	Wallpaper: turn off SimpleUI's wallpaper Night Mode inversion, since black text needs a light background.
	•	Module fill: with a light wallpaper, set module backdrop/fill to 0, or text can disappear in Night Mode.
	•	Colour nav icons: these need a non-Framed nav bar style. Framed draws icons in one colour, but still gets the day look.
	•	Icon files: use SVG icons with transparency.
	•	Section title sizes: these multiply SimpleUI's own label scale (Scale → Labels).

Uninstall: use Reset to defaults if you want the saved settings (simpleui_mod in settings.reader.lua) removed. Then delete the file and restart.

# Tweaks & Mods menu

Declutters Tools by gathering plugin menus and patch settings into one Tools → Tweaks & Mods submenu.

	•	Moved menus: plugins listed in MOVE at the top of the file move in, currently SimpleUI, ReadMastery, ShelfSync and Shortcuts Toolbar. Edit the list and restart to change it. Ids that aren't installed are skipped.
	•	Patch settings: patches that support it add their settings automatically. SimpleUI Mod does.
	•	Nothing is saved: each menu build works on a copy of KOReader's menu order. Delete the file and every menu is back where it was.
	•	Menu Disabler: items hidden with a menu-order file or Menu Disabler stay hidden.
	•	Empty submenus: a built-in submenu emptied by moving its items out is hidden instead of shown empty.

For patch authors: register with the shared table at package.loaded.tweaks_mods. The format is documented at the top of the file. Return an item with sub_item_table_func so large menus are only built when opened.

# ShelfSync Tweaks

	•	Goodreads login on device: a Log in button (email + password) in ShelfSync → Providers → Goodreads → Account, same as StoryGraph's. The login code is bundled from goodreadskosync (MIT, license in the file), so that plugin isn't needed.
	•	Remember login for Goodreads and StoryGraph:
	•	tap Log in as… to sign in with the saved login
	•	long-press it to edit
	•	Forget saved login removes it
	•	Goodreads WAF fix: search and security-token requests use /book/auto_complete and /review/list to get around Amazon's bot check, falling back to the originals if they fail.
	•	New toggles in ShelfSync → Settings:
	•	Exclude WikiReader articles (on): stops koreader/cache/wikireader/ articles being auto-linked to random books.
	•	Hide providers (Fable, Hardcover, Goodreads, StoryGraph; all off): removes a provider from the menu and stops it running.
	•	Link & Update: every enabled provider's Link book and Update status in one menu, with gesture actions for each.
	•	ShelfSync All: Update progress (gesture), in order:
	1.	turns Wi-Fi on if needed
	2.	syncs to every linked, enabled provider (one retry each)
	3.	lists providers still unlinked
	4.	turns Wi-Fi back off if it turned it on
	•	Autolink retry on connect: books opened offline get linked when Wi-Fi connects.
	•	Auto re-login: if a saved-login session expires, it signs in again and re-sends progress, at most once per provider per 30 minutes.
	•	Security: logins stay on the device (koreader/settings/shelfsync_*_login.lua), encrypted with a device-local key. That protects against casual browsing, not full device access.

# ReadMastery Notify

A customizable notification system for ReadMastery: XP, quests, level-ups and reading progress. It offers full, compact or banner styles, a position and duration setting, and an optional custom font. It's designed to feel rewarding without getting in the way while reading.

# ReadMastery Quests

Adds quests and challenges to ReadMastery:

	•	daily reading goals
	•	progress-based quests
	•	seasonal and special challenges

All of them reward XP. Toggle Quests (Enhanced) in the ReadMastery menu. When it's off, the patch does nothing. Works with or without ReadMastery Notify, which styles the quest popups when installed.

Kobo Style Sleep Screen Banner

Redesigns KOReader's banner sleep screen message to look like the Kobo lock screen tag, showing a random highlight from the current book.

	•	Quote fallback: books with no highlights show a random quote from a text file. Put Famous Quotes.txt at /mnt/onboard/.adds/Famous Quotes.txt, or change file_path at the top of the patch.
	•	No repeats: highlights and quotes each have their own no-repeat window.
	•	Seeded randomness: picks stay varied across restarts.
	•	Live quote file: edits to the quote file are picked up without restarting.
	•	Lighter sleep: it only reads highlights, so there's no settings flush on every sleep.

Credits: written with Discord user @sandcastles, with design cues from a patch by u/juancoquet.

Track Reading Location

Remembers the furthest page you've actually read. If you page back, or jump ahead through the table of contents, a small floating button takes you back. Settings are under Reader menu → Navigation.

	•	Backward: paging back more than one page shows a persistent button.
	•	Forward: jumping ahead more than two pages, or skimming 3+ pages within 1.5 s, shows a mirrored button. It auto-dismisses after Off, 15, 20 (default), 30 or 50 s, and your next page turn becomes the new anchor.
	•	Layout: the button docks above KOReader's footer.
	•	Position: EPUB/FB2 track position by xpointer, so font or margin changes don't point "go back" at the wrong page.
	•	Saving:
	•	saves when you accept a page and on suspend
	•	skips the disk write when nothing changed
	•	cleans up timers on close

# Shortcuts Toolbar Icon Tweaks

Adds Shortcuts toolbar → Icon tweaks for Shortcuts Toolbar:

	•	Custom icons: swap any icon for your own SVG/PNG, or restore the original.
	•	Colour mode, globally or per icon:
	•	Default: follows Night Mode
	•	Keep original: true colours in Night Mode
	•	Inverted
	•	On/off indicators: optional per icon, following Wi-Fi, frontlight or Night Mode.

# Custom Quotes for SimpleUI

Quotes.lua has 300 famous quotes for SimpleUI's Quote of the Day module.

	1.	Copy it to koreader/settings/simpleui/sui_quotes/, creating the folders if needed.
	2.	In the module's settings, set Source → Custom and pick the file.

# Reading Insights Tweaks

A KOReader user patch that enhances Reading Insights and the built-in Statistics calendar by adding visual book covers, dynamic goal shading, customizable cell layouts, and sleep screen overlays.

Features
Streak Calendar Covers: Displays the top read book's cover inside each calendar cell, along with time badges shaded according to daily goal progress. Stacked covers indicate reading multiple books in a single day (+N indicator for 3+ books).

Taller Cover Cells: Formats calendar cells to a 2:3 ratio so covers fill the frame completely.

Interactive Day Tap: Tap any day in the streak calendar to open a detailed breakdown of books read, time spent, and pages completed. Tap a book directly from the menu to open it.

Book Progress Header: Adds the cover image, title, and author directly beneath the month title in the Book Progress calendar view.

Heatmap Goal Shading: Recalculates calendar heatmap intensities relative to your personal daily reading goal rather than comparing against your highest activity day.

Record Covers: Displays cover art for your reading achievements (most time spent in a day, most pages read, and best reading streak).

Sleep Screen Card: Displays a "Now Reading" overlay card (featuring cover art, reading progress, and daily goal progress) above the Reading Insights sleep screen.

Built-in Statistics Calendar Covers: Enhances KOReader’s native Statistics calendar by replacing standard title bars with book covers and time badges.

Installation
Copy 2-readinginsights-tweaks.lua into your KOReader patches directory:

Kobo: .adds/koreader/patches/

Other Platforms: koreader/patches/

Restart KOReader.

Requirements
Reading Insights Plugin: peterboda236/readinginsights.koplugin must be installed.

CoverBrowser: Keep the CoverBrowser plugin enabled so covers can be cached and rendered.

Configuration
Access settings and toggles via the KOReader menu:

With 2-tweaks-menu.lua: Tools > Tweaks & Mods > Reading Insights tweaks

Standalone: Tools > Reading Insights tweaks

Each feature can be independently toggled on or off without restarting. You can also adjust your Daily Reading Goal directly within the settings menu.
