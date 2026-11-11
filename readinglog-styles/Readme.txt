Reading Log Monthly Styles 2.1
24 styles for Reading Log (KOReader) by BrownTigerz: 17 that go with
Steven's 7 (stevenzamora1/reading-log-styles) so every month gets two,
and 7 extras. In the format of Steven's styles.
Drawings by Claude; the looks settings and this pack by Tiger.
Needs Reading Log 1.5.0 or newer.


The Year (1st-15th / 16th-end)

January    Northern Lights          Winter (Steven)
February   Candy Hearts             Lanterns
March      Maple                    Forest (Steven)
April      Rain                     Blossom
May        Garden                   Honey (Steven)
June       Solstice                 Campfire
July       Lake                     Ocean (Steven)
August     Sunflower                Space (Steven)
September  Library                  Fair
October    Pumpkin                  Gothic (Steven)
November   Poppy                    Hearth
December   Christmas (Steven)       Fireworks

Extras (not in the year above; pick them for any month by hand):
First Thaw, Meadow, Golden Wheat, Autumn Leaves, Ravens, Gingerbread, Star


What Every Style Does

- The rings card is one scene in a round window, not three rings: the
  pages lay it down, the minutes add to it, both goals done finishes it,
  and a streak adds a last touch. Every style has its own scene.
- Its own days, bar charts, year goal, Monthly challenge, progress bars
  (something rides along them), Today's timeline, calendar, covers and
  tab bar: all 14 of Reading Log's drawing hooks.
- The square, clipped-corner finish, like Cyber.
- A looks setting for the cards with no drawing hook (Books this year,
  Streak, Time read, Pages today, Pages turned, Total pages), picked by
  mood from Reading Log's own looks:
    Cute (hearts, notes, worms): Candy Hearts, Blossom, Garden, Meadow,
      Sunflower, Gingerbread, Rain
    Cyber (neon, monitor, counters): Fireworks, Northern Lights, Fair, Star
    Dark Academia (plaque, candles, card, book, ledger): Library, Hearth,
      Autumn Leaves, Ravens, Pumpkin, Campfire, Lanterns
    A few that suit, the rest left as they are: Lake, Poppy, Maple,
      Solstice, First Thaw, Golden Wheat
  With Reading Log Tweaks' Keep My Card Looks on, a card you've set by
  hand keeps your look.
- Night mode: the cards look the same as by day (Reading Log paints them
  pre-inverted). The tab bar is drawn pre-inverted at night too, so the
  open tab and its name keep their real colours. The open tab's name is
  at least 5:1 contrast on its box in every style.


Install

With Reading Log Tweaks 2.9.6 (download): turn on Styles > Change Style
Each Month and pick Monthly Sets > Monthly Styles. With Wi-Fi on, the
styles the year needs download by themselves (these from the
-KOReader.patches repo's readinglog-styles/ folder, Steven's from his),
at most once a day, or now with Download Styles Now. A newer version in
readinglog-styles/index.json updates them on the device the same way.

By hand: copy each style's folder into
koreader/settings/readinglog/styles/ on the Kobo, e.g.
koreader/settings/readinglog/styles/poppy/style.lua and draw.lua, and
restart KOReader. They show up in Tools > Reading Log > Styles and
colours, next to Default, Cute, Cyber and Dark Academia.

With Keep My Colours on (Reading Log Tweaks), your theme and accents
stay, and the square corners come with these styles (round again with
Steven's).


Notes

- index.json lists all 24 in Steven's format; Reading Log Tweaks 2.9.6
  reads it from readinglog-styles/ to download and update them. Reading
  Log's own Get more styles... only lists Steven's.
- Checks: every style.lua and draw.lua loaded in Reading Log's own
  sandbox with every drawing hook run at big and small sizes, on light
  and dark cards, with no errors; every looks value is one Reading Log
  has; previews drawn by day, with both goals done, on a Dark theme and
  in night mode.
- Not yet done: a look at them on the real Kobo. If anything errors on
  the device, Reading Log falls back to its usual drawing for that piece
  and writes the error to crash.log once.
