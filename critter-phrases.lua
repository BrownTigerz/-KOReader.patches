-- critter-phrases.lua - what the Tiny Critter says
-- Shared by SimpleUI Tweaks (2-simpleui-tweaks.lua) and Reading Log.
--
-- Install: koreader/patches/critter-phrases.lua (next to the patch). The
-- name doesn't start with a number, so KOReader doesn't run it as a patch.
-- Don't name it phrases.lua or put it in settings/simpleui/sui_critters/:
-- that's SimpleUI's own custom phrase file, in another format.
--
-- Edit freely. Missing or broken, both fall back to their built-in lines
-- (Debugging logs which). Keep lines short: about 35 characters fits the
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
-- minutes / pages: steps { upto, mood, text = function(n), subs = {...} },
--   lowest first; the last one's upto is math.huge.
-- Moods: neutral happy party sleepy cheer love sad surprised curious
--   grumpy shy playful, and Donny and Blu's extra ones: reading proud
--   hungry cozy sipping dreamy festive spooky (another critter shows the
--   pose they're drawn from: reading = neutral, proud = cheer, hungry =
--   curious, cozy and dreamy = sleepy, sipping and festive = happy,
--   spooky = surprised).
-- A pep-talk sub can be { "line", mood = "hungry" } to show its own mood.

local function plural(n, one, many) return string.format(n == 1 and one or many, n) end
local function q(s) return "\xE2\x80\x9C" .. tostring(s or "your book") .. "\xE2\x80\x9D" end
local function mins(n) return plural(n or 0, "%d minute", "%d minutes") end
local function every(days_left, books_left)
    if not books_left or books_left <= 0 then return "you're already there" end
    if not days_left or days_left <= 0 then return "a book whenever" end
    local e = days_left / books_left
    if e >= 1.5 then return string.format("one every %d days", math.floor(e + 0.5)) end
    return string.format("%d a week", math.ceil(7 / e))
end
local function s(text) return function() return text end end

return {
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
}
