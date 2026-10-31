--[[
2-readinglog-tweaks.lua
KOReader user patch: TK's extras from "Reading Log for SimpleUI" on
stevenzamora1's Reading Log 1.4+ (readinglog.koplugin), for Simple UI.

Version: 1.1.10

  Today Page Card    the card under the rings on the Today tab: Year Goal With
                     Covers, Year Goal, Book Club, Recently Finished or TBR
                     Shelf. Or Swipe Between 2-3 Cards: tick up to 3 (a 4th
                     replaces the oldest), then swipe left/right on the card
                     or tap its dots. Alternate Or Keep Last and Flash On
                     Swipe work as in Reading Log for SimpleUI.
  Year Goal With     a new card: the year goal on the left, this year's
  Covers             covers on the right, a pace bar along the bottom. Also
                     in Pages And Cards and as its own Simple UI module.
  Fine Tuning        Layout: In The Page or Full Screen (fills everything
                     between the status bar and the nav bar); Bottom Space
                     (Full Screen: room for the page dots); Tab Bar Position.
                     Size and Height are Reading Log's own (Appearance).
  Continue Reading:  opens the book only from its Continue button (off by
  Buttons Only       default).
  Book Club          Collections: one or more (KOReader's and BookOrbit's)
                     together. Opens Picks: hold or tap the card to choose
                     this month's books.
  When You Come      Start On Tab (Last Viewed by default) and Start On First
  Back               Page After Reading Or Sleep (off).
  BookOrbit          BookOrbit Collections (with SimpleUI Side Panel 1.0.18+)
                     and Book Taps Open BookOrbit (off). Shown only with
                     BookOrbit installed.
  Critter Remarks    SimpleUI 3.0's Tiny Critter peeks into each Dashboard
                     page (the heading row; on Today, the banner's spare room)
                     with a remark about that page's numbers, and suggests
                     books. Tap it to talk, play a game or hear a quote.
                     SimpleUI 3.0.2's critters speak in their own voice.
                     Rewards: books, a streak medal or trophy and an
                     anniversary balloon beside the critter. Needs SimpleUI
                     3.0 with Tiny Critter (the critter code is built into
                     this file; voice and games need 3.0.2).

Settings: long-press the Dashboard > Reading Log Tweaks, or Tools > Add-ons > Patches
(with 2-tweaks-menu.lua). Everything is saved in Reading Log's own settings
file (keys starting tk_ and critter_).

Install: copy 2-readinglog-tweaks.lua into koreader/patches/ (Kobo:
.adds/koreader/patches/), then restart. One file, nothing else needed;
critter-phrases.lua there is used if you have it (the shared phrase bank).
Delete it and restart to undo; the Today page goes back to whatever
its rows say (Pages And Cards > Put This Page Back fixes a swipe slot left
behind).

Works only with stevenzamora1's readinglog.koplugin (1.4+); his Bookshelf
cards aren't touched. TK's simpleui_readinglog.koplugin isn't touched either
(it already has all of this).

Versioning: 1.0.x fixes, 1.x.0 new features, 2.0.0 settings changes.

Changelog:
  1.1.10 2026-10-30  Polish: an unused local and a leftover line counter
                     from the phrase bank log removed.
  1.1.9  2026-10-30  Clean-up: Flash To Clear Ghosting removed (Simple UI's
                     own Flash On Every Page Turn does the same). Menu
                     grouped: Today Page Card, Continue Reading: Buttons
                     Only, Book Club, When You Come Back, BookOrbit,
                     Critter Remarks, Fine Tuning. Debugging trace lines
                     removed; real failures still go to crash.log.
  1.1.8  2026-10-30  Alternate: the Today card also moves on when the device
                     goes to sleep and when a book is opened (not only on
                     waking and on closing the book), so it can't be missed;
                     Debugging lines say when it's armed and when it moves.
  1.1.7  2026-10-30  Book Club Collections: tick one or more collections
                     (KOReader's and BookOrbit's) and the Book Club card and
                     its picks chooser use all their books together. None
                     ticked: the card's own Collection, as before.
  1.1.6  2026-10-30  BookOrbit Collections (on by default): BookOrbit's
                     collections show next to KOReader's wherever Reading
                     Log lists one (Book Club's Collection and picks, shelf
                     cards), as "BookOrbit: <name>". Books come from the
                     SimpleUI Side Panel's saved lists (1.0.18+), on-device
                     books only; never waits on the server.
  1.1.5  2026-10-30  Alternate (Today swipe card) and Start On Tab now show
                     when you come back: SimpleUI often reshows the home
                     screen without rebuilding it (after sleep, and after a
                     book with Fast Book Closing), so the Dashboard is
                     rebuilt once when that happens. Book Club Opens Picks:
                     Off / On Hold / On Tap (1.1.4's tap only worked off the
                     picks, which fill nearly the whole card); Hold keeps a
                     tap on a pick opening that book.
  1.1.4  2026-10-30  Start On Tab (Last Viewed by default, or a tab: after
                     a book, after sleep, or turning back onto the page) and
                     Start On First Page After Reading Or Sleep (off), like
                     Reading Log for SimpleUI. Book Club: Tap Opens Picks
                     (off): a tap on the card goes straight to this month's
                     book chooser; a tap on a pick still opens the book.
  1.1.3  2026-10-30  Continue Reading: Buttons Only (off by default): the
                     card opens the book only from its Continue button (or
                     the cover where that's the button), like Reading Log
                     for SimpleUI; a tap anywhere else does nothing.
  1.1.2  2026-10-30  The page insights (comeback, a run of days, best day
                     this month, book milestone, goal pace, weekend reading)
                     in Donny, Blu and Donny & Blu's own voice about half the
                     time: critter-phrases.lua's insight_voices. Under
                     Critter's Own Voice.
  1.1.1  2026-10-30  Donny, Blu and Donny & Blu speak in their own voice too
                     (lines in critter-phrases.lua, added by SimpleUI Tweaks
                     2.14.9+).
  1.1.0  2026-10-30  Critter, better: its own voice (SimpleUI 3.0.2's Suey,
                     Chonk, Tulu, Frankie, Vlad, Sholmes, Argos and Hazel
                     say about one remark in three their own way, on the
                     pages their lines fit); Games And Quotes in the talk
                     window (rock, paper, scissors, heads or tails, guess
                     the author, read me a quote; its last word shows in
                     the bubble); Critter Rewards (book stack, streak medal
                     and trophy, anniversary balloon, here and on the home
                     screen). Each has its own switch under Critter.
                     The watch on KOReader's module list is removed once
                     Reading Log's kit is found.
  1.0.0  2026-10-30  First release: Fine Tuning (Full Screen, Bottom Space,
                     Tab Bar Position), Flash To Clear Ghosting, Book Taps
                     Open BookOrbit, critter follows SimpleUI 3.0.2's
                     one-for-every-screen critter setting, Today Page
                     Card (single or swipe), Year
                     Goal With Covers, Critter Remarks with book
                     suggestions and the talk window.
]]

local PATCH_VERSION = "1.1.10"

local logger = require("logger")
local TAG = "[readinglog-tweaks]"

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local unpack = unpack or table.unpack


local function warn(...) logger.warn(TAG, ...) end

-- ─── the critter (built in) ────────────────────────────────────────────────
-- Called with Reading Log's kit; returns the critter (A.critter).
local function critterKit(...)
    --[==[
    Built in: the same code as Reading Log for SimpleUI's critter, plus a
    paint-cache mark so a new remark is never drawn from an old picture.

    Critter remarks: SimpleUI 3.0's Tiny Critter peeks into each Dashboard page
    and says something about that page's numbers ("3 books ahead of your goal
    pace.", "47 unread books waiting.").

      * The critter, its moods and its speech bubble are SimpleUI's own (the
        critter you picked for the home screen, its bubble style, its text
        sizes and its mood), borrowed from simpleui.koplugin/modules/critter.
        Without SimpleUI 3.0's Tiny Critter none of this shows.
      * Each page keeps its remark for the day (redraws, the per-minute clock and
        turning back to the page keep it, with its numbers kept current). Tap the
        critter for another one. Remarks are dealt like the critter's own phrases:
        none comes round again before the others on that page have been seen.
      * Nothing moves and nothing runs on a timer.
      * Insights: getting back into the habit, your best day this month, book
        milestones, your goal pace (books left over days left) and what this
        month needs for it, weekend reading,
        a book minutes from the end, one you left a while ago, the next in a
        series you just finished, something different after a run of one genre.
        Each only when the stats back it (enough days read, real minutes). The
        big news of the day (goal done, a record, a comeback) comes first.
      * A book you passed on ("Another suggestion") isn't suggested again that day.
      * Settings: statistics remarks, book suggestions and streak remarks can be
        turned off on their own.

    Settings > Critter Remarks turns it off (stored as critter_peek).
    ]==]

    local A = ...
    local D = A.D

    local floor, max = math.floor, math.max

    local C = {}
    A.critter = C

    local SUI_PREFIX = "simpleui_hs_"
    local DECK_KEY = "readinglog_critter_deck_"

    local function sui(name)
        local m = package.loaded[name]
        if m ~= nil then return m end
        local ok, mod = pcall(require, name)
        return ok and mod or nil
    end

    -- SimpleUI 3.0's critter files, or nil without them.
    local function kit()
        local Sprite, Bubble, Assets = sui("modules/critter/sprite"), sui("modules/critter/bubble"), sui("modules/critter/assets")
        if type(Sprite) ~= "table" or type(Bubble) ~= "table" or type(Assets) ~= "table"
                or type(Bubble.build) ~= "function" or type(Assets.get) ~= "function" then
            return nil
        end
        return { Sprite = Sprite, Bubble = Bubble, Assets = Assets,
                 Mood = sui("modules/critter/mood"), Store = sui("infra/sui_store"),
                 Style = sui("features/sui_style"), Config = sui("infra/sui_config"),
                 Deck = sui("infra/sui_deck") }
    end

    function C.available() return kit() ~= nil end
    function C.enabled() return A.get("critter_peek", true) ~= false and C.available() end

    -- ─── facts ───────────────────────────────────────────────────────────────────

    local function n_(n, one, many) return A.plural(n, one, many) end
    local suggestions, questFacts   -- below

    local function mins(secs) return floor((secs or 0) / 60 + 0.5) end

    local function short(s, n)
        s = tostring(s or "")
        n = n or 28
        if #s <= n then return s end
        return s:sub(1, n - 1):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "\xE2\x80\xA6"
    end

    local function q(s) return "\xE2\x80\x9C" .. short(s) .. "\xE2\x80\x9D" end

    local MONTHS = { "January", "February", "March", "April", "May", "June", "July",
                     "August", "September", "October", "November", "December" }

    local function hourText(hr)
        local h12 = hr % 12 == 0 and 12 or hr % 12
        return string.format("%d %s", h12, hr < 12 and "AM" or "PM")
    end

    -- ─── suggestions: books worth opening, worked out from the stats ─────────────
    -- From the library (finished books' authors, series and genres; books on
    -- hold; an unread pick) and from the books in progress (one that could be
    -- done tonight; how much sooner a little more a day would finish one).
    -- The library part is worked out once a day (and when the library changes);
    -- the book chosen for each stays the same all day.

    local function dayIndex(list, salt)
        if #list == 0 then return nil end
        local n = tonumber(os.date("%j")) or 1
        for i = 1, #salt do n = n + salt:byte(i) end
        return list[n % #list + 1]
    end

    local function tally(books, field)
        local t, order = {}, {}
        for _, b in ipairs(books) do
            if b.status == "finished" then
                for _, v in ipairs(b[field] or {}) do
                    local k = v:lower()
                    if not t[k] then t[k] = { name = v, n = 0 }; order[#order + 1] = k end
                    t[k].n = t[k].n + 1
                end
            end
        end
        local out = {}
        for _, k in ipairs(order) do out[#out + 1] = t[k] end
        table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
        return out
    end

    local function librarySuggestions(lib, recent)
        local books = lib.books or {}
        local sug = {}
        recent = recent or {}
        local by_fp = {}
        for _, b in ipairs(books) do by_fp[b.fp] = b end
        -- the next in a series you finished a book of in the last 60 days
        local now = os.time()
        for _, r in ipairs(recent) do
            if now - (r.at or 0) > 60 * 86400 then break end
            local b = by_fp[r.fp]
            if b and b.series then
                local key = b.series:lower()
                for _, c in ipairs(D.pickCandidates(books, {})) do
                    if c.series and c.series:lower() == key then
                        sug.series_next = { done = r.title or b.title, name = b.series, book = c }
                        break
                    end
                end
                if sug.series_next then break end
            end
        end
        -- your last 3 finished share a genre: something from another one you like
        if #recent >= 3 then
            local common
            for _, g in ipairs(recent[1].genres or {}) do
                local k = g:lower()
                local all = true
                for i = 2, 3 do
                    local has = false
                    for _, h in ipairs(recent[i].genres or {}) do if h:lower() == k then has = true end end
                    if not has then all = false break end
                end
                if all then common = g break end
            end
            if common then
                local ck = common:lower()
                for _, g in ipairs(tally(books, "genres")) do
                    if g.name:lower() ~= ck then
                        local cands = {}
                        for _, c in ipairs(D.pickCandidates(books, { genres = { g.name } })) do
                            local same = false
                            for _, h in ipairs(c.genres or {}) do if h:lower() == ck then same = true end end
                            if not same then cands[#cands + 1] = c end
                        end
                        if #cands > 0 then
                            sug.variety = { same = common, other = g.name, book = dayIndex(cands, "variety") }
                            break
                        end
                    end
                end
            end
        end
        -- unread books by authors you've finished
        local fin_auth = {}
        for _, b in ipairs(books) do
            if b.status == "finished" then for _, a in ipairs(b.authors or {}) do fin_auth[a:lower()] = true end end
        end
        local n = 0
        for _, b in ipairs(books) do
            if b.status == "unread" then
                for _, a in ipairs(b.authors or {}) do if fin_auth[a:lower()] then n = n + 1 break end end
            end
        end
        if n >= 3 then sug.discover = n end
        -- an author you finish, with a book of theirs not started yet
        for _, a in ipairs(tally(books, "authors")) do
            local cands = D.pickCandidates(books, { authors = { a.name } })
            if #cands > 0 then
                sug.author = { name = a.name, n = a.n, book = dayIndex(cands, "author" .. a.name) }
                break
            end
        end
        -- the next book of a series you've finished a book of
        local done_series = {}
        for _, b in ipairs(books) do
            if b.status == "finished" and b.series then done_series[b.series:lower()] = b.series end
        end
        local next_in = {}
        for _, c in ipairs(D.pickCandidates(books, {})) do
            if c.series and done_series[c.series:lower()] then next_in[#next_in + 1] = c end
        end
        if #next_in > 0 then
            local b = dayIndex(next_in, "series")
            sug.series = { name = b.series, num = b.num, book = b }
        end
        -- a genre you finish, with a book in it not started yet
        for _, g in ipairs(tally(books, "genres")) do
            if g.n >= 2 then
                local cands = D.pickCandidates(books, { genres = { g.name } })
                if #cands > 0 then
                    sug.genre = { name = g.name, n = g.n, book = dayIndex(cands, "genre" .. g.name) }
                    break
                end
            end
        end
        -- a book on hold
        local held = {}
        for _, b in ipairs(books) do if b.status == "on_hold" then held[#held + 1] = b end end
        if #held > 0 then
            local b = dayIndex(held, "hold")
            local pct = D.progress(b.fp)
            sug.hold = { book = b, pct = tonumber(pct) }
        end
        -- anything not started yet
        local any = D.pickCandidates(books, {})
        if #any > 0 then sug.pick = { book = dayIndex(any, "pick") } end
        return sug
    end

    suggestions = function(f)
        if f.lib and f.lib.books then
            local key = os.date("%Y-%m-%d") .. "|" .. f.lib.total .. "|" .. (f.lib.counts.finished or 0)
                .. "|" .. (f.lib.counts.on_hold or 0)
            local c = A.state.critter_sug
            if not (c and c.key == key) then
                local ok, v = pcall(librarySuggestions, f.lib, f.finished_recent)
                c = { key = key, value = ok and v or {} }
                A.state.critter_sug = c
            end
            f.sug = c.value
        else
            f.sug = {}
        end
        -- from the books in progress and your usual day
        local avg_min = f.avg_secs and f.avg_secs / 60 or nil
        local now = os.time()
        for _, b in ipairs(f.reading or {}) do
            -- a quick win: minutes from the end
            if not f.sug.quick and b.left_min and b.left_min >= 2 and b.left_min <= 25 then
                f.sug.quick = { book = b, left = b.left_min }
            end
            -- one you left a while ago, well under way
            if not f.sug.stale and b.opened and now - b.opened >= 14 * 86400 and (b.pct or 0) >= 0.15 and b.pct <= 0.9 then
                f.sug.stale = { book = b, days = floor((now - b.opened) / 86400) }
            end
        end
        -- a few quiet days: the book you were on
        if f.idle and f.idle >= 3 and f.reading and f.reading[1]
                and not (f.quiet_key and A.get("critter_quiet_pass") == f.quiet_key) then
            f.sug.recover = { book = f.reading[1], days = f.idle }
        end
        for _, b in ipairs(f.reading or {}) do
            if b.left_min and b.left_min > 0 and avg_min and avg_min >= 5 then
                if not f.sug.tonight and b.left_min <= avg_min * 1.5 then
                    f.sug.tonight = { book = b, left = b.left_min, usual = avg_min }
                end
                if not f.sug.boost then
                    local now_days = math.ceil(b.left_min / avg_min)
                    local more_days = math.ceil(b.left_min / (avg_min + 10))
                    if now_days - more_days >= 2 then
                        f.sug.boost = { book = b, now_days = now_days, more_days = more_days }
                    end
                end
            end
        end
    end

    -- ReadMastery quests (ReadMastery Quests patch 1.0.6+, Quests (Enhanced) on):
    -- today's daily quests still open, and a "finish N books" quest one book short
    -- near the end of its week or month.
    questFacts = function(f)
        local Q = rawget(_G, "ReadMasteryQuests")
        if type(Q) ~= "table" or type(Q.enabled) ~= "function" or not Q.enabled() then return end
        if type(Q.daily) == "function" then
            local ok, list = pcall(Q.daily)
            if ok and type(list) == "table" then
                for i = #list, 1, -1 do
                    local q = list[i]
                    if not q.done then f.quest_daily = q break end
                end
            end
        end
        if type(Q.open) == "function" then
            local ok, list = pcall(Q.open)
            if ok and type(list) == "table" then
                for _, q in ipairs(list) do
                    local window = ({ weekly = 2, monthly = 5 })[q.period]
                    if q.type == "books_finished" and q.need - q.have == 1 and window and q.days_left <= window then
                        f.quest_book = q
                        break
                    end
                end
            end
        end
    end

    -- Reading days: the run up to today (or yesterday), the quiet stretch before
    -- it, the days since you last read, your best day this month, weekends.
    local MIN_DAY_SECS = 60
    local function backKey(t, back)
        return os.date("%Y-%m-%d", os.time{ year = t.year, month = t.month, day = t.day - back, hour = 12 })
    end
    -- Worked out once per day and minutes read today (redraws reuse it).
    local _rhythm = {}
    local function rhythm(f)
        local key = os.date("%Y-%m-%d") .. "|" .. tostring(f.today_secs) .. "|" .. tostring(A.epoch)
        if _rhythm.key ~= key then
            local r = {}
            local days, t = f.st.days, f.t
            local BACK = 120
            local function secs(i)
                if i == 0 then return f.today_secs or 0 end
                local rec = days[backKey(t, i)]
                return rec and rec.secs or 0
            end
            local function read(i) return secs(i) >= MIN_DAY_SECS end
            local start = read(0) and 0 or 1
            local i, run = start, 0
            while i < BACK and read(i) do run = run + 1; i = i + 1 end
            local gap = 0
            while i < BACK and not read(i) do gap = gap + 1; i = i + 1 end
            if i < BACK then
                r.run, r.gap = run, gap               -- a reading day before the gap
                if run > 0 then r.run_start = backKey(t, start + run - 1) end
            end
            if not read(0) then
                local k = 1
                while k < BACK and not read(k) do k = k + 1 end
                if k < BACK then r.idle, r.quiet_key = k - 1, backKey(t, k) end   -- since the last reading day
            end
            -- best day of the month, in minutes read: a week in, 20 min+, more
            -- than each of 5+ earlier reading days this month
            if t.day >= 7 and (f.today_secs or 0) >= 1200 then
                local others, top = 0, 0
                for d = 1, t.day - 1 do
                    local sv = secs(d)
                    if sv >= MIN_DAY_SECS then others = others + 1; if sv > top then top = sv end end
                end
                if others >= 5 and f.today_secs > top then r.day_record = true end
            end
            -- weekends against weekdays, the last 8 weeks: 4+ weekend and 8+
            -- weekday reading days. 1.6x says so; the verdict then stays until
            -- the difference is mostly gone (under 1.2x).
            local we, wd, we_n, wd_n = 0, 0, 0, 0
            for d = 1, 56 do
                local sv = secs(d)
                local wday = os.date("*t", os.time{ year = t.year, month = t.month, day = t.day - d, hour = 12 }).wday
                if wday == 1 or wday == 7 then
                    we = we + sv; if sv >= MIN_DAY_SECS then we_n = we_n + 1 end
                else
                    wd = wd + sv; if sv >= MIN_DAY_SECS then wd_n = wd_n + 1 end
                end
            end
            local prev = A.get("critter_weekend")
            local v = prev
            if we_n >= 4 and wd_n >= 8 then
                local we_avg, wd_avg = we / 16, wd / 40
                v = nil
                if we_avg >= 1.6 * wd_avg then v = "weekend"
                elseif wd_avg >= 1.6 * we_avg then v = "weekday"
                elseif prev == "weekend" and we_avg >= 1.2 * wd_avg then v = "weekend"
                elseif prev == "weekday" and wd_avg >= 1.2 * we_avg then v = "weekday" end
                if v == "weekend" then r.weekend_x = wd_avg > 0 and we_avg / wd_avg or 9
                elseif v == "weekday" then r.weekend_x = we_avg > 0 and wd_avg / we_avg or 9 end
                if v ~= prev then A.set("critter_weekend", v) end
            end
            if v and r.weekend_x then r.weekend = v end
            _rhythm = { key = key, r = r }
        end
        for k, v in pairs(_rhythm.r) do f[k] = v end
        A.state.critter_quiet_key = f.quiet_key
    end

    -- Books finished this month and the two before, newest first (with `at`).
    local function recentFinished(f, refresh)
        local t, list = f.t, {}
        for back = 0, 2 do
            local y, m = t.year, t.month - back
            if m < 1 then y, m = y - 1, m + 12 end
            local ok, fin = pcall(D.finishedIn, refresh, y, m)
            if ok and type(fin) == "table" then
                for _, b in ipairs(fin) do
                    list[#list + 1] = { fp = b.fp, title = b.title, genres = b.genres,
                        at = os.time{ year = b.year or y, month = b.month or m, day = b.day or 1, hour = 12 } }
                end
            end
        end
        table.sort(list, function(a, b) return a.at > b.at end)
        f.finished_recent = list
        -- a milestone, reached in the last 3 days
        local n = f.year_done
        if n and list[1] and os.time() - list[1].at <= 3 * 86400 and os.date("%Y", list[1].at) == tostring(t.year)
                and (({ [5] = 1, [10] = 1, [25] = 1, [50] = 1, [75] = 1, [100] = 1 })[n] or (n > 100 and n % 50 == 0)) then
            f.milestone = n
            f.milestone_new = os.date("%Y-%m-%d", list[1].at) == os.date("%Y-%m-%d")   -- finished today
        end
    end

    -- Books you passed on today ("Another suggestion"), by file.
    local function dismissed()
        local d = A.get("critter_dismissed")
        if type(d) == "table" and d.day == os.date("%Y-%m-%d") and type(d.fps) == "table" then return d.fps end
        return {}
    end
    function C.dismiss(fp, page)
        -- passing on the quiet-days nudge: not again this quiet stretch
        local cur = A.state.critter and A.state.critter[(page and page.id) or "?"]
        if cur and cur.id == "s_recover" and A.state.critter_quiet_key then
            A.set("critter_quiet_pass", A.state.critter_quiet_key)
        end
        if type(fp) ~= "string" then return end
        local fps = dismissed()
        local keep = {}
        for k, v in pairs(fps) do keep[k] = v end
        keep[fp] = true
        A.set("critter_dismissed", { day = os.date("%Y-%m-%d"), fps = keep })
    end

    -- Everything the remarks read, gathered once per build. Missing pieces stay nil.
    local function facts(refresh)
        local f = { t = os.date("*t") }
        local t = f.t
        local ok_st, st = pcall(D.stats, refresh)
        if ok_st and type(st) == "table" then
            f.st = st
            f.today_secs, f.today_pages = st.today.secs or 0, st.today.pages or 0
            f.streak, f.best = st.streak or 0, st.best or 0
            local ok_avg, avg = pcall(D.recentAverage, st)
            if ok_avg and avg then f.avg_secs, f.avg_pages = avg.secs, avg.pages end
            -- last week, the same days so far as this week
            local lw_pages, tw_pages = 0, st.week_pages or 0
            for i = 1, 7 do
                local d = st.week[i]
                local y, m, dd = A.parseYmd(d and d.key)
                if y and not d.future then
                    local key = os.date("%Y-%m-%d", os.time{ year = y, month = m, day = dd - 7, hour = 12 })
                    local rec = st.days[key]
                    lw_pages = lw_pages + (rec and rec.pages or 0)
                end
            end
            f.week_pages, f.last_week_pages = tw_pages, lw_pages
            -- months of this year
            local best_m, best_p, done_m, sum_p = nil, 0, 0, 0
            for m = 1, t.month - 1 do
                local p = st.month_pages[m] or 0
                if p > best_p then best_m, best_p = m, p end
                if p > 0 then done_m, sum_p = done_m + 1, sum_p + p end
            end
            f.month_pages = st.month_pages[t.month] or 0
            f.best_month, f.best_month_pages = best_m, best_p
            f.month_avg = done_m > 0 and sum_p / done_m or nil
            f.prev_month_pages = t.month > 1 and (st.month_pages[t.month - 1] or 0) or nil
            -- favourite hour over the last 30 days
            local top_hr, top_s, total = nil, 0, 0
            for hr = 0, 23 do
                local s = st.hours and st.hours.days30 and st.hours.days30[hr] or 0
                total = total + s
                if s > top_s then top_hr, top_s = hr, s end
            end
            if total > 3600 then f.fav_hour, f.fav_share = top_hr, top_s / total end
        end
        local ok_goal, goal_min = pcall(D.dailyMinutesGoal)
        f.goal_min = ok_goal and goal_min or nil
        local ok_yr, yr = pcall(D.year, refresh)
        if ok_yr and type(yr) == "table" then
            local ok_p, pace = pcall(D.yearPace, yr)
            if ok_p and pace then
                f.year_done, f.year_goal, f.year_projected = pace.done, pace.goal, pace.projected
                local doy = tonumber(os.date("%j")) or 1
                local diy = tonumber(os.date("%j", os.time{ year = t.year, month = 12, day = 31, hour = 12 })) or 365
                if pace.goal and pace.goal > 0 then f.year_expected = pace.goal * doy / diy end
            end
            local ok_f, fin = pcall(D.finishedIn, refresh, t.year, t.month)
            if ok_f and type(fin) == "table" then f.month_books = #fin end
        end
        local ok_lib, lib = pcall(D.library, refresh)
        if ok_lib and type(lib) == "table" and lib.counts then f.lib = lib end
        local ok_r, reading = pcall(D.reading, 5)
        if ok_r and type(reading) == "table" then
            f.reading = reading
            local close
            for _, b in ipairs(reading) do
                if (b.pct or 0) >= 0.5 and (not close or b.pct > close.pct) then close = b end
            end
            f.closest = close
        end
        f.days_in_month = tonumber(os.date("%d", os.time{ year = t.year, month = t.month + 1, day = 0, hour = 12 })) or 30
        f.month_left = f.days_in_month - t.day + 1
        if f.st and type(f.st.days) == "table" then pcall(rhythm, f) end
        pcall(recentFinished, f, refresh)
        -- goal pace: what's left over the days left (from mid-January), on pace
        -- or catching up; and what this month needs (1 to 3 books, from the 10th)
        if f.year_goal and f.year_goal > 0 and f.year_done and f.year_done < f.year_goal then
            local diy = tonumber(os.date("%j", os.time{ year = t.year, month = 12, day = 31, hour = 12 })) or 365
            local doy = tonumber(os.date("%j")) or 1
            if doy >= 14 then
                local left, days_left = f.year_goal - f.year_done, diy - doy + 1
                f.pace = { left = left, days_left = days_left,
                           on = f.year_done >= f.year_goal * doy / diy - 0.5 }
            end
            if t.day >= 10 then
                local eom = os.time{ year = t.year, month = t.month + 1, day = 0, hour = 12 }
                local need = math.ceil(f.year_goal * (tonumber(os.date("%j", eom)) or 1) / diy - f.year_done - 1e-9)
                if need >= 1 and need <= 3 then f.pace_need = need end
            end
        end
        f.dismissed = dismissed()
        pcall(suggestions, f)
        pcall(questFacts, f)
        return f
    end

    -- ─── remarks ─────────────────────────────────────────────────────────────────
    -- { id, when(f), mood, text(f), sub(f)? }, by page kind. A page's pool is
    -- what fits right now; one is dealt per day.

    local R = {}

    R.today = {
        { id = "t_goal_done", mood = "party",
          when = function(f) return f.goal_min and f.today_secs and mins(f.today_secs) >= f.goal_min end,
          text = function() return "Daily goal done." end,
          sub = function(f) return string.format("%s today. Anything now is a bonus.", A.fmtMinutes(mins(f.today_secs))) end },
        { id = "t_goal_near", mood = "cheer",
          when = function(f) return f.goal_min and f.today_secs and f.today_secs > 0 and mins(f.today_secs) < f.goal_min end,
          text = function(f) return string.format("%s to your daily goal.", A.fmtMinutes(f.goal_min - mins(f.today_secs))) end,
          sub = function() return "One more chapter should do it." end },
        { id = "t_above_usual", mood = "surprised",
          when = function(f) return f.avg_secs and f.avg_secs > 300 and (f.today_secs or 0) > 1.5 * f.avg_secs end,
          text = function(f) return string.format("%s today.", A.fmtMinutes(mins(f.today_secs))) end,
          sub = function(f) return string.format("Your usual is %s. Who are you?", A.fmtMinutes(mins(f.avg_secs))) end },
        { id = "t_streak_save", mood = "curious",
          when = function(f) return (f.streak or 0) >= 2 and (f.today_secs or 0) == 0 end,
          text = function(f) return string.format("Your %d-day streak needs a page today.", f.streak) end,
          sub = function() return "Just one. I'll wait." end },
        { id = "t_streak_best", mood = "party",
          when = function(f) return (f.streak or 0) >= 3 and f.streak >= (f.best or 0) end,
          text = function(f) return string.format("%d days in a row.", f.streak) end,
          sub = function() return "Your longest streak ever. Keep it going." end },
        { id = "t_streak_near_best", mood = "playful",
          when = function(f) return (f.streak or 0) >= 3 and f.best and f.best > f.streak and f.best - f.streak <= 3 end,
          text = function(f) return string.format("%s to beat your best streak.", n_(f.best - f.streak + 1, "day", "days")) end,
          sub = function(f) return string.format("Best so far: %d days.", f.best) end },
        { id = "t_closest", mood = "curious",
          when = function(f) return f.closest ~= nil end,
          text = function(f) return string.format("%s is %d%% done.", q(f.closest.title), floor(f.closest.pct * 100)) end,
          sub = function(f)
              return f.closest.left_min and string.format("About %s to the end.", A.fmtMinutes(f.closest.left_min))
                  or "The end is in sight."
          end },
        { id = "t_week_up", mood = "cheer",
          when = function(f) return f.week_pages and f.last_week_pages and f.last_week_pages > 0 and f.week_pages > f.last_week_pages end,
          text = function(f) return string.format("%s this week.", n_(f.week_pages, "page", "pages")) end,
          sub = function(f) return string.format("%d more than this time last week.", f.week_pages - f.last_week_pages) end },
        { id = "t_quiet", mood = "sleepy",
          when = function(f) return (f.today_secs or 0) == 0 and (f.streak or 0) < 2 end,
          text = function() return "Quiet day so far." end,
          sub = function() return "Even ten minutes counts." end },
    }

    R.yearly = {
        { id = "y_goal_done", mood = "party",
          when = function(f) return f.year_goal and f.year_done and f.year_done >= f.year_goal end,
          text = function(f) return string.format("%d of %d. Goal reached!", f.year_done, f.year_goal) end,
          sub = function() return "Everything now is extra credit." end },
        { id = "y_ahead", mood = "cheer",
          when = function(f) return f.year_expected and f.year_done and f.year_done < (f.year_goal or 0) and f.year_done - f.year_expected >= 1 end,
          text = function(f) return string.format("%s ahead of your goal pace.", n_(floor(f.year_done - f.year_expected), "book", "books")) end,
          sub = function() return "Smug looks good on you." end },
        { id = "y_behind", mood = "curious",
          when = function(f) return f.year_expected and f.year_done and f.year_expected - f.year_done >= 1 end,
          text = function(f) return string.format("%s behind your goal pace.", n_(floor(f.year_expected - f.year_done + 0.5), "book", "books")) end,
          sub = function(f)
              return f.closest and string.format("Finishing %s would help.", q(f.closest.title)) or "A short one would catch you up."
          end },
        { id = "y_projected", mood = "happy",
          when = function(f) return f.year_projected and f.year_projected > 0 end,
          text = function(f) return string.format("At this rate: %s this year.", n_(f.year_projected, "book", "books")) end,
          sub = function(f) return f.year_goal and string.format("Your goal is %d.", f.year_goal) or nil end },
        { id = "y_best_month", mood = "love",
          when = function(f) return f.best_month ~= nil and f.best_month_pages > 0 end,
          text = function(f) return string.format("%s is your best month so far.", MONTHS[f.best_month]) end,
          sub = function(f) return string.format("%s read.", n_(f.best_month_pages, "page", "pages")) end },
        { id = "y_this_month_top", mood = "party",
          when = function(f) return f.best_month_pages and f.month_pages > f.best_month_pages and f.best_month_pages > 0 end,
          text = function(f) return string.format("%s is beating every month this year.", MONTHS[f.t.month]) end,
          sub = function(f) return string.format("%s and counting.", n_(f.month_pages, "page", "pages")) end },
    }

    R.monthly = {
        { id = "m_books", mood = "cheer",
          when = function(f) return (f.month_books or 0) > 0 end,
          text = function(f) return string.format("%s finished in %s.", n_(f.month_books, "book", "books"), MONTHS[f.t.month]) end,
          sub = function(f) return string.format("%s left in the month.", n_(f.month_left, "day", "days")) end },
        { id = "m_vs_last", mood = "happy",
          when = function(f) return f.prev_month_pages and f.prev_month_pages > 0 and f.month_pages > f.prev_month_pages end,
          text = function(f) return string.format("Already past %s.", MONTHS[f.t.month == 1 and 12 or f.t.month - 1]) end,
          sub = function(f) return string.format("%d pages more, with %s to go.", f.month_pages - f.prev_month_pages, n_(f.month_left, "day", "days")) end },
        { id = "m_vs_avg", mood = "curious",
          when = function(f) return f.month_avg and f.month_pages < f.month_avg and f.month_left <= 10 end,
          text = function(f) return string.format("%d pages to an average month.", floor(f.month_avg - f.month_pages + 0.5)) end,
          sub = function(f) return string.format("%s left. Doable.", n_(f.month_left, "day", "days")) end },
        { id = "m_end_book", mood = "playful",
          when = function(f) return f.month_left <= 5 and f.closest ~= nil end,
          text = function(f) return string.format("%s left in %s.", n_(f.month_left, "day", "days"), MONTHS[f.t.month]) end,
          sub = function(f) return string.format("Finish %s before it's over?", q(f.closest.title)) end },
        { id = "m_pages", mood = "happy",
          when = function(f) return (f.month_pages or 0) > 0 end,
          text = function(f) return string.format("%s so far this month.", n_(f.month_pages, "page", "pages")) end,
          sub = function(f) return f.days_in_month and string.format("Day %d of %d.", f.t.day, f.days_in_month) or nil end },
    }

    R.trends = {
        { id = "r_streak_best", mood = "party",
          when = function(f) return (f.streak or 0) >= 3 and f.streak >= (f.best or 0) end,
          text = function(f) return string.format("A %d-day streak. Your best yet.", f.streak) end,
          sub = function() return "Every day is a new record now." end },
        { id = "r_streak_gap", mood = "playful",
          when = function(f) return (f.streak or 0) >= 1 and f.best and f.best > f.streak end,
          text = function(f) return string.format("%s to beat your best of %d.", n_(f.best - f.streak + 1, "day", "days"), f.best) end,
          sub = function() return "No pressure. Some pressure." end },
        { id = "r_fav_hour", mood = "curious",
          when = function(f) return f.fav_hour ~= nil end,
          text = function(f) return string.format("You read most around %s.", hourText(f.fav_hour)) end,
          sub = function(f) return string.format("%d%% of the last 30 days' reading.", floor(f.fav_share * 100 + 0.5)) end },
        { id = "r_week_trend", mood = "cheer",
          when = function(f) return f.week_pages and f.last_week_pages and f.last_week_pages > 0 end,
          text = function(f)
              local d = f.week_pages - f.last_week_pages
              if d >= 0 then return string.format("Up %s on last week.", n_(d, "page", "pages")) end
              return string.format("Down %s on last week.", n_(-d, "page", "pages"))
          end,
          sub = function(f) return f.week_pages >= f.last_week_pages and "The trend is your friend." or "There's still time to catch up." end },
        { id = "r_avg", mood = "happy",
          when = function(f) return f.avg_pages and f.avg_pages >= 1 end,
          text = function(f) return string.format("About %d pages a day lately.", floor(f.avg_pages + 0.5)) end,
          sub = function(f) return f.avg_secs and string.format("Roughly %s a day.", A.fmtMinutes(mins(f.avg_secs))) or nil end },
    }

    R.library = {
        { id = "l_unread", mood = "curious",
          when = function(f) return f.lib and (f.lib.counts.unread or 0) > 0 end,
          text = function(f) return string.format("%s waiting to be opened.", n_(f.lib.counts.unread, "book", "books")) end,
          sub = function() return "They can hear you, you know." end },
        { id = "l_share", mood = "happy",
          when = function(f) return f.lib and f.lib.total > 0 and (f.lib.counts.finished or 0) > 0 end,
          text = function(f) return string.format("%d%% of your library read.", floor(100 * f.lib.counts.finished / f.lib.total + 0.5)) end,
          sub = function(f) return string.format("%d of %d.", f.lib.counts.finished, f.lib.total) end },
        { id = "l_juggling", mood = "surprised",
          when = function(f) return f.lib and (f.lib.counts.reading or 0) >= 3 end,
          text = function(f) return string.format("%d books on the go at once.", f.lib.counts.reading) end,
          sub = function(f) return f.closest and string.format("%s is closest to done.", q(f.closest.title)) or "Bold." end },
        { id = "l_on_hold", mood = "shy",
          when = function(f) return f.lib and (f.lib.counts.on_hold or 0) > 0 end,
          text = function(f) return string.format("%s on hold.", n_(f.lib.counts.on_hold, "book", "books")) end,
          sub = function() return "Time to pick one back up?" end },
        { id = "l_closest", mood = "cheer",
          when = function(f) return f.closest ~= nil end,
          text = function(f) return string.format("Next to finish: %s.", q(f.closest.title)) end,
          sub = function(f) return string.format("%d%% done already.", floor(f.closest.pct * 100)) end },
    }

    -- ─── insights ────────────────────────────────────────────────────────────────
    -- "one every 6 days" / "3 a week": the finish rate the goal needs
    local function every(p)
        local e = p.days_left / p.left
        if e >= 1.5 then return string.format("one every %d days", floor(e + 0.5)) end
        return string.format("%d a week", math.ceil(7 / e))
    end

    local INSIGHTS = {
        comeback = { id = "t_comeback", mood = "love",
            when = function(f) return f.run == 1 and (f.gap or 0) >= 4 and (f.today_secs or 0) >= MIN_DAY_SECS end,
            text = function(f) return string.format("First reading day in %s.", n_(f.gap + 1, "day", "days")) end,
            sub = function() return "Welcome back!" end },
        momentum = { id = "t_momentum", mood = "cheer",
            when = function(f) return (f.run or 0) >= 2 and f.run <= 5 and (f.gap or 0) >= 4 and (f.today_secs or 0) >= MIN_DAY_SECS end,
            text = function(f) return string.format("%s in a row.", n_(f.run, "reading day", "reading days")) end,
            sub = function() return "You're getting back into the habit." end },
        day_record = { id = "t_day_record", mood = "surprised",
            when = function(f) return f.day_record end,
            text = function() return "Your best reading day this month!" end,
            sub = function(f) return string.format("%s and counting.", A.fmtMinutes(mins(f.today_secs))) end },
        milestone = { id = "y_milestone", mood = "party",
            when = function(f) return f.milestone ~= nil end,
            text = function(f) return string.format("That's book %d this year!", f.milestone) end,
            sub = function() return "Your shelf is looking lighter." end },
        pace = { id = "y_pace", mood = "curious",
            when = function(f) return f.pace ~= nil end,
            text = function(f)
                if f.pace.on then return "You're on pace for your goal." end
                return string.format("%s to go, %d days left.", n_(f.pace.left, "book", "books"), f.pace.days_left)
            end,
            sub = function(f)
                if f.pace.on then return string.format("%d to go: about %s.", f.pace.left, every(f.pace)) end
                return string.format("About %s catches you up.", every(f.pace))
            end },
        month_pace = { id = "m_pace", mood = "curious",
            when = function(f) return f.pace_need ~= nil end,
            text = function(f) return string.format("%s this month", n_(f.pace_need, "more book", "more books")) end,
            sub = function() return "would put you right on your yearly pace." end },
        weekend = { id = "r_weekend", mood = "curious",
            when = function(f) return f.weekend ~= nil end,
            text = function(f)
                local x = f.weekend_x >= 1.9 and "about twice as much" or "a lot more"
                return f.weekend == "weekend" and string.format("You read %s on weekends.", x)
                    or string.format("You read %s on weekdays.", x)
            end,
            sub = function(f) return f.weekend == "weekend" and "Got a book lined up for Saturday?" or "Weekends are for naps, I guess." end },
        discover = { id = "l_discover", mood = "love",
            when = function(f) return f.sug and f.sug.discover end,
            text = function(f) return string.format("%s by authors you've finished.", n_(f.sug.discover, "unread book", "unread books")) end,
            sub = function() return "Old friends, new stories." end },
    }
    R.today[#R.today + 1] = INSIGHTS.comeback
    R.today[#R.today + 1] = INSIGHTS.momentum
    R.today[#R.today + 1] = INSIGHTS.day_record
    R.trends[#R.trends + 1] = INSIGHTS.comeback
    R.trends[#R.trends + 1] = INSIGHTS.momentum
    R.trends[#R.trends + 1] = INSIGHTS.weekend
    R.monthly[#R.monthly + 1] = INSIGHTS.day_record
    R.monthly[#R.monthly + 1] = INSIGHTS.month_pace
    R.yearly[#R.yearly + 1] = INSIGHTS.milestone
    R.yearly[#R.yearly + 1] = INSIGHTS.pace
    R.library[#R.library + 1] = INSIGHTS.discover

    -- ─── suggestions (remarks with a book: a tap offers to open it) ─────────────
    local TAP = "Tap me."
    local function bookOf(get) return function(f) local b = get(f); return b and b.fp or nil end end
    local S_ = {
        series_next = { id = "s_series_next", mood = "love",
            when = function(f) return f.sug and f.sug.series_next end,
            text = function(f) return string.format("Ready for more %s?", short(f.sug.series_next.name, 24)) end,
            sub = function(f) return string.format("%s is next. %s", q(f.sug.series_next.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.series_next.book end) },
        variety = { id = "s_variety", mood = "playful",
            when = function(f) return f.sug and f.sug.variety end,
            text = function(f) return string.format("Three %s books in a row.", short(f.sug.variety.same, 18):lower()) end,
            sub = function(f) return string.format("Something different? %s. %s", q(f.sug.variety.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.variety.book end) },
        quick = { id = "s_quick", mood = "cheer",
            when = function(f) return f.sug and f.sug.quick end,
            text = function(f) return string.format("Only %s left in %s.", A.fmtMinutes(f.sug.quick.left), q(f.sug.quick.book.title)) end,
            sub = function() return "A little time to spare? " .. TAP end,
            fp = bookOf(function(f) return f.sug.quick.book end) },
        stale = { id = "s_stale", mood = "shy",
            when = function(f) return f.sug and f.sug.stale end,
            text = function(f) return string.format("You were %d%% into %s.", floor(f.sug.stale.book.pct * 100), q(f.sug.stale.book.title)) end,
            sub = function() return "Give it another chapter? " .. TAP end,
            fp = bookOf(function(f) return f.sug.stale.book end) },
        recover = { id = "s_recover", mood = "shy",
            when = function(f) return f.sug and f.sug.recover end,
            text = function(f) return string.format("%d quiet days.", f.sug.recover.days) end,
            sub = function(f) return string.format("Fancy a few pages of %s? %s", q(f.sug.recover.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.recover.book end) },
        author = { id = "s_author", mood = "love",
            when = function(f) return f.sug and f.sug.author end,
            text = function(f) return string.format("You've finished %s by %s.", n_(f.sug.author.n, "book", "books"), short(f.sug.author.name, 22)) end,
            sub = function(f) return string.format("%s is waiting. %s", q(f.sug.author.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.author.book end) },
        series = { id = "s_series", mood = "curious",
            when = function(f) return f.sug and f.sug.series end,
            text = function(f) return string.format("Next in %s:", short(f.sug.series.name, 26)) end,
            sub = function(f) return string.format("%s. %s", q(f.sug.series.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.series.book end) },
        genre = { id = "s_genre", mood = "playful",
            when = function(f) return f.sug and f.sug.genre end,
            text = function(f) return string.format("You keep finishing %s.", short(f.sug.genre.name, 20):lower()) end,
            sub = function(f) return string.format("Try %s? %s", q(f.sug.genre.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.genre.book end) },
        hold = { id = "s_hold", mood = "shy",
            when = function(f) return f.sug and f.sug.hold end,
            text = function(f) return string.format("Pick %s back up?", q(f.sug.hold.book.title)) end,
            sub = function(f)
                local pct = f.sug.hold.pct
                return (pct and pct > 0) and string.format("You were %d%% in. %s", floor(pct * 100), TAP) or TAP
            end,
            fp = bookOf(function(f) return f.sug.hold.book end) },
        pick = { id = "s_pick", mood = "curious",
            when = function(f) return f.sug and f.sug.pick end,
            text = function() return "Something new?" end,
            sub = function(f) return string.format("%s, never opened. %s", q(f.sug.pick.book.title), TAP) end,
            fp = bookOf(function(f) return f.sug.pick.book end) },
        tonight = { id = "s_tonight", mood = "cheer",
            when = function(f) return f.sug and f.sug.tonight end,
            text = function(f) return string.format("%s could be done today.", q(f.sug.tonight.book.title)) end,
            sub = function(f) return string.format("About %s left. Your usual day is %s.",
                A.fmtMinutes(f.sug.tonight.left), A.fmtMinutes(f.sug.tonight.usual)) end,
            fp = bookOf(function(f) return f.sug.tonight.book end) },
        boost = { id = "s_boost", mood = "curious",
            when = function(f) return f.sug and f.sug.boost end,
            text = function(f) return string.format("10 more minutes a day finishes %s %s sooner.",
                q(f.sug.boost.book.title), n_(f.sug.boost.now_days - f.sug.boost.more_days, "day", "days")) end,
            sub = function(f) return string.format("%s days instead of %d. %s", f.sug.boost.more_days, f.sug.boost.now_days, TAP) end,
            fp = bookOf(function(f) return f.sug.boost.book end) },
        hour = { id = "s_hour", mood = "playful",
            when = function(f) return f.fav_hour and f.t.hour < f.fav_hour and (f.today_secs or 0) < 600 end,
            text = function(f) return string.format("Your best reading time is around %s.", hourText(f.fav_hour)) end,
            sub = function() return "Save a few chapters for it?" end },
        quest_daily = { id = "s_quest_daily", mood = "cheer",
            when = function(f) return f.quest_daily ~= nil end,
            text = function(f)
                local qd = f.quest_daily
                if qd.have > 0 then return string.format("Quest: %s, %d of %d %s.", qd.title, qd.have, qd.need, qd.unit) end
                return string.format("Today's quest: %s.", qd.title)
            end,
            sub = function(f)
                if f.closest then return string.format("%s would do it. %s", q(f.closest.title), TAP) end
                return string.format("+%d XP in it for you.", f.quest_daily.reward_xp or 0)
            end,
            fp = bookOf(function(f) return f.closest end) },
        quest_book = { id = "s_quest_book", mood = "playful",
            when = function(f) return f.quest_book ~= nil and f.closest ~= nil end,
            text = function(f) return string.format("%s needs one more book.", f.quest_book.title) end,
            sub = function(f) return string.format("%s is %d%% done. %s", q(f.closest.title), floor(f.closest.pct * 100), TAP) end,
            fp = bookOf(function(f) return f.closest end) },
    }
    local function addAll(list, names) for _, n in ipairs(names) do list[#list + 1] = S_[n] end end
    addAll(R.today,   { "tonight", "boost", "hour", "hold", "quest_daily", "quick", "recover", "stale", "series_next" })
    addAll(R.yearly,  { "author", "series", "quest_book", "series_next" })
    addAll(R.monthly, { "tonight", "quest_book", "genre", "quick" })
    addAll(R.trends,  { "boost", "hour", "quest_daily", "recover" })
    addAll(R.library, { "author", "series", "genre", "hold", "pick", "series_next", "variety", "stale" })

    -- ─── more ways to say each remark ────────────────────────────────────────────
    -- VARIANTS[id]: other wordings of a remark (its own wording above is the
    -- first); one is dealt with the remark, so a page's lines don't repeat word
    -- for word before every wording has had its turn. TIERS[id][tier]: what a
    -- critter in that mood says instead (SimpleUI's mood: grumpy, meh, okay,
    -- happy, radiant), like the home screen critter's lines.

    local function s(text) return function() return text end end

    local VARIANTS = {
        s_author = {
            { mood = "happy", text = function(f) return string.format("More %s?", short(f.sug.author.name, 24)) end,
              sub = function(f) return string.format("%s is on your shelf. %s", q(f.sug.author.book.title), TAP) end },
        },
        s_series = {
            { mood = "playful", text = function(f) return string.format("%s isn't over yet.", short(f.sug.series.name, 26)) end,
              sub = function(f) return string.format("%s is next. %s", q(f.sug.series.book.title), TAP) end },
        },
        s_genre = {
            { mood = "curious", text = function(f) return string.format("Another %s book?", short(f.sug.genre.name, 20):lower()) end,
              sub = function(f) return string.format("%s fits. %s", q(f.sug.genre.book.title), TAP) end },
        },
        s_hold = {
            { mood = "curious", text = function(f) return string.format("%s misses you.", q(f.sug.hold.book.title)) end,
              sub = function() return TAP end },
        },
        s_pick = {
            { mood = "playful", text = function(f) return string.format("Judge %s by its cover?", q(f.sug.pick.book.title)) end,
              sub = function() return TAP end },
        },
        s_tonight = {
            { mood = "party", text = function(f) return string.format("Finish %s today?", q(f.sug.tonight.book.title)) end,
              sub = function(f) return string.format("%s to go. %s", A.fmtMinutes(f.sug.tonight.left), TAP) end },
        },
        s_boost = {
            { mood = "cheer", text = function(f) return string.format("%s in %d days, or %d.", q(f.sug.boost.book.title), f.sug.boost.now_days, f.sug.boost.more_days) end,
              sub = function() return "The second one takes 10 more minutes a day." end },
        },
        t_goal_done = {
            { mood = "cheer", text = s("Goal: done. You: brilliant."),
              sub = function(f) return string.format("%s read today.", A.fmtMinutes(mins(f.today_secs))) end },
            { mood = "love", text = function(f) return string.format("%s today. Goal met.", A.fmtMinutes(mins(f.today_secs))) end,
              sub = s("The rest of the day is yours.") },
        },
        t_goal_near = {
            { mood = "curious", text = function(f) return string.format("Only %s left for today's goal.", A.fmtMinutes(f.goal_min - mins(f.today_secs))) end,
              sub = s("A short sitting would do it.") },
            { mood = "playful", text = function(f) return string.format("%s in. %s to go.", A.fmtMinutes(mins(f.today_secs)), A.fmtMinutes(f.goal_min - mins(f.today_secs))) end,
              sub = s("So close I can taste it.") },
        },
        t_above_usual = {
            { mood = "party", text = s("Big reading day!"),
              sub = function(f) return string.format("%s, against a usual %s.", A.fmtMinutes(mins(f.today_secs)), A.fmtMinutes(mins(f.avg_secs))) end },
            { mood = "cheer", text = function(f) return string.format("%s and counting.", A.fmtMinutes(mins(f.today_secs))) end,
              sub = s("Somebody found a good book.") },
        },
        t_streak_save = {
            { mood = "shy", text = s("Not a page yet today."),
              sub = function(f) return string.format("Your %d-day streak is watching.", f.streak) end },
            { mood = "playful", text = function(f) return string.format("Day %d of the streak is waiting.", f.streak + 1) end,
              sub = s("A page is all it takes.") },
        },
        t_streak_best = {
            { mood = "cheer", text = function(f) return string.format("Day %d. A new record.", f.streak) end,
              sub = s("Every day from here is a new best.") },
            { mood = "love", text = s("Your best streak ever, still going."),
              sub = function(f) return string.format("%d days and counting.", f.streak) end },
        },
        t_streak_near_best = {
            { mood = "curious", text = function(f) return string.format("Your best streak is %d days.", f.best) end,
              sub = function(f) return string.format("You're on %d. Getting close…", f.streak) end },
            { mood = "cheer", text = s("A record streak is in reach."),
              sub = function(f) return string.format("%s more and it's yours.", n_(f.best - f.streak + 1, "day", "days")) end },
        },
        t_closest = {
            { mood = "playful", text = function(f) return string.format("%s: %d%% there.", q(f.closest.title), floor(f.closest.pct * 100)) end,
              sub = s("The ending won't read itself.") },
            { mood = "cheer", text = function(f) return string.format("Nearly through %s.", q(f.closest.title)) end,
              sub = function(f)
                  return f.closest.left_min and string.format("%s to go.", A.fmtMinutes(f.closest.left_min)) or "Almost there."
              end },
        },
        t_week_up = {
            { mood = "happy", text = s("A better week than last."),
              sub = function(f) return string.format("%d pages ahead so far.", f.week_pages - f.last_week_pages) end },
            { mood = "party", text = function(f) return string.format("%d pages this week already.", f.week_pages) end,
              sub = s("Last week can't keep up.") },
        },
        t_quiet = {
            { mood = "curious", text = s("No reading yet today."),
              sub = s("A chapter before bed?") },
            { mood = "shy", text = s("I've been waiting all day."),
              sub = s("Just saying.") },
        },
        y_goal_done = {
            { mood = "love", text = s("Year goal reached!"),
              sub = function(f) return string.format("%d books. Raise the bar?", f.year_done) end },
            { mood = "cheer", text = function(f) return string.format("%d books. You did it.", f.year_done) end,
              sub = s("Every book now is a bonus.") },
        },
        y_ahead = {
            { mood = "party", text = s("Ahead of schedule."),
              sub = function(f) return string.format("%s ahead of your goal pace.", n_(floor(f.year_done - f.year_expected), "book", "books")) end },
            { mood = "happy", text = function(f) return string.format("%d books in, ahead of the plan.", f.year_done) end,
              sub = s("Keep this up and the goal falls early.") },
        },
        y_behind = {
            { mood = "shy", text = s("A little behind this year."),
              sub = function(f) return string.format("About %s. Plenty of time.", n_(floor(f.year_expected - f.year_done + 0.5), "book", "books")) end },
            { mood = "playful", text = function(f) return string.format("Goal: %d. So far: %d.", f.year_goal, f.year_done) end,
              sub = s("Catch-up season starts now.") },
        },
        y_projected = {
            { mood = "curious", text = function(f) return string.format("On course for about %d books.", f.year_projected) end,
              sub = s("If nothing changes. Things change.") },
            { mood = "cheer", text = s("Where this year is heading:"),
              sub = function(f) return string.format("%s by December.", n_(f.year_projected, "book", "books")) end },
        },
        y_best_month = {
            { mood = "happy", text = function(f) return string.format("Best month so far: %s.", MONTHS[f.best_month]) end,
              sub = function(f) return string.format("%d pages. Beat it?", f.best_month_pages) end },
            { mood = "curious", text = function(f) return string.format("%s still holds the record.", MONTHS[f.best_month]) end,
              sub = function(f) return string.format("%s.", n_(f.best_month_pages, "page", "pages")) end },
        },
        y_this_month_top = {
            { mood = "cheer", text = s("A record month!"),
              sub = function(f) return string.format("%d pages in %s so far.", f.month_pages, MONTHS[f.t.month]) end },
            { mood = "love", text = function(f) return string.format("%s is your best month this year.", MONTHS[f.t.month]) end,
              sub = s("And it isn't over yet.") },
        },
        m_books = {
            { mood = "happy", text = function(f) return string.format("%s done this month.", n_(f.month_books, "book", "books")) end,
              sub = function(f) return string.format("%s to add another.", n_(f.month_left, "day", "days")) end },
            { mood = "love", text = function(f) return string.format("%s shelved in %s.", n_(f.month_books, "book", "books"), MONTHS[f.t.month]) end,
              sub = s("Nice work.") },
        },
        m_vs_last = {
            { mood = "cheer", text = function(f) return string.format("Already beat %s.", MONTHS[f.t.month == 1 and 12 or f.t.month - 1]) end,
              sub = s("Everything from here is extra.") },
            { mood = "party", text = s("This month is winning."),
              sub = function(f) return string.format("%d pages past last month.", f.month_pages - f.prev_month_pages) end },
        },
        m_vs_avg = {
            { mood = "shy", text = s("A quieter month."),
              sub = function(f) return string.format("%d pages short of your usual.", floor(f.month_avg - f.month_pages + 0.5)) end },
            { mood = "playful", text = function(f) return string.format("%s to catch an average month.", n_(f.month_left, "day", "days")) end,
              sub = function(f) return string.format("%d pages should do it.", floor(f.month_avg - f.month_pages + 0.5)) end },
        },
        m_end_book = {
            { mood = "curious", text = function(f) return string.format("%s ends soon.", MONTHS[f.t.month]) end,
              sub = function(f) return string.format("Room for %s?", q(f.closest.title)) end },
            { mood = "cheer", text = function(f) return string.format("Finish %s this month?", q(f.closest.title)) end,
              sub = function(f) return string.format("%d%% done, %s left.", floor(f.closest.pct * 100), n_(f.month_left, "day", "days")) end },
        },
        m_pages = {
            { mood = "cheer", text = function(f) return string.format("%d pages in %s.", f.month_pages, MONTHS[f.t.month]) end,
              sub = s("Not bad at all.") },
            { mood = "curious", text = function(f) return string.format("About %d pages a day this month.", floor(f.month_pages / math.max(1, f.t.day) + 0.5)) end,
              sub = function(f) return string.format("%d so far.", f.month_pages) end },
        },
        r_streak_best = {
            { mood = "cheer", text = function(f) return string.format("%d days. Never been longer.", f.streak) end,
              sub = s("Look at you go.") },
            { mood = "love", text = s("Your longest streak yet."),
              sub = function(f) return string.format("Day %d.", f.streak) end },
        },
        r_streak_gap = {
            { mood = "curious", text = function(f) return string.format("Best streak: %d. Now: %d.", f.best, f.streak) end,
              sub = s("The gap is closing.") },
            { mood = "cheer", text = function(f) return string.format("%s to a new record.", n_(f.best - f.streak + 1, "day", "days")) end,
              sub = s("One day at a time.") },
        },
        r_fav_hour = {
            { mood = "playful", text = function(f) return string.format("%s is your reading hour.", hourText(f.fav_hour)) end,
              sub = s("Same time tomorrow?") },
            { mood = "sleepy", text = function(f) return string.format("Lately you read most at %s.", hourText(f.fav_hour)) end,
              sub = s("I've noticed. I notice things.") },
        },
        r_week_trend = {
            { mood = "curious", text = function(f) return string.format("This week: %d pages. Last week: %d.", f.week_pages, f.last_week_pages) end,
              sub = function(f) return f.week_pages >= f.last_week_pages and "Ahead so far." or "Behind, for now." end },
            { mood = "playful", text = function(f) return f.week_pages >= f.last_week_pages and "This week is out-reading last week." or "Last week is winning. For now." end,
              sub = function(f) return string.format("%s difference.", n_(math.abs(f.week_pages - f.last_week_pages), "page", "pages")) end },
        },
        r_avg = {
            { mood = "curious", text = function(f) return string.format("Lately: %d pages a day.", floor(f.avg_pages + 0.5)) end,
              sub = s("Steady does it.") },
            { mood = "cheer", text = function(f) return string.format("%s a day, give or take.", A.fmtMinutes(mins(f.avg_secs or 0))) end,
              sub = s("That adds up fast.") },
        },
        l_unread = {
            { mood = "shy", text = function(f) return string.format("%d books still waiting.", f.lib.counts.unread) end,
              sub = s("I hear them whispering.") },
            { mood = "playful", text = function(f) return string.format("%s never opened.", n_(f.lib.counts.unread, "book", "books")) end,
              sub = s("Pick one at random?") },
        },
        l_share = {
            { mood = "curious", text = function(f) return string.format("%d of %d books read.", f.lib.counts.finished, f.lib.total) end,
              sub = s("The shelves await.") },
            { mood = "cheer", text = function(f) return string.format("%d%% of the library, done.", floor(100 * f.lib.counts.finished / f.lib.total + 0.5)) end,
              sub = s("One book at a time.") },
        },
        l_juggling = {
            { mood = "playful", text = function(f) return string.format("Reading %d books at once?", f.lib.counts.reading) end,
              sub = s("Show-off.") },
            { mood = "curious", text = function(f) return string.format("%d books on the go.", f.lib.counts.reading) end,
              sub = s("Which one is the favourite?") },
        },
        l_on_hold = {
            { mood = "curious", text = function(f) return string.format("%s waiting on hold.", n_(f.lib.counts.on_hold, "book", "books")) end,
              sub = s("Still interested?") },
            { mood = "sleepy", text = s("Some books are napping."),
              sub = function(f) return string.format("%d on hold.", f.lib.counts.on_hold) end },
        },
        l_closest = {
            { mood = "happy", text = function(f) return string.format("%s is %d%% done.", q(f.closest.title), floor(f.closest.pct * 100)) end,
              sub = s("Closest to the finish.") },
            { mood = "playful", text = s("Next up for the done pile:"),
              sub = function(f) return q(f.closest.title) end },
        },
    }

    -- A grumpy critter grumbles, a radiant one gushes, a meh one yawns.
    local TIERS = {
        t_goal_done = { grumpy = { mood = "grumpy", text = s("Goal done. Fine. Well done."), sub = s("Don't let it go to your head.") },
                        radiant = { mood = "party", text = s("GOAL DONE! Unstoppable!"), sub = s("I'm so proud I could burst.") } },
        t_goal_near = { meh = { mood = "sleepy", text = s("Almost at the goal."), sub = s("Wake me when you're there.") } },
        t_streak_save = { grumpy = { mood = "grumpy", text = s("No reading today? Really?"),
                                     sub = function(f) return string.format("%d days, about to vanish.", f.streak) end } },
        t_streak_best = { radiant = { mood = "party", text = function(f) return string.format("%d DAYS! A legend is born!", f.streak) end } },
        t_quiet = { grumpy = { mood = "grumpy", text = s("Nothing read today."), sub = s("I'm not mad. I'm disappointed.") },
                    radiant = { mood = "love", text = s("A quiet day."), sub = s("We'll read later. I believe in us.") } },
        y_goal_done = { grumpy = { mood = "grumpy", text = s("Goal reached. Show-off."), sub = s("Fine. Impressive.") } },
        y_ahead = { meh = { mood = "sleepy", text = s("Ahead of pace."), sub = s("Must be nice. I'm tired.") } },
        y_behind = { grumpy = { mood = "grumpy", text = s("Behind on the year goal."), sub = s("Don't look at me.") },
                     radiant = { mood = "love", text = s("A bit behind. No worries!"), sub = s("We've got months. We've got this.") } },
        m_vs_avg = { grumpy = { mood = "grumpy", text = s("Slow month."), sub = s("I've seen faster snails.") } },
        l_unread = { grumpy = { mood = "grumpy", text = function(f) return string.format("%d unread. Still buying more?", f.lib.counts.unread) end },
                     radiant = { mood = "love", text = function(f) return string.format("%d adventures waiting!", f.lib.counts.unread) end } },
        l_juggling = { grumpy = { mood = "grumpy", text = function(f) return string.format("%d books at once. Pick one.", f.lib.counts.reading) end } },
        r_streak_gap = { meh = { mood = "sleepy", text = function(f) return string.format("Best streak: %d.", f.best) end, sub = s("Records are tiring.") } },
    }

    -- wordings and moods of the insights
    VARIANTS.t_comeback = {
        { mood = "happy", text = s("Look who's back!"), sub = function(f) return string.format("First reading in %s.", n_(f.gap + 1, "day", "days")) end },
        { mood = "cheer", text = s("Back to the books."), sub = s("I saved your spot.") },
    }
    VARIANTS.t_momentum = {
        { mood = "happy", text = s("Back on a roll."), sub = function(f) return string.format("%s running.", n_(f.run, "day", "days")) end },
        { mood = "love", text = function(f) return string.format("Day %d of reading again.", f.run) end, sub = s("This feels like the start of something.") },
    }
    VARIANTS.t_day_record = {
        { mood = "party", text = function(f) return string.format("%s today. A monthly best.", A.fmtMinutes(mins(f.today_secs))) end, sub = s("I'll remember this one.") },
        { mood = "cheer", text = s("No day this month beats today."), sub = s("And it isn't over.") },
    }
    VARIANTS.y_milestone = {
        { mood = "love", text = function(f) return string.format("%d books finished this year.", f.milestone) end, sub = s("A milestone. I'm putting it on the fridge.") },
        { mood = "cheer", text = function(f) return string.format("Book number %d. Done.", f.milestone) end, sub = s("What's next on the pile?") },
    }
    VARIANTS.y_pace = {
        { mood = "playful",
          text = function(f)
              if f.pace.on then return string.format("Right on track for %d books.", f.year_goal) end
              return string.format("Your %d-book goal is in reach.", f.year_goal)
          end,
          sub = function(f)
              if f.pace.on then return string.format("Keep it to %s.", every(f.pace)) end
              return string.format("%s left: %s.", n_(f.pace.left, "book", "books"), every(f.pace))
          end },
        { mood = "cheer",
          text = function(f) return string.format("%s left this year.", n_(f.pace.left, "book", "books")) end,
          sub = function(f)
              return (f.pace.on and "You're on pace. About " or "A little behind. About ") .. every(f.pace) .. " does it."
          end },
    }
    VARIANTS.m_pace = {
        { mood = "playful", text = function(f) return string.format("Finish %s this month?", n_(f.pace_need, "book", "books")) end, sub = s("That keeps your yearly goal on track.") },
        { mood = "cheer", text = s("Your yearly goal is in reach."), sub = function(f) return string.format("%s this month does it.", n_(f.pace_need, "more book", "more books")) end },
    }
    VARIANTS.s_quick = {
        { mood = "curious", text = function(f) return string.format("Got %s?", A.fmtMinutes(f.sug.quick.left)) end,
          sub = function(f) return string.format("That's all %s needs. %s", q(f.sug.quick.book.title), TAP) end },
        { mood = "playful", text = s("The finish line is right there."),
          sub = function(f) return string.format("%s, about %s to go. %s", q(f.sug.quick.book.title), A.fmtMinutes(f.sug.quick.left), TAP) end },
    }
    VARIANTS.s_stale = {
        { mood = "curious", text = function(f) return string.format("%s misses you.", q(f.sug.stale.book.title)) end,
          sub = function(f) return string.format("%d%% in, %s ago. %s", floor(f.sug.stale.book.pct * 100), n_(f.sug.stale.days, "day", "days"), TAP) end },
    }
    VARIANTS.s_recover = {
        { mood = "sleepy", text = s("Ready when you are."),
          sub = function(f) return string.format("%s is right where you left it. %s", q(f.sug.recover.book.title), TAP) end },
        { mood = "curious", text = s("Even ten minutes counts."),
          sub = function(f) return string.format("How about %s? %s", q(f.sug.recover.book.title), TAP) end },
    }
    VARIANTS.s_series_next = {
        { mood = "curious", text = function(f) return string.format("You just finished %s.", q(f.sug.series_next.done)) end,
          sub = function(f) return string.format("%s is next. %s", q(f.sug.series_next.book.title), TAP) end },
    }
    VARIANTS.s_variety = {
        { mood = "curious", text = function(f) return string.format("Fancy a break from %s?", short(f.sug.variety.same, 18):lower()) end,
          sub = function(f) return string.format("Some %s: %s. %s", short(f.sug.variety.other, 16):lower(), q(f.sug.variety.book.title), TAP) end },
    }
    TIERS.t_comeback = { grumpy = { mood = "grumpy", text = s("Oh, so you DO remember me."), sub = s("Fine. Welcome back.") } }
    TIERS.t_momentum = { grumpy = { mood = "playful", text = function(f) return string.format("%s in a row. Took you long enough.", n_(f.run, "day", "days")) end } }
    TIERS.t_day_record = { grumpy = { mood = "grumpy", text = s("Best day this month."), sub = s("Don't let it go to your head.") },
                           radiant = { mood = "party", text = s("A record day! Look at you go!") } }
    TIERS.y_milestone = { grumpy = { mood = "grumpy", text = function(f) return string.format("%d books. Fine, I'm impressed.", f.milestone) end },
                          radiant = { mood = "party", text = function(f) return string.format("%d books this year! Unstoppable!", f.milestone) end } }
    TIERS.s_quick = { grumpy = { mood = "grumpy", text = function(f) return string.format("%s won't finish itself.", q(f.sug.quick.book.title)) end,
                                 sub = function(f) return string.format("About %s. You know you want to. %s", A.fmtMinutes(f.sug.quick.left), TAP) end },
                      meh = { mood = "sleepy", text = function(f) return string.format("%s, then %s is done.", A.fmtMinutes(f.sug.quick.left), q(f.sug.quick.book.title)) end,
                              sub = s("One chapter, then we can both rest. " .. TAP) } }
    TIERS.s_recover = { grumpy = { mood = "grumpy", text = function(f) return string.format("%s. Not that I'm counting.", n_(f.sug.recover.days, "day", "days")) end,
                                   sub = function(f) return string.format("%s would cheer me up. %s", q(f.sug.recover.book.title), TAP) end } }

    -- ─── the shared phrase bank ─────────────────────────────────────────────────
    -- koreader/patches/critter-phrases.lua (SimpleUI Tweaks' file; edit it there),
    -- else the copy that comes with Reading Log. Its lines join each remark's
    -- wordings on the tab where the remark lives (Today: record day, back on a
    -- roll, a book nearly done, a quiet stretch; Year: milestones, goal pace;
    -- Trends: weekends). Its minutes and pages steps make Today's pep talk.
    -- Loaded once, with only string and math in reach; missing or broken, the
    -- built-in lines stay.
    local BANK_MAP = {
        tw_milestone = { id = "y_milestone", d = function(f) return { days = f.milestone } end },
        tw_record    = { id = "t_day_record", d = function(f) return { minutes = mins(f.today_secs) } end },
        tw_momentum  = { id = "t_momentum", d = function(f) return { days = f.run } end },
        tw_pace      = { id = "y_pace", d = function(f)
                             return { days = f.pace.left, minutes = f.pace.days_left, years = f.year_goal,
                                      which = f.pace.on and "on" or "behind" } end },
        tw_weekend   = { id = "r_weekend", d = function(f) return { which = f.weekend } end },
        tw_quickwin  = { id = "s_quick", tap = true,
                         d = function(f) return { title = f.sug.quick.book.title, minutes = f.sug.quick.left } end },
        tw_recovery  = { id = "s_recover", tap = true,
                         d = function(f) return { title = f.sug.recover.book.title, days = f.sug.recover.days } end },
    }
    local PEP_OWN = {
        minutes = {
            { upto = 4, mood = "curious", text = function(m) return n_(m, "minute", "minutes") .. " read today." end,
              subs = { "A start is a start.", "Tiny reads still count." } },
            { upto = 29, mood = "happy", text = function(m) return string.format("%d minutes read today.", m) end,
              subs = { "Warming up nicely.", "Now that's a groove." } },
            { upto = 59, mood = "cheer", text = function(m) return string.format("%d minutes read today!", m) end,
              subs = { "A real session. Nice.", "Look at you go." } },
            { upto = math.huge, mood = "party", text = function(m) return string.format("%.1f hours read today!", m / 60) end,
              subs = { "Marathon mode.", "Okay, bookworm." } },
        },
        pages = {
            { upto = 19, mood = "happy", text = function(p) return n_(p, "page", "pages") .. " turned today." end,
              subs = { "Every page counts.", "One page at a time." } },
            { upto = math.huge, mood = "party", text = function(p) return string.format("%d pages turned today!", p) end,
              subs = { "That's a chunk of book.", "Your thumb needs a rest." } },
        },
    }
    local bank, bank_tried
    local function stepsOk(st)
        if type(st) ~= "table" or #st == 0 then return false end
        local prev = 0
        for _, x in ipairs(st) do
            if type(x) ~= "table" or type(x.upto) ~= "number" or x.upto <= prev or type(x.text) ~= "function"
                or type(x.subs) ~= "table" or #x.subs == 0 then return false end
            prev = x.upto
        end
        return prev == math.huge
    end
    local function loadBank()
        if bank_tried then return bank end
        bank_tried = true
        local paths = {}
        local ok_ds, DS = pcall(require, "datastorage")
        if ok_ds and DS and DS.getDataDir then paths[1] = DS:getDataDir() .. "/patches/critter-phrases.lua" end
        paths[#paths + 1] = A.dir .. "/critter-phrases.lua"
        for _, path in ipairs(paths) do
            local fn = loadfile(path)
            if fn then
                setfenv(fn, { string = string, math = math, tostring = tostring, tonumber = tonumber,
                              type = type, ipairs = ipairs, pairs = pairs, select = select })
                local ok, b = pcall(fn)
                if ok and type(b) == "table" then
                    bank = { minutes = stepsOk(b.minutes) and b.minutes or nil, pages = stepsOk(b.pages) and b.pages or nil,
                             iv = type(b.insight_voices) == "table" and b.insight_voices or nil }
                    for kind, m in pairs(BANK_MAP) do
                        local list = type(b.insights) == "table" and b.insights[kind]
                        if type(list) == "table" then
                            for _, l in ipairs(list) do
                                if type(l) == "table" and type(l.text) == "function" and (l.sub == nil or type(l.sub) == "function") then
                                    local adapt, tap = m.d, m.tap
                                    VARIANTS[m.id] = VARIANTS[m.id] or {}
                                    table.insert(VARIANTS[m.id], {
                                        mood = l.mood or "happy",
                                        text = function(f) return l.text(adapt(f)) end,
                                        sub = function(f)
                                            local sv = l.sub and l.sub(adapt(f)) or nil
                                            if tap then return sv and (sv .. " " .. TAP) or TAP end
                                            return sv
                                        end })
                                end
                            end
                        end
                    end
                    return bank
                end
                A.log("critter: phrase bank failed", path, tostring(b))
            end
        end
        return nil
    end

    -- Today's pep talk: minutes (or pages) read today, a step up as the day
    -- grows; within 10 minutes of the daily goal it counts you in. The step's
    -- wording turns with the day, the number stays live.
    local function pepSteps(kind)
        local b = loadBank()
        return (b and b[kind]) or PEP_OWN[kind]
    end
    local function pepStep(kind, v)
        local steps = pepSteps(kind)
        for i, st in ipairs(steps) do if v <= st.upto then return st, i end end
    end
    -- A step's line for today: a string, or { "line", mood = "..." } for a
    -- line with a mood of its own (a snack break looks hungry). Returns text, mood.
    local function pepSub(st, i)
        local salt = (tonumber(os.date("%j")) or 1) + (A.state.critter_pep_turn or 0)
        local sub = st.subs[(salt + i) % #st.subs + 1]
        if type(sub) == "table" then return tostring(sub[1] or ""), sub.mood end
        return sub, nil
    end
    local function pepMood(kind, v)
        local st, i = pepStep(kind, v)
        local _, mood = pepSub(st, i)
        return mood or st.mood or "happy"
    end
    R.today[#R.today + 1] = { id = "t_pep",
        mood = function(f)
            local m = mins(f.today_secs)
            if f.goal_min and m < f.goal_min and f.goal_min - m <= 10 then return "cheer" end
            return pepMood("minutes", m)
        end,
        when = function(f) return (f.today_secs or 0) >= 60 end,
        text = function(f)
            local m = mins(f.today_secs)
            local st = pepStep("minutes", m)
            return st.text(m)
        end,
        sub = function(f)
            local m = mins(f.today_secs)
            if f.goal_min and m < f.goal_min and f.goal_min - m <= 10 then
                return string.format("Just %s to your daily goal!", A.fmtMinutes(f.goal_min - m))
            end
            return (pepSub(pepStep("minutes", m)))
        end }
    R.today[#R.today + 1] = { id = "t_pep_pages",
        mood = function(f) return pepMood("pages", f.today_pages) end,
        when = function(f) return (f.today_pages or 0) >= 1 end,
        text = function(f) return pepStep("pages", f.today_pages).text(f.today_pages) end,
        sub = function(f) return (pepSub(pepStep("pages", f.today_pages))) end }

    -- Pages the reader made: anything from the general pools.
    -- Remarks about a book in progress: tapping the bubble opens that book.
    local CLOSEST_FP = function(f) return f.closest and f.closest.fp or nil end
    for _, kind in ipairs({ "today", "yearly", "monthly", "library" }) do
        for _, r in ipairs(R[kind]) do
            if (r.id == "t_closest" or r.id == "y_behind" or r.id == "m_end_book" or r.id == "l_closest") and not r.fp then
                r.fp = CLOSEST_FP
            end
        end
    end

    R.custom = {}
    do
        local seen = {}
        for _, kind in ipairs({ "today", "yearly", "library" }) do
            for _, r in ipairs(R[kind]) do
                if not seen[r.id] then seen[r.id] = true; R.custom[#R.custom + 1] = r end
            end
        end
    end

    local function poolFor(page)
        local id = page and page.id
        if R[id] then return R[id], id end
        return R.custom, "custom"
    end

    -- ─── picking ─────────────────────────────────────────────────────────────────
    -- A.state.critter[kind] = { day, id }: the remark a page shows today.

    -- Which switch a remark is under: "sug" (book suggestions), "streak"
    -- (streaks and comebacks) or "stats" (the rest).
    local STREAK_IDS = { t_comeback = true, t_momentum = true }
    local function groupOf(id)
        if id:sub(1, 2) == "s_" then return "sug" end
        if id:find("streak", 1, true) or STREAK_IDS[id] then return "streak" end
        return "stats"
    end
    C.SWITCHES = { stats = "critter_stats", sug = "critter_sug", streak = "critter_streak" }

    local function eligible(pool, f)
        local ids, by = {}, {}
        local on = {}
        for g, key in pairs(C.SWITCHES) do on[g] = A.get(key, true) ~= false end
        local passed = f.dismissed or {}
        for _, r in ipairs(pool) do
            if on[groupOf(r.id)] then
                local ok, yes = pcall(r.when, f)
                if ok and yes and r.fp and r.id:sub(1, 2) == "s_" then
                    -- not a book you passed on today
                    local okf, fp = pcall(r.fp, f)
                    if okf and fp and passed[fp] then yes = false end
                end
                if ok and yes then ids[#ids + 1] = r.id; by[r.id] = r end
            end
        end
        return ids, by
    end

    -- The day's big news comes first: once a day each, before the dealt remarks.
    local FIRST = { "t_goal_done", "y_goal_done", "y_milestone", "t_day_record", "t_streak_best", "r_streak_best",
                    "t_comeback", "t_momentum", "s_series_next",
                    "t_pep" } -- once you've read today, the pep talk; it grows as you read
    local FIRST_SET = {}
    for _, id in ipairs(FIRST) do FIRST_SET[id] = true end
    -- news only when it's new: a milestone on the day the book was finished, a
    -- comeback run once per comeback (it stays in the rotation after that)
    local FIRST_WHEN = {
        y_milestone = function(f) return f.milestone_new end,
        t_momentum = function(f) return f.run_start ~= nil and A.get("critter_news_run") ~= f.run_start end,
    }
    local FIRST_DONE = {
        t_momentum = function(f) A.set("critter_news_run", f.run_start) end,
    }

    local function deal(kind, ids, skip)
        local k = kit()
        if k and k.Deck and type(k.Deck.pick) == "function" then
            -- the whole pool goes to the deck, so its cycle stays whole; the
            -- one on show now is dealt past once
            for _ = 1, 2 do
                local ok, id = pcall(k.Deck.pick, DECK_KEY .. kind, ids)
                if not ok or not id then break end
                if id ~= skip or #ids == 1 then return id end
            end
        end
        local list = {}
        for _, id in ipairs(ids) do if id ~= skip or #ids == 1 then list[#list + 1] = id end end
        return list[math.random(#list)]
    end

    -- The remark for `page` now: { text, sub, mood }, or nil when nothing fits.
    -- SimpleUI's mood tier of the critter, nil without it.
    local function moodTier()
        local Mood = sui("modules/critter/mood")
        if type(Mood) ~= "table" or type(Mood.read) ~= "function" or type(Mood.tier) ~= "function" then return nil end
        local ok, tier = pcall(function() return Mood.tier(Mood.read().score) end)
        return ok and tier or nil
    end

    -- The wording to use for remark `r`: 1 = its own, 2.. = VARIANTS[r.id], dealt
    -- from a deck of their own so each comes round before any repeats.
    local function dealWording(kind, r)
        local n = 1 + #(VARIANTS[r.id] or {})
        if n == 1 then return 1 end
        local list = {}
        for i = 1, n do list[i] = tostring(i) end
        local k = kit()
        if k and k.Deck and type(k.Deck.pick) == "function" then
            local ok, v = pcall(k.Deck.pick, DECK_KEY .. kind .. "_" .. r.id, list)
            if ok and tonumber(v) then return tonumber(v) end
        end
        return math.random(n)
    end

    local function render(line, f)
        local ok_t, text = pcall(line.text, f)
        if not ok_t or type(text) ~= "string" or text == "" then return nil end
        local sub
        if line.sub then
            local ok_s, sv = pcall(line.sub, f)
            if ok_s and type(sv) == "string" and sv ~= "" then sub = sv end
        end
        local mood = line.mood
        if type(mood) == "function" then
            local ok_m, mv = pcall(mood, f)
            mood = ok_m and type(mv) == "string" and mv or "happy"
        end
        return { text = text, sub = sub, mood = mood }
    end

    -- ─── the critter's own voice (1.1.0) ──────────────────────────────────────────
    -- SimpleUI 3.0.2 gives each bundled critter lines in its own voice (Suey,
    -- Chonk, Tulu, Frankie, Vlad, Sholmes, Argos, Hazel). The ones about a page's
    -- subjects join that page's remarks; about one remark in three is in the
    -- critter's voice. Donny, Blu and Donny & Blu have voices too with SimpleUI
    -- Tweaks 2.14.9+ and critter-phrases.lua (its voices section).

    -- The critter shown: SimpleUI 3.0.2's one-for-every-screen pick, else the
    -- home screen's (Critter Mix's turn included, through Assets.get).
    local function shownCritter()
        local k = kit()
        if not k then return nil end
        local CS = sui("modules/critter/settings")
        local pick
        if type(CS) == "table" and type(CS.pick) == "function" then
            local okp, v = pcall(CS.pick); if okp then pick = v end
        end
        if pick == nil and k.Store then pick = k.Store:get(SUI_PREFIX .. "critter_pick") end
        local ok, entry = pcall(k.Assets.get, pick)
        return ok and type(entry) == "table" and entry.id or nil
    end

    -- Which voice subjects fit which page.
    local VOICE_CATS = {
        today   = { greeting = true, today = true, special = true, reading = true, streak = true, calendar = true, generic = true },
        yearly  = { books = true, generic = true },
        monthly = { calendar = true, generic = true },
        trends  = { streak = true, calendar = true, generic = true },
        library = { reading = true, generic = true },
    }

    -- The facts the voice lines read (SimpleUI's names), from this page's facts.
    local function voiceFacts(f, cid)
        local t = f.t
        local Ph, CS, Book = sui("modules/critter/phrases"), sui("modules/critter/settings"), sui("modules/critter/book")
        local period
        if type(Ph) == "table" and type(Ph.period) == "function" then period = Ph.period(t.hour)
        else period = (t.hour >= 5 and t.hour < 12 and "morning") or (t.hour >= 12 and t.hour < 20 and "afternoon")
            or (t.hour >= 20 and "evening") or "night" end
        local name, book
        if type(CS) == "table" and type(CS.userName) == "function" then
            local ok, v = pcall(CS.userName); if ok then name = v end
        end
        if type(Book) == "table" and type(Book.current) == "function" then
            local ok, v = pcall(Book.current, os.time()); if ok then book = v end
        end
        return {
            period = period, weekday = t.wday, month = t.month, day = t.day,
            streak = f.streak, today_secs = f.today_secs, today_pages = f.today_pages,
            books_year = f.year_done, goal = f.year_goal or 0,
            daily_goal_secs = (f.goal_min or 0) * 60, user_name = name, book = book, critter_id = cid,
        }
    end

    -- This page's voice lines that fit now: ids, and remarks by id.
    local function voiceLines(kind, f)
        local ids, by = {}, {}
        if A.get("critter_voice", true) == false then return ids, by end
        -- SimpleUI Tweaks 2.14.9+ adds Donny, Blu and Donny & Blu's voices
        -- (critter-phrases.lua) to SimpleUI's list first
        local inject = package.loaded["simpleui_tweaks_voices"]
        if type(inject) == "function" then inject() end
        local Voices = sui("modules/critter/voice_phrases")
        if type(Voices) ~= "table" or #Voices == 0 then return ids, by end
        local cid = shownCritter()
        if not cid then return ids, by end
        local cats = VOICE_CATS[kind] or { generic = true }
        local sf
        for _, v in ipairs(Voices) do
            if type(v) == "table" and v.critter == cid and cats[v.cat] and type(v.text) == "function" then
                sf = sf or voiceFacts(f, cid)
                local ok, yes = pcall(v.when, sf)
                if ok and yes then
                    ids[#ids + 1] = v.id
                    by[v.id] = { id = v.id, mood = v.mood,
                        text = function() return v.text(sf) end,
                        sub = v.sub and function() return v.sub(sf) end or nil }
                end
            end
        end
        return ids, by
    end

    -- Insights in the critter's own voice (1.1.2): critter-phrases.lua's
    -- insight_voices, by the same kinds SimpleUI Tweaks uses, with their data
    -- worked out from this page's facts.
    local INS_KIND = { t_comeback = "tw_recovery", t_momentum = "tw_momentum", t_day_record = "tw_record",
                       y_milestone = "tw_milestone", y_pace = "tw_pace", r_weekend = "tw_weekend" }
    local function insightData(id, f)
        if id == "t_comeback" then return { days = f.gap } end
        if id == "t_momentum" then return { days = f.run } end
        if id == "t_day_record" then return { minutes = mins(f.today_secs) } end
        if id == "y_milestone" then return { days = f.milestone } end
        if id == "y_pace" and f.pace then
            return { days = f.pace.left, minutes = f.pace.days_left, years = f.year_goal, which = f.pace.on and "on" or "behind" }
        end
        if id == "r_weekend" then return { which = f.weekend } end
    end

    -- A reply from the talk window (a game's last word, a comment on a quote):
    -- shown in the bubble of its page until the next new remark there.
    local function heldReply(kind)
        local h = A.state.critter_reply
        if type(h) == "table" and h.kind == kind and h.day == os.date("%Y-%m-%d") then return h.r end
    end

    -- The remark for `page` now: { text, sub, mood }, or nil when nothing fits.
    local function remark(page, refresh, advance, want_book)
        pcall(loadBank)
        local pool, kind = poolFor(page)
        local f = facts(refresh)
        if advance then A.state.critter_pep_turn = (A.state.critter_pep_turn or 0) + 1 end
        if advance or want_book then A.state.critter_reply = nil end
        local held = heldReply(kind)
        if held then return held end
        local ids, by = eligible(pool, f)
        local vids, vby = {}, {}
        if not want_book then vids, vby = voiceLines(kind, f) end
        for id, r in pairs(vby) do by[id] = r end
        if want_book then
            -- only the remarks that suggest a book
            local only = {}
            for _, id in ipairs(ids) do if by[id].fp then only[#only + 1] = id end end
            if #only > 0 then ids = only end
        end
        if #ids == 0 and #vids == 0 then return nil end
        A.state.critter = A.state.critter or {}
        local cur = A.state.critter[kind]
        local today = os.date("%Y-%m-%d")
        -- big news not yet shown today on this page takes the turn: on a tap, or
        -- when the remark on show isn't news itself (news that came up midway
        -- through the day shows once, then stays like any remark)
        local first
        local cur_today = cur and cur.day == today and by[cur.id]
        if not want_book and (advance or not (cur_today and FIRST_SET[cur.id])) then
            A.state.critter_first = A.state.critter_first or {}
            local seen = A.state.critter_first
            if seen.day ~= today then seen = { day = today }; A.state.critter_first = seen end
            for _, id in ipairs(FIRST) do
                if by[id] and not seen[kind .. ":" .. id] and (not FIRST_WHEN[id] or FIRST_WHEN[id](f)) then first = id break end
            end
            if first then
                seen[kind .. ":" .. first] = true
                if FIRST_DONE[first] then FIRST_DONE[first](f) end
            end
        end
        local fresh = false
        if first then
            cur = { day = today, id = first, v = dealWording(kind, by[first]) }
            A.state.critter[kind] = cur
            fresh = true
        elseif advance or not (cur and cur.day == today and by[cur.id]) then
            local id
            if #vids > 0 and (#ids == 0 or math.random(3) == 1) then
                id = deal(kind .. "_voice", vids, cur and cur.id)
            else
                id = deal(kind, ids, cur and cur.id)
            end
            cur = { day = today, id = id, v = dealWording(kind, by[id]) }
            A.state.critter[kind] = cur
            fresh = true
        end
        -- SimpleUI Tweaks' Critter Mix: a new remark here brings the next critter
        if fresh then
            local k = kit()
            local As = k and k.Assets
            if type(As) == "table" and As._tw_mix then
                As.tw_turn = (tonumber(As.tw_turn) or tonumber(os.date("%j")) or 0) + 1
            end
        end
        local r = by[cur.id]
        -- a critter in a strong mood says it its own way; else the dealt wording
        local tier = moodTier()
        local line = (tier and TIERS[r.id] and TIERS[r.id][tier]) and {
            mood = TIERS[r.id][tier].mood,
            text = TIERS[r.id][tier].text,
            sub = TIERS[r.id][tier].sub,   -- its own line or none, as on the home screen
        } or nil
        if not line and (cur.v or 1) > 1 then line = (VARIANTS[r.id] or {})[cur.v - 1] end
        -- an insight in the critter's own voice, about half the time; picked
        -- when the remark is dealt, so it stays the same through redraws
        if INS_KIND[r.id] and A.get("critter_voice", true) ~= false and bank and bank.iv then
            local cid = shownCritter()
            local list = cid and type(bank.iv[cid]) == "table" and bank.iv[cid][INS_KIND[r.id]]
            if type(list) == "table" and #list > 0 then
                if fresh then cur.iv = (math.random(2) == 1) and math.random(#list) or 0 end
                local l = (cur.iv or 0) > 0 and list[cur.iv]
                local d = l and insightData(r.id, f)
                if type(l) == "table" and type(l.text) == "function" and d then
                    line = { mood = l.mood, text = function() return l.text(d) end,
                             sub = type(l.sub) == "function" and function() return l.sub(d) end or nil }
                end
            end
        end
        local out = (line and render(line, f)) or render(r, f)
        -- only a line that names the book (in quotes) opens it on a tap
        local names_book = out and ((out.text .. (out.sub or "")):find("\xE2\x80\x9C", 1, true) ~= nil)
        if out and r.fp and names_book then
            local ok, fp = pcall(r.fp, f)
            if ok and type(fp) == "string" then out.fp = fp end
        end
        if out then
            A.state.critter_fp = A.state.critter_fp or {}
            A.state.critter_fp[(page and page.id) or "?"] = out.fp
        end
        return out
    end

    --- Tapping the bubble of a remark about a book: opens that book.
    function C.open(page, ctx)
        local fp = A.state.critter_fp and A.state.critter_fp[(page and page.id) or "?"]
        if type(fp) == "string" then
            D.openBook(ctx, fp)
            return true
        end
        return false
    end

    --- Tapping the critter: another remark for that page.
    function C.next(page, refresh)
        remark(page, refresh, true)
        C._moveOn(page)   -- and a new spot (defined with the drawing, below)
        A.state.critter_rev = (A.state.critter_rev or 0) + 1   -- the kept tab is stale (main.lua dashKey)
    end

    -- ─── drawing ─────────────────────────────────────────────────────────────────

    local function pfx(ctx) return (ctx and ctx.pfx) or SUI_PREFIX end

    -- The critter's sprite for `mood` (SimpleUI's grumpy mood wins over a cheerful
    -- line, as on the home screen).
    local function moodFor(k, mood)
        if k.Mood and type(k.Mood.read) == "function" and type(k.Mood.tier) == "function" then
            local ok, tier = pcall(function() return k.Mood.tier(k.Mood.read().score) end)
            if ok and tier == "grumpy" and (mood == "party" or mood == "cheer" or mood == "love" or mood == "proud") then return "grumpy" end
            if ok and tier == "meh" and mood == "party" then return "happy" end
        end
        return mood
    end

    -- Faces for the bubble: SimpleUI's critter text styles, else Reading Log's.
    local function faces(k, ctx, scale)
        local ok, msg, msg_b, det, det_b = pcall(function()
            local styles = k.Config.resolveTextStyles(ctx and ctx.sui, "critter", { "message", "detail" })
            local S = k.Style
            local mfs = max(8, floor(S.FS_BODY * scale * styles.message.scale))
            local dfs = max(7, floor(S.FS_DETAIL * scale * styles.detail.scale))
            local a, ab = S.getTextFace(styles.message, mfs)
            local b, bb = S.getTextFace(styles.detail, dfs)
            return a, ab, b, bb
        end)
        if ok and msg and det then return msg, msg_b, det, det_b end
        local h = floor(22 * scale)
        local a, ab = A.face(h, { bold = true })
        local b, bb = A.face(floor(h * 0.85))
        return a, ab, b, bb
    end

    --- Draws the critter at the right of the box (x, y, w, h) of canvas `c`, with
    --- its bubble to its left, and a tap region `region`. Returns true when drawn.
    --- `max_w`: the widest the critter and its bubble may be. In a wider box they
    --- take a spot of their own in it, which changes each day and with each tap
    --- (after the title, the middle, the far end): the critter wanders.
    local SPOTS = { "end", "start", "middle" }

    local function spotFor(page)
        local id = (page and page.id) or "?"
        A.state.critter_spot = A.state.critter_spot or {}
        local cur = A.state.critter_spot[id]
        local today = os.date("%Y-%m-%d")
        if not cur or cur.day ~= today then
            -- a different spot each day, not the same on every page
            local n = tonumber(os.date("%j")) or 1
            for i = 1, #id do n = n + id:byte(i) end
            cur = { day = today, i = n % #SPOTS + 1 }
            A.state.critter_spot[id] = cur
        end
        return SPOTS[cur.i]
    end

    local function moveOn(page)
        spotFor(page)
        local cur = A.state.critter_spot[(page and page.id) or "?"]
        cur.i = cur.i % #SPOTS + 1
    end

    C._moveOn = moveOn

    -- Height of `text` wrapped to `width` in `face` (SimpleUI's own text box, as
    -- the bubble draws it), cached: nil when it can't be measured.
    local _heights = {}
    local function textHeight(face, bold, text, width)
        if not (face and text) then return 0 end
        local key = table.concat({ tostring(face), tostring(bold), width, text }, "|")
        local v = _heights[key]
        if v then return v end
        local UI = sui("infra/sui_core")
        if type(UI) ~= "table" or type(UI.makeTextBox) ~= "function" then return nil end
        local ok, box = pcall(UI.makeTextBox, { text = text, face = face, bold = bold, width = width })
        if not ok or not box then return nil end
        v = box:getSize().h
        pcall(box.free, box)
        if #_heights > 200 then _heights = {} end
        _heights[key] = v
        return v
    end

    -- Whether `r` fits whole (nothing cut short) in a bubble `bw` wide and `h`
    -- tall, the way SimpleUI's bubble lays it out: the main line, a small gap,
    -- the second line, inside its frame. Unmeasurable counts as fitting.
    local function fits(k, r, bw, h, scale, style, unit, mf, mb, df, db)
        local _b, _p, reach, frame = k.Bubble.metrics(scale, true, style, unit)
        local text_w = bw - reach - frame
        if text_w <= 20 then return false end
        local mh, ml = textHeight(mf, mb, r.text, text_w), textHeight(mf, mb, "Xg", text_w)
        if not (mh and ml) then return true end
        if mh > 2 * ml + 1 then return false end   -- the bubble shows 2 lines of each at most
        local used = mh + frame
        if r.sub then
            local dh, dl = textHeight(df, db, r.sub, text_w), textHeight(df, db, "Xg", text_w)
            if not (dh and dl) then return true end
            if dh > 2 * dl + 1 then return false end
            used = used + dh + A.screen():scaleBySize(2) * scale
        end
        return used <= h
    end

    -- Moods past SimpleUI's twelve (Donny and Blu have them), and the mood each
    -- falls back to for a critter that doesn't.
    C.MOOD_BASE = { reading = "neutral", proud = "cheer", hungry = "curious", cozy = "sleepy",
                    sipping = "happy", dreamy = "sleepy", festive = "happy", spooky = "surprised" }

    function C.draw(c, x, y, w, h, page, ctx, region, max_w)
        if not C.enabled() then return false end
        local area_x, area_w = x, w
        local k = kit()
        local r = remark(page, ctx and ctx.refresh)
        if not r then return false end
        local p = pfx(ctx)
        local Screen = A.screen()
        local scale = h / Screen:scaleBySize(104)
        -- SimpleUI 3.0.2+ keeps the critter and its bubble style in one
        -- place for every screen (modules/critter/settings); older builds
        -- per screen
        local CS = sui("modules/critter/settings")
        local pick
        if type(CS) == "table" and type(CS.pick) == "function" then
            local okp, v = pcall(CS.pick); if okp then pick = v end
        end
        if pick == nil and k.Store then pick = k.Store:get(p .. "critter_pick") end
        local entry = k.Assets.get(pick)
        if not entry then return false end
        local mood = moodFor(k, r.mood) or "neutral"
        local path = k.Assets.imagePath(entry, mood)
        -- a critter without the newer moods (reading, proud...): the pose they
        -- were drawn from, not just neutral
        local base = C.MOOD_BASE[mood]
        if base and path and path == k.Assets.imagePath(entry, "neutral") then path = k.Assets.imagePath(entry, base) end
        if not path then return false end
        local cap = (max_w and max_w < w) and max_w or w
        local sprite = k.Sprite:new{ path = path, max_w = floor(cap * 0.3), max_h = h }
        local sw, sh = sprite.dimen.w, sprite.dimen.h
        if sw <= 0 or sh <= 0 then return false end
        local gap = max(4, floor(Screen:scaleBySize(6) * scale))
        local style
        if type(CS) == "table" and type(CS.bubbleStyle) == "function" then
            local oks, v = pcall(CS.bubbleStyle); if oks then style = v end
        end
        if style == nil and k.Store then style = k.Store:get(p .. "critter_bubble_style") end
        if style ~= "smooth" then style = "pixel" end
        local unit = sprite.pixel or max(1, Screen:scaleBySize(2))
        -- text no smaller than 80% of the home screen critter's, even in a
        -- low heading (the bubble then shows fewer lines)
        local mf, mb, df, db = faces(k, ctx, max(scale, 0.8))
        -- Long text: the bubble grows, up to all the room in the row, before
        -- anything is cut short.
        local group_w = cap
        if cap < w then
            for _, cand in ipairs({ cap, floor((cap + w) / 2), w }) do
                group_w = cand
                if fits(k, r, cand - sw - gap, h, scale, style, unit, mf, mb, df, db) then break end
            end
        end
        if group_w < w then
            local spot, free = spotFor(page), w - group_w
            x = x + (spot == "end" and free or (spot == "middle" and floor(free / 2) or 0))
        end
        w = group_w
        local bubble_w = w - sw - gap
        if bubble_w < k.Bubble.minWidth(scale, true, style, unit) then return false end
        local ok_b, bubble = pcall(k.Bubble.build, {
            w = bubble_w, h = h, side = "right",
            message = r.text, detail = r.sub,
            msg_face = mf, msg_bold = mb, det_face = df, det_bold = db,
            scale = scale, style = style, unit = unit,
        })
        if not ok_b or not bubble then return false end
        local bs = bubble:getSize()
        local bx = x + w - sw - gap - bs.w
        local by = y + floor((h - bs.h) / 2)
        local sx, sy = x + w - sw, y + h - sh
        c.owned[#c.owned + 1] = bubble
        -- Reading Log 1.4 keeps painted cards and redraws them only when what
        -- they draw changes: write down what this draws, so a new remark shows
        if type(c.mark) == "function" then
            c:mark("tk_critter", r.text or "", r.sub or "", path, bx, by, sx, sy, bs.w, bs.h, style, mood)
        end
        c:op(function(bb, ox, oy)
            bubble:paintTo(bb, ox + bx, oy + by)
            sprite:paintTo(bb, ox + sx, oy + sy)
        end)
        -- the whole group: a tap opens the conversation (C.talk)
        if region then c:region(region, bx, y, x + w - bx, h) end
        local id = (page and page.id) or "?"
        -- the band it can wander in, so a redraw covers just that (modules.lua)
        A.state.critter_box = A.state.critter_box or {}
        A.state.critter_box[id] = { x = area_x, y = y, w = area_w, h = h }
        -- what the conversation needs to open over it
        A.state.critter_geo = A.state.critter_geo or {}
        A.state.critter_geo[id] = {
            canvas = c, bubble = { x = bx, y = by, w = bs.w, h = bs.h }, sprite = { x = sx, y = sy, w = sw, h = sh },
            style = style, unit = unit, scale = scale, faces = { message = mf, message_bold = mb, answer = df },
        }
        return true
    end

    -- ─── the conversation (a tap): SimpleUI's critter talk window ───────────────
    -- Over a remark about a book: Open it / Another suggestion / Say something
    -- else. Over any other remark: Suggest a book / Not now / Say something else.
    -- `redraw()` repaints the critter's band after the remark changed.

    local function absRect(geo, rect)
        local d = geo.canvas and geo.canvas.dimen
        if not (d and d.x and d.y) then return nil end
        local Geom = require("ui/geometry")
        return Geom:new{ x = d.x + rect.x, y = d.y + rect.y, w = rect.w, h = rect.h }
    end

    local function hasBookRemark(page, refresh)
        local pool = poolFor(page)
        local ids, by = eligible(pool, facts(refresh))
        for _, id in ipairs(ids) do
            if by[id].fp and id:sub(1, 2) == "s_" then return true end
        end
        return false
    end

    --- Opens the conversation for `page`; returns false when it can't (then the
    --- caller just shows another remark).
    function C.talk(page, ctx, redraw)
        local id = (page and page.id) or "?"
        local geo = A.state.critter_geo and A.state.critter_geo[id]
        local TalkWindow = sui("modules/critter/talk_window")
        if not (geo and type(TalkWindow) == "table" and type(TalkWindow.open) == "function") then return false end
        local anchor = absRect(geo, geo.bubble)
        if not anchor then return false end
        local fp = A.state.critter_fp and A.state.critter_fp[id]
        local refresh = ctx and ctx.refresh
        local function another(book)
            remark(page, refresh, true, book)
            moveOn(page)
            A.state.critter_rev = (A.state.critter_rev or 0) + 1
            if redraw then redraw() end
        end
        -- 1.1.0: SimpleUI 3.0.2's games and quotes, played in this window. The
        -- critter's last word shows in the bubble afterwards.
        local base = {
            anchor = anchor, side = "right", critter_rect = absRect(geo, geo.sprite),
            style = geo.style, unit = geo.unit, scale = geo.scale, faces = geo.faces,
        }
        local function win(extra)
            local o = {}
            for k2, v in pairs(base) do o[k2] = v end
            for k2, v in pairs(extra) do o[k2] = v end
            return o
        end
        local function say(reply)
            if type(reply) ~= "table" then return end
            A.state.critter_reply = { kind = select(2, poolFor(page)), day = os.date("%Y-%m-%d"), r = reply }
            A.state.critter_rev = (A.state.critter_rev or 0) + 1
            if redraw then redraw() end
        end
        local extras = {}
        local Games, Lines = sui("modules/critter/games"), sui("modules/critter/game_lines")
        local Mood = sui("modules/critter/mood")
        if type(Games) == "table" and type(Lines) == "table" and type(Games.rps) == "function"
                and type(Lines.menuPrompt) == "function" and A.get("critter_games", true) ~= false then
            local function tier() return moodTier() end
            local function win1()   -- a round won or a question right: the critter's mood goes up a little
                if type(Mood) == "table" and type(Mood.applyChoice) == "function" and type(Mood.rollDay) == "function" then
                    pcall(function() Mood.write(Mood.applyChoice(Mood.rollDay(Mood.read(), os.date("%Y-%m-%d")), 1)) end)
                end
            end
            local function result(text, again_text, again)
                TalkWindow.open(win{ opener = text, options = {
                    { text = again_text, on_pick = again },
                    { text = Lines.enough(), on_pick = function() say(Lines.done(tier())) end },
                } })
            end
            local pool
            local function quotes()
                if not pool then
                    pool = {}
                    local okq, Q = pcall(require, "modules/quotes")
                    if okq and type(Q) == "table" then for _, e in ipairs(Q) do pool[#pool + 1] = e end end
                    local MQ = sui("modules/module_quote")
                    if type(MQ) == "table" and type(MQ.customQuotes) == "function" then
                        local okc, cq = pcall(MQ.customQuotes)
                        if okc and type(cq) == "table" then for _, e in ipairs(cq) do pool[#pool + 1] = e end end
                    end
                end
                return pool
            end
            local rps, coin, quiz
            rps = function()
                local opts = {}
                for _, move in ipairs(Games.MOVES or {}) do
                    opts[#opts + 1] = { text = Lines.name(move), on_pick = function()
                        local mine, outcome = Games.rps(move, math.random)
                        if outcome == "win" then win1() end
                        result(Lines.rpsResult(mine, outcome, tier()), Lines.again(), rps)
                    end }
                end
                TalkWindow.open(win{ opener = Lines.rpsPrompt(), options = opts })
            end
            coin = function()
                local opts = {}
                for _, call in ipairs({ "heads", "tails" }) do
                    opts[#opts + 1] = { text = Lines.name(call), on_pick = function()
                        local side, right = Games.coin(call, math.random)
                        if right then win1() end
                        result(Lines.coinResult(side, right, tier()), Lines.again(), coin)
                    end }
                end
                TalkWindow.open(win{ opener = Lines.coinPrompt(), options = opts })
            end
            quiz = function()
                local qz = Games.quiz(quotes(), math.random)
                if not qz then say(Lines.done(tier())) return end
                local opts = {}
                for i, author in ipairs(qz.choices) do
                    opts[#opts + 1] = { text = author, on_pick = function()
                        local right = i == qz.answer
                        if right then win1() end
                        result(Lines.quizResult(right, qz.author, tier()), Lines.anotherOne(), quiz)
                    end }
                end
                TalkWindow.open(win{ opener = Lines.quizPrompt(qz.quote), opener_lines = Games.QUOTE_LINES, options = opts })
            end
            local function read(skip)
                local entry, index = Games.pickQuote(quotes(), math.random, skip)
                if not entry then say(Lines.done(tier())) return end
                TalkWindow.open(win{ opener = Lines.quoteText(entry), opener_lines = Games.QUOTE_LINES, options = {
                    { text = Lines.anotherOne(), on_pick = function() read(index) end },
                    { text = Lines.thanks(), on_pick = function() say(Lines.comment(tier(), math.random)) end },
                } })
            end
            extras[#extras + 1] = { text = "Let's play", on_pick = function()
                TalkWindow.open(win{ opener = Lines.menuPrompt(), options = {
                    { text = Lines.rpsText(), on_pick = rps },
                    { text = Lines.coinText(), on_pick = coin },
                    { text = Lines.quizText(), on_pick = quiz },
                } })
            end }
            if type(Games.pickQuote) == "function" and type(Lines.quoteText) == "function" then
                extras[#extras + 1] = { text = "Read me a quote", on_pick = function() read(nil) end }
            end
        end
        local opener, options
        if fp then
            opener = nil   -- the bubble already says which book
            options = {
                { text = "Open it", on_pick = function() D.openBook(ctx, fp) end },
                { text = "Another suggestion", on_pick = function() C.dismiss(fp, page); another(true) end },
            }
            for _, e in ipairs(extras) do options[#options + 1] = e end
        else
            local can_suggest = hasBookRemark(page, refresh)
            opener = can_suggest and "Want me to suggest a book?" or nil
            options = {}
            if can_suggest then
                options[#options + 1] = { text = "Suggest a book", on_pick = function() another(true) end }
            end
            for _, e in ipairs(extras) do options[#options + 1] = e end
            options[#options + 1] = { text = "Not now", on_pick = function() end }
        end
        local ok = pcall(TalkWindow.open, {
            opener = opener,
            options = options,
            other = { text = "Say something else\xE2\x80\xA6", on_pick = function() another(false) end },
            anchor = anchor,
            side = "right",
            critter_rect = absRect(geo, geo.sprite),
            style = geo.style, unit = geo.unit, scale = geo.scale, faces = geo.faces,
        })
        return ok
    end

    -- ─── critter rewards (1.1.0) ─────────────────────────────────────────────────
    -- Little things the critter earns, drawn beside it in its own pixel size,
    -- on the home screen and here: a stack of books for this year's books (one
    -- at 5, two at 10, three at 25, four at 50), a medal at a 7-day streak and a
    -- trophy at 30, and a balloon on your reading anniversary (the first day
    -- with reading in your statistics). Critter > Critter Rewards turns it off.

    local PAL = {
        o = { 46, 32, 26 }, r = { 196, 56, 56 }, b = { 60, 110, 190 }, g = { 70, 150, 80 }, p = { 250, 241, 218 },
        y = { 246, 196, 52 }, Y = { 196, 140, 24 }, w = { 255, 255, 255 }, k = { 120, 120, 120 }, m = { 232, 120, 160 },
    }
    local BOOK_COLS = { "r", "b", "g", "Y" }
    local function bookStack(n)
        local rows = {}
        for i = n, 1, -1 do
            local c = BOOK_COLS[i]
            local off = (i % 2 == 0) and 1 or 0
            local pad, tail = string.rep(".", off), string.rep(".", 1 - off)
            rows[#rows + 1] = pad .. "oooooooooooo" .. tail
            rows[#rows + 1] = pad .. "o" .. string.rep(c, 9) .. "po" .. tail
            rows[#rows + 1] = pad .. "o" .. string.rep(c, 9) .. "po" .. tail
        end
        rows[#rows + 1] = ".oooooooooooo"
        return rows
    end
    local MEDAL = { "o...o", "rboro", ".rbr.", "..o..", ".oyo.", "oyYyo", "oyyyo", ".ooo." }
    local TROPHY = {
        "ooooooooo", "oyyyyyyyo", "yoyyyyyoy", "yoyYyyyoy", ".oyyyyyo.", "..oyyyo..", "...oyo...", "...oyo...",
        "..ooooo..", ".oYYYYYo.", ".ooooooo.",
    }
    local BALLOON = { ".ooo.", "ommmo", "omwmo", "ommmo", "ommmo", ".ooo.", "..o..", "..k..", ".k...", "..k..", "...k." }

    local okBB, Blitbuffer = pcall(require, "ffi/blitbuffer")
    local function drawArt(bb, rows, x, y, k, inv)
        local cache = {}
        for j, row in ipairs(rows) do
            for i = 1, #row do
                local ch = row:sub(i, i)
                local rgb = PAL[ch]
                if rgb then
                    local c = cache[ch]
                    if not c then c = A.color(rgb, inv); cache[ch] = c end
                    local px, py = x + (i - 1) * k, y + (j - 1) * k
                    if bb.paintRectRGB32 and okBB and Blitbuffer.isColor8 and not Blitbuffer.isColor8(c) then
                        bb:paintRectRGB32(px, py, k, k, c)
                    else
                        bb:paintRect(px, py, k, k, c)
                    end
                end
            end
        end
    end

    local _rew = { at = -1, v = nil }
    function C.rewards()
        if A.get("critter_rewards", true) == false then return nil end
        local now = os.time()
        if _rew.at >= 0 and now - _rew.at < 60 then return _rew.v end
        local v = { books = 0 }
        local okY, yr = pcall(D.year, nil)
        local okP, pace = pcall(D.yearPace, okY and yr or nil)
        local books = okP and type(pace) == "table" and tonumber(pace.done) or 0
        v.books = (books >= 50 and 4) or (books >= 25 and 3) or (books >= 10 and 2) or (books >= 5 and 1) or 0
        local okS, st = pcall(D.stats, nil)
        if okS and type(st) == "table" then
            local streak = tonumber(st.streak) or 0
            v.prize = (streak >= 30 and "trophy") or (streak >= 7 and "medal") or nil
            local first
            for key in pairs(st.days or {}) do
                if type(key) == "string" and (not first or key < first) then first = key end
            end
            local today = os.date("%Y-%m-%d")
            if first and first:sub(6) == today:sub(6) and first:sub(1, 4) < today:sub(1, 4) then v.balloon = true end
        end
        _rew.at, _rew.v = now, v
        return v
    end

    -- Draws what's earned over a sprite painted at x, y (w x h, pixel size k).
    function C.paintRewards(bb, x, y, w, h, k)
        local v = C.rewards()
        if not v then return end
        local Screen = A.screen()
        local inv = Screen and Screen.night_mode or false
        k = max(1, floor(k or 1))
        if v.books > 0 then
            local art = bookStack(v.books)
            drawArt(bb, art, x, y + h - #art * k, k, inv)
        end
        if v.prize then
            local art = v.prize == "trophy" and TROPHY or MEDAL
            drawArt(bb, art, x + w - #art[1] * k, y + h - #art * k, k, inv)
        end
        if v.balloon then drawArt(bb, BALLOON, x + w - #BALLOON[1] * k, y, k, inv) end
    end

    -- SimpleUI's critter sprite (home screen and here) gets the rewards drawn
    -- on after it, once. Nothing is drawn with the setting off.
    function C.installRewards()
        local k = kit()
        if not k or type(k.Sprite) ~= "table" or type(k.Sprite.paintTo) ~= "function" or k.Sprite._rl_rewards then return end
        k.Sprite._rl_rewards = true
        local orig = k.Sprite.paintTo
        k.Sprite.paintTo = function(self, bb, x, y, ...)
            local r = orig(self, bb, x, y, ...)
            local d = self.dimen
            if d and d.w and d.w > 0 and A.get("critter_rewards", true) ~= false then
                local unit = self.pixel or max(1, floor(d.h / 64))
                pcall(C.paintRewards, bb, x, y, d.w, d.h, unit)
            end
            return r
        end
    end
    pcall(C.installRewards)

    return C
end

-- ─── everything below runs once Reading Log's card kit has loaded ───────────

local function apply(A)
    if type(A) ~= "table" or A._rl_tweaks then return end
    local P, D, H = A.panels, A.D, A.host
    if type(P) ~= "table" or type(D) ~= "table" or type(H) ~= "table"
            or type(A.Dashboard) ~= "table" or type(A.makeEnv) ~= "function"
            or type(A.canvas) ~= "function" or type(A.DASH_WEIGHT) ~= "table" then
        warn("Reading Log kit doesn't look like 1.4+; extras left off")
        return
    end
    A._rl_tweaks = PATCH_VERSION
    if A.get("tk_flash_clean", nil) ~= nil then A.set("tk_flash_clean", nil) end   -- removed in 1.1.9
    local T = (type(A._) == "function") and A._ or function(s) return s end
    local round = A.round or function(n) return floor(n + 0.5) end
    local scaler = A.panelScaler
    local UIManager = require("ui/uimanager")
    local Geom = require("ui/geometry")

    local function redrawAll() pcall(H.redrawAll) end

    -- ════════════════════════════════════════════════════════════════════════
    -- Year Goal With Covers
    -- ════════════════════════════════════════════════════════════════════════
    -- The year goal on the left (books finished, "of N books", ahead or
    -- behind), this year's finished covers on the right, newest first, and a
    -- progress bar along the bottom with a tick where you should be by today.

    -- the card's background, as Reading Log's own cards draw it
    local function card(env, s)
        local radius = max(4, round(32 * s))
        radius = min(radius, floor(min(env.w, env.h) / 4))
        if env.native or env.bare then
            return A.canvas{ w = env.w, h = env.h, tone = env.tone, radius = radius,
                plain = env.bare or not env.tone.panel, bleed = env.bleed }
        end
        return A.canvas{
            w = env.w, h = env.h, tone = env.tone, radius = radius,
            border_w = env.tone.border and (env.tone.border_thin and max(1, round(2 * s)) or max(2, round(4 * s))) or 0,
            bleed = env.bleed and not env.nested,
            page = env.page,
            behind = env.behind,
        }
    end

    if scaler and not P.goal_covers then
        P.goal_covers = {
            does = T("shows the book tapped"),
            title = "Year Goal With Covers", tone = "ink", ratio = 0.36, ratio_narrow = 0.62,
            summary = "Books finished this year against your goal, with their covers. Works offline.",
        }

        function P.goal_covers.build(env)
            local w, h, tone = env.w, env.h, env.tone
            local s = min(h / 300, w / 860)
            local px, fpx = scaler(s, env.ts)
            local c = card(env, s)
            local t = os.date("*t")
            local yr
            if env.sample then
                yr = { total = 29, list = {} }
                for i, tt in ipairs{ "Our Wives Under the Sea", "The Starless Sea", "Dark Matter", "Educated" } do
                    yr.list[i] = { title = tt }
                end
            else
                yr = D.year(env.refresh)
            end
            local pad = px(30)

            local target, other = D.yearGoal()
            if env.sample then target, other = 36, 0 end
            local list = yr and yr.list or {}
            target = max(1, tonumber(target) or 24)
            local done = (yr and yr.total or 0) + (tonumber(other) or 0)

            local yday = tonumber(os.date("%j"))
            local leap = (t.year % 4 == 0 and (t.year % 100 ~= 0 or t.year % 400 == 0))
            local expected = target * yday / (leap and 366 or 365)
            local diff = done - expected
            local status
            if not yr then status = "\xE2\x80\xA6"
            elseif done >= target then status = "Goal reached"
            elseif diff >= 1 then status = A.plural(floor(diff), "book", "books") .. " ahead"
            elseif diff <= -1 then status = A.plural(ceil(-diff), "book", "books") .. " behind"
            else status = "On track" end

            -- header: "2026 GOAL" left, status right
            local hy = px(20)
            local t_label = c:label(tostring(t.year) .. " goal", fpx(22), pad, hy, { bold = true, caps = true, color = tone.accent })
            c:label(status, fpx(22), w - pad, hy, { bold = true, color = tone.accent2, anchor = "r", max_w = w * 0.5 })

            -- progress bar along the bottom, with a tick for "where you should be"
            local bar_h = max(4, px(12))
            local bar_y = h - px(22) - bar_h
            local bar_w = w - 2 * pad
            c:rrect(pad, bar_y, bar_w, bar_h, bar_h / 2, tone.track)
            local frac = min(1, done / target)
            if frac > 0 then
                c:rrect(pad, bar_y, max(bar_h, floor(bar_w * frac)), bar_h, bar_h / 2, tone.accent)
            end
            local ex = pad + floor(bar_w * min(1, expected / target))
            c:rrect(ex - max(1, px(2)), bar_y - px(6), max(2, px(4)), bar_h + px(12), max(1, px(2)), tone.fg)

            -- left: the count
            local top = hy + t_label.h + px(12)
            local band_h = bar_y - px(16) - top
            local left_w = floor(w * 0.30)
            local big = c:text(yr and tostring(done) or "\xE2\x80\xA6", fpx(104), { bold = true, color = tone.fg })
            local of_t = c:text("of " .. A.plural(target, "book", "books"), fpx(26), { color = tone.accent2, max_w = left_w })
            local by = top + floor((band_h - big.h - of_t.h) / 2)
            c:put(big, pad - round(fpx(104) * 0.04), by)
            c:put(of_t, pad, by + big.h)

            -- right: this year's covers, newest first
            local area_x = pad + left_w
            local area_w = w - pad - area_x
            local files = {}
            if #list == 0 then
                local msg = yr and "No books finished yet this year" or "\xE2\x80\xA6"
                local t1 = c:text(msg, fpx(24), { bold = true, color = tone.muted, max_w = area_w })
                c:put(t1, area_x + area_w / 2, top + band_h / 2, "c", "mid")
            elseif band_h > 24 then
                local gap = px(16)
                local ch = band_h
                local cw = round(ch / 1.5)
                local fit = max(1, floor((area_w + gap) / (cw + gap)))
                local n = min(#list, fit, A.clamp(tonumber(env.cfg("count", 8)) or 8, 1, 12))
                for i = 1, n do
                    local b = list[i]
                    local x = area_x + (i - 1) * (cw + gap)
                    c:cover(b.fp, x, top, cw, ch, { title = b.title, edge = tone.border or tone.bg })
                    files[i] = b.fp or false
                    c:region("book:" .. i, x, top, cw, ch, px(4))
                end
                if #list > n then
                    c:label("+" .. (#list - n), fpx(22), w - pad, top + ch,
                        { bold = true, color = tone.muted, anchor = "r", valign = "base" })
                end
            end
            if not env.sample then A.state.tk_goal_covers_files = files end
            return c
        end

        function P.goal_covers.tap(env, region)
            local i = region and tonumber(region:match("^book:(%d+)$"))
            local fp = i and A.state.tk_goal_covers_files and A.state.tk_goal_covers_files[i]
            if fp then D.showDetails(env.ctx, fp) end
        end

        A.DASH_WEIGHT.goal_covers = 0.27
        -- offered in Pages And Cards (after Year goal) and as a Simple UI module
        local function insertAfter(list, after, name)
            if type(list) ~= "table" then return end
            for _, n in ipairs(list) do if n == name then return end end
            for i, n in ipairs(list) do
                if n == after then table.insert(list, i + 1, name); return end
            end
            list[#list + 1] = name
        end
        insertAfter(A.DASH_CARDS, "goal", "goal_covers")
        if not A._modules then insertAfter(A.MODULE_ORDER, "goal", "goal_covers") end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Today Page Card, and Swipe Between 2-3 Cards
    -- ════════════════════════════════════════════════════════════════════════

    local PICKS = {
        { "goal_covers", "Year Goal With Covers" },
        { "goal",        "Year Goal" },
        { "bookclub",    "Book Club" },
        { "finished",    "Recently Finished" },
        { "tbr",         "TBR Shelf" },
    }
    local PICK_SET = {}
    for _, p in ipairs(PICKS) do PICK_SET[p[1]] = true end
    local SWIPE = "swipe_today"
    local SWIPE_CAP = 0.36

    local function swipeCards()
        local v = A.get("tk_swipe_cards", nil)
        local out, seen = {}, {}
        if type(v) == "table" then
            for _, n in ipairs(v) do
                if PICK_SET[n] and P[n] and not seen[n] and #out < 3 then out[#out + 1] = n; seen[n] = true end
            end
        end
        if #out < 1 then
            for _, n in ipairs({ "goal_covers", "finished" }) do if P[n] then out[#out + 1] = n end end
        end
        return out
    end

    local function swipeWeight()
        local wgt = 0
        for _, n in ipairs(swipeCards()) do wgt = max(wgt, A.DASH_WEIGHT[n] or 0.25) end
        A.DASH_WEIGHT[SWIPE] = min(max(wgt, 0.2), SWIPE_CAP)
    end

    local function alternate() return A.get("tk_swipe_return", "stay") == "next" end

    -- 1.1.5: SimpleUI often shows the home screen again without rebuilding it
    -- (after sleep, and after a book with Fast Book Closing), so a card change
    -- decided while away (Alternate, Start On Tab) never showed. When one is
    -- waiting and the Dashboard is painted without having been rebuilt, it's
    -- rebuilt once, right after.
    local want_rebuild = false
    local swipeOn   -- defined below, with the Today slot

    -- which card shows now (1..n); after a book or sleep, "Alternate" moves on once
    local function swipeIndex(n)
        local i = A.state.tk_swipe_i or tonumber(A.get("tk_swipe_i", 1)) or 1
        if A.state.tk_swipe_away then
            A.state.tk_swipe_away = nil
            want_rebuild = false
            if alternate() then
                i = i + 1
                A.set("tk_swipe_i", ((i - 1) % n) + 1)
            end
        end
        i = ((i - 1) % n) + 1
        A.state.tk_swipe_i = i
        return i
    end

    local function swipeAway(why)
        A.state.tk_swipe_away = true
        local on = alternate() and swipeOn and swipeOn() and #swipeCards() >= 2
        if on then want_rebuild = true end
    end

    local function swipeCell(ctx)
        for _, r in ipairs((ctx and ctx._regions) or {}) do
            if r.id == SWIPE .. "|" then return r end
        end
        return nil
    end

    -- Redraw only the swipe card's band of the Dashboard.
    local function repaintCell(ctx)
        local cell = swipeCell(ctx)
        local d = ctx and ctx._box and ctx._box.dimen
        if not cell then pcall(H.repaint, ctx, {}) return end
        pcall(H.repaint, ctx, { strip = { y = cell.y, h = cell.h }, reason = "swipe" })
        if A.get("tk_swipe_flash", false) and d and d.x and ctx.screen then
            local region = Geom:new{ x = d.x + cell.x, y = d.y + cell.y, w = cell.w, h = cell.h }
            UIManager:setDirty(ctx.screen, function() return "flashui", region, true end)
        end
    end

    local function setSwipe(k, ctx)
        local n = #swipeCards()
        if n < 2 then return end
        k = ((k - 1) % n) + 1
        if k == (A.state.tk_swipe_i or 1) then return end
        A.state.tk_swipe_i = k
        A.set("tk_swipe_i", k)
        repaintCell(ctx)
    end

    local function flipSwipe(step, ctx) setSwipe((A.state.tk_swipe_i or 1) + step, ctx) end

    P[SWIPE] = {
        does = T("shows the card tapped"),
        title = "Today Page Card (Swipe)", tone = "ink", ratio = 0.36, ratio_narrow = 0.62,
        summary = "Two or three cards in one spot: swipe left or right on it, or tap its dots.",
        -- a tap goes to the card shown, never to a tap action of the swipe spot
        controls = function() return true end,
    }

    function P.swipe_today.build(env)
        local cards = swipeCards()
        local n = #cards
        local w, h = env.w, env.h
        local dots_h = n > 1 and max(12, floor(h * 0.075)) or 0
        local ch = h - dots_h
        local c = A.canvas{ w = w, h = h, plain = true, page = env.page }
        local i = swipeIndex(max(1, n))
        local name = cards[i]
        if name and P[name] then
            local ienv = A.makeEnv(name, env.ctx, w, ch, { nested = true, slot = 1, page = env.page,
                see = env.see, page_heading = env.page_heading })
            ienv.sample = env.sample
            local ok, child = pcall(P[name].build, ienv)
            if ok and child then
                c:sub(child, 0, 0, name .. "|")
            else
                warn("swipe card", tostring(name), "failed:", tostring(child))
                c:label(tostring(P[name].title or name) .. T(" could not be drawn"), max(12, floor(ch * 0.08)),
                    w / 2, ch / 2, { anchor = "c", valign = "mid", max_w = w - 20 })
            end
            c:region(name .. "|", 0, 0, w, ch)
        end
        if n > 1 then
            local page_bg, page_fg = A.dashPage()
            local r = max(3, floor(dots_h * 0.24))
            local step = r * 5
            local x0 = w / 2 - (n - 1) * step / 2
            for k = 1, n do
                local cx = x0 + (k - 1) * step
                c:disc(cx, ch + dots_h / 2, k == i and r or floor(r * 0.75 + 0.5),
                    k == i and page_fg or A.mix(page_fg, page_bg, 0.6))
                c:region("dot:" .. k, cx - step / 2, ch, step, dots_h)
            end
            c:region("dots", 0, ch, w, dots_h)
        end
        return c
    end

    function P.swipe_today.tap(env, region)
        local ctx = env.ctx
        if type(region) ~= "string" then return end
        if region == "dots" then return flipSwipe(1, ctx) end
        local k = tonumber(region:match("^dot:(%d+)$"))
        if k then return setSwipe(k, ctx) end
        local inner, sub = region:match("^([%w_]+)|(.*)$")
        local def = inner and P[inner]
        if not def then return end
        sub = (sub ~= "") and sub or nil
        local custom = A.customTap and A.customTap(inner, sub)
        if custom and A.runTapAction then return A.runTapAction(custom, ctx) end
        if not def.tap then return end
        local ok, err = pcall(def.tap, A.makeEnv(inner, ctx, 0, 0, { nested = true, slot = 1 }), sub)
        if not ok then warn("tap", inner, "in swipe failed:", tostring(err)) end
        if def.keep and def.keep(sub) then pcall(H.repaint, ctx, {}) end
    end

    swipeWeight()

    -- What sits in the Today slot: one of PICKS, or the swipe spot. Changing
    -- it rewrites the Today page's rows (as Pages And Cards would).
    local function todayPage()
        for _, p in ipairs(A.dashPages()) do if p.id == "today" then return p end end
        return nil
    end

    -- the slot is the lowest such card on the page (Book Club, by default)
    local function slotAt(rows)
        local at
        for ri, r in ipairs(rows) do
            for ci, n in ipairs(r.cards) do
                if n == SWIPE or PICK_SET[n] then at = { ri, ci, n } end
            end
        end
        return at
    end

    local function todaySlot()
        local page = todayPage()
        if not page then return nil end
        local at = slotAt(A.dashPageRows(page))
        return at and at[3] or nil
    end

    local function setTodaySlot(new)
        local page = todayPage()
        if not page or not P[new] then return end
        local rows = A.dashPageRows(page)
        local at = slotAt(rows)
        local saved = {}
        for ri, r in ipairs(rows) do
            local cards = {}
            for ci, n in ipairs(r.cards) do
                if at and at[1] == ri and at[2] == ci then n = new end
                cards[#cards + 1] = n
            end
            saved[#saved + 1] = { c = cards, k = r.k }
        end
        if not at then saved[#saved + 1] = { c = { new }, k = 1 } end
        A.set("dash_rows_today", saved)
        if new ~= SWIPE then A.set("tk_today_card", new) end
        A.epoch = (A.epoch or 0) + 1
    end

    swipeOn = function() return todaySlot() == SWIPE end

    -- ─── swipes: Simple UI turns pages on a swipe before the cards see it, so
    -- a left/right swipe that starts on the swipe card is caught at the window.
    local LIVE = setmetatable({}, { __mode = "k" }) -- dashboard box -> { ctx, win, painted }
    local CUR_WIN

    local function windowOf()
        local stack = UIManager._window_stack or {}
        for i = #stack, 1, -1 do
            local w = stack[i].widget
            if type(w) == "table" and w.name == "homescreen" then return w end
        end
        for i = #stack, 1, -1 do
            local w = stack[i].widget
            if type(w) == "table" and w.covers_fullscreen and w.name ~= "ReaderUI" then return w end
        end
        return nil
    end

    local function onSwipe(win, ges)
        -- a swipe from the screen's edge belongs to the side panel
        -- (2-simpleui-sidepanel.lua: up to 1/8 of the width), not the card
        local sw = A.screen():getWidth()
        if ges.pos.x < sw / 8 or ges.pos.x > sw - sw / 8 then return false end
        for box, e in pairs(LIVE) do
            local d = box.dimen
            if e.painted and e.win == win and d and d.x and d.w then
                local rx, ry = ges.pos.x - d.x, ges.pos.y - d.y
                if rx >= 0 and ry >= 0 and rx < d.w and ry < d.h then
                    local cell = swipeCell(e.ctx)
                    if cell and rx >= cell.x and rx < cell.x + cell.w and ry >= cell.y and ry < cell.y + cell.h then
                        flipSwipe(ges.direction == "west" and 1 or -1, e.ctx)
                        return true
                    end
                end
            end
        end
        return false
    end

    -- ─── Start On Tab / Start On First Page (1.1.4) ─────────────────────────────
    -- Like Reading Log for SimpleUI: which Dashboard tab shows when you come
    -- back to it (turning onto its page, after a book, after sleep), and
    -- whether SimpleUI's home goes back to its first page after a book or
    -- sleep. Defaults keep Reading Log's and SimpleUI's own behaviour.

    local function startTabId() return A.get("tk_start_tab", "last") end
    local function firstPageOn() return A.get("tk_first_page", false) == true end

    local function goStartTab(why)
        local id = startTabId()
        if id == "last" then return end
        for _, t in ipairs(A.state.dash_tabs or {}) do
            if t.kind == "page" and t.id == id then
                if A.state.dash_page ~= t.page then
                    A.state.dash_page = t.page
                    A.state.month_offset = 0
                    want_rebuild = true
                end
                return
            end
        end
    end

    local function resetHomePage(why)
        if not firstPageOn() then return end
        local SE = package.loaded["engines/sui_screen_engine"]
        if type(SE) ~= "table" then return end
        -- the page SimpleUI remembers for a home screen it reopens
        if SE._current_page and SE._current_page ~= 1 then SE._current_page = nil end
        if type(SE._cs_state) == "table" then
            for _, st in pairs(SE._cs_state) do
                if type(st) == "table" and st._current_page and st._current_page ~= 1 then st._current_page = nil end
            end
        end
        -- a home screen still open (or parked while reading)
        local ids = { "hs" }
        if type(SE.knownScreenIds) == "function" then
            local ok, l = pcall(SE.knownScreenIds)
            if ok and type(l) == "table" then ids = l end
        end
        for _, id in ipairs(ids) do
            local ok, w = pcall(SE.getInstance, id)
            if ok and type(w) == "table" and (w._current_page or 1) ~= 1 then
                if type(w._setPage) == "function" then pcall(w._setPage, w, 1) else w._current_page = 1 end
            end
        end
    end

    local clubHold   -- set with Book Club Opens Picks, below

    -- A long-press on the Book Club card (on its own, or showing in the Today
    -- swipe spot): its Dashboard ctx, else nil.
    local function clubUnder(win, pos)
        for box, e in pairs(LIVE) do
            local d = box.dimen
            if e.painted and e.win == win and d and d.x and d.w then
                local rx, ry = pos.x - d.x, pos.y - d.y
                if rx >= 0 and ry >= 0 and rx < d.w and ry < d.h then
                    for _, r in ipairs((e.ctx and e.ctx._regions) or {}) do
                        if rx >= r.x and rx < r.x + r.w and ry >= r.y and ry < r.y + r.h then
                            if r.id == "bookclub|" then return e.ctx end
                            if r.id == SWIPE .. "|" then
                                local list = swipeCards()
                                local i = A.state.tk_swipe_i or 1
                                if list[((i - 1) % math.max(1, #list)) + 1] == "bookclub" then return e.ctx end
                            end
                        end
                    end
                end
            end
        end
    end

    local function hookWindow(w)
        if type(w) ~= "table" or rawget(w, "_tk_rl_hooked") then return end
        w._tk_rl_hooked = true
        local orig_he, orig_paint = w.handleEvent, w.paintTo
        if type(orig_he) == "function" then
            w.handleEvent = function(self, event, ...)
                if type(event) == "table" then
                    if event.handler == "onGesture" then
                        local ges = event.args and event.args[1]
                        if type(ges) == "table" and ges.ges == "hold" and ges.pos and clubHold then
                            local okc, cctx = pcall(clubUnder, self, ges.pos)
                            if okc and cctx then
                                local okh, opened = pcall(clubHold, cctx)
                                if okh and opened then return true end
                            end
                        end
                        if type(ges) == "table" and ges.ges == "swipe" and ges.pos
                                and (ges.direction == "west" or ges.direction == "east") then
                            local ok, took = pcall(onSwipe, self, ges)
                            if ok and took then return true end
                        end
                    elseif event.handler == "onResume" then
                        swipeAway("wake")
                    elseif event.handler == "onSuspend" then
                        swipeAway("sleep")
                        goStartTab("sleep")
                        pcall(resetHomePage, "sleep")
                    elseif event.handler == "onShowingReader" or event.handler == "onCloseWidget" then
                        swipeAway("book opened")
                        goStartTab("book opened")
                        pcall(resetHomePage, "book opened")
                    end
                end
                return orig_he(self, event, ...)
            end
        end
        if type(orig_paint) == "function" then
            -- which Dashboard was actually painted this time (not one on
            -- another Simple UI page)
            w.paintTo = function(self, ...)
                for _, e in pairs(LIVE) do if e.win == self then e.painted = false end end
                CUR_WIN = self
                local res = { orig_paint(self, ...) }
                CUR_WIN = nil
                local vis = false
                for _, e in pairs(LIVE) do if e.win == self and e.painted then vis = true end end
                local was = rawget(self, "_rl_vis")
                if was == true and vis == false then goStartTab("page turned") end
                if vis and want_rebuild then
                    want_rebuild = false
                    UIManager:nextTick(redrawAll)
                end
                self._rl_vis = vis
                return unpack(res)
            end
        end
    end

    local function watchBox(box, ctx)
        if type(box) ~= "table" then return box end
        local e = { ctx = ctx, painted = false }
        LIVE[box] = e
        local orig = box.paintTo
        box.paintTo = function(self, bb, x, y, ...)
            local win = CUR_WIN
            if not win then
                win = windowOf()
                hookWindow(win)
            end
            e.win, e.painted = win, true
            return orig(self, bb, x, y, ...)
        end
        return box
    end

    -- back from a book: "Alternate" shows the next card
    do
        local ok, ReaderUI = pcall(require, "apps/reader/readerui")
        if ok and type(ReaderUI) == "table" and type(ReaderUI.onClose) == "function" and not ReaderUI._tk_rl_hooked then
            ReaderUI._tk_rl_hooked = true
            local orig = ReaderUI.onClose
            ReaderUI.onClose = function(...)
                swipeAway("book closed")
                return orig(...)
            end
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Continue Reading: Buttons Only (1.1.3, off by default)
    -- ════════════════════════════════════════════════════════════════════════
    -- Like Reading Log for SimpleUI: a tap on the Continue Reading card opens
    -- the book only on its Continue button (or the cover, in the looks where
    -- the cover is the button); Details shows the details and the pager
    -- flips books. A tap anywhere else on the card does nothing.

    local function contButtons() return A.get("tk_continue_buttons", false) == true end
    local CONT_CONTROLS = { open = true, details = true, next = true }
    if type(P.continue) == "table" and type(P.continue.tap) == "function" and not P.continue._tk_buttons then
        P.continue._tk_buttons = true
        local orig_ctap = P.continue.tap
        P.continue.tap = function(env, region, ...)
            if contButtons() and not CONT_CONTROLS[region] then return end
            return orig_ctap(env, region, ...)
        end
    end

    -- BookOrbit Collections (1.1.6, on by default)
    -- ════════════════════════════════════════════════════════════════════════
    -- BookOrbit's collections join KOReader's wherever Reading Log lists or
    -- reads a collection: the Book Club card (its Collection setting and the
    -- picks chooser), the shelf cards. Named "BookOrbit: <name>". The books
    -- come from the SimpleUI Side Panel's saved BookOrbit lists (1.0.18+), so
    -- nothing here waits on the server; only books on this device are listed.
    -- A collection shows its books once its Side Panel view has been opened.

    local BO_PREFIX = "BookOrbit: "
    local function boCollsOn() return A.get("tk_bo_colls", true) ~= false end
    local function boShare()
        local t = package.loaded["simpleui_sidepanel_bo"]
        return type(t) == "table" and type(t.collections) == "function" and t or nil
    end
    local function boCollId(name)
        if type(name) ~= "string" or name:sub(1, #BO_PREFIX) ~= BO_PREFIX then return nil end
        local share = boShare()
        if not share then return nil end
        local ok, list = pcall(share.collections)
        if not ok or type(list) ~= "table" then return nil end
        local want = name:sub(#BO_PREFIX + 1)
        for _, e in ipairs(list) do if tostring(e.title) == want then return e.id end end
        return nil
    end
    if type(D.collections) == "function" and type(D.collection) == "function" and not D._tk_bo_colls then
        D._tk_bo_colls = true
        local orig_colls, orig_coll = D.collections, D.collection
        D.collections = function(...)
            local names, fav = orig_colls(...)
            if not boCollsOn() then return names, fav end
            local share = boShare()
            if share and type(names) == "table" then
                local ok, list = pcall(share.collections)
                if ok and type(list) == "table" and #list > 0 then
                    local out = {}
                    for _, n in ipairs(names) do out[#out + 1] = n end
                    for _, e in ipairs(list) do out[#out + 1] = BO_PREFIX .. tostring(e.title) end
                    return out, fav
                end
            end
            return names, fav
        end
        D.collection = function(name, ...)
            if boCollsOn() then
                local id = boCollId(name)
                if id ~= nil then
                    local ok, books = pcall(boShare().books, id)
                    local out = {}
                    if ok and type(books) == "table" then
                        for _, b in ipairs(books) do
                            if type(b.path) == "string" then out[#out + 1] = b.path end
                        end
                    end
                    return out
                end
            end
            return orig_coll(name, ...)
        end
    end

    -- Book Club from several collections (1.1.7)
    -- ════════════════════════════════════════════════════════════════════════
    -- Tick one or more collections (KOReader's and BookOrbit's) and the Book
    -- Club card and its picks chooser use all their books together. None
    -- ticked: the card's own Collection setting, as before.

    local CLUB_MULTI = "\1tk_book_club"
    local function clubColls()
        local v = A.get("tk_club_colls", nil)
        local out = {}
        if type(v) == "table" then for _, n in ipairs(v) do if type(n) == "string" then out[#out + 1] = n end end end
        return out
    end
    if type(P.bookclub) == "table" and type(P.bookclub.collection) == "function" and not P.bookclub._tk_multi then
        P.bookclub._tk_multi = true
        local orig_pick = P.bookclub.collection
        P.bookclub.collection = function(env, ...)
            if #clubColls() > 0 then return CLUB_MULTI end
            return orig_pick(env, ...)
        end
        local inner_coll, inner_label = D.collection, D.collectionLabel
        D.collection = function(name, ...)
            if name == CLUB_MULTI then
                local out, seen = {}, {}
                for _, n in ipairs(clubColls()) do
                    local ok, files = pcall(D.collection, n)
                    if ok and type(files) == "table" then
                        for _, fp in ipairs(files) do
                            if not seen[fp] then seen[fp] = true; out[#out + 1] = fp end
                        end
                    end
                end
                return out
            end
            return inner_coll(name, ...)
        end
        if type(inner_label) == "function" then
            D.collectionLabel = function(name, ...)
                if name == CLUB_MULTI then
                    local list = clubColls()
                    return #list == 1 and inner_label(list[1]) or table.concat(list, " + ")
                end
                return inner_label(name, ...)
            end
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Book Club Opens Picks (1.1.4; hold added in 1.1.5, off by default)
    -- ════════════════════════════════════════════════════════════════════════
    -- Long-press (or tap) the Book Club card to go straight to Reading Log's
    -- own "this month's books" chooser, the one in the card's settings. With
    -- Hold, a tap on a pick still opens that book. (1.1.4's tap only worked
    -- off the picks, which fill nearly the whole card.) Found inside Reading Log's settings code,
    -- so a Reading Log update that moves it just turns this off.

    -- "hold", "tap" or off (an old true counts as "tap")
    local function clubMode()
        local v = A.get("tk_club_picks", nil)
        if v == true then return "tap" end
        return (v == "hold" or v == "tap") and v or nil
    end
    local club_picks_fn
    local function findClubPicks()
        if club_picks_fn ~= nil then return club_picks_fn or nil end
        club_picks_fn = false
        local S = A.S
        if type(S) ~= "table" or type(S.card) ~= "function" or not debug or not debug.getupvalue then return nil end
        local seen = {}
        local function up(fn, name, depth)
            if type(fn) ~= "function" or seen[fn] or depth > 3 then return nil end
            seen[fn] = true
            local i = 1
            while true do
                local n, v = debug.getupvalue(fn, i)
                if not n then break end
                if n == name and type(v) == "function" then return v end
                if type(v) == "function" then
                    local r = up(v, name, depth + 1); if r then return r end
                end
                i = i + 1
            end
        end
        local i, rows = 1, nil
        while true do
            local n, v = debug.getupvalue(S.card, i)
            if not n then break end
            if n == "ROWS" and type(v) == "table" then rows = v break end
            i = i + 1
        end
        local f = rows and up(rows.bookclub, "clubPicks", 0)
        club_picks_fn = f or false
        if not f then warn("book club picks chooser not found; Book Club Opens Picks stays off") end
        return f
    end
    if type(P.bookclub) == "table" and type(P.bookclub.tap) == "function" and not P.bookclub._tk_picks then
        P.bookclub._tk_picks = true
        local orig_btap = P.bookclub.tap
        P.bookclub.tap = function(env, region, ...)
            if clubMode() == "tap" then
                local f = findClubPicks()
                if f and type(env) == "table" then
                    local ok, err = pcall(f, env.ctx, env, function() end)
                    if ok then return end
                    warn("book club picks:", tostring(err))
                end
            end
            return orig_btap(env, region, ...)
        end
    end
    -- Hold: called from the window's gesture watch with the Dashboard ctx
    -- whose Book Club card is under the finger. True when the chooser opened.
    clubHold = function(ctx)
        if clubMode() ~= "hold" then return false end
        local f = findClubPicks()
        if not f or type(A.makeEnv) ~= "function" then return false end
        local okE, env = pcall(A.makeEnv, "bookclub", ctx, 0, 0, { nested = true, slot = 1 })
        if not okE or type(env) ~= "table" then return false end
        local ok, err = pcall(f, ctx, env, function() end)
        if not ok then warn("book club picks:", tostring(err)) end
        return ok
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Book Taps Open BookOrbit
    -- ════════════════════════════════════════════════════════════════════════
    -- A tap on a book (a cover in Recently Finished, Year In Covers, Year Goal
    -- With Covers, Continue Reading's details...) opens that book's page in
    -- BookOrbit when BookOrbit knows the file; any other book gets Reading
    -- Log's usual book details.

    local function boOn() return A.get("tk_bo_details", false) == true end

    local function boPlugin()
        for _, mod in ipairs({ "apps/filemanager/filemanager", "apps/reader/readerui" }) do
            local UI = package.loaded[mod]
            local inst = type(UI) == "table" and UI.instance
            local pl = type(inst) == "table" and (inst.bookorbit or inst.BookOrbit)
            if type(pl) == "table" then return pl end
        end
        return nil
    end

    -- BookOrbit's id for a file on the device, or nil
    local function boBookId(fp)
        if type(fp) ~= "string" then return nil end
        local ok, SM = pcall(require, "bookorbit_state_manager")
        if not (ok and type(SM) == "table" and type(SM.onDeviceMaps) == "function") then return nil end
        local okm, maps = pcall(SM.onDeviceMaps)
        if not (okm and type(maps) == "table") then return nil end
        if type(maps.byPath) == "table" and maps.byPath[fp] ~= nil then
            local v = maps.byPath[fp]
            return type(v) == "table" and (v.id or v.book_id) or v
        end
        for id, path in pairs(type(maps.byBookId) == "table" and maps.byBookId or {}) do
            if path == fp then return id end
        end
        return nil
    end

    local function openBoDetail(id)
        local pl = boPlugin()
        if not pl then return false end
        if not pl.catalog_browser then
            for _, fn in ipairs({ "openBookOrbit", "browseCatalog", "openCatalogBrowser" }) do
                if not pl.catalog_browser and type(pl[fn]) == "function" then
                    pcall(pl[fn], pl, fn == "browseCatalog" and false or nil)
                end
            end
        end
        local cat = pl.catalog_browser
        if type(cat) ~= "table" or type(cat.loadBookDetail) ~= "function" then return false end
        local ok, err = pcall(cat.loadBookDetail, cat, id)
        if not ok then warn("BookOrbit detail failed:", tostring(err)) end
        return ok
    end

    local orig_details = D.showDetails
    if type(orig_details) == "function" then
        D.showDetails = function(ctx, fp, ...)
            if boOn() and boPlugin() then
                local id = boBookId(fp)
                if id ~= nil then
                    local home
                    for _i, e in ipairs(UIManager._window_stack or {}) do
                        if type(e.widget) == "table" and e.widget.name == "homescreen" then home = e.widget end
                    end
                    if home then home._navbar_closing_intentionally = true end
                    UIManager:nextTick(function()
                        local ok = openBoDetail(id)
                        if home then home._navbar_closing_intentionally = nil end
                        if not ok then orig_details(ctx, fp) end
                    end)
                    return
                end
            end
            return orig_details(ctx, fp, ...)
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Critter Remarks
    -- ════════════════════════════════════════════════════════════════════════

    local C = A.critter
    if not C then
        local ok, r = pcall(critterKit, A)
        if ok and type(r) == "table" then C = r; A.critter = r
        else warn("critter didn't load:", tostring(r)) end
    end

    local CUR_CTX -- the Dashboard being drawn (headings don't get a ctx)
    local tabsMoved, renderTK -- Tab Bar Position (below)
    local function curPage()
        local pages = A.dashPages()
        return pages[tonumber(A.state.dash_page) or 1] or pages[1]
    end
    local function critterOn() return C and C.enabled and C.enabled() end

    -- The Dashboard's page heading: the critter in what's left of the row
    -- after the title (and before the month buttons).
    local orig_heading = P.heading
    if type(orig_heading) == "function" and scaler then
        P.heading = function(env, kicker, title, nav)
            local c = orig_heading(env, kicker, title, nav)
            if not (c and CUR_CTX and critterOn()) then return c end
            pcall(function()
                local w, h = env.w, env.h
                local px, fpx = scaler(h / 150, env.ts)
                local room, right = w, w
                if nav then
                    local bs = max(32, floor(min(h * 0.8, w * 0.11)))
                    local gap = max(8, floor(bs * 0.2))
                    local x = w - bs - gap - bs
                    if nav.today then
                        local t_today = c:text(T("Today"), fpx(30), { bold = true })
                        x = x - floor(gap * 1.6) - (t_today.w + floor(bs * 0.7))
                    end
                    room = x - px(24)
                    right = x - px(24)
                end
                local inset = env.see and px(26) or 0
                if env.see then room = room - 2 * inset end
                local tk = kicker and c:text(kicker, fpx(24), { bold = true, caps = true, max_w = room }) or nil
                local tt = c:text(title, fpx(74), { bold = true, max_w = room })
                local text_end = inset + max(tk and tk.w or 0, tt.w) + inset + px(24)
                local free_w = right - text_end
                if free_w <= 0 then return end
                local cy = floor(h * 0.06)
                C.draw(c, text_end, cy, free_w, h - 2 * cy, curPage(), CUR_CTX, "critter", floor(w * 0.5))
            end)
            return c
        end
    end

    -- Today's banner (its "heading" style, with no lines of your own): the
    -- critter wanders in the room the clock leaves.
    local orig_banner = P.banner and P.banner.heading
    if type(orig_banner) == "function" and scaler then
        P.banner.heading = function(env)
            local c = orig_banner(env)
            if not (c and env.nested and not env.page_heading and CUR_CTX and critterOn()) then return c end
            if env.cfg("line1", "") ~= "" or env.cfg("line2", "") ~= "" then return c end
            pcall(function()
                local w, h = env.w, env.h
                local px, fpx = scaler(min(h / 170, w / 700), env.ts)
                local pad = env.see and px(26) or 0
                local now = os.time()
                local twelve = G_reader_settings and G_reader_settings:isTrue("twelve_hour_clock")
                local time_str = twelve and (os.date("%I:%M", now):gsub("^0", "")) or os.date("%H:%M", now)
                local kick = A.date("%A", now) .. "  \xE2\x80\xA2  " .. tonumber(os.date("%d", now)) .. " " .. A.date("%B", now)
                local t_k = c:text(kick, fpx(24), { bold = true, caps = true })
                local t_t = c:text(time_str, fpx(84), { bold = true })
                local t_s = twelve and c:text(os.date("%p", now), fpx(30), { bold = true }) or nil
                local left_w = max(t_k.w, t_t.w + (t_s and (t_s.w + px(10)) or 0))
                local free_x = pad + left_w + px(48)
                local free_w = w - pad - free_x
                if free_w <= 0 then return end
                local cy = floor(h * 0.06)
                C.draw(c, free_x, cy, free_w, h - 2 * cy, curPage(), CUR_CTX, "critter", floor(w * 0.5))
            end)
            return c
        end
    end

    local function critterTap(ctx)
        local page = curPage()
        local id = (page and page.id) or "?"
        local function redraw()
            local geo = A.state.critter_geo and A.state.critter_geo[id]
            local cd = geo and geo.canvas and geo.canvas.dimen
            local bd = ctx._box and ctx._box.dimen
            if cd and bd and cd.y and bd.y then
                pcall(H.repaint, ctx, { strip = { y = cd.y - bd.y, h = cd.h }, reason = "critter" })
            else
                pcall(H.repaint, ctx, {})
            end
        end
        local ok, opened = pcall(C.talk, page, ctx, redraw)
        if not (ok and opened) then
            pcall(C.next, page, ctx.refresh)
            redraw()
        end
    end

    -- ─── the Dashboard: its ctx while drawing, critter taps ─────────────────
    local Dash = A.Dashboard
    local orig_render, orig_tap = Dash.render, Dash.on_tap
    if type(orig_render) == "function" then
        Dash.render = function(ctx)
            want_rebuild = false   -- being rebuilt now: nothing waiting
            CUR_CTX = ctx
            local ok, c = pcall(function()
                if tabsMoved and tabsMoved() and renderTK then
                    local ok2, c2 = pcall(renderTK, ctx)
                    if ok2 and c2 then return c2 end
                    warn("moved tab bar layout failed, Reading Log's own used:", tostring(c2))
                end
                return orig_render(ctx)
            end)
            CUR_CTX = nil
            if not ok then error(c, 0) end
            return c
        end
    end
    if type(orig_tap) == "function" then
        Dash.on_tap = function(ctx)
            local r = ctx and ctx.tapped_region
            if C and (r == "heading|critter" or r == "banner|critter") then
                local ok, err = pcall(critterTap, ctx)
                if ok then return end
                warn("critter tap failed:", tostring(err))
            end
            return orig_tap(ctx)
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Fine tuning: Layout (Full Screen), Bottom Space, Tab Bar Position
    -- ════════════════════════════════════════════════════════════════════════

    local function suiTry(name)
        local m = package.loaded[name]
        if m ~= nil then return m end
        local ok, r = pcall(require, name)
        return ok and type(r) == "table" and r or nil
    end
    local function contentTop()
        local UI = suiTry("infra/sui_core")
        if UI and type(UI.getContentTop) == "function" then
            local ok, y = pcall(UI.getContentTop)
            if ok and tonumber(y) then return y end
        end
        return nil
    end
    local function contentHeight()
        local UI = suiTry("infra/sui_core")
        if UI and UI.getContentHeight then
            local ok, h = pcall(UI.getContentHeight)
            if ok and tonumber(h) then return h end
        end
        return floor(A.screen():getHeight() * 0.85)
    end
    local function fullOn() return A.get("tk_dash_layout", "card") == "full" and contentTop() ~= nil end

    -- The automatic room for SimpleUI's page dots (0 with one page, or the
    -- dots hidden); Bottom Space adds or takes away pixels on top of it.
    local function autoDots(sctx)
        local screen = type(sctx) == "table" and sctx._screen_widget or nil
        if screen and tonumber(screen._total_pages) and screen._total_pages <= 1 then return 0 end
        local pfx = type(sctx) == "table" and sctx.pfx or "simpleui_hs_"
        local St = suiTry("infra/sui_store")
        if St and St.isTrue then
            local ok, hidden = pcall(St.isTrue, St, pfx .. "pagination_hidden")
            if ok and hidden then return 0 end
        end
        local Screen = A.screen()
        local h = Screen:scaleBySize(28)
        local BB = suiTry("screens/sui_bottombar")
        if BB and type(BB.getPaginationIconSize) == "function" then
            local ok, icon = pcall(BB.getPaginationIconSize)
            if ok and tonumber(icon) then h = max(h, icon + Screen:scaleBySize(8)) end
        end
        return h
    end
    local function dotsRoom(sctx)
        return max(0, autoDots(sctx) + (tonumber(A.get("tk_dash_bottom_adjust", 0)) or 0))
    end

    -- Reading Log 1.4's Dashboard, with Tab Bar Position added. Used only
    -- while the tab bar is moved; at 0 Reading Log's own layout runs.
    local function textScale() return A.TEXT_SCALE or 1.25 end
    local pageLabel, pageRows = A.dashPageLabel, A.dashPageRows
    local function pageHeading(page)
        local v = A.get("dash_heading_" .. page.id, nil)
        if v == nil then return page.heading and true or false end
        return v and true or false
    end
    local function rowWeight(row)
        local wgt = 0
        for _, name in ipairs(row.cards) do wgt = max(wgt, A.DASH_WEIGHT[name] or 0.25) end
        return wgt * (row.k or 1)
    end
    local function dashTabs()
        local tabs = {}
        local pages = A.dashPages()
        for i, page in ipairs(pages) do
            if A.get("dash_page_" .. page.id, true) ~= false then
                tabs[#tabs + 1] = { kind = "page", page = i, label = pageLabel(page), id = page.id }
            end
        end
        if #tabs == 0 then tabs[1] = { kind = "page", page = 1, label = pageLabel(pages[1]), id = pages[1].id } end
        return tabs, pages
    end
    local function dashMargin(gap)
        local k = (A.DASH_MARGINS or { none = 0, small = 1, medium = 2 })[A.get("dash_margin", "small")]
        return floor(gap * (k or 1))
    end
    local function currentPage(tabs)
        local want = tonumber(A.state.dash_page)
        for _, t in ipairs(tabs) do
            if t.kind == "page" and t.page == want then return want end
        end
        for _, t in ipairs(tabs) do
            if t.kind == "page" then A.state.dash_page = t.page; return t.page end
        end
        return 1
    end
    local makeEnv = A.makeEnv
    local function buildPanel(name, env)
        local ok, c = pcall(P[name].build, env)
        if ok and c then return c end
        A.log(name, "render failed:", c)
        local ec = A.canvas{ w = env.w, h = env.h, tone = "ink", radius = 12 }
        ec:label(tostring(P[name] and P[name].title or name) .. T(" could not be drawn"),
            max(12, floor(22 * min(env.w / 500, env.h / 200))), env.w / 2, env.h / 2,
            { anchor = "c", valign = "mid", max_w = env.w - 20 })
        return ec
    end

    local function buildDashboardTK(ctx, w, h)
        local page_bg, page_fg, dark, _, page_look = A.dashPage()
        -- A theme with its own page colour: paint it, out to the edges of the
        -- cell. Over a Simple UI wallpaper with this module's Background Opacity
        -- below Solid, leave the page unpainted so the wallpaper shows between
        -- the cards (the cards and the tab bar stay solid, to stay readable).
        local see = ctx and H.seeThrough(ctx.pfx, ctx.mod_id) or false
        local c = A.canvas{ w = w, h = h, plain = true, bleed = page_look ~= nil and not see,
            fill = (page_look and not see) and page_bg or nil }
        local th = A.theme()
        local ts = textScale()
        local gap = max(6, floor(min(w, h) * 0.016 + 0.5))
        local tabs, pages = dashTabs()
        local page_i = currentPage(tabs)
        local page = pages[page_i]

        -- Everything is laid out inside a margin: from here on w and h are the
        -- space inside it, and (ox, oy) is where that space starts.
        local m = dashMargin(gap)
        if w - 2 * m < 60 or h - 2 * m < 60 then m = 0 end
        local ox, oy = m, m
        w, h = w - 2 * m, h - 2 * m

        -- tab bar
        local body_h = h
        local head_from = h -- what the heading's size comes from (not the tab bar's position)
        if #tabs > 1 then
            local bar_h = A.clamp(floor(h * 0.056 + 0.5), 40, 110)
            local bar_w = min(w, max(floor(w * 0.72), #tabs * floor(bar_h * 2.3)))
            local bx, by = ox + floor((w - bar_w) / 2), oy + h - bar_h
            -- Tab Bar Position: up (-) or down (+) by that many pixels. Down only
            -- into the margin below; up leaves the cards at least half the room.
            local adj = tonumber(A.get("tabs_adjust", 0)) or 0
            if adj ~= 0 then
                by = A.clamp(by + floor(adj), oy + floor(h * 0.5), oy + h + m - bar_h)
            end
            local bw_ = max(2, floor(bar_h * 0.045 + 0.5))
            local CYT = A.cutTheme()
            -- the Dark Academia theme: the tab names alone, the open one underlined in brass
            local ACT = not CYT and A.academiaTheme()
            if CYT or ACT then
                -- the Cyber theme: a row of square tabs, the open one filled
                bar_w, bx = w, ox
            else
                c:frame(bx, by, bar_w, bar_h, bar_h / 2, bw_, page_fg, page_bg, see and A.BEHIND or page_bg)
            end
            local inner = (CYT or ACT) and bar_w or (bar_w - bar_h * 0.5)
            local cell = inner / #tabs
            local size = max(10, floor(bar_h * 0.36 * ts + 0.5))
            local tgap = CYT and max(4, floor(bar_h * 0.12)) or 0
            local caps = CYT and true or nil
            if CYT then size = max(10, floor(size * 0.86)) end
            -- longer tab names (another language, a name of your own) get a
            -- smaller size that fits, instead of being cut short
            for _ = 1, 6 do
                local widest = 0
                for _, tab in ipairs(tabs) do
                    widest = max(widest, c:text(tab.label, size, { bold = true, caps = caps }).w)
                end
                local room = CYT and (cell - 6 - tgap - floor(bar_h * 0.3)) or (cell - bar_h * 0.3)
                if widest <= room or size <= 12 then break end
                size = max(12, floor(size * room / widest))
            end
            local fill = A.shown(dark and th.gold or th.wine)
            local on_fill = A.shown(dark and th.ink or th.paper)
            local line = A.mix(page_fg, page_bg, 0.72)
            for i, tab in ipairs(tabs) do
                local cx = bx + ((CYT or ACT) and 0 or bar_h * 0.25) + (i - 0.5) * cell
                local active = tab.kind == "page" and tab.page == page_i
                local t_tab = c:text(tab.label, size, { bold = active or caps, caps = caps, max_w = cell - 6 - tgap,
                    color = (active and ACT) and page_fg or active and on_fill or A.mix(page_fg, page_bg, ACT and 0.45 or 0.38) })
                if CYT then
                    local tx0, tw0 = floor(cx - cell / 2 + tgap / 2), floor(cell - tgap)
                    local th0 = floor(bar_h * 0.86)
                    local ty0 = by + floor((bar_h - th0) / 2)
                    if active then
                        CYT.cutRect(c, tx0, ty0, tw0, th0, th0 * 0.3, fill)
                    else
                        c:frame(tx0, ty0, tw0, th0, 0, max(1, floor(bw_ * 0.6)), line, page_bg, see and A.BEHIND or page_bg)
                    end
                elseif ACT then
                    if active then
                        local uw = t_tab.w + floor(bar_h * 0.2)
                        c:rect(floor(cx - uw / 2), floor(by + bar_h / 2 + t_tab.h / 2), uw, max(2, floor(bar_h * 0.05)),
                            A.ACCENTS.brass.bright)
                    end
                elseif active then
                    local pw = min(cell - 4, t_tab.w + bar_h * 0.5)
                    local ph = bar_h * 0.6
                    c:rrect(cx - pw / 2, by + (bar_h - ph) / 2, pw, ph, ph * 0.22, fill, page_bg)
                end
                c:put(t_tab, cx, by + bar_h / 2, "c", "mid")
                c:region("tab:" .. i, cx - cell / 2, by, cell, bar_h)
            end
            head_from = h - bar_h - gap
            body_h = min(head_from, by - oy - gap)
        end

        -- Short, wide cell (the hero area): there is not room for a whole page,
        -- so show as many of its rows as fit at a readable height.
        local rows = pageRows(page)
        local heading = pageHeading(page)
        local min_row = w * 0.17
        if body_h < #rows * min_row then
            heading = false
            local keep = max(1, floor(body_h / min_row))
            local cut = {}
            for i = 1, min(keep, #rows) do cut[i] = rows[i] end
            rows = cut
        end

        local y = 0
        if heading then
            local head_h = floor(head_from * 0.105)
            local kicker, nav
            local refresh = ctx.refresh
            local st = D.stats(refresh)
            local dot = "  \xE2\x80\xA2  "
            if page.kicker == "year" then
                -- "2026 · 29 books"
                local yr = D.year(refresh)
                kicker = os.date("%Y") .. (yr and (dot .. A.plural(yr.total, "book", "books")) or "")
            elseif page.kicker == "month" then
                -- "October · day 8 of 31", or for a month gone by "September · 30 days";
                -- and the switcher that steps back through the last twelve months
                local t = os.date("*t")
                local vy, vm, current = A.viewMonth()
                local n_days = tonumber(os.date("%d", os.time{ year = vy, month = vm + 1, day = 0, hour = 12 })) or 30
                kicker = A.monthTitle(vy, vm) .. dot .. (current and (T("day ") .. t.day .. T(" of ") .. n_days) or (n_days .. T(" days")))
                nav = { prev = (tonumber(A.state.month_offset) or 0) > -D.BACK_MONTHS, next = not current, today = not current }
            elseif page.kicker == "library" then
                -- "412 books · 168 read"
                local lib = D.library(refresh)
                kicker = lib and (A.plural(lib.total, "book", "books") .. dot .. A.thousands(lib.counts.finished) .. T(" read")) or nil
            elseif page.kicker == "streak" and st then
                -- "Streak 147 days · best 150"
                kicker = (st.streak > 0 and (T("Streak ") .. A.plural(st.streak, "day", "days")) or T("No streak yet"))
                    .. ((st.best or 0) > st.streak and (dot .. T("best ") .. st.best) or "")
            elseif st then
                kicker = T("This week") .. dot .. A.plural(st.week_pages, "page", "pages")
            end
            local env = { w = w, h = head_h, ts = ts, see = see }
            local ok, hc = pcall(P.heading, env, kicker, pageLabel(page), nav)
            if ok and hc then
                hc.cache_me = true
                c:sub(hc, ox, oy + y, "heading|")
            end
            y = y + head_h + floor(gap * 0.6)
        end

        local total = 0
        for _, row in ipairs(rows) do total = total + rowWeight(row) end
        local avail = body_h - y - gap * (#rows - 1)
        for ri, row in ipairs(rows) do
            local rh = floor(avail * rowWeight(row) / total)
            if ri == #rows then rh = body_h - y end
            local names = row.cards
            local pw = floor((w - gap * (#names - 1)) / #names)
            for ni, name in ipairs(names) do
                local x = (ni - 1) * (pw + gap)
                local width = (ni == #names) and (w - x) or pw
                local env = makeEnv(name, ctx, width, rh, { nested = true, slot = 1, page = page_look, see = see, page_heading = heading })
                local child = buildPanel(name, env)
                child.cache_me = not P[name].tick
                c:sub(child, ox + x, oy + y, name .. "|")
                if P[name].tick then c.clock_y, c.clock_h = oy + y, rh end
                -- the rest of the panel: a plain tap on it
                c:region(name .. "|", ox + x, oy + y, width, rh)
            end
            y = y + rh + gap
        end
        A.state.dash_tabs = tabs
        return c
    end

    tabsMoved = function() return (tonumber(A.get("tabs_adjust", 0)) or 0) ~= 0 end
    local _seen_screens = setmetatable({}, { __mode = "k" })
    renderTK = function(ctx)
        local w = max(80, floor(tonumber(ctx.width) or 400))
        local h = (ctx.height and ctx.height > 0) and floor(ctx.height) or floor(w * 1.2)
        if ctx.screen and not _seen_screens[ctx.screen] then
            _seen_screens[ctx.screen] = true
            A.state.month_offset = 0
        end
        local c = buildDashboardTK(ctx, w, h)
        A.state.regions_ok = true
        if ctx and ctx.set_tap_regions then pcall(ctx.set_tap_regions, c.regions) end
        H.wantTick(ctx, c.clock_y and { y = c.clock_y, h = c.clock_h } or nil)
        return c
    end

    -- Full Screen: Reading Log builds the Dashboard at the size of the whole
    -- area between SimpleUI's status bar and nav bar (less Bottom Space), and
    -- it is drawn there; SimpleUI lays out a smaller slot for it.
    local FULL = setmetatable({}, { __mode = "k" }) -- screen -> the full rect last drawn
    local function buildFull(orig_build, w, sctx, id)
        local screen = type(sctx) == "table" and sctx._screen_widget or nil
        local top = contentTop()
        if not screen then return nil end
        local Screen = A.screen()
        local fw = Screen:getWidth()
        local fh = max(200, contentHeight() - dotsRoom(sctx))
        -- Reading Log sizes the Dashboard from the screen's content height and
        -- its Height setting: for this one build, "100% of fh"
        local pfx = sctx.pfx or "simpleui_hs_"
        local hkey = A.screenKey and A.screenKey(pfx, id, "dash_height")
        local old_h = rawget(screen, "_layout_content_h")
        local old_get = A.get
        A.get = function(k, d)
            if hkey and k == hkey then return 100 end
            return old_get(k, d)
        end
        rawset(screen, "_layout_content_h", fh)
        local ok, box = pcall(orig_build, fw, sctx)
        A.get = old_get
        rawset(screen, "_layout_content_h", old_h)
        if not ok or type(box) ~= "table" then return nil end
        local slot_h = floor(contentHeight() * 0.8)
        local WidgetContainer = require("ui/widget/container/widgetcontainer")
        local holder = WidgetContainer:new{ dimen = Geom:new{ w = w, h = slot_h }, box }
        function holder:paintTo(bb)
            -- SimpleUI places the slot; the Dashboard covers the whole area
            box:paintTo(bb, 0, top)
            FULL[screen] = Geom:new{ x = 0, y = top, w = fw, h = fh }
        end
        holder._readinglog_ctx = box._readinglog_ctx
        return holder, box
    end

    -- A page turn or tap repaints SimpleUI's slot; in Full Screen the
    -- Dashboard is bigger than that, so its whole area is refreshed too.
    local repaint_now = H.repaint
    H.repaint = function(ctx, o)
        local r = repaint_now(ctx, o)
        if type(ctx) == "table" and ctx.screen and FULL[ctx.screen] and fullOn()
                and ctx.mod_id == (A.ID_PREFIX or "readinglog_") .. "dashboard"
                and not (type(o) == "table" and o.strip) then
            local rect = FULL[ctx.screen]
            local kind = (type(o) == "table" and o.flash) and "flashui" or "ui"
            UIManager:setDirty(ctx.screen, function() return kind, rect, true end)
        end
        return r
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Settings: "Reading Log Tweaks" (Dashboard long-press, and Tools > Add-ons)
    -- ════════════════════════════════════════════════════════════════════════

    local function after() swipeWeight(); redrawAll() end

    local function extrasMenu()
        local function picked()
            local set = {}
            for _, n in ipairs(swipeCards()) do set[n] = true end
            return set
        end
        local today = {
            {
                text_func = function()
                    return "Swipe Between 2-3 Cards" .. (swipeOn() and (" (" .. #swipeCards() .. ")") or "")
                end,
                checked_func = swipeOn,
                keep_menu_open = true,
                help_text = "On: tick up to 3 cards below (a 4th replaces the oldest), then swipe left or right on the card, or tap its dots, to switch.",
                callback = function()
                    if swipeOn() then
                        local one = A.get("tk_today_card", nil)
                        if not (one and P[one]) then one = swipeCards()[1] or "bookclub" end
                        setTodaySlot(one)
                    else
                        local cur = todaySlot()
                        if PICK_SET[cur or ""] then A.set("tk_today_card", cur) end
                        local saved = A.get("tk_swipe_cards", nil)
                        if type(saved) ~= "table" or #saved < 2 then
                            local one = todaySlot()
                            if not PICK_SET[one or ""] then one = "goal_covers" end
                            A.set("tk_swipe_cards", { one, one == "goal_covers" and "finished" or "goal_covers" })
                        end
                        A.state.tk_swipe_i = nil
                        setTodaySlot(SWIPE)
                    end
                    after()
                end,
                separator = true,
            },
        }
        for _, pk in ipairs(PICKS) do
            if P[pk[1]] then
                today[#today + 1] = {
                    text = pk[2],
                    checked_func = function()
                        if swipeOn() then return picked()[pk[1]] == true end
                        return todaySlot() == pk[1]
                    end,
                    keep_menu_open = true,
                    callback = function()
                        if swipeOn() then
                            local list = {}
                            for _, n in ipairs(swipeCards()) do if n ~= pk[1] then list[#list + 1] = n end end
                            if picked()[pk[1]] then
                                if #list < 1 then return end
                            else
                                list[#list + 1] = pk[1]
                                while #list > 3 do table.remove(list, 1) end
                            end
                            A.set("tk_swipe_cards", list)
                            A.state.tk_swipe_i = nil
                        else
                            setTodaySlot(pk[1])
                        end
                        after()
                    end,
                }
            end
        end
        today[#today].separator = true
        today[#today + 1] = {
            text_func = function() return "Alternate Or Keep Last: " .. (alternate() and "Alternate" or "Keep Last") end,
            enabled_func = swipeOn,
            help_text = "With swipe on. Alternate: the next card each time you come back from a book or sleep. Keep Last: the one you swiped to.",
            sub_item_table = {
                { text = "Alternate", radio = true, checked_func = function() return alternate() end,
                  callback = function() A.set("tk_swipe_return", "next") end },
                { text = "Keep Last", radio = true, checked_func = function() return not alternate() end,
                  callback = function() A.set("tk_swipe_return", nil) end },
            },
        }
        today[#today + 1] = {
            text = "Flash On Swipe",
            enabled_func = swipeOn,
            checked_func = function() return A.get("tk_swipe_flash", false) == true end,
            keep_menu_open = true,
            help_text = "Flashes the card when you swipe, to clear ghosting. Slower (about 0.6 s instead of 0.2 s).",
            callback = function() A.set("tk_swipe_flash", not A.get("tk_swipe_flash", false) or nil) end,
        }

        local function critterToggle(text, key, help)
            return {
                text = text,
                help_text = help,
                enabled_func = function() return critterOn() and true or false end,
                checked_func = function() return A.get(key, true) ~= false end,
                keep_menu_open = true,
                callback = function()
                    A.set(key, A.get(key, true) == false and nil or false)
                    redrawAll()
                end,
            }
        end
        local critter = {
            {
                text = "Critter Remarks",
                help_text = "SimpleUI's Tiny Critter peeks into each Dashboard page and says something about its numbers. Tap it to talk. Needs SimpleUI 3.0 with Tiny Critter.",
                enabled_func = function() return C and C.available and C.available() or false end,
                checked_func = function() return critterOn() and true or false end,
                keep_menu_open = true,
                callback = function()
                    A.set("critter_peek", A.get("critter_peek", true) == false and nil or false)
                    redrawAll()
                end,
                separator = true,
            },
            critterToggle("Statistics Remarks", "critter_stats", "Remarks about your numbers: goal pace, records, milestones, streaks."),
            critterToggle("Book Suggestions", "critter_sug", "Books worked out from your stats: the next in a series, one nearly done, one you left a while ago."),
            critterToggle("Streak Remarks", "critter_streak", "Remarks about your reading streak."),
            critterToggle("Critter's Own Voice", "critter_voice", "SimpleUI 3.0.2's critters (Suey, Chonk, Tulu, Frankie, Vlad, Sholmes, Argos, Hazel), and Donny, Blu and Donny & Blu with SimpleUI Tweaks and critter-phrases.lua, say some of the remarks their own way: about one in three, on the pages where their lines fit."),
            critterToggle("Games And Quotes", "critter_games", "Tap the critter to talk: Let's Play (rock, paper, scissors, heads or tails, guess the author) and Read Me A Quote, with SimpleUI 3.0.2. Its last word shows in the bubble."),
            {
                text = "Critter Rewards",
                help_text = "Little things the critter earns, drawn beside it here and on the home screen: a stack of books at 5, 10, 25 and 50 books this year, a medal at a 7-day streak and a trophy at 30, and a balloon on your reading anniversary.",
                enabled_func = function() return C and C.available and C.available() or false end,
                checked_func = function() return A.get("critter_rewards", true) ~= false end,
                keep_menu_open = true,
                callback = function()
                    A.set("critter_rewards", A.get("critter_rewards", true) == false and nil or false)
                    redrawAll()
                end,
            },
        }

        local function spin(title, info, key, lo, hi, done_fn)
            return function(touchmenu_instance)
                local SpinWidget = require("ui/widget/spinwidget")
                UIManager:show(SpinWidget:new{
                    title_text = title, info_text = info,
                    value = tonumber(A.get(key, 0)) or 0,
                    value_min = lo, value_max = hi, value_step = 2, value_hold_step = 10,
                    default_value = 0, unit = "px", ok_text = "Save",
                    callback = function(sp)
                        A.set(key, sp.value ~= 0 and sp.value or nil)
                        if touchmenu_instance and touchmenu_instance.updateItems then touchmenu_instance:updateItems() end
                        if done_fn then done_fn() end
                        redrawAll()
                    end,
                })
            end
        end
        local function px(v) return v == 0 and nil or ((v > 0 and "+" or "") .. v .. " px") end
        local fine = {
            {
                text_func = function()
                    return "Layout: " .. (A.get("tk_dash_layout", "card") == "full" and "Full Screen" or "In The Page")
                end,
                sub_item_table = {
                    { text = "In The Page", radio = true, keep_menu_open = true,
                      help_text = "Sits in SimpleUI's page like other modules, with its margins and page dots.",
                      checked_func = function() return A.get("tk_dash_layout", "card") ~= "full" end,
                      callback = function() A.set("tk_dash_layout", nil); redrawAll() end },
                    { text = "Full Screen", radio = true, keep_menu_open = true,
                      help_text = "Fills everything between the status bar and the nav bar, so every card is bigger.",
                      enabled_func = function() return contentTop() ~= nil end,
                      checked_func = function() return A.get("tk_dash_layout", "card") == "full" end,
                      callback = function() A.set("tk_dash_layout", "full"); redrawAll() end },
                },
            },
            {
                text_func = function()
                    return "Bottom Space: " .. (px(tonumber(A.get("tk_dash_bottom_adjust", 0)) or 0) or "Auto")
                end,
                help_text = "Full Screen only. Room left under the dashboard for SimpleUI's page dots. Auto fits the dots; add or take away pixels from there.",
                enabled_func = function() return A.get("tk_dash_layout", "card") == "full" end,
                keep_menu_open = true,
                callback = function(tmi)
                    spin("Bottom Space", "Pixels added to the automatic room for the page dots (0 = Auto).",
                        "tk_dash_bottom_adjust", -200, 200)(tmi)
                end,
            },
            {
                text_func = function()
                    return "Tab Bar Position: " .. (px(tonumber(A.get("tabs_adjust", 0)) or 0) or "Default")
                end,
                help_text = "Moves the Today / Monthly / Yearly tab bar up (-) or down (+) from where it normally sits. Only the tab bar moves: the heading at the top stays put and the cards make room. It can only go down into the dashboard's margin.",
                keep_menu_open = true,
                callback = function(tmi)
                    spin("Tab Bar Position", "Pixels up (-) or down (+) from the default (0).", "tabs_adjust", -300, 100)(tmi)
                end,
            },
        }

        local out = {
            { text = "Fine Tuning", sub_item_table = fine,
              help_text = "Size and Height are Reading Log's own: long-press the Dashboard > Appearance." },
            {
                text_func = function()
                    local id = startTabId()
                    if id == "last" then return "Start On Tab: Last Viewed" end
                    for _, t in ipairs(A.state.dash_tabs or {}) do
                        if t.id == id then return "Start On Tab: " .. tostring(t.label) end
                    end
                    return "Start On Tab: " .. tostring(id)
                end,
                help_text = "Which Dashboard tab shows when you come back to it: turning onto its page, after a book or after sleep. Last Viewed (default) keeps the one you left on.",
                sub_item_table_func = function()
                    local list = { {
                        text = "Last Viewed", radio = true,
                        checked_func = function() return startTabId() == "last" end,
                        keep_menu_open = true,
                        callback = function() A.set("tk_start_tab", nil) end,
                        separator = true,
                    } }
                    local tabs = A.state.dash_tabs
                    if type(tabs) ~= "table" or #tabs == 0 then
                        tabs = {}
                        if type(A.dashPages) == "function" then
                            local ok, pages = pcall(A.dashPages)
                            if ok and type(pages) == "table" then
                                for i, pg in ipairs(pages) do
                                    tabs[#tabs + 1] = { kind = "page", page = i, id = pg.id, label = pg.label }
                                end
                            end
                        end
                    end
                    for _, t in ipairs(tabs) do
                        if t.kind == "page" and t.id then
                            list[#list + 1] = {
                                text = tostring(t.label or t.id), radio = true,
                                checked_func = function() return startTabId() == t.id end,
                                keep_menu_open = true,
                                callback = function() A.set("tk_start_tab", t.id) end,
                            }
                        end
                    end
                    return list
                end,
            },
            {
                text = "Start On First Page After Reading Or Sleep",
                help_text = "Opening a book or putting the device to sleep sends SimpleUI's home screen back to page 1. Off (default): it comes back on the page you left.",
                checked_func = firstPageOn,
                keep_menu_open = true,
                callback = function() A.set("tk_first_page", (not firstPageOn()) or nil) end,
                separator = true,
            },
            {
                text = "BookOrbit Collections",
                help_text = "Your BookOrbit collections show next to KOReader's wherever Reading Log asks for a collection (the Book Club card's Collection and picks, the shelf cards), as \"BookOrbit: <name>\". Their books come from the SimpleUI Side Panel's saved BookOrbit lists (Side Panel 1.0.18+): open a collection's view in the Side Panel once to fill it. Only books on this device are listed. Nothing waits on the BookOrbit server.",
                enabled_func = function() return boShare() ~= nil end,
                checked_func = boCollsOn,
                keep_menu_open = true,
                callback = function() A.set("tk_bo_colls", (not boCollsOn()) and nil or false); redrawAll() end,
            },
            {
                text_func = function()
                    local n = #clubColls()
                    return n == 0 and "Book Club Collections: Card's Own" or ("Book Club Collections: " .. n)
                end,
                help_text = "Tick one or more collections (KOReader's, and BookOrbit's with BookOrbit Collections on) and the Book Club card and its picks use all their books together. None ticked: the card's own Collection setting.",
                sub_item_table_func = function()
                    local items = {}
                    local ok, names = pcall(D.collections)
                    for _, n in ipairs(ok and names or {}) do
                        items[#items + 1] = {
                            text = (D.collectionLabel and D.collectionLabel(n)) or n,
                            checked_func = function()
                                for _, c in ipairs(clubColls()) do if c == n then return true end end
                                return false
                            end,
                            keep_menu_open = true,
                            callback = function()
                                local list, found = {}, false
                                for _, c in ipairs(clubColls()) do
                                    if c == n then found = true else list[#list + 1] = c end
                                end
                                if not found then list[#list + 1] = n end
                                A.set("tk_club_colls", #list > 0 and list or nil)
                                redrawAll()
                            end,
                        }
                    end
                    if #items == 0 then items[1] = { text = "No collections yet", enabled = false } end
                    return items
                end,
            },
            {
                text_func = function()
                    local m = clubMode()
                    return "Book Club Opens Picks: " .. (m == "hold" and "On Hold" or m == "tap" and "On Tap" or "Off")
                end,
                help_text = "Go straight to choosing this month's books (Reading Log's own chooser; the arrows step to other months). On Hold: long-press the Book Club card; a tap on a pick still opens that book. On Tap: any tap on the card. Off (default): Reading Log's own tap.",
                sub_item_table = {
                    { text = "Off", radio = true, keep_menu_open = true,
                      checked_func = function() return clubMode() == nil end,
                      callback = function() A.set("tk_club_picks", nil) end },
                    { text = "On Hold", radio = true, keep_menu_open = true,
                      checked_func = function() return clubMode() == "hold" end,
                      callback = function() A.set("tk_club_picks", "hold") end },
                    { text = "On Tap", radio = true, keep_menu_open = true,
                      checked_func = function() return clubMode() == "tap" end,
                      callback = function() A.set("tk_club_picks", "tap") end },
                },
            },
            {
                text = "Continue Reading: Buttons Only",
                help_text = "On: the Continue Reading card opens the book only when you tap its Continue button (or the cover, in the looks where the cover is the button). Details shows the details and the dots flip books; a tap anywhere else on the card does nothing. Off (default): a tap anywhere opens the book, as Reading Log does.",
                checked_func = contButtons,
                keep_menu_open = true,
                callback = function() A.set("tk_continue_buttons", (not contButtons()) or nil) end,
            },
            {
                text = "Book Taps Open BookOrbit",
                help_text = "A tap on a book's cover opens its page in BookOrbit, when BookOrbit has that file. Other books get the usual book details.",
                checked_func = boOn,
                keep_menu_open = true,
                callback = function() A.set("tk_bo_details", (not boOn()) or nil) end,
                separator = true,
            },
            { text = "Today Page Card", sub_item_table = today },
            { text = "Critter Remarks", sub_item_table = critter,
              enabled_func = function() return C ~= nil end, separator = true },
            { text = "About Reading Log Tweaks " .. PATCH_VERSION, enabled = false },
        }
        -- 1.1.9: grouped. The items above, in the order they're listed:
        -- 1 Fine Tuning, 2 Start On Tab, 3 Start On First Page, 4 BookOrbit
        -- Collections, 5 Book Club Collections, 6 Book Club Opens Picks,
        -- 7 Continue Reading: Buttons Only, 8 Book Taps Open BookOrbit,
        -- 9 Today Page Card, 10 Critter Remarks, 11 About.
        local function plain(it) it.separator = nil; return it end
        local grouped = {
            { text = "Today Page Card", sub_item_table = out[9].sub_item_table },
            plain(out[7]),
            { text = "Book Club", sub_item_table = { plain(out[5]), plain(out[6]) } },
            { text = "When You Come Back", sub_item_table = { plain(out[2]), plain(out[3]) }, separator = true },
        }
        -- BookOrbit's two only with BookOrbit installed
        if boPlugin() then
            grouped[#grouped + 1] = { text = "BookOrbit", sub_item_table = { plain(out[4]), plain(out[8]) }, separator = true }
        else
            grouped[#grouped].separator = true
        end
        grouped[#grouped + 1] = out[10]
        grouped[#grouped + 1] = plain(out[1])
        grouped[#grouped].separator = true
        grouped[#grouped + 1] = out[11]
        return grouped
    end

    -- the Dashboard's long-press menu
    local orig_mods = A.simpleUIModules
    if type(orig_mods) == "function" then
        A.simpleUIModules = function(...)
            local list = orig_mods(...)
            for _, m in ipairs(list or {}) do
                if type(m) == "table" and m.id == (A.ID_PREFIX or "readinglog_") .. "dashboard" and not m._rl_tweaks then
                    m._rl_tweaks = true
                    local orig_build, orig_menu = m.build, m.getMenuItems
                    local orig_height = m.getHeight
                    m.build = function(w, sctx)
                        if fullOn() then
                            local holder, box = buildFull(orig_build, w, sctx, m.id)
                            if holder then
                                watchBox(box, box._readinglog_ctx)
                                return holder
                            end
                        end
                        local box = orig_build(w, sctx)
                        local ctx = type(box) == "table" and box._readinglog_ctx
                        if ctx then watchBox(box, ctx) end
                        return box
                    end
                    if type(orig_height) == "function" then
                        m.getHeight = function(sctx)
                            if fullOn() then return floor(contentHeight() * 0.8) end
                            return orig_height(sctx)
                        end
                    end
                    if type(orig_menu) == "function" then
                        m.getMenuItems = function(ctx_menu)
                            local items = orig_menu(ctx_menu)
                            if type(items) == "table" then
                                items[#items + 1] = { text = "Reading Log Tweaks", sub_item_table_func = extrasMenu }
                            end
                            return items
                        end
                    end
                end
            end
            return list
        end
    end

    -- Tools > Add-ons > Patches (2-tweaks-menu.lua)
    local TM = package.loaded.tweaks_mods or {}
    package.loaded.tweaks_mods = TM
    TM.entries = TM.entries or {}
    TM.entries.readinglog_tweaks = {
        text = "Reading Log Tweaks",
        order = 400,
        where = "filemanager",
        build = function()
            return { text = "Reading Log Tweaks", sub_item_table_func = extrasMenu }
        end,
    }

    logger.info(TAG, PATCH_VERSION, "on Reading Log", tostring(A.VERSION or "?"),
        C and "(critter on)" or "(no critter)")
end

-- ─── waiting for the kit ─────────────────────────────────────────────────────
-- Reading Log loads its card kit the first time it needs it and keeps it as
-- package.loaded.readinglog_kit. Catch that moment (before any module is
-- handed to Simple UI), or patch it at once if it's already there.

local function guarded(A)
    local ok, err = pcall(apply, A)
    if not ok then warn("failed:", tostring(err)) end
end

if type(package.loaded.readinglog_kit) == "table" then
    guarded(package.loaded.readinglog_kit)
else
    local loaded = package.loaded
    local mt = getmetatable(loaded) or {}
    local prev = mt.__newindex
    mt.__newindex = function(t, k, v)
        if k == "readinglog_kit" and type(v) == "table" then
            mt.__newindex = prev   -- found: KOReader's module list goes back to how it was
            guarded(v)
        end
        if type(prev) == "function" then return prev(t, k, v) end
        if type(prev) == "table" then prev[k] = v return end
        rawset(t, k, v)
    end
    setmetatable(loaded, mt)
end
