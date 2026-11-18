# SimpleUI Side Panel changelog

Newest first. Moved here from the patch in 1.0.37 (old entries unchanged; they had no dates).

## 1.0.37 (2026-11-16)

- History view: a book hidden from the reading history in SimpleUI 3.1.0 (its "hide from history") isn't listed either.
- Header gets a `Version:` line; history moved into this file.

## 1.0.36

- No Gesture Only swipe zone: Panel: Off turns the edge swipe off and the gesture action still opens the panel (on the right). A saved Gesture Only reads as Narrow.

## 1.0.35

- The gesture action works anywhere but in a book: SimpleUI home, the library, Project: Title and Bookshelf (the panel slides in over whatever is showing). 1.0.34 only reached it on home.

## 1.0.34

- A gesture action, "SimpleUI Side Panel", in KOReader's Gestures. Swipe Zone › Gesture Only turns the edge swipe off so only the gesture opens it. Loops no longer use _ as their variable.

## 1.0.33

- The list of books downloaded from here stays small: an entry goes once BookOrbit has linked the file, or the file was deleted (from the file browser too). A cover removed from BookOrbit's cache (Reading Log Tweaks' Clean Up Cache, or BookOrbit's own pruning) is fetched again when shown.

## 1.0.32

- A book downloaded from here counts as on the device straight away (even before BookOrbit links it), here and in Reading Log. The compact window's Open says Read, Continue Reading or Read Again, and a BookOrbit book on the device gets Remove From Device (KOReader's own delete: the file, its sidecar, History and collections; reading statistics stay). It stays in BookOrbit.

## 1.0.31

- Compact detail of a BookOrbit book not on the device: its cached BookOrbit cover, what BookOrbit knows (series, year, pages, file, description; fetched in the background the first time), and a Download button that downloads it straight from BookOrbit (its download folder and layout, hash-checked, linked so it syncs), then offers to open it. Covers and downloads shared with Reading Log Tweaks.

## 1.0.30

- BookOrbit books not on this device show their cover: the one BookOrbit already keeps in koreader/cache/bookorbit/, or, when it isn't there yet and Wi-Fi is on, fetched in the background (up to 8 at a time) into that same folder and shown in place.

## 1.0.29

- Fix: compact detail had a blank strip under Cancel that looked like part of the button but did nothing. Cancel now runs to the card's bottom edge, and a tap under the buttons counts as Cancel.

## 1.0.28

- Compact detail: only one at a time. A second request while one is open is ignored, so two windows never stack (Cancel closed the top one and the one under it looked like Cancel did nothing).

## 1.0.27

- Fix: Cancel on the compact detail now refreshes only the dialog card, as 1.0.26 meant to (it looked up the card before it was made, so it refreshed the whole window). Patch Backup & Restore 3.0: registers its settings (BookOrbit list caches stay out). Two leftovers from SimpleUI Tweaks that never ran here are gone.

## 1.0.26

- Compact detail close: refresh only the dialog rectangle (ui, not full-screen flash) so Cancel clears the e-ink ghost without a whole-screen update.

## 1.0.25

- Compact detail includes the book cover again (non-tappable). Uses ButtonTable so Cancel / Open / BookOrbit always work. Side panel still closes while the dialog is open; author + short description.

## 1.0.24

- Compact detail: Cancel now closes the dialog; side panel is hidden while the dialog is open so it sits cleanly on the home screen; shows author + short description when metadata has one.

## 1.0.23

- Compact book detail on tap: instead of opening the book immediately, a small dialog shows cover (non-tappable), title, author, status and buttons only. Open / Open in BookOrbit (when available) / Cancel. Prevents accidental opens; same compact design for local and BookOrbit.

## 1.0.22

- Add-ons menu: no second copy in Tools. The panel added its own Tools entry even when it was in Tools > Add-ons, so it never moved; now it does that only without the Add-ons menu (or when it's turned off there), like the other patches.

## 1.0.21

- Polish: dead code removed (a duplicate note helper, an unused BookOrbit check, unused locals); a failed BookOrbit book detail is now logged as a warning.

## 1.0.20

- Clean-up: debugging trace lines removed from crash.log (BookOrbit fetches, detail opening, swipe hook). Only the version line stays.

## 1.0.19

- Header fix: long view titles ("Book Club Anthology", "BookOrbit Newly Added") were still cut after a word or two. The two-line box was sized from a plain text line, which is shorter than a text-box line, so it only held one. It's now sized by the text box itself.

## 1.0.18

- Shares its saved BookOrbit lists with Reading Log Tweaks (1.1.6+), so BookOrbit collections can be picked there (the Book Club card and any card with a collection). Saved lists only: Reading Log never waits on the BookOrbit server.

## 1.0.17

- Header: the whole view title shows ("Book Club Anthology", "BookOrbit Newly Added"): a title that nearly fits steps down to 20 to stay on one line; a longer one wraps onto two lines at full size instead of being cut after a few words.

## 1.0.16

- Speed: at most one BookOrbit refresh per panel open. Swiping through BookOrbit views ran one refresh per view (0.75-0.9 s each, the panel frozen meanwhile: four in six seconds in the log). Now only the first view you stop on (0.4 s) is refreshed; the others show their saved list. Saved lists count as fresh for 30 minutes (was 10).

## 1.0.15

- Speed: BookOrbit lists no longer block the swipe. Checking which views have books (every open and every swipe) reads only the saved lists, never BookOrbit's server; the list on show comes from the saved copy straight away and, when it's over 10 minutes old with Wi-Fi on, is refreshed once right after the panel is up, then redrawn in place. Each refresh is one request (up to 100 books) instead of one per page. Was: a swipe asked the server for every picked BookOrbit collection older than 45 s, 0.5-0.6 s each, so swipes took up to 1.8 s.
