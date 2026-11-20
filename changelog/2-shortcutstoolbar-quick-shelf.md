# Quick Shelf Changelog

`2-shortcutstoolbar-quick-shelf.lua`, newest first. Everything before 1.6.2 was moved here unchanged from the patch file on Nov 17, 2026 (the file kept no dates).

## 1.6.2 (2026-11-17)

- Books In Progress leaves out books you hid from the reading history in SimpleUI 3.1 (they still showed on the strip). Nothing changes without SimpleUI 3.1, or when nothing is hidden.
- The version history moved out of the patch file into this file; the old entries are unchanged.

## 1.6.1

- Book Panel, Quick Shelf and Critter Remarks are submenus instead of grey headings, so the Shortcuts toolbar menu is half as long. They sit after File browser settings, before Icon Tweaks and the plugin's Reset settings (now last). Critter Remarks goes While Reading, On Quick Shelf, On Library Toolbar, then Critters Say Notifications under a line (it covers every critter). Same saved settings, nothing resets.

## 1.6.0

- The Shortcuts toolbar menu is grouped under three headings: Quick Shelf, Book Panel and Critter Remarks. Menu Opens On is now Opens On and Quick Shelf Shows is now Shows, the Book Panel Tap submenu is two tick boxes under Book Panel, and the critter switches sit together. Same saved settings, nothing resets. Opens On (new): Book Panel (as before, the default) or Quick Shelf. With Quick Shelf the toolbar opens on the strip of books, so you don't swipe to it; swipe left or right still flips to the book panel. After the device sleeps with the menu up, it comes back on the page you chose. Off by default; nothing changes until you pick it. The last two loops that used _ as their variable now use _i.

## 1.5.3

- Loops no longer use _ as their variable (it's gettext's name).

## 1.5.2

- SimpleUI 3.0.3: the critter's bubble counts the pixel style's new shadow when it checks what fits, and the critter gets SimpleUI's ground shadow like the home screen's.

## 1.5.1

- Critters Say Notifications now also catches Network Tweaks' corner notes (Minimal style) and BookOrbit's pills, not just KOReader's own toasts; on your setup that's where nearly every notification comes from, so before this the critter never got any. Warning, loading and tap-to-act ones stay popups.

## 1.5.0

- Smarter remarks. While Reading goes by what's happening in this book: pages and time left (at your usual pace), the chapter ending, this sitting's pace against your usual (wow fast / slow going / steady), long and late sessions, quarter / halfway / home stretch, the finish, and sweet little remarks any time. Picks what fits now, never the same thing twice in a row, in your critter's own voice about half the time when it has lines (Donny, Blu, Donny & Blu). On Library Toolbar notices the tab and submenu you open (fonts, Wi-Fi, the sleep screen, your Add-ons...) and says something about it; submenus are known by name on KOReader 2025.10 too (Quick Shelf notes each one you open). Lines are in critter-phrases.lua 1.1.0 (editable, updatable). Some use your name, the one you gave SimpleUI's critter (Your name); without one they're skipped. Donny and Blu's extra poses show the base pose on other critters. With the Quick Shelf diagnostic installed, each menu remark is logged. On Quick Shelf (follows While Reading until set): the critter on the strip, with a remark about the books on the shelf (a different one each time, the one nearly done, how many are going, an empty shelf). Under Small Covers: covers the height of the book panel's title, author and page lines, the critter always in the row under them. Beside Full Covers: full covers, the critter in the room they leave, gone once they fill the row. Critters Say Notifications (Critter Remarks, off by default; one setting shared with SimpleUI Tweaks and Reading Log Tweaks): a notification that comes in while one of these critters is on screen is said by it instead of the popup (the popup shows when it doesn't fit). Tappable banners, questions and failures stay popups. In the library's tab bar, a remark shows whole: smaller text (two rows if needed), else another remark that fits, instead of being cut short.

## 1.4.3

- Critter Remarks show SimpleUI's Tiny Critter (the one you picked) with its speech bubble. While Reading: in the book panel's free strip, under the title / author / page line, right of the cover; it measures the strip so it never covers the text. On Library Toolbar: in the empty stretch of the menu's tab bar before the last tab icon, instead of a row of its own. Tap the critter for another remark. It's the critter your home screen shows: SimpleUI Tweaks' Critter Mix (today's turn) when two or more are ticked, else the one picked in SimpleUI. (1.4.2's line on the book panel never painted: its text call had its arguments out of order.)

## 1.4.2

- Critter text draw fix (RenderText width API) so the book-panel remark actually paints; library row insert cleaned up. Both still off until enabled under Critter Remarks.

## 1.4.1

- Critter On Library Toolbar (off by default): a short remark in the empty area of the file-browser Shortcuts Toolbar home (near the top strip by Search / Menu), not on the swipe shelf.

## 1.4.0

- Critter On Book Panel (off by default): a remark about the open book on the toolbar's book panel when you pull it down — not on the swipe shelf. Tap the line for another remark.

## 1.3.2

- Clean-up: This Book trace lines removed from crash.log.

## 1.3.1

- Book Panel Tap: more reliable BookOrbit This Book (Dispatcher/event fallbacks; pager forwards taps on the book panel page).

## 1.3.0

- Book Panel Tap (Shortcuts toolbar menu): tap the book panel to open BookOrbit's This book sheet, with Hold Opens Book Details so KOReader's book details stay a long-press away. Off by default; nothing changes until you turn it on.

## 1.2.2

- Covers are kept between menu opens, already sized, so the first swipe of a menu open doesn't resize them again (about 25 ms a cover on a Clara Colour). Up to 10 covers are kept. A SimpleUI cover that changes is picked up straight away.

## 1.2.1

- Suspend dismisses the shelf: if the Quick Shelf page is showing when the device sleeps, the pager drops back to the book panel.

## 1.2.0

- Renamed Quick Shelf (was Recent Books: it shows To Be Read too). File is now 2-shortcutstoolbar-quick-shelf.lua: delete 2-shortcutstoolbar-recent-books.lua. Your list choice carries over. If the old file is still there it's kept from doing anything, so the toolbar isn't patched twice.

## 1.1.0

- Swipe left or right: either flips to the other page (loops). No more ghosting: a page change flashes just the book row once.

## 1.0.0

- First release.
