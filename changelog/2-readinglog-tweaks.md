# Reading Log Tweaks changelog

`2-readinglog-tweaks.lua`, newest first. Everything before 2.9.9 was moved here unchanged from the patch file on Nov 16, 2026.

## 2.9.9 (2026-11-16)

- Critter rewards stay at the critter's feet with SimpleUI 3.1.0, which adds a few rows under the critter for its new shadow (they were drawn that much lower).
- History moved out of the patch into this file.

## 2.9.8 (2026-11-11)

- Styles > Get Styles: every style Change Style Each Month can use (the Monthly Styles' 24, then Steven's 7), with a check when it's on the device and "(update)" when a newer one is out. Tap one to download just it; one on the device has Use It Now and Download Again / Update. Download All gets every missing one. Works with Change Style Each Month off, and doesn't count as the day's check.

## 2.9.7 (2026-11-11)

- Style downloads that finish: they come a few at a time, each few put in place before the next, so a tap (which stops a background download) or a restart only loses the few being fetched and the rest carry on next time. The day's check only counts once a download gets to the end. Download Styles Now shows how far it is (tap to stop). Half-done download folders (.<id>.new) are cleared, and a stopped download is noted in crash.log.

## 2.9.6 (2026-11-11)

- Monthly Styles download themselves: the set's own 24 styles come from the -KOReader.patches repo (readinglog-styles/), Steven's from his, in the background when Wi-Fi is already on (at most once a day, no timers) or from Download Styles Now. Styles from that repo also update themselves when its index.json has a newer version (never downgrades). Month lists offer the 24 before they're on the device.

## 2.9.5 (2026-11-11)

- Square corners: a downloaded style that asks for square corners (as Cyber and Dark Academia have) keeps them with Keep My Colours on: your theme takes the style's square corners while it's on and goes back to round with a round style; cards on their own on the home screen are framed by Reading Log meanwhile, as with Cyber. Monthly Sets: BrownTigerz Monthly Styles is now Monthly Styles: the 17 hand-copied styles with Steven's 7 (January Northern Lights and Winter ... December Christmas and Fireworks). Saved month picks are unchanged.

## 2.9.4 (2026-11-11)

- Change Style Each Month: two styles a month. Each month has a 1st half (1st-15th) and a 2nd half (16th to the end, or Same As 1st Half); the 2nd style goes on at the first Dashboard draw on or after the 16th, no timers. New, off by default: Random Order Each Month (a coin flip at the start of the month picks which of the two goes first; saved, and you always get both). New: Monthly Sets, all 12 months in one tap: BrownTigerz Monthly Styles (the 24 hand-copied styles, never sent for download), Downloadable Styles Two A Month, Reading Log's Own Styles, and Ready-Made One A Month (replaces Back To The Ready-Made List). Saved month picks are unchanged: a month with one style works as before.

## 2.9.3 (2026-11-11)

- Pocket watch back: the crash was this patch's, not Reading Log's (Reading Log's own page never crashed). A Smart card now hosts its card the way Reading Log's page does (the card keeps its own drawing cache, the Smart card none), and the Pocket watch is drawn again instead of the Brass dial. The critter's suggestions work out the unread list once and skip authors and genres with nothing unread (half the Random pick work after a restart, same suggestions). New, on by default: Quote Card Extras (Styles menu): every quote card, every look, shows the name under the quote bigger and in the accent (always smaller than the quote); a short quote is drawn bigger in the middle of the card; and Plain and Manuscript get a small divider between them, its mark from the style (a diamond; a snowflake for Winter and Christmas; a star for Space).

## 2.9.2 (2026-11-11)

- New, on by default: Keep My Card Looks (Styles menu): a look picked by hand in a card's own settings (Year in covers: Plain, the rings' shape...) stays when the style changes; the style changes the rest. Forget My Card Looks lets the styles decide again. Keep My Colours and Keep My Card Looks work together in one style change.

## 2.9.1 (2026-11-11)

- Book Club Picks on Both: the picks chooser lists only the books in the club's BookOrbit collections (ticked in Book Club Collections, or the card's own Collection), on this device or not, instead of your whole BookOrbit library; with no BookOrbit collection, none. Their lists are saved here and refreshed in the background with Wi-Fi already on (when the collections change, or every 6 hours), so a BookOrbit collection's books on this device count on the card even before its Side Panel view was opened. A downloaded pick from those collections isn't put into a KOReader collection; with several collections ticked, it goes into the first KOReader one, never a made-up one. New, on by default: Keep My Colours (Styles menu): a style change changes only how the cards look; your colour theme and accents stay. Dark Academia's Pocket watch rings are drawn as the Brass dial for now: the Pocket watch crashed KOReader now and then while being drawn (your setting stays Pocket watch). The Smart cards no longer draw their unused page dots a few pixels past the card's edge. Change Style Each Month moved into the new Styles menu.

## 2.9.0 (2026-11-11)

- Move Tab Row on Reading Log 1.5: the moved tab row now has what 1.5 added to it: a downloaded style's own tab bar (Gothic, Christmas, Forest, Ocean, Space, Honey, Winter), the plate behind the tabs over a wallpaper, the full-screen Dashboard's close button at the row's end, and the Yearly page's year switcher. New, off by default: Change Style Each Month. A style for each month (a ready-made list: January Winter, February Cute, March Forest, April-May Honey, June-July Ocean, August Space, September Forest, October Gothic, November Dark Academia, December Christmas; every month can be changed or set to Keep Current), put on with Reading Log's own style switch on the first Dashboard draw of a new month (no timers). Styles not on the device yet are downloaded in the background with Reading Log's own style downloads, only the ones the months use, only with Wi-Fi already on, at most once a day; that month waits for its style. The last few loops named _ are renamed.

## 2.8.1 (2026-11-07)

- SimpleUI 3.0.3: the critter's bubble counts the pixel style's new shadow when it sizes the text, and the critter gets SimpleUI's ground shadow like the home screen's. Loops no longer use _ as their variable (it's gettext's name).

## 2.8.0 (2026-10-31)

- Paired cards: Library gets a second side, Collecting Dust (books you haven't started, the longest waiting first, under a little dust), and Reading trends gets Discover Something New (BookOrbit's Discover topped up from your BookOrbit library, or the newest or random books on this device), 3 covers on top and 3 below, each title under its cover in the column's width. Each switch to the second side shows the next few books. The 1 / 2 sits in the card's top right corner like Continue reading's (the card's colours, square in the HUD look, turning with it at night), over what the card had there. Switch Cards By (Books): Tapping 1 / 2 (default, swipes change the tab) or Swiping; the Today Page Card follows it too. When You Come Back (Books): Alternate (now the default) moves Library, Trends and the Today Page Card to their next card each time you come back (a book, sleep, another home page or tab); you can still switch by hand. Keep Last keeps the one you chose. Continue reading and Smart Cards aren't affected. BookOrbit menu: Stock, BookOrbit or Both for Random pick, Collecting Dust, Book Club picks and Discover, or Use BookOrbit In Every Card; without BookOrbit every card is stock. Book Club picks can be books from the club's BookOrbit collections (compact window: download, read, remove; downloaded, it's that book). Clean Up Cache: old covers (the newest of each book kept, at most 600), half-finished cover downloads, deleted Side Panel downloads and unused old settings. Fix: BookOrbit covers could show as static (a cover still on screen was freed when the cache filled).

## 2.7.0 (2026-10-31)

- Library Card Takes Turns With Collecting Dust (Books, on): the Library card swapped with BookOrbit books you hadn't started when you came back. Replaced in 2.8.0 by the paired cards' 1 / 2.

## 2.6.1 (2026-10-31)

- A BookOrbit pick you downloaded counts as on the device at once: its own cover, and its window says Read / Continue Reading, with BookOrbit and Remove From Device (SimpleUI Side Panel 1.0.32). It stays the pick until you start it.

## 2.6.0 (2026-10-31)

- Random Pick Includes BookOrbit (Books, on): books in your BookOrbit library that aren't on this device can be the Random pick, with their BookOrbit cover; a tap shows the compact window with Download (straight from BookOrbit) and BookOrbit. Needs SimpleUI Side Panel 1.0.31 for covers and Download. The list refreshes in the background with Wi-Fi on, at most every 6 hours.

## 2.5.4 (2026-10-31)

- Continue reading's cover counts as one of the card's buttons: a When Tapped action set for the card no longer takes it over (it opened the book instead of Compact Detail).

## 2.5.3 (2026-10-31)

- Enter From The Side You Swipe From (Fine Tuning, on): swiping from another Simple UI page onto the Dashboard lands on its first tab when you swipe left and its last tab when you swipe right, so with Swipe Between Tabs the tabs and pages feel like one row.

## 2.5.2 (2026-10-31)

- Smart Cards only follow their rules: no swiping or dots to flip them by hand, so a swipe on one changes the tab (Swipe Between Tabs) or goes back to the home page's other page, like anywhere else on the Dashboard. Continue reading: the cover follows Book Tap Opens (Compact Detail), Details always opens Reading Log's own simple details, Continue opens the book.

## 2.5.1 (2026-10-31)

- Critters Say Notifications now also catches Network Tweaks' corner notes (Minimal style) and BookOrbit's pills, not just KOReader's own toasts; on your setup that's where nearly every notification comes from, so before this the critter never got any. Warning, loading and tap-to-act ones stay popups.

## 2.5.0 (2026-10-31)

- Three more Smart Cards: Smart Activity (Activity, Today's timeline, Finish forecast), Smart This Week (This week, Finish forecast, Today's timeline) and Smart Month (Pages per day, Monthly challenge, This week vs last). Two on one page never show the same card. Pages And Cards -> Smart Cards On Today And Monthly puts them in place of Activity, This week and Pages per day in one tap (and back). Continue reading's cover follows Book Tap Opens (Compact Detail), its Continue button still opens the book. Quote Of The Day (Books): SimpleUI's Quotes, the default, takes the Quote of the day card's quote from where SimpleUI's own Quote of the Day does (built-in list or your sui_quotes/ file), one a day, Another for the next; Your Highlights for Reading Log's own.

## 2.4.0 (2026-10-31)

- Critters Say Notifications (Critter, off by default; one setting shared with Shortcuts Toolbar Quick Shelf and SimpleUI Tweaks): a notification that comes in while the Dashboard's critter is on screen is said by the critter, in its bubble until its next remark, instead of the popup. Banners you can tap, questions and failures always stay popups.

## 2.3.0 (2026-10-31)

- Book Tap Opens: Compact Detail is the default when the SimpleUI Side Panel has its window (1.0.26+): a tap on any book cover in Reading Log shows the same compact window as the side panel. Continue reading's Continue and the hold menu's Open still open the book straight away (before, in Compact Detail they showed the window too). "Default" is now "Reading Log's Own" (saved as its own choice). Fixed: 2.0.2's settings move stored Book Tap Opens as "default" on every device ("x and nil or y" is always y in Lua); that's now read as not chosen.

## 2.2.0 (2026-10-31)

- Smart Cards: Smart: Current Book, Smart: Goals and Smart: Shelf, in Pages And Cards like any card. Each shows whichever card of its group matters now, decided when you come back to the Dashboard (a book closed, waking, turning back onto its page), never while you look. First rule that's true wins: Finish forecast when a book is 2 h or less from done, Today's timeline after 6 PM with 2+ sessions, This Book once you've read today; Finish by within 7 days, Year Goal With Covers after a finish (3 days) or a book behind pace, Monthly challenge in the month's last week, This week vs last on your week's first 2 days; Recently finished (3 days), Book club in the month's first week, Random pick after 3 days without reading, TBR shelf with only one book going. None true: the next card in turn. Dots or a swipe flip by hand, until you come back. Finish by without a book and date is left out. Continue reading stays where it is. Hold A Cover now also works on a card inside a Smart Card or the Today swipe spot.

## 2.1.0 (2026-10-31)

- New: This Book card (the book you're on: time spent, sessions this week, pages today, pace, finish date at your last two weeks' pace; from KOReader's statistics, read again only when they change). Swipe Between Tabs (Fine Tuning, off): swipe left/right on the Dashboard for the next/previous tab; at the ends Simple UI turns its page. Hold A Cover For Quick Actions (Books, on): long-press a cover for Open, Book Details, Reading / On hold / Finished, Add To / Remove From To Be Read and Collections. The critter's weekly recap: on the first two days of the week, last week's time, books and best day, once (Donny, Blu and Donny & Blu in their own voice with critter-phrases.lua 1.2.0).

## 2.0.3 (2026-10-31)

- Fine Tuning: Tab Bar Position is now Move Tab Row, its own setting (rlt_tabs_move; Reading Log 2.0's Tab Bar Position in Appearance is separate, they shared tabs_adjust). Down really moves it: away from the cards toward the page dots (the margin, and in Full Screen the room Bottom Space adds), then the cards get shorter, so the gap grows by the whole amount. Before, down only went into the margin (a few px, none with Margins at None). The moved layout shows Year in Review on the Yearly page in December like Reading Log 2.0. A Patch Backup made before 2.0.2 restores again (its 1.x keys are moved over on the next start), and the old flash-clean key is cleared.

## 2.0.2 (2026-10-30)

- Settings keys are rlt_* only. No personal labels in code or comments. Schema 3 migrates 1.x keys once, then clears them. Book Tap Opens unchanged.

## 2.0.0 (2026-10-30)

- Settings schema: Book Tap Opens (Default / Compact / BookOrbit). Neutral header. Menu Books group. Critter kept.

## 1.1.12 (2026-10-30)

- Patch Backup & Restore 3.0: registers its settings, so they are in Everything and in One Patch Or Plugin.

## 1.1.11 (2026-10-30)

- Compact Book Detail (needs SimpleUI Side Panel 1.0.26+): when on, a tap on a book (Book Club picks, covers on cards that use Reading Log's book details) opens the same compact window as the Side Panel — cover, author, description, Open / BookOrbit / Cancel — instead of opening the book or the full details page. Off = default.

## 1.1.10 (2026-10-30)

- Polish: an unused local and a leftover line counter from the phrase bank log removed.

## 1.1.9 (2026-10-30)

- Clean-up: Flash To Clear Ghosting removed (Simple UI's own Flash On Every Page Turn does the same). Menu grouped: Today Page Card, Continue Reading: Buttons Only, Book Club, When You Come Back, BookOrbit, Critter Remarks, Fine Tuning. Debugging trace lines removed; real failures still go to crash.log.

## 1.1.8 (2026-10-30)

- Alternate: the Today card also moves on when the device goes to sleep and when a book is opened (not only on waking and on closing the book), so it can't be missed; Debugging lines say when it's armed and when it moves.

## 1.1.7 (2026-10-30)

- Book Club Collections: tick one or more collections (KOReader's and BookOrbit's) and the Book Club card and its picks chooser use all their books together. None ticked: the card's own Collection, as before.

## 1.1.6 (2026-10-30)

- BookOrbit Collections (on by default): BookOrbit's collections show next to KOReader's wherever Reading Log lists one (Book Club's Collection and picks, shelf cards), as "BookOrbit: <name>". Books come from the SimpleUI Side Panel's saved lists (1.0.18+), on-device books only; never waits on the server.

## 1.1.5 (2026-10-30)

- Alternate (Today swipe card) and Start On Tab now show when you come back: SimpleUI often reshows the home screen without rebuilding it (after sleep, and after a book with Fast Book Closing), so the Dashboard is rebuilt once when that happens. Book Club Opens Picks: Off / On Hold / On Tap (1.1.4's tap only worked off the picks, which fill nearly the whole card); Hold keeps a tap on a pick opening that book.

## 1.1.4 (2026-10-30)

- Start On Tab (Last Viewed by default, or a tab: after a book, after sleep, or turning back onto the page) and Start On First Page After Reading Or Sleep (off), like Reading Log for SimpleUI. Book Club: Tap Opens Picks (off): a tap on the card goes straight to this month's book chooser; a tap on a pick still opens the book.

## 1.1.3 (2026-10-30)

- Continue Reading: Buttons Only (off by default): the card opens the book only from its Continue button (or the cover where that's the button), like Reading Log for SimpleUI; a tap anywhere else does nothing.

## 1.1.2 (2026-10-30)

- The page insights (comeback, a run of days, best day this month, book milestone, goal pace, weekend reading) in Donny, Blu and Donny & Blu's own voice about half the time: critter-phrases.lua's insight_voices. Under Critter's Own Voice.

## 1.1.1 (2026-10-30)

- Donny, Blu and Donny & Blu speak in their own voice too (lines in critter-phrases.lua, added by SimpleUI Tweaks 2.14.9+).

## 1.1.0 (2026-10-30)

- Critter, better: its own voice (SimpleUI 3.0.2's Suey, Chonk, Tulu, Frankie, Vlad, Sholmes, Argos and Hazel say about one remark in three their own way, on the pages their lines fit); Games And Quotes in the talk window (rock, paper, scissors, heads or tails, guess the author, read me a quote; its last word shows in the bubble); Critter Rewards (book stack, streak medal and trophy, anniversary balloon, here and on the home screen). Each has its own switch under Critter. The watch on KOReader's module list is removed once Reading Log's kit is found.

## 1.0.0 (2026-10-30)

- First release: Fine Tuning (Full Screen, Bottom Space, Tab Bar Position), Flash To Clear Ghosting, Book Taps Open BookOrbit, critter follows SimpleUI 3.0.2's one-for-every-screen critter setting, Today Page Card (single or swipe), Year Goal With Covers, Critter Remarks with book suggestions and the talk window.
