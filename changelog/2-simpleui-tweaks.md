# SimpleUI Tweaks changelog

`2-simpleui-tweaks.lua`, newest first. Everything before 2.16.2 was moved here unchanged from the patch file on Nov 15, 2026 (the file kept no dates).

## 2.16.4 (2026-11-15)

- Book Opens With One Flash: the book now opens with one flash only. While it loads, a full refresh asked for by something else (TK's log showed one on a full-screen box just before the book, a second before ours) is done as a plain refresh, so the one after the book is on screen is the only flash. Only from the tap until the book shows (15 seconds at most).

## 2.16.3 (2026-11-15)

- Appearance › Book Opens With One Flash (off by default): a book opened from the SimpleUI home screen opens the way Bookshelf opens one, without KOReader's "Opening file" box and with one full refresh once the book is on screen, instead of a flash for the box and another for the book (TK). Nothing shows while the book loads.

## 2.16.2 (2026-11-15)

- Close Bookshelf with a book held really goes to SimpleUI home now: Bookshelf closes the shelf twice (while the book closes, then after the stock library shows) and 2.16.1 used its one chance on the first, too early to open home.

## 2.16.1 (2026-11-15)

- Close Bookshelf with a book held behind it (Bookshelf's Instant book close) goes straight to SimpleUI home too; it showed the stock library for a moment first (2.6.0 only covered no book held). Three loop counters named _loop are now _i (as in every patch).

## 2.16.0

- Finished Books In Stats (SimpleUI Tweaks menu): every finished book SimpleUI counts, newest year first. Tap one: Don't Count (stays listed, like SimpleUI's Exclude from goals, and works for a deleted book too) / Count Again, and for a deleted book Remove From Stats (asks first). No more editing sui_settings by hand. Manual books stay in SimpleUI's own Finished Books window.

## 2.15.0

- Home Screen Pages (SimpleUI Tweaks menu): untick a page to hide it without deleting it, and Open On picks the page the home screen opens on. SimpleUI's saved layout isn't changed (its page editor still shows every page); tick the page to bring it back as it was. At least one page always shows. Home screen only, off by default. Last loop using _ as its variable renamed.

## 2.14.17

- SimpleUI 3.0.3: Dynamic Bubble Width counts the pixel bubble's new shadow, so the text it picks a width for still shows whole. Loops no longer use _ as their variable (it's gettext's name).

## 2.14.16

- Fix: Open Book From Cover Only: the critter's tap-the-cover tip stayed on the first one (SimpleUI holds a said line 20 minutes). Another four wrong taps now swap in a new tip.

## 2.14.15

- Fix: Open Book From Cover Only did nothing (any tap still opened the book): its hook couldn't be found when Currently Reading loaded, so it never went on.

## 2.14.14

- Currently Reading: Open Book From Cover Only (Modules, off by default). Only a tap on the cover opens the book; a tap on the title, author or anywhere else on the module does nothing. Four wrong taps in a row (a few seconds apart at most) and the home critter tells you to tap the cover, with a different cute line each time.

## 2.14.13

- Critters Say Notifications now also catches Network Tweaks' corner notes (Minimal style) and BookOrbit's pills, not just KOReader's own toasts; on your setup that's where nearly every notification comes from, so before this the critter never got any. Warning, loading and tap-to-act ones stay popups.

## 2.14.12

- Critters Say Notifications (Critter menu, off by default; one setting shared with Shortcuts Toolbar Quick Shelf and Reading Log Tweaks): a notification that comes in while the home screen's critter is on screen is said by the critter, as a reaction, instead of the popup. When another reaction is waiting or on show, or reactions are off, the popup shows as usual. Banners you can tap, questions and failures always stay popups.

## 2.14.11

- Critter phrases: one load line with the file's version ("critter phrases v1.0.0 loaded") replaces the three count lines; critter-phrases.lua is now on the patch updater.

## 2.14.10

- Critter Insights in Donny, Blu and Donny & Blu's own voice: critter-phrases.lua's insight_voices section. With SimpleUI 3.0.2 a critter with its own wording of an insight uses it about half the time, the shared lines the rest.

## 2.14.9

- Donny, Blu and Donny & Blu talk in their own voice, like SimpleUI 3.0.2's critters (Suey, Hazel...): their lines are in critter-phrases.lua (voices) and join SimpleUI's voice lines, so the home screen and Reading Log Tweaks both use them. Same situations as SimpleUI's: greetings, streak, today, books this year, the current book, goal, Monday, weekend, any time.

## 2.14.8

- Early Page Turn (Page Turns, off by default): a sideways swipe turns the page once your finger has moved 35 dp (or 50 / 80), without waiting for the lift. Books in page mode and full-screen lists (file browser, history, collections, TOC, bookmarks, search). One turn per swipe. Steps aside if 2-earlyturn.lua is installed.

## 2.14.7

- Menu reorganised: Modules, Critter, Appearance, Bars & Menus; toggles listed above submenus in each group.

## 2.14.6

- Side panel moved to 2-simpleui-sidepanel.lua (settings + BookOrbit + view toggles). This patch only bridges the home swipe when that patch is installed.

## 2.14.4

- Section label hook forwards SimpleUI 3.0.1's new `inside` param, so labels inside a module's box keep their inside styling.

## 2.14.3

- Wording pass: menu help texts and critter lines rewritten to sound natural (no AI phrasing). No functionality changed.

## 2.14.2

- Critter Mix (Modules): tick two or more critters (say Donny, Blu and Donny & Blu) and they take turns: the next one shows each time the critter has something new to say. Reading Log's critter takes turns too (a new remark or a tap there moves it along). Off (fewer than two ticked): SimpleUI's own pick.

## 2.14.1

- More critter moods: reading, proud, hungry, cozy, sipping, dreamy, festive and spooky (Donny and Blu have them in critters.zip). The phrase bank uses them; a critter without one shows the pose it's drawn from (reading = neutral, proud = cheer...), not plain neutral. Party is festive in December and spooky in the last week of October, when the critter has those. A pep-talk line can carry its own mood ({ "Snack break?", mood = "hungry" }).

## 2.14.0

- Critter phrase bank: Critter Insights and Critter Pep Talk read their lines from koreader/patches/critter-phrases.lua when it's there (several times the lines, a bit sassier; edit it freely). Missing or broken, the built-in lines are used as before. Same triggers, limits and steps (pep talk adds 90-119 min and 50-99 pages). Reading Log reads the same file.

## 2.13.9

- Critter Pep Talk (Modules, on by default): SimpleUI's "minutes read today" and "pages turned today" lines grow with your reading. 1 minute gets a nudge, 15 a groove, an hour a party, and within 10 minutes of your daily goal it counts you in. Moves up a step on the next home screen draw as you read.

## 2.13.8

- Critter Bubble Max removed. To Be Read side panel: Side Panel Swipe Zone (Modules) - Narrow (default, 1/14 of the screen) or Edge Only (1/24): the swipe has to start nearer the edge, so page swipes don't open it by accident. Wide is the old 1/8.

## 2.13.7

- Page Turn Flash (SimpleUI Tweaks menu): SimpleUI turns home pages with a quiet update, so the old page ghosts through. Normal adds a quick flash to each turn, Strong a full refresh (dark pages and night mode). Off (default) as before.

## 2.13.6

- Critter text in night mode: the module text colours (Text Colour / Night Text Colour, made for text on the page or wallpaper) no longer reach inside the critter's bubble, which has its own background; in night mode they made the text the same colour as the bubble. Auto now keeps SimpleUI's ink (white on the dark bubble at night); White / Black are as they look, night included.

## 2.13.5

- Critter Text Colour (Modules): Auto writes the critter's speech in white when its bubble is dark (a dark SimpleUI look), White / Black always; its outline follows. Reading Log's critter too.

## 2.13.4

- Critter Position (Modules): Left, Right, or Left or right (never the middle) for the critter and its bubble in their row, so the middle of the row stays clear; works with or without Critter Wanders. With Critter Side, the cat's side of its text.

## 2.13.3

- Critters Everywhere removed. Critter Side (Modules) now works whatever the bubble width or Critter Wanders: Left of Text / Right of Text keeps the critter on that side of its bubble; the third choice uses SimpleUI's own Side (random while wandering).

## 2.13.2

- Fix: 2.13.0/2.13.1 stopped the patch from loading (Critters Everywhere used two helpers before the file defines them).

## 2.13.1

- Critter Side (Modules, with Critter Wanders on): keep the critter always left or always right of its text while the row still moves left, centre or right; Random keeps the old switching.

## 2.13.0

- Critters Everywhere (Modules → Critters Everywhere, on by default): SimpleUI's Tiny Critters on every KOReader window - top menus (Tools, Search, Add-ons, settings), button popups, the search box, confirmations, X-ray and other patches' popups, and full-screen pages (file browser, history, collections, lists, toolbar panels, the home screen). Never on the book page or the sleep screen. A critter only goes where that bit of the window is blank (one plain colour, plus a margin), so it never covers text, icons or lines; it sits on a bottom edge or hangs upside down from a top edge, and takes no taps. Options: menus/dialogs, pages, hanging, 1 or 2 per window, size, a different critter per window or one all day, and which critters (all, or tick the ones you want, your own packs included). Its mood fits the place. Drawn after the window paints; a spot is looked for once per window.

## 2.12.6

- Critter Insights, tightened:
  - Milestones fire when the count goes up to one (finishing that book), not when the home screen first sees it, and stay said for the year. Before, the record of what was said was trimmed to today's after 60 entries, so a milestone could come again.
  - What's remembered has its own life now: today's insights reset each day, milestones last the year, comebacks / quiet stretches / weekly ones are dropped after 90 days.
  - Back on a roll: once per comeback (was once a day for up to 4 days).
  - Goal pace: books left over days left ("20 books to go, 69 days left. About one every 3 days catches you up."), worded for on pace or catching up; weekly from mid-January.
  - Weekend reader: needs 4+ weekend and 8+ weekday reading days in 8 weeks; the verdict sticks until the difference is mostly gone.

## 2.12.5

- Tiny Critter:
  - Critter Bubble Width > Dynamic. The bubble keeps SimpleUI's width for short lines and grows, up to all the room the critter and decorations leave, when a line would otherwise be cut short. Measured with SimpleUI's own text box, per phrase (its chat replies too).
  - Critter Bubble Max: Full Row and Dynamic can stop short of the row's end (90% or 80% of the room), so a long bubble doesn't run to the edge.
  - Critter Wanders (Dynamic): each time the home screen draws the row, the critter and its bubble move to the left, centre or right of the row, with the critter on either side of the bubble (never the same spot twice in a row). Overrides SimpleUI's Side / Alignment while it's on.
  - Critter Insights: remarks from your reading history (best day this month, book milestones, back on a roll, nearly done with your book, goal pace this month, a gentle nudge after quiet days, weekend reading). Waits for the critter like SimpleUI's own reactions, once each, at most 3 a day, only when the stats back it. One statistics query a day. Its chat no longer offers the same book twice in a day.
  - Critter Row Height: Taller (+30%) or Tallest (+60%) gives the bubble room for its full 2 + 2 lines. The row keeps that height for every phrase, so nothing below it moves. The critter keeps its size (Critter Size > Fill Height grows it to the new row).

## 2.12.4

- Tiny Critter: Modules > Critter Size. SimpleUI draws the critter at the largest whole pixel step that fits the row, which often leaves it well short of its speech bubble. Fill Height scales it to the bubble's height (still sharp pixels, each a little uneven); Smaller takes it one pixel step down. Its moods, and decorations next to it, follow. Default is SimpleUI's own.

## 2.12.3

- Tiny Critter (SimpleUI 3.0): Modules > Critter Bubble Width makes its speech bubble wider (SimpleUI's is fixed), so longer lines fit on fewer rows. Its chat answers follow the bubble. The bubble still gives way to decorations and never leaves the row.

## 2.12.2

- SimpleUI 3.0:
  - Reading Stats takes the module colours again (it showed SimpleUI's own white in Night Mode). SimpleUI 3.0 moved it to modules/reading_stats/module_reading_stats, and only files directly in modules/ were hooked. Modules in a folder are now hooked too (also the new Critter module).
  - Palette colours SimpleUI 3.0 works out live (track, surface_flat: they follow the secondary colour and Night Mode) no longer get stuck at one value after this patch swaps them for a moment (progress accents, nav bar in Night Mode).

## 2.12.1

- Section titles on SimpleUI v3.0.0: the label builder moved to engines/sui_section_label, so the hook retargets there (v2.x inline fallback kept).

## 2.12.0

- TBR panel: more collections. Modules > Collections In Panel picks any of your KOReader collections (e.g. Book Club); each becomes a panel view after To Be Read: swipe left/right through To Be Read, your collections, Newly Added (one dot per view). Each works like To Be Read: 5 books, Show all, hold to remove from that collection. Panel Opens To can open straight to one. A picked collection with no books isn't shown, and a note says so (when you pick it, and once per start when the panel opens).

## 2.11.15

- TBR panel: dismisses on device suspend (was staying open over the sleep screen).

## 2.11.14

- TBR panel: switching views rebuilds the panel in place instead of closing and reopening it, so the home screen behind isn't redrawn each time (about 60 ms less per switch).

## 2.11.13

- TBR panel: back from History works again (2.11.12's faster view switch overwrote where back should go, so it stayed on History).

## 2.11.12

- TBR panel: switching views (swipe, history icon) is about 4x faster: a quick refresh of the panel instead of a full flash, and the home behind isn't flashed in between. Opening and closing the panel still do one full flash, which also clears any faint ghost left by switching.

## 2.11.11

- New Books on SimpleUI 2.7.5 (no book sources there, which 2.11.10 relied on): the side panel's Newly Added view was always empty, and the home New Books module used SimpleUI's own folder walk (every 5 minutes, stops after 5000 entries, so a new book on a bigger library could be missed). Both now rank the newest files from SimpleUI's shared library scan, the one that notices a new book straight away, recomputed only when it re-walks.

## 2.11.10

- New Books (home module and the side panel's Newly Added): a book you add (e.g. from Calibre) shows up right away instead of after up to 5 minutes. SimpleUI's library scan already spots new books by checking folder dates (like Bookshelf's Latest); its newest- books ranking just waited on its own 5-minute timer. Now it's redone whenever the scan sees a change, reused otherwise.

## 2.11.9

- TBR panel: "Panel Opens To" now applies on every open (was only the first); added 4th option "Last View" to reopen wherever you left off.

## 2.11.8

- TBR panel: fixed tap-to-go-back in History view (custom paintTo was breaking gestures); back icon is now simple "<" text. New setting: Panel Opens To (To Be Read / Newly Added / History).

## 2.11.7

- TBR panel: back.svg wouldn't load on-device, so the History view's back icon is now a drawn chevron (reliable on Kobo).

## 2.11.6

- TBR panel: header icon uses SimpleUI's own path resolver (infra/sui_paths) for the absolute plugin dir — the relative plugins/... path failed on Kobo where CWD isn't the app dir.

## 2.11.5

- TBR panel: header icon is context-aware — history icon in TBR/New views, back icon in History view (tap returns to previous view).

## 2.11.4

- TBR panel: history icon fixed (was passing path as icon name, now uses file=); 2 dots for swipe views (TBR/New), History is tap-only via the icon again.

## 2.11.3

- TBR panel: history icon uses SimpleUI's own history.svg; swipe loops through all 3 views (TBR/New/History) and never closes — only tapping outside closes the panel. History view shows completion status ("Completed", "X% read", "Not started").

## 2.11.2

- TBR panel fixes: 2 view dots (not 3, History is tap-only); history icon is a drawn circular arrow (tap fixed); swiping back from History returns to the previous view instead of closing.

## 2.11.1

- TBR panel: view indicator dots at the bottom (TBR/New/History), and the history icon is a drawn clock now (the Unicode arrow didn't render on Kobo).

## 2.11.0

- To Be Read panel: swipe sideways to switch between To Be Read and Newly Added. History icon (top-right) shows your reading history.

## 2.10.2

- To Be Read side panel is narrower now (42% of screen width, was 66%) — reads as a panel instead of a full page.

## 2.10.1

- To Be Read panel: one flash of just the panel area when it opens and closes, so it no longer leaves a ghost.

## 2.10.0

- To Be Read side panel: swipe in from the right edge of SimpleUI home (or the left, or off: Modules > To Be Read Side Panel). It lists the To Be Read collection (Bookshelf's "To Be Read" and SimpleUI's TBR), 5 books one per line with cover, title and author, "Show all (N)" when there are more. Tap opens a book, hold removes it from the list. Tap outside or swipe back to close.

## 2.9.10

- Currently Reading: days read and time left now show for the books you swipe to too, not just the current one (their stats id is read once from the book's sidecar; SimpleUI only had it for the current book).

## 2.9.9

- Currently Reading dots are drawn shapes now: a filled black dot for the book showing, black outlined circles for the others (the text glyph outlines were too faint to see).

## 2.9.8

- Swipe logging follows the SimpleUI diagnostic: on while it's installed and logging, off otherwise (no setting to remember).

## 2.9.7

- Currently Reading: dots are back, in a small row below the cover (not on it), filled dot = the book showing. The row only appears when there are 2+ books to swipe through. Swipe logging is off now that swipes work.

## 2.9.6

- Swipe fixed for real: SimpleUI's home screen takes every left/right swipe itself and only passes it to a book module that has an onSwipe handler (how Cover Deck gets its swipes). Ours was named differently, so the home screen never passed it on. Also: the book you swiped to survives a full home rebuild (it only resets when a book is opened or the list changes), and the swipe log is capped at 128 KB.

## 2.9.5

- Fixed swipe diagnostics log path (was writing to wrong location; now uses DataStorage path like other diagnostics).

## 2.9.4

- Removed the tap gesture entirely (v2.9.2/v2.9.3 broke swipe; the invisible tap zone was confusing). Back to swipe-only as in the working v2.9.1. Swipe left/right on the Currently Reading cover to change books.

## 2.9.3

- Removed the cover dots and the 2/2 page indicator visuals per TK (2/2 overlapped the title; header can't be hooked safely). Fixed the tap-zone crash (range must be a Geom, not a plain table). Invisible tap zone at top-right of the module remains: tap for next book.

## 2.9.2

- Tappable page indicator ("1/4") at top-right of Currently Reading (tap = next book) — swipe was sometimes captured by the quote module instead. Swipe diagnostics now log to diagnostics.log ([simpleui] tag): handler fires, idx changes, refresh results.

## 2.9.1

- Fixed swipe getting stuck on last book: the fallback refresh now does a full rebuild (was repaint-only, leaving the old book visible).

## 2.9.0

- Currently Reading: swipe left/right to step through your most recent books still in progress (4 by default, 2-6; finished ones skipped), with dots on the cover showing where you are. Tap opens the book shown. Only the module is repainted, no flash. Modules > Currently Reading: swipe between books.

## 2.8.5

- Title case for all menu item texts (per TK's house convention).

## 2.8.4

- Reverted the 2.8.0 title/nav hook changes (they caused module build failures with makeAlphaTextBox on some setups); kept the shared notification contract v1 from 2.8.1. Title/nav styling fixes are parked pending a root-cause fix.

## 2.8.1

- Shared notification contract v1: status notes (restart prompt, colour/size validation) go through Network Tweaks' or ReadMastery notify's style when installed, else the InfoMessage default.

## 2.7.0

- Windows opened from the menu while it stays open (e.g. Shortcuts Toolbar: ReadMastery quests) keep SimpleUI home underneath, so closing them goes back to the menu over the home instead of the stock library.

## 2.6.0

- Close Bookshelf goes straight to SimpleUI home (when it's your start screen) instead of showing the stock library for a moment first. Nothing to set.

## 2.5.0

- Removed Series folders (2.4.x): they only fix SimpleUI's own library file browser, and the library here is Bookshelf, which groups series itself. Its hooks on the file browser and Cover Browser are gone.

## 2.4.2

- The file browser check behind the series fixes' backup never matched (it looked for the name "filemanager", which is the file list's name, not the file browser's), so the backup never ran.

## 2.4.1

- Series folder fixes are hooked in once per SimpleUI install. Before, if another patch or plugin also hooked the file browser, each time the file browser opened could add another copy of them.

## 2.4.0

- Series folders (fixes for SimpleUI's series grouping, each a toggle under SimpleUI Tweaks > Series folders, all on by default): new series group as soon as Cover Browser has scanned the books (no more opening and closing a book first); closing a book from a series returns to that book's page instead of page 1; books with the same or no series number keep a fixed order.

## 2.3.2

- Trimmed: removed settings conversions from 1.x versions and the one-time Bold move from 2.0.0 (both long done), shorter changelog.

## 2.3.1

- Colour picker no longer looks cut off at the bottom: it now asks for its own screen refresh over the whole dialog instead of relying on the menu's, which only updated the area the menu covered.

## 2.3.0

- Faster Quote of the Day module. Each time it picked a quote, SimpleUI rewrote its whole settings file to disk three times and wrote debug lines to crash.log. Now the quote position is kept in memory and saved when the Kobo sleeps or KOReader closes (as SimpleUI already does for everything), and those debug lines are skipped. Nothing changes on screen.

## 2.2.0

- Removed the Colour boost for e-ink setting (it only changes coloured text, so it made no visible difference here). Colours are drawn exactly as picked again. The deep "Ink" swatches in the colour picker stay.

## 2.1.1

- A module set to "SimpleUI default" text colour keeps it when it refreshes in place (e.g. stats after closing a book); it could pick up the All modules colour there. Hardening for future SimpleUI versions: a missing palette colour can't leave an override behind, and the clock hook only wraps a real function.

## 2.1.0

- Colour boost for e-ink (Off / Medium / Strong): text colours you pick are drawn deeper and more saturated so they hold up on colour e-ink, which washes colours out. Hue is kept; black, white and greys are untouched; in Night Mode colours stay bright enough to read on the dark background. Applies to module text (normal and Night Mode, all modules and per module) and section titles, not to progress bars or borders. The colour picker previews text colours with the boost, and has a new row of deep "Ink" shades made for colour e-ink.

## 2.0.0

- For SimpleUI 2.7.5. Removed what SimpleUI now does itself: module Bold (SimpleUI: each module's Text > Style) and nav bar Bold labels (SimpleUI: nav bar label Style). Your Bold choices are moved into SimpleUI's own settings once, so nothing changes on screen, and the two can no longer stack (double bold). Also removed: the reader tab id workaround (fixed in SimpleUI 2.7.5) and the old Shortcuts Toolbar fix that looked for its internals (1.10.2's covers every version).

## 1.x

- Earlier versions: see the GitHub history.
