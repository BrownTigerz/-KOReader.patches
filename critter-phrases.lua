-- critter-phrases.lua - what the Tiny Critter says
-- Shared by SimpleUI Tweaks (2-simpleui-tweaks.lua) and Reading Log.
-- The Tiny Critter and the voices system are SimpleUI's, by Doctor
-- Hetfield (https://github.com/doctorhetfield-cmd/simpleui.koplugin).
-- Donny, Blu and Donny & Blu's own lines here are TK's.
--
-- Install: koreader/patches/critter-phrases.lua (next to the patch). The
-- name doesn't start with a number, so KOReader doesn't run it as a patch.
-- Don't name it phrases.lua or put it in settings/simpleui/sui_critters/:
-- that's SimpleUI's own custom phrase file, in another format.
--
-- Updates: Patch Backup & Restore > Check for Patch Updates lists this
-- file under Extras (VERSION below). Updating replaces the whole file, so
-- if you've edited it, keep your copy or skip the update.
--
-- Edit freely. Missing or broken, both fall back to their built-in lines
-- (crash.log says which). Keep lines short: about 35 characters fits the
-- bubble on two rows.
--
-- insights[kind]: list of { mood, text = function(d), sub = function(d),
--   by_tier = { grumpy = {...}, radiant = {...} } (optional) }. Data d:
--   tw_milestone  d.days = books finished this year
--   tw_record     d.minutes = minutes read today
--   tw_quickwin   d.title, d.minutes = minutes left in the book
--   tw_momentum   d.days = reading days in a row
--   tw_pace       d.days = books left, d.minutes = days left,
--                 d.years = yearly goal, d.which = "on" / "behind"
--   tw_recovery   d.title (may be nil), d.days = quiet days (may be nil)
--   tw_weekend    d.which = "weekend" / "weekday"
--   tw_recap      last week (Reading Log Tweaks 2.1.0, on the first days
--                 of the week): d.minutes read, d.days read (of 7),
--                 d.years = books finished, d.which = the best day (may be nil)
-- minutes / pages: steps { upto, mood, text = function(n), subs = {...} },
--   lowest first; the last one's upto is math.huge.
-- Moods: neutral happy party sleepy cheer love sad surprised curious
--   grumpy shy playful, and Donny and Blu's extra ones: reading proud
--   hungry cozy sipping dreamy festive spooky (another critter shows the
--   pose they're drawn from: reading = neutral, proud = cheer, hungry =
--   curious, cozy and dreamy = sleepy, sipping and festive = happy,
--   spooky = surprised).
-- A pep-talk sub can be { "line", mood = "hungry" } to show its own mood.
-- voices[critter id][situation]: list of { mood, text = function(f),
--   sub = function(f) } that this critter says in its own voice, alongside
--   SimpleUI 3.0.2's own critters (Suey, Hazel...). The critter id is its
--   folder name (donny, blu, donny-and-blu). Situations: greet_morning
--   greet_afternoon greet_evening greet_night streak streak_paused today
--   books_year book_progress book_waiting goal_day monday weekend anytime.
--   Facts f: f.streak (days), f.books_year, f.today_secs, f.book.title
--   (book_progress / book_waiting only), f.user_name (may be nil).
-- insight_voices[critter id][kind]: that critter's own wording of the
--   insights above (same kinds and data d). Shown about half the time, the
--   shared insight lines the rest (SimpleUI 3.0.2+, and Reading Log Tweaks).
--
-- 1.1.0, for Shortcuts Toolbar Quick Shelf's critter (While Reading, and
-- On Library Toolbar for the menus):
-- reading[situation]: lines about the open book. L(mood, text, sub) with
--   {fields} filled in: {page} {total} {left} (pages left) {left_pg}
--   ("12 pages") {pct} {ch_pg} (pages left in the chapter) {ch_time}
--   {time_left} (book, at your pace) {pph} (pages an hour) {sess_pg}
--   {sess_time} (this sitting, since the device woke) {read_time} (all
--   your time in this book) {title} {chapter} {menu} {name} (the name
--   you gave SimpleUI's critter; lines with it are skipped when there's
--   none). Situations:
--   finished finish_now finish_tonight chapter_last chapter_soon
--   chapter_quick chapter_long fast slow steady marathon big_session
--   just_opened late_night early start quarter halfway three_quarter
--   home_stretch big_book short_book speedy unhurried invested
--   pages_left time_left sweet (any time: just being cute). Pace lines need KOReader's statistics on.
-- reading_voices[critter id][situation]: that critter's own lines, used
--   about half the time when it has some for the situation.
-- shelf[situation], shelf_voices[critter id][situation]: the critter on
--   the Quick Shelf strip, about the shelf. {shelf_n} ("3 books") {next}
--   (a book on the shelf) {next_pct}. It shows under the strip's covers.
--   Situations: one_progress one_tbr (just one book) progress (Books In
--   Progress, 2+) tbr (To Be Read, 2+) many (6+) nearly (a book 80%+ read)
--   empty_progress empty_tbr sweet.
-- menus[key], menu_voices[critter id][key]: what the critter says about
--   the menu you open. menu_words picks the key from the submenu's name;
--   tab_* keys are the tabs themselves; "any" is the fallback.

local function plural(n, one, many) return string.format(n == 1 and one or many, n) end
local function q(s) return "\xE2\x80\x9C" .. tostring(s or "your book") .. "\xE2\x80\x9D" end
local function mins(n) return plural(n or 0, "%d minute", "%d minutes") end
-- "6 h 20 m" / "45 m"
local function hm(m)
    m = math.floor((m or 0) + 0.5)
    if m < 60 then return m .. " m" end
    return string.format("%d h %d m", math.floor(m / 60), m % 60)
end
local function every(days_left, books_left)
    if not books_left or books_left <= 0 then return "you're already there" end
    if not days_left or days_left <= 0 then return "a book whenever" end
    local e = days_left / books_left
    if e >= 1.5 then return string.format("one every %d days", math.floor(e + 0.5)) end
    return string.format("%d a week", math.ceil(7 / e))
end
local function s(text) return function() return text end end
local function readToday(f) return mins(math.floor((f.today_secs or 0) / 60)) end
local function title(f) return q(f.book and f.book.title) end

-- 1.1.0 helpers for the reading and menu lines
local function pg(n) return plural(n or 0, "%d page", "%d pages") end
local function dur(m)
    m = math.floor((m or 0) + 0.5)
    if m < 1 then return "under a minute" end
    if m < 60 then return mins(m) end
    local h, r = math.floor(m / 60), m % 60
    local hs = plural(h, "%d hour", "%d hours")
    if r < 5 then return hs end
    return string.format("%s %d min", hs, r)
end
local FIELDS = {
    page      = function(f) return tostring(f.page or "?") end,
    total     = function(f) return tostring(f.total or "?") end,
    left      = function(f) return tostring(f.left or "?") end,
    left_pg   = function(f) return pg(f.left) end,
    pct       = function(f) return tostring(f.pct or 0) .. "%" end,
    ch_pg     = function(f) return pg(f.ch_left) end,
    ch_time   = function(f) return dur(f.ch_mins) end,
    time_left = function(f) return dur(f.book_mins) end,
    pph       = function(f) return tostring(math.floor((f.pph or 0) + 0.5)) end,
    sess_pg   = function(f) return pg(f.sess_pages) end,
    sess_time = function(f) return dur(f.sess_mins) end,
    read_time = function(f) return dur(f.read_mins) end,
    title     = function(f) return q(f.title) end,
    chapter   = function(f) return q(f.chapter or "this chapter") end,
    menu      = function(f) return f.menu or "this menu" end,
    name      = function(f) return f.user_name or "friend" end,
    shelf_n   = function(f) return plural(f.shelf_n or 0, "%d book", "%d books") end,
    next      = function(f) return q(f.next_title) end,
    next_pct  = function(f) return tostring(f.next_pct or 0) .. "%" end,
}
-- t("Only {left_pg} left!") -> a line function filling in the facts
local function t(text)
    return function(f)
        f = f or {}
        return (string.gsub(text, "{([%w_]+)}", function(k)
            local fn = FIELDS[k]
            return fn and fn(f) or ("{" .. k .. "}")
        end))
    end
end
-- A line with {name} is only used when you've told SimpleUI's critter your
-- name (its settings: Your name); one with {menu} only when the menu has a
-- name to show.
local function L(mood, text, sub)
    local all = text .. (sub or "")
    local named = string.find(all, "{name}", 1, true) ~= nil
    local menu = string.find(all, "{menu}", 1, true) ~= nil
    return { mood = mood, text = t(text), sub = sub and t(sub) or nil,
             needs_name = named or nil, needs_menu = menu or nil }
end

return {
    VERSION = "1.2.0",
    version = 1,

    insights = {
        tw_milestone = {
            { mood = "proud", text = function(d) return string.format("That's book %d this year!", d.days) end,
              sub = s("Your shelf is looking lighter."),
              by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("%d books. Fine, I'm impressed.", d.days) end },
                          radiant = { mood = "party", text = function(d) return string.format("%d books! You're unstoppable!", d.days) end } } },
            { mood = "love", text = function(d) return string.format("%d books finished this year.", d.days) end,
              sub = s("It's going on the imaginary fridge.") },
            { mood = "cheer", text = function(d) return string.format("Book %d: done.", d.days) end,
              sub = s("Which world is next?") },
            { mood = "playful", text = function(d) return string.format("%d books? Your shelf is nervous.", d.days) end,
              sub = s("As it should be.") },
            { mood = "surprised", text = function(d) return string.format("Wait, book %d already?!", d.days) end,
              sub = s("I was busy being cute. You read.") },
            { mood = "playful", text = function(d) return string.format("%d books this year. Show-off.", d.days) end,
              sub = s("Fine. I'm impressed."),
              by_tier = { grumpy = { mood = "grumpy", text = function(d) return string.format("%d books. Hmph. Not bad.", d.days) end } } },
            { mood = "party", text = function(d) return string.format("%d books! Milestone!", d.days) end,
              sub = s("Tiny critter. Big applause.") },
            { mood = "happy", text = function(d) return string.format("Book %d is read. Done deal.", d.days) end,
              sub = s("Please do a small victory wiggle.") },
        },

        tw_record = {
            { mood = "surprised", text = s("Your best reading day this month!"),
              sub = function(d) return mins(d.minutes) .. " and counting." end },
            { mood = "party", text = function(d) return mins(d.minutes) .. " today. A new best." end,
              sub = s("The book really had you.") },
            { mood = "cheer", text = s("No day this month beats today."),
              sub = function(d) return mins(d.minutes) .. " so far." end },
            { mood = "playful", text = s("New monthly best? Casual flex."),
              sub = function(d) return mins(d.minutes) .. " today. I noticed." end },
            { mood = "party", text = s("Record day. Book 1, phone 0."),
              sub = function(d) return mins(d.minutes) .. " on the clock." end },
            { mood = "surprised", text = s("Okay, reader. I see you."),
              sub = function(d) return mins(d.minutes) .. ". Best this month." end },
            { mood = "proud", text = s("Today's the one to beat now."),
              sub = s("No pressure. Just a nice win.") },
        },

        tw_quickwin = {
            { mood = "cheer", text = function(d) return string.format("Only %d min left in %s.", d.minutes, q(d.title)) end,
              sub = s("Got a little time?") },
            { mood = "playful", text = function(d) return string.format("%s: about %d min to go.", q(d.title), d.minutes) end,
              sub = s("The finish line is right there.") },
            { mood = "reading", text = function(d) return string.format("Got %d minutes?", d.minutes) end,
              sub = function(d) return "That's all " .. q(d.title) .. " needs." end },
            { mood = "party", text = function(d) return string.format("Final stretch: %d minutes!", d.minutes) end,
              sub = function(d) return q(d.title) .. " is nearly yours." end },
            { mood = "playful", text = s("Not saying one more chapter..."),
              sub = function(d) return string.format("...but %d minutes. Just saying.", d.minutes) end },
            { mood = "curious", text = function(d) return string.format("What happens in the last %d min?", d.minutes) end,
              sub = function(d) return q(d.title) .. " is waiting." end },
            { mood = "surprised", text = function(d) return "You're nearly done with " .. q(d.title) .. "!" end,
              sub = s("I'm not emotionally ready.") },
        },

        tw_momentum = {
            { mood = "cheer", text = function(d) return plural(d.days, "%d reading day in a row.", "%d reading days in a row.") end,
              sub = s("Back in the habit.") },
            { mood = "happy", text = function(d) return string.format("Back on a roll: %d days.", d.days) end,
              sub = s("The habit was hiding, not gone.") },
            { mood = "playful", text = function(d) return string.format("%d days running. Nice streak.", d.days) end,
              sub = s("I won't make a fuss. (I lied.)") },
            { mood = "party", text = function(d) return string.format("The streak lives: %d days!", d.days) end,
              sub = s("Tiny fanfare. Very tiny.") },
            { mood = "playful", text = function(d) return string.format("%d days. Should I start a fan club?", d.days) end,
              sub = s("Members so far: me.") },
            { mood = "cheer", text = s("The comeback tour continues."),
              sub = function(d) return string.format("%d days running. Encore optional.", d.days) end },
        },

        tw_pace = {
            { mood = "curious",
              text = function(d)
                  if d.which == "on" then return "You're right on pace." end
                  return string.format("%s to go, %d days left.", plural(d.days, "%d book", "%d books"), d.minutes)
              end,
              sub = function(d)
                  if d.which == "on" then return string.format("%d to go: about %s.", d.days, every(d.minutes, d.days)) end
                  return "About " .. every(d.minutes, d.days) .. " catches you up."
              end },
            { mood = "playful",
              text = function(d)
                  return d.which == "on" and string.format("On track for %d books.", d.years)
                      or string.format("Your %d-book goal is still on.", d.years)
              end,
              sub = function(d) return "Keep it to " .. every(d.minutes, d.days) .. "." end },
            { mood = "happy",
              text = function(d) return d.which == "on" and "Your goal is nicely in reach." or "A bit behind isn't out." end,
              sub = function(d) return plural(d.days, "%d book left. One at a time.", "%d books left. One at a time.") end },
            { mood = "playful",
              text = function(d) return d.which == "on" and "Keeping the goal in sight, I see." or "The goal is side-eyeing you. Gently." end,
              sub = function(d) return "About " .. every(d.minutes, d.days) .. " does it." end },
            { mood = "love",
              text = function(d) return d.which == "on" and "A year of stories." or "No need to save the year today." end,
              sub = s("Slow and steady is allowed.") },
            { mood = "sleepy",
              text = function(d) return d.which == "on" and "All good with the plan." or "There's time yet. Breathe." end,
              sub = function(d) return string.format("%s, %d days.", plural(d.days, "%d book", "%d books"), d.minutes) end },
        },

        tw_recovery = {
            { mood = "shy", text = function(d) return d.title and ("It's been a while since " .. q(d.title) .. ".") or "It's been a few quiet days." end,
              sub = s("Fancy a few pages?"),
              by_tier = { grumpy = { mood = "grumpy",
                  text = function(d) return d.days and plural(d.days, "%d day. Not that I'm counting.", "%d days. Not that I'm counting.") or "Not that I'm counting." end,
                  sub = s("A page would cheer me up.") } } },
            { mood = "curious", text = function(d) return d.title and (q(d.title) .. " misses you.") or "Your books miss you." end,
              sub = s("Even ten minutes counts.") },
            { mood = "cozy", text = s("Ready when you are."),
              sub = function(d) return d.title and (q(d.title) .. " is right where you left it.") or "No rush." end },
            { mood = "love", text = s("Hello again, reader."),
              sub = s("No guilt. Just story time?") },
            { mood = "cheer", text = s("A break isn't a broken habit."),
              sub = s("One sentence starts it again.") },
            { mood = "playful", text = s("I didn't eat your bookmark."),
              sub = s("I thought about it, though.") },
            { mood = "shy", text = s("Psst. Your book is still here."),
              sub = s("Just thought you'd like to know.") },
        },

        tw_weekend = {
            { mood = "curious", text = function(d) return d.which == "weekend" and "You read more on weekends." or "You read more on weekdays." end,
              sub = function(d) return d.which == "weekend" and "Got a book lined up?" or "A fresh week, a fresh chapter." end },
            { mood = "playful", text = function(d) return d.which == "weekend" and "Weekend reader, I see." or "Weekdays are your reading days." end,
              sub = function(d) return d.which == "weekend" and "Your best time is nearly here." or "Chapters between the busy bits." end },
            { mood = "surprised", text = function(d) return d.which == "weekend" and "Weekends: your natural habitat." or "A weekday bookworm! I approve." end,
              sub = s("Your reading has a favourite time.") },
            { mood = "playful", text = function(d) return d.which == "weekend" and "Saturday-you loves books." or "Weekday-you sneaks in chapters." end,
              sub = s("A solid pattern.") },
            { mood = "happy", text = function(d) return d.which == "weekend" and "Weekend reading suits you." or "Weekday reading suits you." end,
              sub = s("Your stats don't lie.") },
        },
    },

    -- "N minutes read today" (the number line stays plain, the sub has the fun)
    minutes = {
        { upto = 4, mood = "reading",
          text = function(m) return plural(m, "%d minute read today.", "%d minutes read today.") end,
          subs = { "A start is a start.", "Tiny reads still count.", "The first page is the hardest.",
                   "A little story snack.", "You showed up. That counts.", "Five more and you're warmed up.",
                   "The story's open.", "Even a nibble counts.", "Consider it a warm-up." } },
        { upto = 14, mood = "happy",
          text = function(m) return string.format("%d minutes read today.", m) end,
          subs = { "Warming up nicely.", "The story's getting going.", "Ten more? Just saying.",
                   "A decent little escape.", "Your brain likes this.", "We're getting somewhere.",
                   "The plot thickens. Probably.", "Past the hello stage now.", "Your reading nook approves." } },
        { upto = 29, mood = "happy",
          text = function(m) return string.format("%d minutes read today!", m) end,
          subs = { "Now that's a groove.", "Proper reading time.", "Half an hour is right there.",
                   "Came for a page, stayed for plot.", "The world can wait. Briefly.", "Plot's moving now.",
                   "The book made its case.", "This is how one page gets you.", "Properly bookish." } },
        { upto = 59, mood = "cheer",
          text = function(m) return string.format("%d minutes read today!", m) end,
          subs = { "A real session. Nice.", "Look at you go.", "The hour mark is waving.",
                   "Reading mode: on.", "You got comfy, didn't you?", "Your bookmark's had a day.",
                   "The plot has you. I can tell.", "A fine use of quiet time.", "Trophy polished. Imaginary." } },
        { upto = 89, mood = "party",
          text = function(m) return string.format("%d minutes read today!", m) end,
          subs = { { "An hour plus! Snack break?", mood = "hungry" }, "That's a serious read.", "The book is winning today.",
                   "Off on an adventure, eh?", "A proper reading feast.", { "Your tea went cold, didn't it?", mood = "cozy" },
                   "Bookmark promoted to full-time.", "Okay, bookworm. I see you.", "I'm impressed. And neglected." } },
        { upto = 119, mood = "party",
          text = function(m) return string.format("%.1f hours read today!", m / 60) end,
          subs = { { "Marathon mode.", mood = "proud" }, "Did you even blink?", "Okay, bookworm.",
                   "A whole expedition, seated.", "The plot has you in a headlock.", "Deep in the story now.",
                   "Bookmark wants overtime pay.", "Practically co-authors now.", "Stretch? The book will wait." } },
        { upto = math.huge, mood = "party",
          text = function(m) return string.format("%.1f hours read today!", m / 60) end,
          subs = { { "Legendary bookworm.", mood = "proud" }, "The plot owns you now.", "Unlocked: what time is it?",
                   "A world tour in page form.", "First-name basis with this story.", { "Water exists. Just a reminder.", mood = "sipping" },
                   "The chair would like a word.", "Save some wonder for tomorrow?", "I applaud. Tiny paws, big clap." } },
    },

    -- "N pages turned today"
    pages = {
        { upto = 4, mood = "curious",
          text = function(p) return plural(p, "%d page turned today.", "%d pages turned today.") end,
          subs = { "Every page counts.", "A few more? The story won't mind.", "One page is still a page.",
                   "A tiny paper trail.", "The plot's moving.", "A tiny turn of events." } },
        { upto = 19, mood = "happy",
          text = function(p) return string.format("%d pages turned today!", p) end,
          subs = { "One page at a time.", "Chapter's end is near, maybe.", "The story is picking up speed.",
                   "Finding the rhythm.", "Your bookmark earns its keep.", "Pages are turning." } },
        { upto = 49, mood = "cheer",
          text = function(p) return string.format("%d pages turned today!", p) end,
          subs = { "Turning pages like a pro.", "That's a chunk of book.", "The plot is going places.",
                   "Travelled far without moving.", "Pages: 0. Curiosity: 1.", "A nice dent in the book." } },
        { upto = 99, mood = "party",
          text = function(p) return string.format("%d pages turned today!", p) end,
          subs = { "That's a chapter or three.", "Your thumb needs a rest.", "Not a skim. A visit.",
                   "The page counter is blushing.", "A hefty helping of story.", "Bookmark is a manager now." } },
        { upto = math.huge, mood = "party",
          text = function(p) return string.format("%d pages today!", p) end,
          subs = { "A chapter or three. Or ten.", "Page-turning legend.", "The bookmark needs a holiday.",
                   { "Smugness: fully earned.", mood = "proud" }, "The page counter needs a nap.", "Be kind to your eyes, too." } },
    },

    -- The insights in their own voice (same data d as the insights above).
    insight_voices = {
        donny = {
            tw_milestone = {
                { mood = "proud", text = function(d) return string.format("Book %d this year!", d.days) end,
                  sub = s("I'll nap on it in your honour.") },
                { mood = "party", text = function(d) return string.format("%d books! Treats all round.", d.days) end,
                  sub = s("Mostly for me.") },
                { mood = "love", text = function(d) return string.format("That's %d books this year.", d.days) end,
                  sub = s("Proud of you. Also hungry.") },
            },
            tw_record = {
                { mood = "surprised", text = s("Best reading day this month!"),
                  sub = function(d) return mins(d.minutes) .. ". I didn't move once." end },
                { mood = "proud", text = s("New record this month!"),
                  sub = function(d) return mins(d.minutes) .. " of lap time." end },
                { mood = "cozy", text = s("Longest read this month."), sub = s("Best lap day ever.") },
            },
            tw_quickwin = {
                { mood = "curious", text = function(d) return mins(d.minutes) .. " to the end!" end,
                  sub = function(d) return "Finish " .. q(d.title) .. "?" end },
                { mood = "hungry", text = s("So close to the end!"),
                  sub = function(d) return mins(d.minutes) .. " left. Then dinner." end },
                { mood = "playful", text = s("Finish line ahead!"),
                  sub = function(d) return mins(d.minutes) .. " left. I'll wait." end },
            },
            tw_momentum = {
                { mood = "happy", text = function(d) return string.format("%d days in a row again!", d.days) end,
                  sub = s("Back in our routine.") },
                { mood = "cozy", text = function(d) return string.format("%d reading days running.", d.days) end,
                  sub = s("Same lap, same time. Love it.") },
                { mood = "cheer", text = s("You're on a roll again."),
                  sub = function(d) return plural(d.days, "%d day. Purr.", "%d days. Purr.") end },
            },
            tw_pace = {
                { mood = "proud",
                  text = function(d) return d.which == "on" and string.format("On pace for %d books.", d.years)
                      or plural(d.days, "%d book to go.", "%d books to go.") end,
                  sub = function(d) return d.which == "on" and "Snack break earned." or "About " .. every(d.minutes, d.days) .. ". Easy." end },
                { mood = "happy",
                  text = function(d) return d.which == "on" and "Right on track for the year." or "A bit behind. No worries." end,
                  sub = function(d) return d.which == "on" and "I'll celebrate with a nap." or every(d.minutes, d.days) .. " gets us there." end },
                { mood = "cheer",
                  text = function(d) return d.which == "on" and "Your goal's looking good." or "Goal check: we can do it." end,
                  sub = function(d) return plural(d.days, "%d book left this year.", "%d books left this year.") end },
            },
            tw_recovery = {
                { mood = "love", text = s("You're back! I missed you."),
                  sub = function(d) return d.title and (q(d.title) .. " did too.") or "So did the books." end },
                { mood = "happy", text = s("Reading again. Good."),
                  sub = function(d) return d.days and plural(d.days, "%d quiet day. Over now.", "%d quiet days. Over now.") or "Quiet spell's over." end },
                { mood = "cozy", text = s("Welcome back to the lap."), sub = s("I kept it warm.") },
            },
            tw_weekend = {
                { mood = "cozy", text = function(d) return d.which == "weekend" and "Weekends are your reading days." or "You read more on weekdays." end,
                  sub = function(d) return d.which == "weekend" and "Couch, book, cat. Classic." or "Weekends are for naps. Agreed." end },
                { mood = "sleepy", text = function(d) return d.which == "weekend" and "Saturday's your big read." or "Weekdays win. Weird." end,
                  sub = function(d) return d.which == "weekend" and "I'll save your spot." or "Saturdays are nap days, I get it." end },
            },
            tw_recap = {
                { mood = "cozy", text = function(d) return "Last week: " .. hm(d.minutes) .. "." end,
                  sub = function(d) return d.which and (d.which .. " was the coziest.") or "Lots of lap time." end },
                { mood = "hungry", text = function(d) return plural(d.days, "%d day", "%d days") .. " of reading last week." end,
                  sub = function(d) return (d.years or 0) > 0 and (plural(d.years, "%d book", "%d books") .. " done. Treats?") or "Snack for every one?" end },
                { mood = "sleepy", text = function(d) return hm(d.minutes) .. " last week. Yawn." end,
                  sub = function(d) return d.which and ("I napped through " .. d.which .. ".") or "I napped through it." end },
            },
        },
        blu = {
            tw_milestone = {
                { mood = "proud", text = function(d) return string.format("Book %d. I picked most of them.", d.days) end,
                  sub = s("You're welcome.") },
                { mood = "party", text = function(d) return string.format("%d books! Finally!", d.days) end,
                  sub = s("I've been saying it for weeks.") },
                { mood = "cheer", text = function(d) return string.format("%d books this year. Bravo.", d.days) end,
                  sub = s("Now read one to me.") },
            },
            tw_record = {
                { mood = "surprised", text = s("Best day this month!"),
                  sub = function(d) return mins(d.minutes) .. ". Who are you?" end },
                { mood = "proud", text = s("Monthly record. As I predicted."),
                  sub = function(d) return mins(d.minutes) .. " of reading." end },
                { mood = "grumpy", text = s("Your longest read this month."), sub = s("And not one pet. Noted.") },
            },
            tw_quickwin = {
                { mood = "curious", text = function(d) return mins(d.minutes) .. " left. Finish it." end,
                  sub = function(d) return "I need to know how " .. q(d.title) .. " ends." end },
                { mood = "playful", text = s("Almost the end! Go!"),
                  sub = function(d) return mins(d.minutes) .. ". I'll narrate." end },
                { mood = "grumpy", text = s("So close. Don't stop now."),
                  sub = function(d) return mins(d.minutes) .. " left. I'm watching." end },
            },
            tw_momentum = {
                { mood = "proud", text = function(d) return string.format("%d days in a row. Good.", d.days) end,
                  sub = s("As I demanded.") },
                { mood = "cheer", text = s("Back on a roll!"),
                  sub = function(d) return plural(d.days, "%d day. Keep going.", "%d days. Keep going.") end },
                { mood = "playful", text = function(d) return string.format("%d days running!", d.days) end,
                  sub = s("I trained you well.") },
            },
            tw_pace = {
                { mood = "proud",
                  text = function(d) return d.which == "on" and string.format("On pace for %d. Acceptable.", d.years)
                      or plural(d.days, "%d book behind plan.", "%d books to go.") end,
                  sub = function(d) return d.which == "on" and "Don't get lazy." or "About " .. every(d.minutes, d.days) .. ". Chop chop." end },
                { mood = "cheer",
                  text = function(d) return d.which == "on" and "Right on track. My plan works." or "Behind? We'll fix it." end,
                  sub = function(d) return d.which == "on" and "Pets as a reward." or every(d.minutes, d.days) .. ". I'll supervise." end },
                { mood = "happy",
                  text = function(d) return d.which == "on" and "Goal pace: perfect." or "The goal! It's slipping!" end,
                  sub = function(d) return plural(d.days, "%d book left.", "%d books left.") end },
            },
            tw_recovery = {
                { mood = "grumpy", text = s("Oh, NOW you read."),
                  sub = function(d) return d.days and plural(d.days, "%d day. I counted.", "%d days. I counted.") or "I counted the days." end },
                { mood = "love", text = s("You're back. I wasn't worried."),
                  sub = function(d) return d.title and (q(d.title) .. " was.") or "The books were." end },
                { mood = "happy", text = s("Reading again! Finally!"), sub = s("Never do that to me again.") },
            },
            tw_weekend = {
                { mood = "proud", text = function(d) return d.which == "weekend" and "Weekends: big reading days." or "Weekdays: your reading days." end,
                  sub = function(d) return d.which == "weekend" and "And pet-me days." or "Weekends are for me, then." end },
                { mood = "curious", text = function(d) return d.which == "weekend" and "You read more on weekends." or "You read less on weekends." end,
                  sub = function(d) return d.which == "weekend" and "Saturday's mine too, though." or "Suspicious. Where do you go?" end },
            },
            tw_recap = {
                { mood = "proud", text = function(d) return "Weekly report: " .. hm(d.minutes) .. "." end,
                  sub = function(d) return d.which and ("Best day: " .. d.which .. ". Approved.") or "Approved. Barely." end },
                { mood = "grumpy", text = function(d) return plural(d.days, "%d day", "%d days") .. " of 7. Hmm." end,
                  sub = function(d) return d.days >= 6 and "Fine. Impressive." or "I expect more this week." end },
                { mood = "playful", text = function(d) return (d.years or 0) > 0 and (plural(d.years, "%d book", "%d books") .. " last week!") or (hm(d.minutes) .. " last week.") end,
                  sub = function() return "My supervision works." end },
            },
        },
        ["donny-and-blu"] = {
            tw_milestone = {
                { mood = "party", text = function(d) return string.format("Book %d! Two cats cheering.", d.days) end,
                  sub = s("Blu loudly. Donny from bed.") },
                { mood = "proud", text = function(d) return string.format("%d books this year!", d.days) end,
                  sub = s("We napped on every one.") },
            },
            tw_record = {
                { mood = "surprised", text = s("Best day this month!"),
                  sub = function(d) return mins(d.minutes) .. ". Blu timed it." end },
                { mood = "cozy", text = s("Monthly record!"), sub = s("Two cats, one long lap session.") },
            },
            tw_quickwin = {
                { mood = "curious", text = function(d) return mins(d.minutes) .. " to the end!" end,
                  sub = s("Blu wants to know. Donny too.") },
                { mood = "playful", text = s("Nearly done! Go go go!"),
                  sub = function(d) return mins(d.minutes) .. ". We'll wait." end },
            },
            tw_momentum = {
                { mood = "cheer", text = function(d) return string.format("%d days in a row!", d.days) end,
                  sub = s("Donny purrs. Blu brags.") },
                { mood = "happy", text = s("Back in the reading groove!"),
                  sub = function(d) return plural(d.days, "%d day so far.", "%d days so far.") end },
            },
            tw_pace = {
                { mood = "proud",
                  text = function(d) return d.which == "on" and string.format("On pace for %d books!", d.years)
                      or plural(d.days, "%d book to go.", "%d books to go.") end,
                  sub = function(d) return d.which == "on" and "Blu planned it. Donny napped." or "About " .. every(d.minutes, d.days) .. ". Together." end },
                { mood = "happy",
                  text = function(d) return d.which == "on" and "Right on track!" or "A little behind. Don't worry." end,
                  sub = function(d) return plural(d.days, "%d book left this year.", "%d books left this year.") end },
            },
            tw_recovery = {
                { mood = "love", text = s("You're back! Both cats missed you."), sub = s("Blu won't admit it.") },
                { mood = "happy", text = s("Reading again!"),
                  sub = function(d) return d.days and plural(d.days, "%d quiet day. Over now.", "%d quiet days. Over now.") or "Laps are open again." end },
            },
            tw_weekend = {
                { mood = "cozy", text = function(d) return d.which == "weekend" and "Weekends are reading days." or "Weekdays are reading days." end,
                  sub = function(d) return d.which == "weekend" and "Two cats approve." or "Weekends: nap pile. Got it." end },
                { mood = "playful", text = function(d) return d.which == "weekend" and "You read more on weekends." or "You read less on weekends." end,
                  sub = function(d) return d.which == "weekend" and "More lap time for us." or "Blu thinks you're hiding." end },
            },
            tw_recap = {
                { mood = "happy", text = function(d) return "Last week: " .. hm(d.minutes) .. "." end,
                  sub = function(d) return d.which and ("Both of us liked " .. d.which .. ".") or "We kept count. Blu did." end },
                { mood = "playful", text = function(d) return plural(d.days, "%d day", "%d days") .. " with a book." end,
                  sub = function() return "Donny slept. Blu supervised." end },
            },
        },
    },

    -- In their own voice: Donny (tabby: laid-back, food first), Blu (Siamese:
    -- loud, bossy, dramatic) and the two together. About a week before a
    -- line comes round again: 7 greetings per time of day, 5 for streak,
    -- today and any time, 3 for the rest. Placeholders as above.
    voices = {
        donny = {
            greet_morning = {
                { mood = "hungry", text = s("Morning! Breakfast first?"),
                  sub = s("Then a chapter. Deal.") },
                { mood = "cozy", text = s("Morning. Bed's still warm."),
                  sub = s("Read here a bit longer?") },
                { mood = "sleepy", text = s("Morning... already?"),
                  sub = s("Read to me while I wake up.") },
                { mood = "happy", text = s("Good morning, favourite human."),
                  sub = s("Coffee for you, book for us.") },
                { mood = "sipping", text = s("Morning! Coffee's on."),
                  sub = s("I'll take the warm spot.") },
                { mood = "playful", text = s("Morning zoomies: done."),
                  sub = s("Now a quiet chapter.") },
                { mood = "hungry", text = s("Food bowl's empty. Just saying."),
                  sub = s("Feed me, then read a page.") },
            },
            greet_afternoon = {
                { mood = "happy", text = s("Afternoon! Sun spot's free."),
                  sub = s("Bring the book.") },
                { mood = "sleepy", text = s("Nap or a chapter?"),
                  sub = s("Why not both?") },
                { mood = "cozy", text = s("Afternoon. Couch is warm."),
                  sub = s("I checked. Twice.") },
                { mood = "curious", text = s("Where did we leave off?"),
                  sub = s("I fell asleep on page two.") },
                { mood = "hungry", text = s("Is it snack o'clock?"),
                  sub = s("Read until it is.") },
                { mood = "reading", text = s("Lazy afternoon reading?"),
                  sub = s("My favourite kind.") },
                { mood = "dreamy", text = s("Sunbeam, purr, good story."),
                  sub = s("Afternoon perfection.") },
            },
            greet_evening = {
                { mood = "cozy", text = s("Evening. Blanket's ready."),
                  sub = s("I saved you a spot.") },
                { mood = "reading", text = s("Evening read? I'm in."),
                  sub = s("I'll hold the page down.") },
                { mood = "happy", text = s("Evening! Dinner was great."),
                  sub = s("Mine was, anyway.") },
                { mood = "love", text = s("Evening. Lap available?"),
                  sub = s("Asking for me.") },
                { mood = "sipping", text = s("Tea and a book tonight?"),
                  sub = s("I'll guard the mug.") },
                { mood = "dreamy", text = s("Lamp on, world off."),
                  sub = s("Just us and the story.") },
                { mood = "sleepy", text = s("Evening. I'm half asleep."),
                  sub = s("Read the good part out loud.") },
            },
            greet_night = {
                { mood = "sleepy", text = s("Late one? I'll keep you company."),
                  sub = s("Purring on low volume.") },
                { mood = "dreamy", text = s("Night. Just one more page?"),
                  sub = s("I won't tell.") },
                { mood = "cozy", text = s("Night reading. My favourite."),
                  sub = s("You hold the book. I hold you.") },
                { mood = "sleepy", text = s("It's late. I'm a loaf now."),
                  sub = s("Read me to sleep.") },
                { mood = "curious", text = s("Midnight snack and a chapter?"),
                  sub = s("I'll do the snack part.") },
                { mood = "dreamy", text = s("Quiet house, soft light."),
                  sub = s("Perfect for a story.") },
                { mood = "love", text = s("Night. Stay a while."),
                  sub = s("The book's not going anywhere.") },
            },
            streak = {
                { mood = "proud", text = function(f) return tostring(f.streak) .. " days straight!" end,
                  sub = s("I'd bring you a mouse for that.") },
                { mood = "happy", text = s("Streak's still going."),
                  sub = s("Same time, same lap, tomorrow?") },
                { mood = "cheer", text = function(f) return tostring(f.streak) .. " days of reading!" end,
                  sub = s("That deserves a treat. For me.") },
                { mood = "proud", text = function(f) return tostring(f.streak) .. " days. It's a habit now." end,
                  sub = s("Like my dinner.") },
                { mood = "love", text = s("Every day, a page. Love it."),
                  sub = function(f) return tostring(f.streak) .. " days and counting." end },
            },
            streak_paused = {
                { mood = "sad", text = s("Streak's napping. So am I."),
                  sub = s("Let's both wake up with a page.") },
                { mood = "cozy", text = s("No streak? No problem."),
                  sub = s("One page starts a new one.") },
                { mood = "curious", text = s("Did the streak run off?"),
                  sub = s("Let's catch a new one.") },
            },
            today = {
                { mood = "reading", text = function(f) return readToday(f) .. " today!" end,
                  sub = s("I helped. I sat on the book.") },
                { mood = "cheer", text = s("You read today. Good human."),
                  sub = s("Treats are in order.") },
                { mood = "happy", text = function(f) return readToday(f) .. " read today." end,
                  sub = s("Time well spent. Like naps.") },
                { mood = "proud", text = function(f) return readToday(f) .. " today! I'm proud." end,
                  sub = s("And a little hungry.") },
                { mood = "love", text = s("You read today."),
                  sub = s("That's my favourite human.") },
            },
            books_year = {
                { mood = "proud", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year!" end,
                  sub = s("I sat on every single one.") },
                { mood = "happy", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " so far this year." end,
                  sub = s("That's a lot of laps.") },
                { mood = "cheer", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year. Wow." end,
                  sub = s("More books, more naps on them.") },
            },
            book_progress = {
                { mood = "curious", text = function(f) return "How's " .. title(f) .. "?" end,
                  sub = s("Any cats in it?") },
                { mood = "reading", text = function(f) return "Back to " .. title(f) .. "?" end,
                  sub = s("I'll lie on the left page.") },
                { mood = "happy", text = function(f) return title(f) .. ", eh? Good pick." end,
                  sub = s("I like the cover. Smells nice.") },
            },
            book_waiting = {
                { mood = "sad", text = function(f) return title(f) .. " misses you." end,
                  sub = s("I kept it warm. By sitting on it.") },
                { mood = "curious", text = function(f) return "Remember " .. title(f) .. "?" end,
                  sub = s("It's waiting. Like me at dinner.") },
                { mood = "cozy", text = function(f) return title(f) .. " is still here." end,
                  sub = s("Pick it up? I'll make room.") },
            },
            goal_day = {
                { mood = "party", text = s("Goal done! Snack time?"),
                  sub = s("You earned it. So did I.") },
                { mood = "proud", text = s("Daily goal: done."),
                  sub = s("Now a lap break. Mandatory.") },
                { mood = "cheer", text = s("Goal reached!"),
                  sub = s("Celebrating with a big stretch.") },
            },
            monday = {
                { mood = "grumpy", text = s("Monday. Let's hide in a book."),
                  sub = s("Nobody looks there.") },
                { mood = "sleepy", text = s("Monday. I'm staying in bed."),
                  sub = s("Read to me from there?") },
                { mood = "cozy", text = s("Monday blues? Book cure."),
                  sub = s("Plus one purring cat.") },
            },
            weekend = {
                { mood = "cozy", text = s("Weekend! Couch, book, cat."),
                  sub = s("That's the whole plan.") },
                { mood = "happy", text = s("No alarms this weekend."),
                  sub = s("Just chapters and naps.") },
                { mood = "hungry", text = s("Weekend brunch and a book?"),
                  sub = s("I'll have the bacon.") },
            },
            anytime = {
                { mood = "hungry", text = s("Is it dinner yet?"),
                  sub = s("Read till it is.") },
                { mood = "love", text = s("You, me and a book."),
                  sub = s("Best kind of day.") },
                { mood = "sipping", text = s("Tea for you, water for me."),
                  sub = s("Now we read.") },
                { mood = "playful", text = s("I knocked your bookmark off."),
                  sub = s("Sorry. Not sorry.") },
                { mood = "cozy", text = s("Find a comfy spot."),
                  sub = s("I'll find you.") },
            },
        },
        blu = {
            greet_morning = {
                { mood = "grumpy", text = s("MORNING. You overslept."),
                  sub = s("I've been yelling for ages.") },
                { mood = "playful", text = s("Up! Books won't read themselves."),
                  sub = s("I checked.") },
                { mood = "grumpy", text = s("Breakfast. Then reading. Now."),
                  sub = s("I'm not asking.") },
                { mood = "proud", text = s("Morning. I've been up for hours."),
                  sub = s("Supervising.") },
                { mood = "sipping", text = s("Morning. Coffee's not for you?"),
                  sub = s("Fine. Read while it cools.") },
                { mood = "curious", text = s("Morning! What's the plan?"),
                  sub = s("Reading. The plan is reading.") },
                { mood = "surprised", text = s("You're awake! Finally!"),
                  sub = s("The book and I were worried.") },
            },
            greet_afternoon = {
                { mood = "curious", text = s("Afternoon. What are we reading?"),
                  sub = s("Tell me everything.") },
                { mood = "sipping", text = s("Tea and a chapter?"),
                  sub = s("You make the tea.") },
                { mood = "grumpy", text = s("Afternoon. You ignored me."),
                  sub = s("Read to me. Make it up to me.") },
                { mood = "playful", text = s("Afternoon chapter? I'll narrate."),
                  sub = s("Loudly. With feeling.") },
                { mood = "proud", text = s("This sunbeam is mine."),
                  sub = s("You may read beside it.") },
                { mood = "happy", text = s("Afternoon! Perfect reading light."),
                  sub = s("I arranged it.") },
                { mood = "dreamy", text = s("A slow afternoon. Finally."),
                  sub = s("Read. I'll judge quietly.") },
            },
            greet_evening = {
                { mood = "cozy", text = s("Evening. Lap. Book. Now."),
                  sub = s("I make the rules.") },
                { mood = "dreamy", text = s("Evening. Lights low, please."),
                  sub = s("Ambience matters.") },
                { mood = "grumpy", text = s("Dinner was late again."),
                  sub = s("Read to me as an apology.") },
                { mood = "love", text = s("Evening. I missed you."),
                  sub = s("Don't make it weird. Read.") },
                { mood = "playful", text = s("Evening! Story time?"),
                  sub = s("I pick the voices.") },
                { mood = "sipping", text = s("Evening tea? I'll inspect it."),
                  sub = s("Then we read.") },
                { mood = "curious", text = s("What happens next tonight?"),
                  sub = s("I can't wait. Literally.") },
            },
            greet_night = {
                { mood = "sleepy", text = s("Night reading? I'll supervise."),
                  sub = s("Loudly.") },
                { mood = "dreamy", text = s("It's late. One more chapter."),
                  sub = s("Then bed. I mean it.") },
                { mood = "grumpy", text = s("It's past midnight."),
                  sub = s("...Fine. One more page.") },
                { mood = "cozy", text = s("Night. Blanket fort for two."),
                  sub = s("I claimed the good side.") },
                { mood = "curious", text = s("Can't sleep either?"),
                  sub = s("Read me the scary part.") },
                { mood = "love", text = s("Late night, just us."),
                  sub = s("Don't tell Donny.") },
                { mood = "sleepy", text = s("My eyes are closing."),
                  sub = s("Keep reading. I'm listening.") },
            },
            streak = {
                { mood = "proud", text = function(f) return tostring(f.streak) .. " days. I'm impressed." end,
                  sub = s("Don't let it go to your head.") },
                { mood = "cheer", text = s("Streak intact. As I demanded."),
                  sub = s("Good. Carry on.") },
                { mood = "proud", text = function(f) return tostring(f.streak) .. " days in a row." end,
                  sub = s("I take full credit.") },
                { mood = "playful", text = function(f) return tostring(f.streak) .. " days! Look at you." end,
                  sub = s("I trained you well.") },
                { mood = "happy", text = s("Another day, another page."),
                  sub = function(f) return tostring(f.streak) .. " days. Keep it up." end },
            },
            streak_paused = {
                { mood = "grumpy", text = s("You broke the streak."),
                  sub = s("I'm telling Donny.") },
                { mood = "sad", text = s("The streak is gone. GONE."),
                  sub = s("Read a page. Fix this.") },
                { mood = "curious", text = s("No reading yesterday?"),
                  sub = s("I noticed. I notice everything.") },
            },
            today = {
                { mood = "proud", text = function(f) return readToday(f) .. " today. Acceptable." end,
                  sub = s("Barely. Read more.") },
                { mood = "playful", text = s("You read today!"),
                  sub = s("I narrated. You're welcome.") },
                { mood = "cheer", text = function(f) return readToday(f) .. " today! Bravo." end,
                  sub = s("I'll allow a short break.") },
                { mood = "curious", text = function(f) return readToday(f) .. " today. And?" end,
                  sub = s("What happened? Tell me.") },
                { mood = "happy", text = s("Reading done today."),
                  sub = s("Now pet me. Fair's fair.") },
            },
            books_year = {
                { mood = "cheer", text = function(f) return plural(f.books_year, "%d book", "%d books") .. "! I approve." end,
                  sub = s("Next one: about Siamese cats.") },
                { mood = "proud", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year." end,
                  sub = s("I picked most of them.") },
                { mood = "surprised", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year?!" end,
                  sub = s("When do you even sleep?") },
            },
            book_progress = {
                { mood = "curious", text = function(f) return title(f) .. "? Spill." end,
                  sub = s("Who's the villain? A dog, I bet.") },
                { mood = "grumpy", text = function(f) return "Still on " .. title(f) .. "?" end,
                  sub = s("Pick up the pace. I'm waiting.") },
                { mood = "playful", text = function(f) return title(f) .. "! Good bit coming." end,
                  sub = s("I peeked. No spoilers.") },
            },
            book_waiting = {
                { mood = "grumpy", text = function(f) return title(f) .. " is waiting." end,
                  sub = s("So am I. Rudely.") },
                { mood = "sad", text = function(f) return "Poor " .. title(f) .. "." end,
                  sub = s("Left alone on the shelf. Like me.") },
                { mood = "curious", text = function(f) return "Forgot " .. title(f) .. "?" end,
                  sub = s("I didn't. I remember everything.") },
            },
            goal_day = {
                { mood = "party", text = s("Goal done! Now pet me."),
                  sub = s("That's the real goal.") },
                { mood = "proud", text = s("Daily goal met."),
                  sub = s("Exactly as I planned.") },
                { mood = "cheer", text = s("Goal reached! Bravo!"),
                  sub = s("Treats for the coach, please.") },
            },
            monday = {
                { mood = "grumpy", text = s("Monday. I object."),
                  sub = s("Formally. And loudly.") },
                { mood = "sad", text = s("Monday. Ugh."),
                  sub = s("Read something to cheer me up.") },
                { mood = "playful", text = s("Monday? Not in this book."),
                  sub = s("In here it's always Saturday.") },
            },
            weekend = {
                { mood = "happy", text = s("Weekend! You're all mine."),
                  sub = s("Me, you and a long chapter.") },
                { mood = "playful", text = s("Weekend! No excuses."),
                  sub = s("Read all day. Pet me hourly.") },
                { mood = "cozy", text = s("Weekend. Blanket. Book. Blu."),
                  sub = s("Blu first, obviously.") },
            },
            anytime = {
                { mood = "surprised", text = s("Did you hear that? No?"),
                  sub = s("Read on, then.") },
                { mood = "love", text = s("I yell because I care."),
                  sub = s("Now read.") },
                { mood = "playful", text = s("Pages to turn, cats to praise."),
                  sub = s("In that order? No.") },
                { mood = "proud", text = s("I'm the main character."),
                  sub = s("The book is a side quest.") },
                { mood = "curious", text = s("What's that book about?"),
                  sub = s("Read it to me. Every word.") },
            },
        },
        ["donny-and-blu"] = {
            greet_morning = {
                { mood = "happy", text = s("Morning from both of us!"),
                  sub = s("Blu's yelling. Donny's eating.") },
                { mood = "hungry", text = s("Two cats. Two empty bowls."),
                  sub = s("Then a chapter. We promise.") },
                { mood = "sleepy", text = s("Morning! Donny's still asleep."),
                  sub = s("Blu is not. Clearly.") },
                { mood = "playful", text = s("We raced to your bed."),
                  sub = s("It was a tie. Read to us.") },
                { mood = "cozy", text = s("Morning. Warm bed, two cats."),
                  sub = s("Read a bit before you go?") },
            },
            greet_afternoon = {
                { mood = "playful", text = s("We fought over your lap."),
                  sub = s("Blu won. Donny took the book.") },
                { mood = "sleepy", text = s("Afternoon nap pile."),
                  sub = s("Room for one reader.") },
                { mood = "curious", text = s("What are we reading today?"),
                  sub = s("Blu asked. Donny's listening.") },
                { mood = "happy", text = s("Sunbeam for two."),
                  sub = s("And a chapter for you.") },
                { mood = "dreamy", text = s("Quiet afternoon. Both purring."),
                  sub = s("Perfect reading weather.") },
            },
            greet_evening = {
                { mood = "cozy", text = s("Two cats, one blanket."),
                  sub = s("Room for a reader.") },
                { mood = "love", text = s("Evening! We missed you."),
                  sub = s("Both of us. Blu won't admit it.") },
                { mood = "hungry", text = s("Dinner first, story second."),
                  sub = s("Blu's rules. Donny agrees.") },
                { mood = "reading", text = s("Evening story time!"),
                  sub = s("Blu does the voices.") },
                { mood = "sipping", text = s("Tea, a book, two cats."),
                  sub = s("The perfect evening.") },
            },
            greet_night = {
                { mood = "sleepy", text = s("Night shift: two cats on duty."),
                  sub = s("Read. We'll guard the door.") },
                { mood = "dreamy", text = s("Late night reading club."),
                  sub = s("Members: you, Donny, Blu.") },
                { mood = "cozy", text = s("Night. Two warm cats."),
                  sub = s("One more chapter?") },
                { mood = "sleepy", text = s("Donny's snoring. Blu's not."),
                  sub = s("Read quietly. Or don't.") },
                { mood = "love", text = s("Goodnight from both of us."),
                  sub = s("After this page.") },
            },
            streak = {
                { mood = "proud", text = function(f) return tostring(f.streak) .. " days! We're proud." end,
                  sub = s("Blu takes the credit.") },
                { mood = "cheer", text = function(f) return tostring(f.streak) .. " days in a row!" end,
                  sub = s("Two cats cheering. Quietly.") },
                { mood = "happy", text = s("Streak still going!"),
                  sub = s("Donny purrs. Blu brags.") },
                { mood = "love", text = function(f) return tostring(f.streak) .. " days of stories." end,
                  sub = s("Our favourite habit of yours.") },
            },
            streak_paused = {
                { mood = "sad", text = s("Streak's paused."),
                  sub = s("Blu blames Donny. Read a page?") },
                { mood = "cozy", text = s("New streak starts today."),
                  sub = s("We'll sit with you for it.") },
            },
            today = {
                { mood = "cheer", text = function(f) return readToday(f) .. " today! Paws up." end,
                  sub = s("Donny wants a treat. Blu too.") },
                { mood = "happy", text = s("You read today!"),
                  sub = s("Two very proud cats here.") },
                { mood = "proud", text = function(f) return readToday(f) .. " today." end,
                  sub = s("Blu counted. Donny napped.") },
                { mood = "love", text = s("Reading done today."),
                  sub = s("Pets for both of us, please.") },
            },
            books_year = {
                { mood = "party", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year!" end,
                  sub = s("Fan club: two cats, eight paws.") },
                { mood = "proud", text = function(f) return plural(f.books_year, "%d book", "%d books") .. " this year." end,
                  sub = s("We've napped on every one.") },
                { mood = "cheer", text = function(f) return plural(f.books_year, "%d book", "%d books") .. "! Shelf's filling up." end,
                  sub = s("More room for cats, please.") },
            },
            book_progress = {
                { mood = "curious", text = function(f) return "Both hooked on " .. title(f) end,
                  sub = s("Turn the page. We'll wait.") },
                { mood = "reading", text = function(f) return "Back to " .. title(f) .. "?" end,
                  sub = s("Donny left page, Blu right.") },
                { mood = "happy", text = function(f) return "Read us " .. title(f) .. "!" end,
                  sub = s("Blu wants drama. Donny, snacks.") },
            },
            book_waiting = {
                { mood = "sad", text = function(f) return title(f) .. " is lonely." end,
                  sub = s("We napped on it to keep it warm.") },
                { mood = "curious", text = function(f) return "Remember " .. title(f) .. "?" end,
                  sub = s("We do. We sat on it.") },
                { mood = "cozy", text = function(f) return title(f) .. " is still waiting." end,
                  sub = s("So are two cats. On your lap.") },
            },
            goal_day = {
                { mood = "party", text = s("Goal done! Zoomies for two!"),
                  sub = s("Donny's on the counter again.") },
                { mood = "proud", text = s("Daily goal: done!"),
                  sub = s("Blu says well done. Donny agrees.") },
                { mood = "cheer", text = s("Goal reached!"),
                  sub = s("Treats for the whole team.") },
            },
            monday = {
                { mood = "grumpy", text = s("Monday. Blu's complaining."),
                  sub = s("Donny's asleep. Read anyway?") },
                { mood = "sleepy", text = s("Monday. Both cats in bed."),
                  sub = s("Join us. Bring the book.") },
                { mood = "cozy", text = s("Monday? Stay in. Read."),
                  sub = s("Two cats prescribe it.") },
            },
            weekend = {
                { mood = "cozy", text = s("Weekend! Both laps booked."),
                  sub = s("Bring a long book.") },
                { mood = "happy", text = s("Weekend! Two cats, one plan."),
                  sub = s("You. Couch. Book. Us.") },
                { mood = "playful", text = s("Weekend zoomies, then a read."),
                  sub = s("Blu runs. Donny watches.") },
            },
            anytime = {
                { mood = "love", text = s("Two cats, one reader."),
                  sub = s("Best deal in the house.") },
                { mood = "playful", text = s("Blu talks. Donny listens."),
                  sub = s("You read. Everyone wins.") },
                { mood = "hungry", text = s("Is it dinner yet?"),
                  sub = s("Asking for both of us.") },
                { mood = "curious", text = s("What's the book about?"),
                  sub = s("Blu wants to know. Donny too.") },
                { mood = "sipping", text = s("Tea, cats, a good book."),
                  sub = s("What else is there?") },
            },
        },
    },

    -- ------------------------------------------------------------------
    -- 1.1.0: While reading (Quick Shelf's critter). Lines use {fields}:
    --   {page} {total} {left} {left_pg} {pct} {ch_pg} {ch_time}
    --   {time_left} {pph} {sess_pg} {sess_time} {read_time} {title}
    --   {chapter} {menu}  (see the top of this file)
    -- ------------------------------------------------------------------
    reading = {
        finished = {
            L("party", "The end! You did it.", "{total} pages. All yours."),
            L("proud", "Finished. Take a bow.", "{read_time} well spent."),
            L("surprised", "That's the last page!", "Now what? Another one?"),
            L("love", "Done. Did it hold up?", "Sit with it a minute."),
            L("cheer", "Book closed. Victory lap.", "I'll hold the snacks."),
            L("party", "You finished it, {name}!", "{total} pages. Legend."),
            L("love", "You finished! I'm so proud.", "Tiny critter, big hugs."),
        },
        finish_now = {
            L("surprised", "Only {left_pg} left!", "Don't stop now."),
            L("cheer", "{left_pg} to the end!", "The finish line's right there."),
            L("curious", "{left_pg} left. Ready?", "Endings hit different."),
            L("playful", "So close. {left_pg}.", "You could finish before tea."),
            L("party", "Last {left_pg}. Drumroll...", "No pressure. Lots of pressure."),
            L("cheer", "Come on, {name}! {left_pg} left.", "You've got this."),
            L("love", "Almost there. I believe in you.", "{left_pg} left."),
        },
        finish_tonight = {
            L("cheer", "You could finish this today.", "About {time_left} left."),
            L("curious", "{time_left} to the end.", "Finish it tonight? Just saying."),
            L("playful", "One sitting left. Maybe.", "{left_pg}, about {time_left}."),
            L("proud", "Within reach: {time_left}.", "Then bragging rights."),
        },
        chapter_last = {
            L("surprised", "Last page of the chapter!", "Stop here? Or one more..."),
            L("playful", "Chapter's ending. Clean break.", "Or don't. I won't tell."),
            L("sleepy", "A neat place to stop.", "End of the chapter, right here."),
            L("curious", "Chapter done. Peek at the next?", "Just the first line. Sure."),
            L("grumpy", "Perfect stopping point.", "Which you'll ignore."),
            L("curious", "End of the chapter, {name}.", "Stop here? I dare you."),
            L("cozy", "Chapter done. Cuddle break?", "Then the next one."),
        },
        chapter_soon = {
            L("curious", "{ch_pg} left in this chapter.", "Finish it, then decide."),
            L("cheer", "Chapter ends in {ch_pg}.", "Almost a clean break."),
            L("playful", "{ch_pg} to the chapter end.", "Then 'just one more'. I know you."),
            L("reading", "Nearly done with this chapter.", "{ch_pg} to go."),
        },
        chapter_quick = {
            L("playful", "This chapter? {ch_time} left.", "That's nothing. Keep going."),
            L("curious", "{ch_time} to the chapter end.", "Shorter than a coffee."),
            L("cheer", "Quick one: {ch_time} left.", "{ch_pg} in this chapter."),
        },
        chapter_long = {
            L("surprised", "Long chapter. {ch_time} left.", "{ch_pg}. Settle in."),
            L("grumpy", "This chapter goes on a while.", "{ch_pg} more of it."),
            L("sleepy", "{ch_time} to the chapter end.", "Bring a blanket."),
        },
        fast = {
            L("surprised", "Wow, you're flying!", "{sess_pg} already this sitting."),
            L("party", "Speed mode! {sess_pg} so far.", "Faster than your usual."),
            L("playful", "Whoa. Are you skimming?", "{sess_pg} at warp speed."),
            L("cheer", "Page-turner, huh?", "You're well above your pace."),
            L("curious", "Gripping bit? You're racing.", "{sess_pg} in {sess_time}."),
            L("proud", "Fastest you've read this.", "Don't let me slow you down."),
            L("surprised", "Slow down, {name}!", "{sess_pg} already. Wow."),
            L("love", "Look at you go!", "So proud of you."),
        },
        slow = {
            L("sleepy", "Slow going today.", "That's okay. No rush."),
            L("curious", "Taking your time on this bit?", "Dense pages, huh?"),
            L("grumpy", "This is a slow one.", "{sess_pg} in {sess_time}."),
            L("cozy", "Savouring it, I see.", "Slower than usual. Fine by me."),
            L("playful", "Reading or daydreaming?", "I won't judge. Much."),
            L("sleepy", "Getting sleepy?", "You're slower than usual."),
            L("sleepy", "Tired, {name}?", "Slow pages tonight."),
            L("love", "Take all the time you need.", "I'm right here."),
        },
        steady = {
            L("reading", "Nice steady pace.", "{sess_pg} this sitting."),
            L("happy", "Right in your groove.", "About {pph} pages an hour."),
            L("cozy", "Steady reading. Love it.", "{sess_pg} in {sess_time}."),
        },
        marathon = {
            L("surprised", "{sess_time} straight!", "Stretch? Water? Snack?"),
            L("sleepy", "Long session. Blink, please.", "{sess_time} and counting."),
            L("proud", "Marathon reader!", "{sess_pg} this sitting."),
            L("grumpy", "You've been at it {sess_time}.", "Your eyes called. Break?"),
            L("hungry", "{sess_time} in. Snack time?", "I'm asking for both of us."),
            L("grumpy", "{name}. {sess_time}. Break.", "Your eyes will thank me."),
            L("sipping", "{sess_time}! Water and a stretch?", "Look after yourself."),
        },
        big_session = {
            L("party", "{sess_pg} this sitting!", "That's a real dent."),
            L("surprised", "{sess_pg} already?", "Who are you today?"),
            L("proud", "Huge session: {sess_pg}.", "The book is nervous."),
        },
        just_opened = {
            L("happy", "Back at it! Page {page}.", "{left_pg} to go."),
            L("curious", "Where were we? Page {page}.", "{pct} through."),
            L("cozy", "Settling in?", "{title}, page {page}."),
            L("reading", "Picking up at page {page}.", "{time_left} left, roughly."),
            L("happy", "Welcome back, {name}!", "Page {page}, where you left it."),
            L("love", "Yay, you're back!", "I missed you. Page {page}."),
        },
        late_night = {
            L("sleepy", "It's late. One more page?", "Famous last words."),
            L("grumpy", "Bedtime was a while ago.", "{left_pg} will still be here."),
            L("dreamy", "Night reading is the best.", "Just don't regret it at 7."),
            L("sleepy", "Eyes getting heavy?", "Bookmark it, I'll guard it."),
            L("spooky", "Reading in the dark again.", "Spooky. Cozy. Bad idea."),
            L("sleepy", "Bedtime, {name}.", "One more page. Then bed."),
            L("grumpy", "{name}, it's late.", "The book will still be here."),
            L("cozy", "Snuggle up. It's late.", "One more page, then dreams."),
            L("love", "Sweet dreams soon?", "I'll keep your place safe."),
        },
        early = {
            L("sipping", "Early pages. Respect.", "Coffee and a chapter."),
            L("sleepy", "Reading before sunrise?", "Who hurt you. Kidding."),
            L("happy", "Morning read. Great start.", "Page {page} already."),
            L("love", "Good morning, sunshine.", "A few pages with breakfast?"),
        },
        start = {
            L("curious", "Just getting started.", "{total} pages ahead."),
            L("happy", "Fresh book energy!", "Page {page} of {total}."),
            L("reading", "Early days in {title}.", "Hooked yet?"),
            L("playful", "First impressions?", "Keep or drop. Your call."),
        },
        quarter = {
            L("cheer", "A quarter in!", "{pct} done. Story's warming up."),
            L("curious", "{pct} through. Liking it?", "This is where it hooks you."),
        },
        halfway = {
            L("party", "Halfway! {pct} done.", "All downhill from here."),
            L("surprised", "Half the book. Already!", "{left_pg} on the other side."),
            L("proud", "Halfway mark.", "Things get good now."),
            L("playful", "Middle of the book.", "Plot twist incoming. Maybe."),
            L("party", "Halfway, {name}!", "Downhill from here."),
            L("love", "Halfway! You're amazing.", "I made you a tiny medal."),
        },
        three_quarter = {
            L("cheer", "Three quarters done!", "{left_pg} left."),
            L("curious", "{pct} in. Endgame soon.", "Who do you think wins?"),
        },
        home_stretch = {
            L("cheer", "Home stretch: {pct}.", "{left_pg} to the end."),
            L("surprised", "Almost there!", "Only {time_left} left."),
            L("playful", "Final act. No skipping.", "{left_pg} left."),
        },
        big_book = {
            L("surprised", "{total} pages? Big book.", "You're on {page}. Brave."),
            L("grumpy", "This book is a doorstop.", "{left_pg} to go."),
            L("proud", "Tackling a chunky one.", "{pct} through {total} pages."),
            L("playful", "Heavy book. Literally.", "Good thing it's an e-reader."),
        },
        short_book = {
            L("happy", "Short and sweet.", "Only {total} pages."),
            L("playful", "A quick one. Finish it today?", "{left_pg} left."),
        },
        speedy = {
            L("surprised", "{pph} pages an hour!", "You're quick at this one."),
            L("proud", "This book reads fast.", "About {pph} pages an hour."),
        },
        unhurried = {
            L("sleepy", "A slow read, this one.", "About {pph} pages an hour."),
            L("curious", "Chewy book, huh?", "Slow pages. Worth it?"),
            L("cozy", "No rush with this book.", "{time_left} left at your pace."),
        },
        invested = {
            L("proud", "{read_time} in this book.", "You're committed now."),
            L("love", "You and {title}: {read_time}.", "That's a relationship."),
            L("surprised", "{read_time} so far!", "It better have a good ending."),
            L("love", "{read_time} in, {name}.", "You really like this one."),
        },
        pages_left = {
            L("reading", "Page {page} of {total}.", "{left_pg} to go."),
            L("happy", "{pct} through.", "{left_pg} left."),
            L("curious", "{left_pg} to the end.", "We've got this."),
            L("playful", "Page {page}. Not bad.", "Keep turning."),
            L("reading", "Page {page}, {name}.", "{left_pg} to go."),
        },
        time_left = {
            L("reading", "{time_left} left in this book.", "At your usual pace."),
            L("curious", "Done in about {time_left}.", "Give or take a snack."),
            L("cozy", "About {time_left} to go.", "Plenty of reading left."),
            L("playful", "{time_left} until the end.", "Spread it out or binge it?"),
            L("cozy", "{time_left} left, {name}.", "At your pace."),
        },
        sweet = {
            L("love", "I like reading with you.", "Best part of my day."),
            L("shy", "Can I sit here while you read?", "I'll be very quiet."),
            L("cozy", "Blanket, book, you. Perfect.", "Don't move. Ever."),
            L("love", "You look cute when you read.", "Just saying."),
            L("happy", "Hi. Just checking on you.", "Okay, back to the book."),
            L("shy", "Psst. You're doing great.", "That's all."),
            L("dreamy", "What's happening in the story?", "Tell me the good parts."),
            L("love", "Proud of you for reading.", "Even one page counts."),
            L("sipping", "Did you drink some water?", "Hydrated readers are happy readers."),
            L("cozy", "This is my happy place.", "Right here, with you."),
            L("playful", "Boop. Hi. Okay, read.", "I just wanted a boop."),
            L("love", "Sending you a tiny hug.", "From a tiny critter."),
            L("love", "Hi {name}. Love you.", "Okay. Read now."),
            L("shy", "Is it okay if I stay, {name}?", "I'll be quiet. Promise."),
        },
    },

    reading_voices = {
        donny = {
            finish_now = {
                L("hungry", "{left_pg} left! Then dinner.", "Ending first. Food second."),
                L("cozy", "Last {left_pg}. I'll stay.", "I want to know too."),
                L("proud", "Almost done! I helped.", "By sitting on you."),
                L("hungry", "{left_pg} left, {name}. Then dinner.", "Ending first."),
            },
            finished = {
                L("party", "Finished! Treat time?", "I think we both earned one."),
                L("sleepy", "The end. Nap time.", "Best part of a book."),
            },
            chapter_last = {
                L("sleepy", "End of chapter. Nap?", "I'm voting nap."),
                L("hungry", "Chapter's done. Snack break?", "Asking for me."),
            },
            chapter_soon = {
                L("cozy", "{ch_pg} more, then cuddles.", "That's the deal."),
                L("sleepy", "Finish the chapter. I'll wait.", "Zzz... {ch_pg} left."),
            },
            fast = {
                L("surprised", "So fast! I can't keep up.", "{sess_pg}, my head's spinning."),
                L("playful", "Slow down! I'm reading too.", "Over your shoulder."),
                L("hungry", "Racing to dinner?", "Good. Same."),
            },
            slow = {
                L("sleepy", "Slow pages. Perfect napping.", "Take all night."),
                L("cozy", "No hurry. I'm comfy.", "Don't move."),
                L("dreamy", "Slow and cozy. Love it.", "{sess_pg} in {sess_time}."),
            },
            marathon = {
                L("hungry", "{sess_time}! Food break?", "For me. Obviously."),
                L("sleepy", "{sess_time} of reading.", "I've napped three times."),
            },
            late_night = {
                L("sleepy", "Bedtime? I'm already there.", "Bring the book."),
                L("cozy", "Late. Warm. One more page.", "Then lights out."),
                L("dreamy", "Night reading with you.", "My favourite kind."),
                L("sleepy", "Bed, {name}? I'm already in it.", "Bring the book."),
            },
            halfway = {
                L("proud", "Halfway! I'll nap on it.", "In your honour."),
                L("hungry", "Halfway. Halfway snack?", "That's a thing now."),
            },
            big_book = {
                L("surprised", "{total} pages? Nap first.", "Then I'll help."),
                L("cozy", "Big book. Long cuddles.", "Works for me."),
            },
            pages_left = {
                L("reading", "Page {page}. I'm listening.", "{left_pg} more stories."),
                L("cozy", "{left_pg} left. Lots of laps.", "My plan exactly."),
            },
            time_left = {
                L("sleepy", "{time_left} left. Naps in between.", "That's how I'd do it."),
                L("hungry", "{time_left} left. Snacks?", "Lots of snack breaks in that."),
            },
            just_opened = {
                L("happy", "Back! Page {page}.", "I kept it warm."),
                L("cozy", "You're back. Lap please.", "Then page {page}."),
                L("cozy", "{name}! I kept your spot warm.", "Page {page}."),
            },
            invested = {
                L("love", "{read_time} together on this.", "Best {read_time} ever."),
            },
            sweet = {
                L("cozy", "Your lap is the best place.", "I'm staying forever."),
                L("love", "Purrrr. That's all.", "Keep reading. Keep petting."),
                L("sleepy", "I fell asleep on you again.", "Sorry. Not sorry."),
                L("hungry", "I saved you a snack.", "I ate it. But I thought of you."),
                L("love", "I love you, {name}.", "And fish. But mostly you."),
            },
        },
        blu = {
            finish_now = {
                L("grumpy", "{left_pg}. Finish. Now.", "I'm not asking."),
                L("playful", "{left_pg} left! Go go go!", "I'll yell the countdown."),
                L("proud", "Almost there. I believed in you.", "Mostly."),
            },
            finished = {
                L("proud", "Done. As I planned.", "You're welcome."),
                L("grumpy", "Finished? Finally.", "Feed me to celebrate."),
            },
            chapter_last = {
                L("grumpy", "Chapter's over. Pet me.", "That was the deal."),
                L("playful", "Chapter end! My turn.", "Throw something."),
            },
            chapter_soon = {
                L("grumpy", "{ch_pg}. Then me.", "Clock's ticking."),
                L("curious", "{ch_pg} left. What happens?", "Tell me. Now."),
            },
            fast = {
                L("surprised", "WHOA. Slow down, show-off.", "{sess_pg} already?!"),
                L("proud", "Fast. Like me.", "Obviously I taught you."),
                L("grumpy", "Are you even reading?", "{sess_pg} that fast? Suspicious."),
            },
            slow = {
                L("grumpy", "Turn. The. Page.", "I've been waiting."),
                L("playful", "Snail mode activated.", "{sess_pg} in {sess_time}. Wow."),
                L("grumpy", "Slower than my dinner service.", "That's saying something."),
                L("grumpy", "Turn the page, {name}.", "I've been waiting."),
            },
            marathon = {
                L("grumpy", "{sess_time}! I've been ignored.", "For {sess_time}."),
                L("proud", "{sess_time} straight. Impressive.", "Still, pet me."),
            },
            late_night = {
                L("grumpy", "It's late. Lights OFF.", "I need my beauty sleep."),
                L("playful", "Late night? Zoomies time!", "Just kidding. Read."),
                L("spooky", "Late-night reading again?", "I'll watch the shadows."),
                L("grumpy", "{name}. Lights. OFF.", "I need my beauty sleep."),
            },
            halfway = {
                L("proud", "Halfway. Under my supervision.", "Keep it up."),
                L("grumpy", "Only halfway?", "Pick up the pace."),
            },
            big_book = {
                L("grumpy", "{total} pages?! Ridiculous.", "Fine. I'll supervise."),
                L("surprised", "That's a huge book.", "Bigger than me. Rude."),
            },
            pages_left = {
                L("grumpy", "{left_pg} left. Get going.", "Chop chop."),
                L("curious", "Page {page}. What's happening?", "Explain everything."),
            },
            time_left = {
                L("grumpy", "{time_left} left. Read faster.", "I have plans."),
                L("proud", "{time_left} to go. Easy.", "For us."),
            },
            just_opened = {
                L("grumpy", "Oh, NOW you're back.", "Page {page}. Hmph."),
                L("playful", "Back! Page {page}. Go!", "I'm timing you."),
                L("grumpy", "Oh, NOW you're back, {name}.", "Page {page}. Hmph."),
            },
            invested = {
                L("grumpy", "{read_time} on this book.", "That's {read_time} not petting me."),
            },
            sweet = {
                L("shy", "I don't love you. Okay, I do.", "Don't tell Donny."),
                L("proud", "You may pet me now.", "It's an honour."),
                L("love", "Fine. You're my favourite.", "This is a one-time statement."),
                L("playful", "I sat on your book. Cute, right?", "You're welcome."),
                L("shy", "{name}... thanks for the lap.", "Don't make it weird."),
            },
        },
        ["donny-and-blu"] = {
            finish_now = {
                L("party", "{left_pg} left! We're chanting.", "Blu's loud. Donny's eating."),
                L("cheer", "Both of us: finish it!", "{left_pg} to go."),
            },
            finished = {
                L("party", "Done! Two-cat celebration.", "Treats for the team."),
                L("happy", "The end! We both cried.", "Donny did. Blu won't say."),
            },
            chapter_last = {
                L("playful", "Chapter's done. Lap war.", "Blu's winning."),
                L("sleepy", "End of chapter. Nap pile?", "Donny's in. Blu says read."),
            },
            chapter_soon = {
                L("curious", "{ch_pg} left. We're both curious.", "Blu more loudly."),
            },
            fast = {
                L("surprised", "You're flying! We're dizzy.", "{sess_pg} this sitting."),
                L("playful", "Donny can't keep up.", "Blu says go faster."),
            },
            slow = {
                L("sleepy", "Slow going. Donny's asleep.", "Blu's tapping her paw."),
                L("cozy", "Slow pages, warm cats.", "Nobody's complaining. Except Blu."),
            },
            marathon = {
                L("hungry", "{sess_time}! Two cats starving.", "Theatrically."),
                L("grumpy", "{sess_time} of reading.", "Blu filed a complaint."),
            },
            late_night = {
                L("sleepy", "Late! Donny's out cold.", "Blu says lights off."),
                L("cozy", "Late night, two cats, one book.", "One more page. Then bed."),
            },
            halfway = {
                L("party", "Halfway! Paw-five.", "Donny missed. Blu didn't."),
            },
            big_book = {
                L("surprised", "{total} pages! We'd need two laps.", "Good thing there's two of us."),
            },
            pages_left = {
                L("reading", "Page {page}. Both listening.", "{left_pg} left."),
                L("playful", "{left_pg} to go.", "Blu's counting. Donny's not."),
            },
            time_left = {
                L("cozy", "{time_left} left. Plenty of lap time.", "We'll take turns."),
            },
            just_opened = {
                L("happy", "You're back! Page {page}.", "We saved your spot. Both of us."),
                L("happy", "{name}'s back! We both cheered.", "Page {page}."),
            },
            sweet = {
                L("love", "Two cats love you.", "Officially."),
                L("cozy", "Cat sandwich. You're the bread.", "Don't move."),
                L("happy", "We made you a nest.", "It's your blanket. Now it's ours."),
                L("love", "We love you, {name}!", "Donny said it first."),
            },
        },
    },

    -- ------------------------------------------------------------------
    -- 1.1.0: the Quick Shelf strip (swipe the toolbar's book row).
    -- ------------------------------------------------------------------
    shelf = {
        one_progress = {
            L("curious", "Just {next} on the side.", "A shelf of one. Classy."),
            L("playful", "One other book? Cute.", "{next} is waiting patiently."),
            L("happy", "{next} is at {next_pct}.", "Want to visit it?"),
            L("shy", "Just you, me and {next}.", "Cozy little shelf."),
            L("proud", "Only one on the side.", "Very disciplined."),
            L("curious", "{next} says hi.", "It's at {next_pct}. No pressure."),
        },
        one_tbr = {
            L("happy", "One book waiting: {next}.", "Good choice, past you."),
            L("curious", "Just {next} up next.", "Easy decision, then."),
            L("playful", "A to-be-read of one.", "Lonely shelf. Add a friend?"),
            L("dreamy", "{next}, waiting its turn.", "It looks excited."),
        },
        progress = {
            L("curious", "{shelf_n} on the go.", "Juggling stories, huh?"),
            L("reading", "Your other books miss you.", "{next} is next in line."),
            L("playful", "So many open books.", "Commitment issues? Kidding."),
            L("happy", "Want to switch it up?", "Tap a cover. I'll come too."),
            L("cozy", "Your reading pile. Cozy.", "{shelf_n} waiting for you."),
            L("curious", "Back to {next}?", "It's at {next_pct}."),
            L("love", "Every one of these is good.", "Pick whichever feels right."),
            L("playful", "Book hopping again?", "Fine by me."),
            L("curious", "How's {next} going?", "It's at {next_pct}."),
            L("reading", "{next} looks lonely.", "Just saying."),
            L("happy", "Remember {next}?", "It remembers you."),
            L("playful", "{next} or this one?", "Tough call."),
            L("proud", "{next}: {next_pct} done.", "Not bad at all."),
            L("dreamy", "I keep thinking about {next}.", "Where were we in that one?"),
        },
        tbr = {
            L("curious", "{shelf_n} to be read.", "Which one's calling you?"),
            L("dreamy", "So many stories waiting.", "I like this shelf."),
            L("happy", "Next up: {next}?", "Looks good to me."),
            L("playful", "Your someday shelf.", "Someday could be today."),
            L("love", "Saving the best for later?", "Smart."),
            L("curious", "Picking the next adventure?", "{shelf_n} to choose from."),
            L("curious", "{next} looks good.", "Next up, maybe?"),
            L("dreamy", "Picture yourself in {next}.", "Cozy, right?"),
            L("playful", "{next} keeps staring at me.", "Read it so it stops."),
        },
        many = {
            L("surprised", "{shelf_n}?! That's a lot.", "We should get reading."),
            L("playful", "This shelf is overflowing.", "I'll hold a few."),
            L("grumpy", "{shelf_n}. Again.", "Finish one. Maybe."),
            L("curious", "{shelf_n} going at once.", "{next} misses you most."),
        },
        nearly = {
            L("cheer", "{next} is at {next_pct}!", "Finish it next?"),
            L("curious", "{next} is nearly done.", "So close. Just saying."),
            L("proud", "Almost done with {next}.", "That one's yours."),
        },
        empty_progress = {
            L("happy", "Just this one on the go.", "Loyal. I like it."),
            L("cozy", "One book at a time.", "The best way, honestly."),
            L("love", "Only this book. Focused.", "I'm proud of you."),
        },
        empty_tbr = {
            L("curious", "To Be Read is empty!", "Time to go book shopping?"),
            L("sad", "No books waiting.", "Add some? Please?"),
            L("playful", "An empty shelf?!", "I'll sit here till it's full."),
        },
        sweet = {
            L("love", "I like browsing with you.", "Take your time."),
            L("shy", "Can I pick next time?", "I pick the cute cover."),
            L("cozy", "Nice shelf. Nice you.", "That's all."),
            L("love", "Any book, as long as it's with you.", "Okay, go pick."),
            L("happy", "Hi {name}! Browsing?", "I'll help."),
        },
    },

    shelf_voices = {
        donny = {
            progress = {
                L("hungry", "{shelf_n}? Snack per book.", "That's the rule."),
                L("sleepy", "So many books. So sleepy.", "Pick one, I'll nap on it."),
            },
            tbr = {
                L("cozy", "Pick the fluffiest one.", "For me."),
                L("hungry", "Is one about fish?", "Pick that one."),
            },
            nearly = { L("proud", "{next} at {next_pct}!", "Finish it, then treats.") },
            one_progress = { L("cozy", "Just {next}. One more lap.", "I mean book. Lap too.") },
            empty_tbr = { L("sad", "No books? No laps.", "Fix this, please.") },
            sweet = { L("love", "Whatever you pick, I'm in.", "As long as I'm on you.") },
        },
        blu = {
            progress = {
                L("grumpy", "{shelf_n}?! Finish one.", "I'm counting."),
                L("proud", "I've approved all of these.", "Proceed."),
            },
            tbr = {
                L("proud", "I'll pick. That one.", "No, the other one."),
                L("grumpy", "So many books. So little lap.", "Choose wisely."),
            },
            many = { L("grumpy", "{shelf_n}. Ridiculous.", "I'm judging. Quietly.") },
            nearly = { L("grumpy", "{next}: {next_pct}. Finish it.", "I'm not asking.") },
            one_progress = { L("proud", "One other book. Acceptable.", "I'm watching it.") },
            empty_tbr = { L("grumpy", "Empty? Unacceptable.", "Buy books. Now.") },
            sweet = { L("shy", "Fine. I like browsing with you.", "Don't tell Donny.") },
        },
        ["donny-and-blu"] = {
            progress = { L("playful", "{shelf_n}! One each?", "Blu gets the big one.") },
            one_progress = { L("playful", "One book, two cats.", "We'll share. Blu won't.") },
            tbr = { L("curious", "We each picked one.", "They're both the same book.") },
            nearly = { L("cheer", "{next} at {next_pct}!", "We're both cheering.") },
            sweet = { L("love", "Two cats, one shelf, you.", "Perfect.") },
        },
    },

    -- ------------------------------------------------------------------
    -- 1.1.0: The menus (Quick Shelf's critter in the menu tab bar).
    -- menu_words: the first entry whose word is in the open submenu's
    -- name (lower case; deepest submenu first) picks the lines, else the
    -- tab's own lines (tab_navigation tab_typeset tab_settings tab_tools
    -- tab_search tab_files tab_main), else "any". {menu} = submenu name.
    -- ------------------------------------------------------------------
    menu_words = {
        { key = "addons",      words = { "add-ons", "addons" } },
        { key = "toolbar",     words = { "shortcuts toolbar", "quick shelf", "icon tweaks", "critter remarks" } },
        { key = "backup",      words = { "backup", "back up", "restore" } },
        { key = "customize",   words = { "menu disabler", "menu customizer", "arrange" } },
        { key = "debug",       words = { "debug", "diagnostic" } },
        { key = "xray",        words = { "x-ray", "xray" } },
        { key = "quests",      words = { "readmastery", "read mastery", "quest", "mastery" } },
        { key = "location",    words = { "reading location", "furthest" } },
        { key = "status",      words = { "footcream", "foot cream", "status bar", "footer" } },
        { key = "goodreads",   words = { "shelfsync", "goodreads" } },
        { key = "bookorbit",   words = { "bookorbit", "book orbit" } },
        { key = "bookcard",    words = { "book card", "bookcard" } },
        { key = "critter",     words = { "critter", "simpleui", "simple ui", "home screen", "homescreen", "side panel" } },
        { key = "sleep",       words = { "sleep screen", "screensaver", "sleep", "suspend", "standby", "lock screen" } },
        { key = "wifi",        words = { "wi-fi", "wifi", "network", "wireless", "connect" } },
        { key = "sync",        words = { "sync", "bookorbit", "shelfsync", "calibre", "opds", "cloud", "kosync", "progress sync" } },
        { key = "update",      words = { "update", "version", "nightly" } },
        { key = "exit",        words = { "exit", "restart", "quit", "power off", "reboot" } },
        { key = "battery",     words = { "battery", "power", "charging" } },
        { key = "bookmarks",   words = { "bookmark", "highlight", "note", "annotation", "quote" } },
        { key = "light",       words = { "frontlight", "front light", "warmth", "brightness", "night mode", "light" } },
        { key = "stats",       words = { "statistic", "stats", "reading log", "insight", "progress", "streak" } },
        { key = "toc",         words = { "table of contents", "contents", "go to", "skim", "chapter", "toc", "page scrubber", "glimpse" } },
        { key = "fonts",       words = { "font", "typeset", "style tweak", "text", "bold", "embolden", "hyphen" } },
        { key = "layout",      words = { "margin", "spacing", "layout", "page", "zoom", "column", "rotation", "orientation" } },
        { key = "dictionary",  words = { "dictionar", "translat", "wikipedia", "lookup", "vocabulary" } },
        { key = "collections", words = { "collection", "history", "favorite", "favourite", "shelf", "to be read", "library", "bookshelf", "storefront" } },
        { key = "gestures",    words = { "gesture", "tap", "swipe", "taps", "multiswipe", "long-press", "corner" } },
        { key = "keyboard",    words = { "keyboard", "input" } },
        { key = "screenshot",  words = { "screenshot" } },
        { key = "plugins",     words = { "plugin" } },
        { key = "time",        words = { "time", "date", "clock" } },
        { key = "language",    words = { "language" } },
        { key = "navigation",  words = { "navigation", "back button", "page turn", "volume key", "turn pages" } },
        { key = "device",      words = { "device", "usb", "mass storage", "cover event", "haptic", "power led" } },
        { key = "document",    words = { "document", "metadata", "book status", "end of document" } },
        { key = "screen",      words = { "screen", "dpi", "refresh", "flash", "fullscreen", "color", "colour", "dither" } },
        { key = "files",       words = { "file", "folder", "storage", "cover" } },
        { key = "help",        words = { "about", "help", "manual", "feedback" } },
    },

    menus = {
        tab_navigation = {
            L("curious", "Jumping around? Lost?", "I won't tell the author."),
            L("playful", "Skipping ahead? Cheater.", "Okay, a little peek."),
            L("reading", "Navigation. Where to?", "Not the last page. Please."),
            L("happy", "Going somewhere in the book?", "I'll come too."),
        },
        tab_typeset = {
            L("playful", "Font fiddling again?", "It looked fine. I promise."),
            L("curious", "Making it pretty?", "The words stay the same."),
            L("grumpy", "Reading or decorating?", "Pick one."),
            L("playful", "Fonts again, {name}?", "It looked fine."),
        },
        tab_settings = {
            L("curious", "Settings. Something bugging you?", "Careful with those toggles."),
            L("love", "Making it just how you like it?", "You deserve cozy."),
            L("grumpy", "Settings again.", "The book's getting lonely."),
            L("shy", "Fixing something? Need a paw?", "I'm good at pressing buttons."),
            L("curious", "So many settings!", "Which one's the cuddle button?"),
            L("happy", "Settings! I like buttons.", "Press one for me."),
        },
        tab_tools = {
            L("curious", "Tools? Building something?", "Don't break anything."),
            L("playful", "Ooh, the toolbox.", "Hand me the shiny one."),
            L("love", "Ooh, tools. You're so clever.", "I'll watch."),
            L("curious", "Tools time? What are we making?", "Something good, I bet."),
        },
        tab_search = {
            L("curious", "Looking for something?", "I hid it. Kidding."),
            L("playful", "Search time. What'd you lose?", "Probably under the couch."),
            L("reading", "Searching. Who said what?", "I knew it was them."),
            L("love", "Looking for something?", "I'll help you find it."),
        },
        tab_files = {
            L("curious", "Leaving already?", "Just browsing, right?"),
            L("grumpy", "Cheating on this book?", "I saw that."),
            L("playful", "Shopping for the next one?", "Finish this one first. Maybe."),
            L("grumpy", "Leaving this book, {name}?", "I saw that."),
        },
        tab_main = {
            L("curious", "The main menu. Fancy.", "What are we up to?"),
            L("playful", "Big menu energy.", "Don't press anything weird."),
            L("happy", "Hi! What are we doing?", "Can I help?"),
            L("love", "The big menu! Hi!", "I'm here if you need me."),
        },
        critter = {
            L("surprised", "Wait, that's my menu!", "Be nice. I'm watching."),
            L("shy", "Changing me? Rude.", "Unless it's a new hat."),
            L("proud", "My settings. My kingdom.", "Choose wisely."),
            L("playful", "Customizing me? Flattered.", "Pick the cute options."),
            L("shy", "Changing me, {name}?", "Be gentle."),
            L("love", "Are you making me cuter?", "Impossible. But try."),
        },
        sleep = {
            L("sleepy", "Sleep screen stuff? Yes.", "Naps are my area."),
            L("dreamy", "Making bedtime prettier?", "I approve."),
            L("sleepy", "Talking about sleep... yawn.", "Contagious."),
            L("love", "Picking a pretty sleep screen?", "Put me on it. Please?"),
        },
        wifi = {
            L("curious", "Going online?", "Don't buy more books. Okay, do."),
            L("grumpy", "Wi-Fi drains the battery.", "Just saying."),
            L("playful", "Connecting to the internet?", "Say hi from me."),
            L("curious", "Going online, {name}?", "Don't buy more books. Okay, do."),
        },
        sync = {
            L("curious", "Syncing? Good call.", "Your page is safe with me."),
            L("proud", "Backing up your progress.", "Very responsible."),
            L("playful", "Sync all the things!", "Then read all the things."),
        },
        update = {
            L("surprised", "Updates? Ooh, shiny.", "Back up first. Please."),
            L("curious", "New version? What's new?", "Hope it's more treats."),
            L("grumpy", "Updating. Again.", "Fine. Back up first."),
        },
        battery = {
            L("curious", "Battery check?", "Charge me too. Kidding."),
            L("sleepy", "Low battery? Same.", "Nap for both of us."),
        },
        light = {
            L("dreamy", "Adjusting the light?", "Warmer is cozier."),
            L("sleepy", "Dimmer, please.", "Easier on the eyes."),
            L("playful", "Light show!", "Don't blind me."),
            L("cozy", "Warm light is cozy light.", "Perfect for snuggles."),
        },
        stats = {
            L("proud", "Checking your stats?", "Numbers look good."),
            L("curious", "Stats again? Show-off.", "Fine, I'm impressed."),
            L("playful", "Admiring your numbers?", "Go make more of them."),
            L("love", "Look how much you've read!", "I'm so proud of you."),
        },
        fonts = {
            L("playful", "Font shopping again?", "It's still the same book."),
            L("curious", "Bigger? Smaller? Bolder?", "You'll pick the first one."),
            L("grumpy", "The font was fine.", "I liked the font."),
            L("proud", "Typography critic now?", "Very fancy."),
        },
        layout = {
            L("curious", "Margins? Spacing?", "Picky. I respect it."),
            L("playful", "Moving the furniture?", "Leave room for me."),
        },
        dictionary = {
            L("curious", "Big word, huh?", "I knew it. Probably."),
            L("proud", "Learning new words!", "Use one on me."),
            L("playful", "Look it up. I'll wait.", "Smartypants."),
        },
        bookmarks = {
            L("curious", "Saving a good bit?", "Read it to me."),
            L("love", "Highlights! Good lines?", "Mark the best ones."),
            L("proud", "Bookmarking. Smart.", "Future you says thanks."),
            L("love", "Saving a pretty line?", "Read it to me later."),
        },
        toc = {
            L("curious", "Checking how long this chapter is?", "I won't tell."),
            L("playful", "Peeking at chapter names?", "Spoilers lurk there."),
            L("grumpy", "No skipping ahead.", "I'm watching."),
        },
        collections = {
            L("curious", "Organizing the shelves?", "Put me on top."),
            L("playful", "Collections! Very tidy.", "Unlike my toys."),
            L("happy", "Planning what's next?", "Good. Keep the streak going."),
            L("dreamy", "So many books to love.", "Which one next?"),
        },
        gestures = {
            L("playful", "Rewiring the taps?", "Don't lose me in there."),
            L("curious", "New gestures? Fancy.", "Swipe right on me."),
            L("curious", "Taps and swipes? Teach me some.", "I only know 'boop'."),
            L("playful", "Changing what taps do?", "Make one that pets me."),
            L("shy", "New gestures? Be gentle.", "I'm ticklish."),
        },
        screenshot = {
            L("proud", "Screenshot? Get my good side.", "Left. It's the left."),
            L("shy", "Taking pictures?", "Wait, my fur."),
        },
        plugins = {
            L("curious", "Plugins? Adding more stuff?", "We're running out of menu."),
            L("playful", "Plugin shopping.", "Get one for snacks."),
        },
        time = {
            L("curious", "Checking the time?", "Late, probably."),
            L("sleepy", "Time? It's nap o'clock.", "It's always nap o'clock."),
            L("love", "Time for one more chapter.", "Always."),
        },
        language = {
            L("surprised", "Changing languages?", "Bonjour? Hola? Meow."),
        },
        files = {
            L("curious", "File stuff. Very serious.", "Don't delete anything good."),
            L("grumpy", "Careful with that delete.", "I've seen things."),
        },
        exit = {
            L("sad", "Leaving? Already?", "Come back soon."),
            L("grumpy", "Restarting? Don't you dare.", "Fine. Hurry back."),
            L("sad", "Wait, don't go!", "We were having fun."),
            L("sad", "Leaving, {name}?", "Come back soon."),
            L("love", "Bye! Come back soon.", "I'll miss you."),
        },
        help = {
            L("curious", "Reading the manual?", "Who are you?!"),
            L("proud", "Asking for help. Mature.", "I'd have just guessed."),
        },
        any = {
            L("curious", "Ooh, {menu}.", "What are we doing in here?"),
            L("playful", "{menu}? Interesting choice.", "Carry on."),
            L("reading", "Exploring {menu}.", "Don't get lost."),
            L("curious", "What's in {menu}?", "Tell me if it's snacks."),
            L("curious", "{menu}, {name}? Why?", "Just curious."),
            L("happy", "Ooh, {menu}! I'll come too.", "Hold my paw."),
            L("curious", "Ooh, where are we going?", "I'll follow you."),
            L("playful", "Exploring? Take me with you.", "I'm small. I fit."),
            L("happy", "New menu! What's in here?", "Something fun, I hope."),
            L("shy", "I've never been in here.", "Is it safe?"),
        },
        addons = {
            L("happy", "Ooh, the fun drawer!", "All your extras live here."),
            L("curious", "So many goodies in here.", "Which one today?"),
            L("playful", "The secret extras menu!", "I won't tell anyone."),
            L("love", "Your special stuff. Cozy.", "Everything just how you like it."),
        },
        toolbar = {
            L("surprised", "Hey, that's where I live!", "Be nice to my house."),
            L("shy", "Rearranging my home?", "Leave me a cozy corner."),
            L("happy", "My toolbar! Hi!", "I'm right up there."),
        },
        backup = {
            L("proud", "Backing things up? Smart.", "Safe and sound."),
            L("cozy", "Tucking everything in safe.", "Like a blanket for your stuff."),
            L("curious", "Restoring something?", "I hope nothing got lost."),
        },
        customize = {
            L("shy", "Hiding menus? Don't hide me.", "I'm small but important."),
            L("playful", "Tidying up the menus?", "Very neat. Very you."),
        },
        debug = {
            L("curious", "Something acting up?", "I'll hold the flashlight."),
            L("shy", "Uh oh. Is it my fault?", "I didn't touch anything."),
        },
        xray = {
            L("surprised", "X-Ray vision!", "Who's who in this book?"),
            L("curious", "Forgot who someone is?", "Happens to the best of us."),
        },
        quests = {
            L("party", "Quests! Got any for me?", "I'll be your sidekick."),
            L("proud", "Leveling up your reading?", "Go get that badge."),
        },
        location = {
            L("curious", "Lost your place?", "I'll help you find it."),
            L("happy", "Back to where you were.", "I remember. Kind of."),
        },
        status = {
            L("playful", "Fixing the bottom bar?", "Make it pretty."),
            L("curious", "Footer stuff?", "So many little numbers."),
        },
        goodreads = {
            L("proud", "Telling Goodreads about it?", "Show off a little."),
            L("happy", "Syncing your shelves!", "Everyone will know how cool you are."),
        },
        bookorbit = {
            L("surprised", "BookOrbit! Books in space!", "Can I come?"),
            L("happy", "Checking your BookOrbit?", "Your books are safe up there."),
        },
        bookcard = {
            L("love", "A little book card. Cute.", "Just like me."),
        },
        keyboard = {
            L("curious", "Keyboard stuff?", "Type something nice."),
            L("playful", "Typing? Write me a poem.", "Rhymes with 'critter'. Go."),
        },
        navigation = {
            L("curious", "How the pages turn? Fancy.", "Forward is my favourite."),
            L("playful", "Page-turning settings!", "Swipe, tap, wiggle?"),
        },
        device = {
            L("curious", "Device settings? Very techy.", "I just live in here."),
            L("shy", "Poking the e-reader's insides?", "That's my house. Careful."),
            L("love", "Taking care of your Kobo?", "It takes care of your books."),
        },
        document = {
            L("curious", "Document settings?", "Very official."),
            L("playful", "Book paperwork. Fun.", "I'll stamp it."),
        },
        screen = {
            L("curious", "Screen stuff? Make it pretty.", "Pretty like me."),
            L("playful", "Fiddling with the screen?", "Don't make me blurry."),
            L("happy", "A nicer screen? Yes, please.", "Crisp critter incoming."),
        },
    },

    menu_voices = {
        donny = {
            tab_typeset = { L("sleepy", "Fonts again? I'll nap.", "Wake me when it's pretty.") },
            tab_files = { L("sad", "Leaving our book?", "I was comfy in it.") },
            tab_search = { L("hungry", "Searching for snacks?", "Check the kitchen.") },
            sleep = { L("sleepy", "Sleep screen? My favourite.", "I'm the model, right?") },
            critter = {
                L("love", "That's my menu! Hi!", "Pick the hungry pose."),
                L("shy", "Are you choosing me?", "Pick me. Please."),
            },
            wifi = { L("hungry", "Order food while you're online?", "Fish, please.") },
            fonts = { L("sleepy", "Make it big. I'm sleepy.", "Easier to read upside down.") },
            stats = { L("proud", "Look at all that reading.", "I napped through most of it.") },
            exit = { L("sad", "Leaving? Take me too.", "I fit in the bag.") },
            any = { L("curious", "{menu}? Is there food?", "No? Okay.") },
            tab_settings = {
                L("cozy", "Settings? I'll nap on your arm.", "Take your time."),
            },
            addons = {
                L("cozy", "The fun drawer. Any treats?", "No? Still cozy."),
            },
            toolbar = {
                L("sleepy", "My house! Shh, I'm napping.", "Rearrange quietly."),
            },
            xray = {
                L("hungry", "X-Ray! Can it find snacks?", "Worth a try."),
            },
            backup = {
                L("cozy", "Tucking it all in?", "Me next, please."),
            },
            gestures = {
                L("sleepy", "New gestures? Add 'pet Donny'.", "Two-finger scritch."),
            },
            device = {
                L("cozy", "Device settings. It's warm in here.", "Don't turn it off."),
            },
        },
        blu = {
            tab_typeset = { L("grumpy", "Stop fiddling. Read.", "The font is FINE.") },
            tab_files = {
                L("grumpy", "Leaving this book? Traitor.", "I'll remember this."),
                L("grumpy", "Traitor, {name}.", "I'll remember this."),
            },
            tab_settings = {
                L("grumpy", "Settings again?!", "You're stalling."),
                L("shy", "Need help? Not that I care.", "Okay, I care."),
            },
            sleep = { L("proud", "Sleep screen? Put me on it.", "Obviously.") },
            critter = {
                L("proud", "My menu. Choose me.", "Correct answer: Blu."),
                L("grumpy", "Thinking of switching critters?", "Try it. I dare you."),
            },
            wifi = { L("grumpy", "Wi-Fi? Battery hog.", "Off when you're done.") },
            fonts = { L("grumpy", "The font was fine!", "Stop. Reading.") },
            stats = { L("proud", "Numbers. All thanks to me.", "You're welcome.") },
            exit = { L("grumpy", "Don't you DARE leave.", "Fine. Feed me first.") },
            any = { L("curious", "{menu}? Explain. Now.", "I demand answers.") },
            addons = {
                L("proud", "The extras menu. I approve.", "Proceed."),
            },
            toolbar = {
                L("grumpy", "Careful. That's MY house.", "Don't move my stuff."),
            },
            quests = {
                L("proud", "Quests? I'm the boss level.", "Good luck."),
            },
            debug = {
                L("grumpy", "Something broke? Not me.", "Probably Donny."),
            },
            gestures = {
                L("grumpy", "No tickling gestures.", "I mean it."),
            },
            screen = {
                L("proud", "Make the screen worthy of me.", "Sharp. Bright. Blu."),
            },
        },
        ["donny-and-blu"] = {
            tab_typeset = { L("playful", "Fonts? Donny likes big.", "Blu likes bold. Obviously.") },
            tab_files = { L("sad", "Leaving the book?", "Donny's sad. Blu's furious.") },
            critter = { L("happy", "Our menu! Pick both of us.", "We come as a set.") },
            wifi = { L("curious", "Online? Order treats.", "Two of everything.") },
            exit = { L("sad", "Leaving? Two sad cats.", "Come back soon.") },
            any = {
                L("curious", "{menu}? We're both curious.", "Blu louder."),
                L("love", "{menu}? We'll come too!", "Two cats, one adventure."),
            },
            toolbar = {
                L("happy", "That's our house!", "Donny's napping in it."),
            },
            addons = {
                L("playful", "The fun drawer! We're in.", "Blu first, obviously."),
            },
        },
    },
}
