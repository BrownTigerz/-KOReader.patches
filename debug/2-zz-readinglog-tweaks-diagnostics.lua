--[[
2-zz-readinglog-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.4

Changelog:
  1.1.4 - Lighter: one line before each of the Activity card's drawing
          steps and no shape or text lines, so it paints at close to normal
          speed (1.1.3 slowed it so much the crash stopped coming).
  1.1.3 - The Activity card in Dark Academia, one drawing step at a time:
          each step with where in Reading Log's code it was asked for, and
          inside a Dark Academia step each shape and text it paints (text:
          where, on how big an image, colour ink, whether it was freed).
          For the Pocket watch crash.
  1.1.2 - Dark Academia step by step: while it's on, each card's build
          and each card's paint is logged as it starts and ends ("A:"
          lines). After a crash, the last start with no end names the card.
  1.1.1 - Colours: each style change logs your theme and both accents
          before and after, and a theme or accent changed any other way is
          logged with what changed it. The window snapshot shows them too.
  1.1.0 - Crash hunt: logs drawing that reaches past its canvas, each big
          canvas (the Dashboard) painted onto the screen image (and when
          it's done), pixels Reading Log caught past the edge, where a
          downloaded style draws the tab bar, and every style change. Lines
          are written straight away, so the last ones before a crash stay.
          The window snapshot adds the style, Move Tab Row and Change Style
          Each Month.
  1.0.1 - Logs each card's source (Stock / BookOrbit / Both), Switch Cards
          By and the paired cards (Reading Log Tweaks 2.8.0).
  1.0.0 - First version.

Watches 2-readinglog-tweaks.lua from the outside and writes tagged lines
([readinglog-tweaks]) to the shared diagnostics log (shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing in the patch or Reading Log. It records:
  • What's there when the window opens: Reading Log Tweaks and Reading Log
    versions, the Side Panel (compact window, BookOrbit covers, Download),
    whether BookOrbit is signed in (yes/no only), the BookOrbit list kept
    for Random pick and Collecting Dust (books, age), each card's source
    (Stock / BookOrbit / Both), Switch Cards By, and the Reading Log Tweaks
    settings that change what's drawn.
  • Every card drawn, by name: how long it took. 100 ms or more is logged
    as it happens (a card inside a Smart Card or swipe spot says so). A
    page drawn in one go (cards right after each other) is logged when it
    took 150 ms or more, with its slowest card.
  • Every tap on a card: the card, the spot tapped and how long it took.
  • Reading Log's data calls (the library, stats, the year...) taking
    50 ms or more, and totals per call.
  • Random pick: how many books it chose from and how many came from
    BookOrbit, and how long that took.
  • Covers: on-device and BookOrbit ones, how long they took and how many
    weren't there yet (a BookOrbit cover not cached is fetched once).
  • The BookOrbit list being refreshed (in the background), settings
    writes per key (a key written over and over is a battery cost), and
    home screen redraws asked for.
  • Shared perf core: Reading Log Tweaks timers that hold the screen 80 ms+,
    flashes it asks for, its warnings and errors, timers left waiting when
    the device sleeps (should be none), and a once-a-minute perf line.
  • Crash hunt (1.1.0): drawing that reaches past its canvas ("outside"),
    each Dashboard painted onto the screen image ("paint" ... "paint end";
    a "paint" with no "end" is where KOReader died), pixels Reading Log
    caught past the edge ("clipped"), where a downloaded style draws the
    tab bar, and every style change.
  • Dark Academia step by step (1.1.2): while it's on, "A:" lines for each
    card's build and paint, start and end.
  • Colours (1.1.1): your theme and accents before and after each style
    change, and any other change to them with what made it.
  • A summary with hints when the window closes.

Battery safety (in case you forget to delete it):
  • Logs for 15 minutes, starting the first time a Reading Log card is
    drawn after KOReader starts. Then it writes a summary and goes quiet
    until the next restart. One window per restart.
  • After 24 hours it stops for good: it loads, sees it's expired, and does
    nothing. The start time is kept in its own state file
    (readinglog-tweaks-diagnostics.state), so nothing is saved in KOReader's
    or Reading Log's settings. Delete the state file for a fresh 24h.
  • No background polling and no timers of its own. The window just closes
    once 15 minutes have passed. Lines go to the shared diagnostics.log
    (2 MB rotation, older part kept as diagnostics.log.old).

How to use:
  1. Put this file in koreader/patches/ next to 2-readinglog-tweaks.lua and
     restart KOReader.
  2. Within 15 minutes: open the Dashboard and go through every tab, tap a
     few covers (Continue reading, Random pick, Collecting Dust), Another on
     Random pick, open and close a book, let it sleep and wake it, come back
     to the Dashboard.
  3. Send diagnostics.log (the [readinglog-tweaks] lines).
  4. Delete this file and restart.
The "zz" makes it load after Reading Log Tweaks.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local ok_time, ktime = pcall(require, "ui/time")

local DIAG_VERSION = "1.1.4"
local DIAG_TAG = "readinglog-tweaks"   -- = the filename stem (Debugging Menu)
local DATA = DataStorage:getDataDir()
local STATE = DATA .. "/" .. DIAG_TAG .. "-diagnostics.state"
local MAIN_FILE = DATA .. "/patches/2-readinglog-tweaks.lua"
local MAIN_TAG = "2-readinglog-tweaks.lua"   -- in the patch's source path
local WINDOW_S = 15 * 60
local EXPIRE_S = 24 * 60 * 60
local SLOW_CARD_MS = 100   -- a card this slow is logged as it happens
local SLOW_PAGE_MS = 150   -- a whole page this slow is logged
local SLOW_DATA_MS = 50    -- a data call this slow is logged
local BURST_GAP_MS = 400   -- cards drawn closer than this are one page

-- --------------------------------------------------------------------------
-- Shared log contract v1
-- --------------------------------------------------------------------------

local SHARED_LOG = DATA .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
-- One line per entry: line breaks (multi-line popups and messages) are
-- joined with " / ", and the invisible text-direction marks KOReader puts
-- around file paths are removed, so every line keeps its time and tag.
local DIAG_BIDI = { "\226\129\166", "\226\129\167", "\226\129\168", "\226\129\169",
    "\226\128\170", "\226\128\171", "\226\128\172", "\226\128\173", "\226\128\174" }
local function diagOneLine(s)
    s = tostring(s)
    for _i, m in ipairs(DIAG_BIDI) do s = s:gsub(m, "") end
    s = s:gsub("%s*[\r\n]+%s*", " / ")
    return s
end

local function shared_log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    pcall(function()
        if (lfs.attributes(SHARED_LOG, "size") or 0) > SHARED_MAX_BYTES then
            os.remove(SHARED_LOG .. ".old")
            os.rename(SHARED_LOG, SHARED_LOG .. ".old")
        end
        local f = io.open(SHARED_LOG, "a")
        if not f then return end
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", diagOneLine(line), "\n")
        f:close()
    end)
end

-- --------------------------------------------------------------------------
-- Shared notification contract v1
-- --------------------------------------------------------------------------

local function shared_note(banner_text, minimal_text, timeout)
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local NetworkMgr = require("ui/network/manager")
    if type(NetworkMgr.__network_tweaks_note) == "function" then
        local ok, handled = pcall(NetworkMgr.__network_tweaks_note, banner_text, minimal_text, timeout)
        if ok and handled then return true end
    end
    local rm = _G.__readmastery_note
    if type(rm) == "function" then
        local ok, handled = pcall(rm, banner_text or minimal_text, timeout)
        if ok and handled then return true end
    end
    return false
end

-- --------------------------------------------------------------------------
-- Expiry (state file) and the logging window (no timers)
-- --------------------------------------------------------------------------

local function readStamp()
    local f = io.open(STATE, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    -- "<version> started <time>": another version starts a new 24 hours
    local v, t = (line or ""):match("^(%S+) started (%d+)")
    if v ~= DIAG_VERSION then return nil end
    return tonumber(t)
end

local started = readStamp()
if not started then
    started = os.time()
    local f = io.open(STATE, "w")
    if f then f:write(DIAG_VERSION .. " started " .. started .. "\n") f:close() end
    shared_log("==================== Reading Log Tweaks diagnostics %s first run ====================  [# started %d]",
        DIAG_VERSION, started)
end
if os.difftime(os.time(), started) > EXPIRE_S then
    shared_log("expired (first ran more than 24h ago): doing nothing. Delete this patch.")
    logger.info("readinglog tweaks diagnostics: expired, inactive")
    return
end

local function now() return ok_time and ktime.now() or nil end
local function us(since)
    if not (ok_time and since) then return 0 end
    local ok, v = pcall(function() return ktime.to_us(ktime.since(since)) end)
    return ok and v or 0
end
local function f1(u) return string.format("%.1f", (u or 0) / 1000) end
local function q(v) return v == nil and "(nil)" or tostring(v) end
local function pk(...) return { n = select("#", ...), ... } end
local function mem() return collectgarbage("count") end

local window_start, window_start_s
local window_open, window_done = false, false
local closeWindow

local function elapsedS()
    if window_start_s then return os.time() - window_start_s end
    return 0
end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    local off = window_start and math.floor(us(window_start) / 1000) or 0
    shared_log("%s", string.format("+%7dms  ", off) .. line)
end

local function active()
    if window_open and elapsedS() >= WINDOW_S then closeWindow() end
    return window_open
end

-- --------------------------------------------------------------------------
-- Counters
-- --------------------------------------------------------------------------

local function bucket() return { n = 0, us = 0, max = 0 } end
local function add(b, u)
    b.n, b.us = b.n + 1, b.us + u
    if u > b.max then b.max = u end
end

local stats = {
    cards = {},      -- card name -> bucket (every build, nested included)
    taps = {},       -- card name -> bucket
    data = {},       -- D.<name> -> bucket
    sets = {},       -- setting key -> writes
    pages = bucket(), page_max_cards = 0,
    picks = bucket(), pick_bo_max = 0, pick_max = 0,
    cover_dev = bucket(), cover_dev_miss = 0,
    cover_bo = bucket(), cover_bo_miss = 0,
    redraws = 0, bo_refreshes = 0,
    mem_open = 0,
}
local A_ref -- Reading Log's kit, once found

-- crash hunt (1.1.0): its counters and helpers (see "Crash hunt" below)
local HUNT_MAX = 60          -- "outside" lines per window (then only counted)
local PAINT_LOG_MAX = 300    -- "paint" lines per window
local BIG_PX = 150000        -- a canvas this big is a page, not a small card
local hunt = { outside = 0, outside_logged = 0, paints = 0, clipped = 0, paint_clipped = 0, seen = {} }

local function caller(skip)
    for lvl = skip or 3, 14 do
        local info = debug.getinfo(lvl, "Sl")
        if not info then break end
        local src = tostring(info.short_src or info.source or "?")
        if not src:find("init%.lua$") and not src:find("diagnostics%.lua$") then
            return (src:match("[^/]+/[^/]+$") or src) .. ":" .. tostring(info.currentline or "?")
        end
    end
    return "?"
end

local function styleName(A)
    local okS, s = pcall(function() return A.styleNow and A.styleNow() end)
    local okP, pack = pcall(function() return A.get("style_pack", nil) end)
    pack = okP and pack or nil
    return tostring(okS and s or "?") .. (pack and (" (pack " .. tostring(pack) .. ")") or "")
end

-- 1.1.2: Dark Academia on (the style the crashes follow); the step-by-step
-- lines below are written only then
local function academiaOn(A)
    if type(A) ~= "table" then return false end
    local ok, on = pcall(function()
        if type(A.academiaTheme) == "function" and A.academiaTheme() then return true end
        return type(A.styleNow) == "function" and A.styleNow() == "academia"
    end)
    return ok and on and true or false
end
local SMALL_PX = 20000 -- an unnamed canvas smaller than this isn't logged step by step
-- 1.1.3: the card the crashes die in, painted one drawing step at a time
-- (each step: where in Reading Log's code it was asked for), and inside a
-- Dark Academia step each shape and text it paints
local STEP_CARDS = { activity = true }
local SUB_STEPS = false  -- 1.1.3's shape-by-shape lines (off in 1.1.4: they hid the crash)
local acad_now = false            -- Dark Academia on at the last card build
local function Blitbuffer_isColour(c)
    local ok, BB = pcall(require, "ffi/blitbuffer")
    if not (ok and type(BB) == "table" and type(BB.isColor8) == "function") then return "?" end
    local ok2, grey = pcall(BB.isColor8, c)
    return ok2 and not grey or "?"
end
local opsrc = setmetatable({}, { __mode = "k" })   -- step -> code that asked for it
local in_ac_step = false          -- painting a step from academia.lua now
local sub_n = 0

-- your colours (1.1.1): the theme and both accents as saved, and the theme
-- in use ("(default)" = nothing saved, Reading Log's default)
local function colourVal(v)
    if v == nil or v == false then return "(default)" end
    if type(v) == "table" then
        local parts = {}
        for i = 1, math.min(4, #v) do parts[#parts + 1] = tostring(v[i]) end
        if #parts > 0 then return "{" .. table.concat(parts, ",") .. "}" end
        return tostring(v.id or v.name or "table")
    end
    return tostring(v)
end
local function colours(A)
    local function g(k)
        local ok, v = pcall(function() return A.get(k, nil) end)
        return ok and v or nil
    end
    local okT, tid = pcall(function() return A.themeId and A.themeId() end)
    return string.format("theme %s (in use %s), accent %s, accent2 %s", colourVal(g("theme")),
        tostring(okT and tid or "?"), colourVal(g("accent")), colourVal(g("accent2")))
end
local in_style = false



local function avg(b) return b.n > 0 and f1(b.us / b.n) or "0.0" end

-- The biggest entries of a name -> bucket table, by total time.
local function top(t, k)
    local list = {}
    for name, b in pairs(t) do list[#list + 1] = { name = name, b = b } end
    table.sort(list, function(x, y) return x.b.us > y.b.us end)
    local out = {}
    for i = 1, math.min(k, #list) do
        local e = list[i]
        out[#out + 1] = string.format("%s %dx avg %s max %s ms", e.name, e.b.n, avg(e.b), f1(e.b.max))
    end
    return out, list
end

local function summary(why)
    log("---- summary (%s) ----", why)
    log("crash hunt: %d drawing steps past their canvas (%d logged), %d Dashboard paints, %d pixels clipped",
        hunt.outside, hunt.outside_logged, hunt.paints, hunt.clipped)
    local cards, card_list = top(stats.cards, 12)
    log("cards drawn (by total time): %s", #cards > 0 and table.concat(cards, " | ") or "none")
    log("pages drawn: %d, avg %s ms, slowest %s ms (up to %d cards)",
        stats.pages.n, avg(stats.pages), f1(stats.pages.max), stats.page_max_cards)
    local taps = top(stats.taps, 10)
    log("taps: %s", #taps > 0 and table.concat(taps, " | ") or "none")
    local data, data_list = top(stats.data, 10)
    log("Reading Log data calls: %s", #data > 0 and table.concat(data, " | ") or "none")
    log("Random pick lists: %d, avg %s ms, slowest %s ms, up to %d books (%d from BookOrbit)",
        stats.picks.n, avg(stats.picks), f1(stats.picks.max), stats.pick_max, stats.pick_bo_max)
    log("covers on the device: %d, avg %s ms, slowest %s ms, %d not there | BookOrbit covers: %d, avg %s ms, slowest %s ms, %d not cached yet",
        stats.cover_dev.n, avg(stats.cover_dev), f1(stats.cover_dev.max), stats.cover_dev_miss,
        stats.cover_bo.n, avg(stats.cover_bo), f1(stats.cover_bo.max), stats.cover_bo_miss)
    local sets, total_sets = {}, 0
    for k, n in pairs(stats.sets) do sets[#sets + 1] = { k = k, n = n }; total_sets = total_sets + n end
    table.sort(sets, function(x, y) return x.n > y.n end)
    local bits = {}
    for i = 1, math.min(8, #sets) do bits[#bits + 1] = sets[i].k .. " " .. sets[i].n .. "x" end
    log("settings writes: %d (%s) | home redraws asked: %d | BookOrbit list refreshes: %d",
        total_sets, #bits > 0 and table.concat(bits, ", ") or "none", stats.redraws, stats.bo_refreshes)
    local m = mem()
    log("Lua memory: %d KB (was %d KB when the window opened)", math.floor(m), math.floor(stats.mem_open))

    -- Hints: what the numbers suggest. A Clara Colour is the yardstick: older
    -- or slower devices take about 2-3 times as long.
    local hints = {}
    for _i, e in ipairs(card_list) do
        if e.b.n > 0 and e.b.us / e.b.n >= SLOW_CARD_MS * 1000 then
            hints[#hints + 1] = string.format("card %s is slow (avg %s ms): on a slower device expect 2-3x", e.name, avg(e.b))
        end
    end
    if stats.pages.max >= 400000 then
        hints[#hints + 1] = string.format("a page took %s ms to draw: the slowest cards above are where it goes", f1(stats.pages.max))
    end
    for _i, e in ipairs(data_list) do
        if e.b.n > 0 and e.b.us / e.b.n >= SLOW_DATA_MS * 1000 then
            hints[#hints + 1] = string.format("data call %s is slow (avg %s ms)", e.name, avg(e.b))
        end
    end
    if stats.picks.n > 0 and stats.picks.us / stats.picks.n >= 30000 then
        hints[#hints + 1] = string.format("Random pick list is slow (avg %s ms)", avg(stats.picks))
    end
    if stats.cover_bo_miss > 0 then
        hints[#hints + 1] = string.format("%d BookOrbit cover(s) weren't cached yet: fetched once with Wi-Fi, then kept", stats.cover_bo_miss)
    end
    for _i, s in ipairs(sets) do
        if s.n >= 20 then hints[#hints + 1] = string.format("setting %s written %d times: each write costs battery", s.k, s.n) end
    end
    if m - stats.mem_open > 4096 then
        hints[#hints + 1] = string.format("Lua memory grew %d KB during the window", math.floor(m - stats.mem_open))
    end
    if #hints == 0 then hints[1] = "Nothing slow enough to worry about" end
    for i, h in ipairs(hints) do log("hint %d: %s", i, h) end
end

closeWindow = function()
    if not window_open then return end
    window_open = false -- before summary: summary's log() mustn't re-enter
    summary("15 minutes up")
    log("logging stopped until next restart (delete this patch when done)")
    window_done = true
    if not shared_note("Diagnostics: done, log written") then
        pcall(function() require("ui/widget/notification"):notify("Diagnostics: done, log written") end)
    end
end

local function onOff(v) return v and "on" or "off" end

local function snapshot(A)
    local f = io.open(MAIN_FILE, "r")
    local file_v
    if f then
        local head = f:read(600) or ""
        f:close()
        file_v = head:match("Version:%s*([%d%.]+)")
    end
    log("Reading Log Tweaks %s (file %s) | Reading Log %s | Lua memory: %d KB",
        q(A and A._rl_tweaks or nil), file_v or "not found at " .. MAIN_FILE, q(A and A.VERSION), math.floor(mem()))
    if A and not A._rl_tweaks then
        log("CHECK: Reading Log Tweaks didn't apply (look for its warning in crash.log)")
    end
    local SP = package.loaded.simpleui_sidepanel
    log("Side Panel: %s | compact window %s | BookOrbit covers %s | Download %s",
        type(SP) == "table" and "loaded" or "not loaded",
        onOff(type(SP) == "table" and type(SP.showCompactBookDetail) == "function"),
        onOff(type(SP) == "table" and type(SP.boCoverPath) == "function"),
        onOff(type(SP) == "table" and type(SP.boDownload) == "function"))
    local st = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    local signed = type(st) == "table" and st.server_url and st.username and st.userkey and true or false
    log("BookOrbit: plugin %s | signed in %s", package.loaded["bookorbit_api"] and "loaded" or "not loaded yet", signed and "yes" or "no")
    if A and type(A.get) == "function" then
        local function g(k, d)
            local ok, v = pcall(A.get, k, d)
            return ok and v or d
        end
        local lib = g("rlt_bo_lib", nil)
        if type(lib) == "table" and type(lib.books) == "table" then
            log("BookOrbit list kept: %d books, refreshed %.1f h ago", #lib.books, (os.time() - (tonumber(lib.at) or 0)) / 3600)
        else
            log("BookOrbit list kept: none yet (fetched in the background with Wi-Fi on)")
        end
        log("settings: Book Tap Opens %s | Enter From Side %s | Quote Of The Day %s | Hold A Cover %s | Today card %s | Start tab %s",
            q(g("rlt_book_tap", "default")), onOff(g("rlt_enter_side", true) ~= false),
            q(g("rlt_quote_source", "simpleui")), onOff(g("rlt_cover_hold", true) ~= false),
            q(g("rlt_today_card", "default")), q(g("rlt_start_tab", "last")))
        log("style: %s | Move Tab Row %s | Change Style Each Month %s",
            styleName(A), q(g("rlt_tabs_move", 0)), onOff(g("rlt_month_style", false) == true))
        log("colours: %s", colours(A))
        local src = A.state and A.state.rlt_src
        if type(src) == "table" and type(src.of) == "function" then
            local bits = {}
            for _i, k in ipairs(src.cards or {}) do
                local ok, v = pcall(src.of, k)
                bits[#bits + 1] = k .. " " .. (ok and tostring(v) or "?")
            end
            log("sources: %s | BookOrbit usable %s | Switch Cards By %s | Collecting Dust side %s | Discover side %s (without BookOrbit: %s)",
                table.concat(bits, ", "), onOff(pcall(src.avail) and src.avail()), q(g("rlt_switch_by", "tap")),
                onOff(g("rlt_pair_dust", true) ~= false), onOff(g("rlt_pair_discover", true) ~= false),
                q(g("rlt_discover_stock", "new")))
        end
    end
end

local function openWindow()
    if window_open or window_done then return end
    window_open = true
    window_start = now()
    window_start_s = os.time()
    stats.mem_open = mem()
    log("==================== Reading Log Tweaks diagnostics %s: 15-minute window ====================", DIAG_VERSION)
    pcall(snapshot, A_ref)
end

-- --------------------------------------------------------------------------
-- Hooks on Reading Log's kit (after Reading Log Tweaks applied)
-- --------------------------------------------------------------------------

local wrapped = setmetatable({}, { __mode = "k" })
local depth = 0
-- a page: cards drawn right after each other
local page = nil   -- { us, cards, slowest, slowest_us, last }
local function closePage()
    if not page then return end
    local p = page
    page = nil
    if p.cards < 2 then return end
    add(stats.pages, p.us)
    if p.cards > stats.page_max_cards then stats.page_max_cards = p.cards end
    if p.us >= SLOW_PAGE_MS * 1000 then
        log("page drawn: %d cards in %s ms, slowest %s %s ms", p.cards, f1(p.us), p.slowest, f1(p.slowest_us))
    end
end

local function wrapCard(name, def)
    if type(def) ~= "table" then return end
    if type(def.build) == "function" and wrapped[def.build] == nil then
        local orig = def.build
        local fn = function(env, ...)
            if not window_open and not window_done then openWindow() end
            if not active() then return orig(env, ...) end
            local sample = type(env) == "table" and env.sample
            if depth == 0 and page and us(page.last) >= BURST_GAP_MS * 1000 then closePage() end
            local t = now()
            local acad = academiaOn(A_ref)
            acad_now = acad
            if acad then log("A: card %s build start (%sx%s)", name, q(type(env) == "table" and env.w), q(type(env) == "table" and env.h)) end
            depth = depth + 1
            local res = pk(pcall(orig, env, ...))
            depth = depth - 1
            local took = us(t)
            -- the card's canvas carries its name, for the paint lines
            if res[1] and type(res[2]) == "table" then pcall(function() res[2]._rltd_name = name end) end
            if acad then log("A: card %s build end", name) end
            local key = sample and (name .. " (sample)") or name
            stats.cards[key] = stats.cards[key] or bucket()
            add(stats.cards[key], took)
            if not res[1] then
                log("ERROR card %s failed to draw: %s", name, tostring(res[2]))
                error(res[2], 0)
            end
            if took >= SLOW_CARD_MS * 1000 then
                log("slow card: %s took %s ms (%sx%s%s%s)", name, f1(took),
                    q(type(env) == "table" and env.w), q(type(env) == "table" and env.h),
                    depth > 0 and ", inside another card" or "", sample and ", sample" or "")
            end
            if depth == 0 and not sample then
                page = page or { us = 0, cards = 0, slowest_us = 0 }
                page.us, page.cards = page.us + took, page.cards + 1
                if took > page.slowest_us then page.slowest, page.slowest_us = name, took end
                page.last = now()
            end
            return unpack(res, 2, res.n)
        end
        wrapped[fn] = true
        def.build = fn
    end
    if type(def.tap) == "function" and wrapped[def.tap] == nil then
        local orig = def.tap
        local fn = function(env, region, ...)
            if not active() then return orig(env, region, ...) end
            closePage()
            local t = now()
            local res = pk(pcall(orig, env, region, ...))
            local took = us(t)
            stats.taps[name] = stats.taps[name] or bucket()
            add(stats.taps[name], took)
            if not res[1] then
                log("ERROR tap on %s (%s) failed: %s", name, q(region), tostring(res[2]))
                error(res[2], 0)
            end
            log("tap: %s, spot %s, %s ms", name, q(region), f1(took))
            return unpack(res, 2, res.n)
        end
        wrapped[fn] = true
        def.tap = fn
    end
end

local function isBo(fp) return type(fp) == "string" and fp:match("^bookorbit:%d+$") ~= nil end

local function wrapData(D)
    for name, orig in pairs(D) do
        if type(orig) == "function" and not wrapped[orig] and type(name) == "string" and not name:match("^_") then
            local fn
            if name == "cover" then
                fn = function(fp, ...)
                    if not active() then return orig(fp, ...) end
                    local t = now()
                    local res = pk(orig(fp, ...))
                    local took = us(t)
                    if isBo(fp) then
                        add(stats.cover_bo, took)
                        if res[1] == nil then stats.cover_bo_miss = stats.cover_bo_miss + 1 end
                    else
                        add(stats.cover_dev, took)
                        if res[1] == nil then stats.cover_dev_miss = stats.cover_dev_miss + 1 end
                    end
                    if took >= SLOW_DATA_MS * 1000 then
                        log("slow cover: %s %s ms", isBo(fp) and fp or "(on device)", f1(took))
                    end
                    return unpack(res, 1, res.n)
                end
            elseif name == "pickCandidates" then
                fn = function(...)
                    if not active() then return orig(...) end
                    local t = now()
                    local res = pk(orig(...))
                    local took = us(t)
                    add(stats.picks, took)
                    local n, bo = 0, 0
                    if type(res[1]) == "table" then
                        for _i, b in ipairs(res[1]) do
                            n = n + 1
                            if type(b) == "table" and isBo(b.fp) then bo = bo + 1 end
                        end
                    end
                    if n > stats.pick_max then stats.pick_max = n end
                    if bo > stats.pick_bo_max then stats.pick_bo_max = bo end
                    log("Random pick chose from %d books (%d from BookOrbit) in %s ms", n, bo, f1(took))
                    return unpack(res, 1, res.n)
                end
            else
                fn = function(...)
                    if not active() then return orig(...) end
                    local t = now()
                    local res = pk(orig(...))
                    local took = us(t)
                    local key = "D." .. name
                    stats.data[key] = stats.data[key] or bucket()
                    add(stats.data[key], took)
                    if took >= SLOW_DATA_MS * 1000 then log("slow data call: %s %s ms", key, f1(took)) end
                    return unpack(res, 1, res.n)
                end
            end
            wrapped[fn] = true
            D[name] = fn
        end
    end
end

-- --------------------------------------------------------------------------
-- Crash hunt (1.1.0): where drawing goes outside what it's drawn into
-- --------------------------------------------------------------------------
-- Reading Log draws each card on a canvas: the drawing steps are written
-- down first and painted onto the screen image later. A step that reaches
-- past the canvas, or a canvas painted past the screen image, is what can
-- write into memory beside it and crash KOReader a moment later (a
-- segfault, with no Lua error). Each line is written straight to the file,
-- so the last ones before a crash are kept.
--   • "outside": a drawing step reaching past its canvas, with the step,
--     its numbers, the canvas size and the code that asked for it.
--   • "paint": each big canvas (the Dashboard) painted onto the screen
--     image: its size and place, the image's size, the style, and "end"
--     once it's done. A "paint" with no "end" after it is where it died.
--   • "clipped": pixels Reading Log itself caught going past the edge
--     (it skips them).
--   • "tab bar": where a downloaded style is asked to draw the tab bar.
--   • "style": every style change, and what changed it.
local function hookCrashHunt(A)
    if A._rltd_hunt then return end
    A._rltd_hunt = true
    -- pixels Reading Log caught past the edge
    local prev_oob = A._oob
    A._oob = function(x, y, bw, bh, ...)
        if window_open then
            hunt.clipped = hunt.clipped + 1
            hunt.paint_clipped = hunt.paint_clipped + 1
            if hunt.clipped <= 10 then
                log("clipped: pixel at %s,%s on a %sx%s image, from %s", q(x), q(y), q(bw), q(bh), caller(3))
            end
        end
        if type(prev_oob) == "function" then return prev_oob(x, y, bw, bh, ...) end
    end
    -- the canvas class, from the first canvas made
    local function hookCanvas(C)
        if type(C) ~= "table" or C._rltd_hunt then return end
        C._rltd_hunt = true
        local function outside(self, what, x, y, w, h)
            if not window_open then return end
            x, y, w, h = tonumber(x), tonumber(y), tonumber(w) or 0, tonumber(h) or 0
            if not (x and y) then return end
            local cw, ch = tonumber(self.w) or 0, tonumber(self.h) or 0
            if x >= -1 and y >= -1 and x + w <= cw + 1 and y + h <= ch + 1 then return end
            hunt.outside = hunt.outside + 1
            local from = caller(4)
            local key = what .. "@" .. from
            hunt.seen[key] = (hunt.seen[key] or 0) + 1
            if hunt.seen[key] > 3 or hunt.outside_logged >= HUNT_MAX then return end
            hunt.outside_logged = hunt.outside_logged + 1
            log("outside: %s x=%d y=%d w=%d h=%d on a %dx%d canvas, from %s",
                what, math.floor(x), math.floor(y), math.floor(w), math.floor(h), cw, ch, from)
        end
        -- (x, y, w, h, ...) steps
        for _i, name in ipairs({ "rect", "rrect", "frame" }) do
            local orig = C[name]
            if type(orig) == "function" then
                C[name] = function(self, x, y, w, h, ...)
                    outside(self, name, x, y, w, h)
                    return orig(self, x, y, w, h, ...)
                end
            end
        end
        -- (file, x, y, w, h, ...) steps
        for _i, name in ipairs({ "image", "cover" }) do
            local orig = C[name]
            if type(orig) == "function" then
                C[name] = function(self, fp, x, y, w, h, ...)
                    outside(self, name, x, y, w, h)
                    return orig(self, fp, x, y, w, h, ...)
                end
            end
        end
        -- (cx, cy, r, ...) steps
        for _i, name in ipairs({ "disc", "ring" }) do
            local orig = C[name]
            if type(orig) == "function" then
                C[name] = function(self, cx, cy, r, ...)
                    local rr = tonumber(r) or 0
                    if tonumber(cx) and tonumber(cy) then outside(self, name, cx - rr, cy - rr, 2 * rr, 2 * rr) end
                    return orig(self, cx, cy, r, ...)
                end
            end
        end
        if type(C.tilted) == "function" then
            local orig = C.tilted
            C.tilted = function(self, fp, cx, cy, w, h, ...)
                if tonumber(cx) and tonumber(cy) and tonumber(w) and tonumber(h) then
                    local d = math.sqrt(w * w + h * h) / 2 -- turned: its corners reach this far
                    outside(self, "tilted", cx - d, cy - d, 2 * d, 2 * d)
                end
                return orig(self, fp, cx, cy, w, h, ...)
            end
        end
        if type(C.polyline) == "function" then
            local orig = C.polyline
            C.polyline = function(self, pts, lw, ...)
                if window_open and type(pts) == "table" and #pts >= 4 then
                    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
                    for i = 1, #pts - 1, 2 do
                        local px, py = tonumber(pts[i]), tonumber(pts[i + 1])
                        if px and py then
                            if px < minx then minx = px end
                            if px > maxx then maxx = px end
                            if py < miny then miny = py end
                            if py > maxy then maxy = py end
                        end
                    end
                    local r = (tonumber(lw) or 0) / 2
                    if minx <= maxx then
                        outside(self, "polyline", minx - r, miny - r, maxx - minx + 2 * r, maxy - miny + 2 * r)
                    end
                end
                return orig(self, pts, lw, ...)
            end
        end
        if type(C.sub) == "function" then
            local orig = C.sub
            C.sub = function(self, child, x, y, ...)
                if type(child) == "table" then outside(self, "card canvas", x, y, child.w, child.h) end
                return orig(self, child, x, y, ...)
            end
        end
        -- a big canvas (the Dashboard) painted onto the screen image
        -- 1.1.3: where each drawing step was asked for (Dark Academia only)
        if type(C.op) == "function" then
            local orig = C.op
            C.op = function(self, fn, ...)
                if acad_now and window_open and type(fn) == "function" then opsrc[fn] = caller(3) end
                return orig(self, fn, ...)
            end
        end
        -- inside a Dark Academia step: each shape and text, before it's painted
        local G = A.G
        if type(G) == "table" then
            for _i, nm in ipairs({ "ring", "polyline", "disc", "rect", "rrect", "frame" }) do
                local origG = G[nm]
                if type(origG) == "function" then
                    G[nm] = function(bb, a1, a2, a3, ...)
                        if in_ac_step then
                            sub_n = sub_n + 1
                            if nm == "polyline" then
                                local pts = type(a1) == "table" and a1 or {}
                                log("A:     %d %s %d points from %s,%s lw %s", sub_n, nm, math.floor(#pts / 2),
                                    q(pts[1]), q(pts[2]), q(a2))
                            else
                                log("A:     %d %s %s,%s,%s", sub_n, nm, q(a1), q(a2), q(a3))
                            end
                        end
                        return origG(bb, a1, a2, a3, ...)
                    end
                end
            end
        end
        local okT, TC = pcall(function() return A.host and A.host.textClass and A.host.textClass() end)
        if okT and type(TC) == "table" and type(TC.paintTo) == "function" and not TC._rltd_hunt then
            TC._rltd_hunt = true
            local origP = TC.paintTo
            TC.paintTo = function(self, bb, x, y, ...)
                if in_ac_step then
                    sub_n = sub_n + 1
                    local okW, bw = pcall(function() return bb:getWidth() end)
                    local okH, bh = pcall(function() return bb:getHeight() end)
                    log("A:     %d text '%s' at %s,%s on a %sx%s image, colour ink %s, freed %s", sub_n,
                        tostring(self.text), q(x), q(y), okW and q(bw) or "?", okH and q(bh) or "?",
                        q(type(self.fgcolor) ~= "nil" and Blitbuffer_isColour(self.fgcolor)),
                        q(self._xtext == nil and self._xshaping == nil))
                end
                return origP(self, bb, x, y, ...)
            end
        end
        if type(C.paintTo) == "function" then
            local orig = C.paintTo
            C.paintTo = function(self, bb, x, y, nested, ...)
                local cw, ch = tonumber(self.w) or 0, tonumber(self.h) or 0
                -- 1.1.2: with Dark Academia on, every card's paint, start and
                -- end (a start with no end is where KOReader died)
                if window_open and academiaOn(A) and (self._rltd_name or cw * ch >= SMALL_PX) then
                    local label = self._rltd_name or string.format("canvas %dx%d", cw, ch)
                    log("A: paint %s start (%dx%d at %s,%s%s, %d steps, Lua %d KB)", label, cw, ch, q(x), q(y),
                        nested and ", inside another" or "", type(self.ops) == "table" and #self.ops or -1, math.floor(mem()))
                    local saved
                    if STEP_CARDS[label] and type(self.ops) == "table" then
                        saved = self.ops
                        local stepped, n = {}, #saved
                        for i, op in ipairs(saved) do
                            local src = opsrc[op] or "?"
                            -- 1.1.4: one line before each step and nothing
                            -- else, so it paints at close to normal speed (the
                            -- step-by-step detail of 1.1.3 slowed it enough
                            -- that the crash didn't come). A step's end is the
                            -- next step's line, or "paint activity end".
                            stepped[i] = function(...)
                                log("A:   step %d/%d %s", i, n, src)
                                if SUB_STEPS then
                                    local was = in_ac_step
                                    in_ac_step = src:find("academia", 1, true) ~= nil
                                    sub_n = 0
                                    local r = pk(pcall(op, ...))
                                    in_ac_step = was
                                    if not r[1] then error(r[2], 0) end
                                    return unpack(r, 2, r.n)
                                end
                                return op(...)
                            end
                        end
                        self.ops = stepped
                    end
                    local res = pk(pcall(orig, self, bb, x, y, nested, ...))
                    if saved then self.ops = saved end
                    log("A: paint %s end", label)
                    if not res[1] then error(res[2], 0) end
                    return unpack(res, 2, res.n)
                end
                if not (window_open and not nested and cw * ch >= BIG_PX and type(bb) == "table") then
                    return orig(self, bb, x, y, nested, ...)
                end
                local okW, bw = pcall(function() return bb:getWidth() end)
                local okH, bh = pcall(function() return bb:getHeight() end)
                bw, bh = okW and tonumber(bw) or -1, okH and tonumber(bh) or -1
                local px, py = tonumber(x) or 0, tonumber(y) or 0
                local past = bw > 0 and (px < 0 or py < 0 or px + cw > bw or py + ch > bh)
                hunt.paints = hunt.paints + 1
                hunt.paint_clipped = 0
                local logit = past or hunt.paints <= PAINT_LOG_MAX
                if logit then
                    log("paint%s: %dx%d canvas at %d,%d onto a %dx%d image, %d steps, style %s, Lua %d KB",
                        past and " PAST THE IMAGE" or "", cw, ch, px, py, bw, bh,
                        type(self.ops) == "table" and #self.ops or -1, styleName(A), math.floor(mem()))
                end
                local t0 = now()
                local res = pk(orig(self, bb, x, y, nested, ...))
                if logit then
                    log("paint end: %s ms%s", f1(us(t0)),
                        hunt.paint_clipped > 0 and (", " .. hunt.paint_clipped .. " pixels clipped") or "")
                end
                return unpack(res, 1, res.n)
            end
        end
        log("crash hunt: watching Reading Log's drawing")
    end
    if type(A.canvas) == "function" then
        local orig = A.canvas
        A.canvas = function(o, ...)
            local c = orig(o, ...)
            if type(c) == "table" and not hunt.canvas_hooked then
                hunt.canvas_hooked = true
                local mt = getmetatable(c)
                if type(mt) == "table" and rawget(mt, "paintTo") == nil and type(mt.__index) == "table" then mt = mt.__index end
                local ok, err = pcall(hookCanvas, mt)
                if not ok then log("crash hunt: couldn't watch the canvas: %s", tostring(err)) end
            end
            return c
        end
    end
    -- where a downloaded style is asked to draw the tab bar
    if type(A.packTabs) == "function" then
        local orig = A.packTabs
        A.packTabs = function(c, x, y, w, h, ...)
            local drew = orig(c, x, y, w, h, ...)
            if window_open then
                local cw, ch = type(c) == "table" and c.w, type(c) == "table" and c.h
                local sig = table.concat({ q(x), q(y), q(w), q(h), q(cw), q(ch), q(drew) }, "|")
                if not hunt.seen["tabs " .. sig] then
                    hunt.seen["tabs " .. sig] = true
                    log("tab bar: style %s, row x=%s y=%s w=%s h=%s on a %sx%s canvas, the style drew it: %s, from %s",
                        styleName(A), q(x), q(y), q(w), q(h), q(cw), q(ch), drew and "yes" or "no", caller(3))
                end
            end
            return drew
        end
    end
    -- every style change
    if type(A.setStyle) == "function" then
        local orig = A.setStyle
        A.setStyle = function(v, ...)
            local was, was_c = styleName(A), colours(A)
            in_style = true
            local res = pk(pcall(orig, v, ...))
            in_style = false
            if window_open then
                log("style: %s -> %s (asked %s), from %s", was, styleName(A), q(v), caller(3))
                local now_c = colours(A)
                log("colours: %s%s", was_c == now_c and "unchanged, " or (was_c .. " -> "), now_c)
            end
            if not res[1] then error(res[2], 0) end
            return unpack(res, 2, res.n)
        end
    end
end

local function hookKit(A)
    if type(A) ~= "table" or A._rltd_hooked then return end
    A._rltd_hooked = true
    A_ref = A
    pcall(hookCrashHunt, A)
    local P, D, H = A.panels, A.D, A.host
    if type(P) == "table" then
        for name, def in pairs(P) do pcall(wrapCard, name, def) end
        -- cards added later (Reading Log adds some on demand)
        local mt = getmetatable(P)
        if mt == nil then
            setmetatable(P, { __newindex = function(t, k, v)
                rawset(t, k, v)
                pcall(wrapCard, k, v)
            end })
        end
    end
    if type(D) == "table" then pcall(wrapData, D) end
    if type(H) == "table" and type(H.redrawAll) == "function" and not wrapped[H.redrawAll] then
        local orig = H.redrawAll
        local fn = function(...)
            if active() then
                stats.redraws = stats.redraws + 1
                closePage()
            end
            return orig(...)
        end
        wrapped[fn] = true
        H.redrawAll = fn
    end
    if type(A.set) == "function" and not wrapped[A.set] then
        local orig = A.set
        local fn = function(k, v, ...)
            if active() and type(k) == "string" then
                stats.sets[k] = (stats.sets[k] or 0) + 1
                -- 1.1.1: your colours changed outside a style change (picked
                -- by hand, or by something else), with what changed them
                if (k == "theme" or k == "accent" or k == "accent2") and not in_style then
                    log("colour setting: %s %s -> %s, from %s", k, colourVal(A.get(k, nil)), colourVal(v), caller(3))
                end
                if k == "rlt_bo_lib" then
                    stats.bo_refreshes = stats.bo_refreshes + 1
                    log("BookOrbit list refreshed: %d books", type(v) == "table" and type(v.books) == "table" and #v.books or 0)
                end
            end
            return orig(k, v, ...)
        end
        wrapped[fn] = true
        A.set = fn
    end
    logger.info("readinglog tweaks diagnostics: hooked Reading Log " .. tostring(A.VERSION)
        .. ", tweaks " .. tostring(A._rl_tweaks))
end

-- Reading Log loads its kit the first time it needs it and keeps it as
-- package.loaded.readinglog_kit; Reading Log Tweaks applies right then, so
-- the hooks go on just after it (outermost).
if type(package.loaded.readinglog_kit) == "table" then
    pcall(hookKit, package.loaded.readinglog_kit)
else
    local loaded = package.loaded
    local mt = getmetatable(loaded) or {}
    local prev = mt.__newindex
    local mine
    mine = function(t, k, v)
        local found = k == "readinglog_kit" and type(v) == "table"
        -- found: step out first (Reading Log Tweaks steps out too, inside prev)
        if found and mt.__newindex == mine then mt.__newindex = prev end
        if type(prev) == "function" then prev(t, k, v)
        elseif type(prev) == "table" then prev[k] = v
        else rawset(t, k, v) end
        if found then pcall(hookKit, v) end
    end
    mt.__newindex = mine
    setmetatable(loaded, mt)
end


-- --------------------------------------------------------------------------
-- Shared perf core v1 (the same block in every diagnostic that uses it)
-- The first diagnostic to load installs it; the others plug into it. One
-- copy of KOReader's timer loop with each timer timed, one watch on screen
-- updates, sleep, input events and warnings, handed to whichever
-- diagnostics are logging right now. With none logging, every hook passes
-- straight through. No timers of its own; it's installed on the first pass
-- of the main loop, after every patch, so its hooks are the outermost.
-- --------------------------------------------------------------------------
local DiagCore
do
    local CORE_VERSION = 1
    DiagCore = package.loaded["diag_perf_core"]
    if type(DiagCore) ~= "table" then
        DiagCore = { version = CORE_VERSION, clients = {} }
        package.loaded["diag_perf_core"] = DiagCore
        local UIM = require("ui/uimanager")
        local ok_time, ktime = pcall(require, "ui/time")
        local function nowMs()
            if ok_time and type(ktime) == "table" and ktime.now and ktime.to_ms then
                return ktime.to_ms(ktime.now())
            end
            return math.floor(os.clock() * 1000)
        end
        DiagCore.now_ms = nowMs
        local function pk(...) return { n = select("#", ...), ... } end

        -- "plugins/x.koplugin/main.lua:12" for a function or a debug.getinfo
        local function short(src, line)
            src = tostring(src or "?"):gsub("^@", ""):gsub("^%./", ""):gsub("^.-plugins/", "plugins/")
                :gsub("^.-patches/", "patches/")
            return line and (src .. ":" .. tostring(line)) or src
        end
        function DiagCore.where(fn)
            if type(fn) ~= "function" then return tostring(fn) end
            local info = debug.getinfo(fn, "S")
            if not info then return "?" end
            return short(info.source, info.linedefined)
        end
        local function caller(level)
            local info = debug.getinfo(level + 1, "Sl")
            if not info then return "?" end
            return short(info.source, info.currentline)
        end

        local function anyOn()
            for _i, c in ipairs(DiagCore.clients) do
                local ok, v = pcall(c.on)
                if ok and v then return true end
            end
            return false
        end
        local function emit(kind, ...)
            for _i, c in ipairs(DiagCore.clients) do
                local ok, v = pcall(c.on)
                if ok and v then pcall(c.handle, kind, ...) end
            end
        end

        local function install()
            -- Timers: KOReader's _checkTasks loop, each task timed.
            local orig_tasks = UIM._checkTasks
            if ok_time and type(orig_tasks) == "function" and type(UIM._task_queue) == "table" then
                UIM._checkTasks = function(self)
                    if not anyOn() then return orig_tasks(self) end
                    self._now = ktime.now()
                    local wait_until = nil
                    self._task_queue_dirty = false
                    while self._task_queue[1] do
                        local task_time = self._task_queue[#self._task_queue].time
                        if task_time <= self._now then
                            local task = table.remove(self._task_queue)
                            local t0 = nowMs()
                            if type(task.args) == "table" then
                                task.action(unpack(task.args, 1, task.args.n))
                            else
                                task.action()
                            end
                            emit("timer", task.action, nowMs() - t0)
                        else
                            wait_until = task_time
                            break
                        end
                    end
                    return wait_until, self._now
                end
            end

            -- Screen updates: who asked, and which kind (a flash or not).
            local orig_sd = UIM.setDirty
            if type(orig_sd) == "function" then
                UIM.setDirty = function(self, widget, refresh, ...)
                    if not anyOn() then return orig_sd(self, widget, refresh, ...) end
                    local src = caller(2)
                    if type(refresh) == "function" then
                        local f = refresh
                        refresh = function(...)
                            local r = pk(f(...))
                            emit("dirty", src, r[1])
                            return unpack(r, 1, r.n)
                        end
                    else
                        emit("dirty", src, refresh)
                    end
                    return orig_sd(self, widget, refresh, ...)
                end
            end

            -- Input events: slow ones (taps, swipes) are reported.
            local orig_send = UIM.sendEvent
            if type(orig_send) == "function" then
                UIM.sendEvent = function(self, event, ...)
                    if not anyOn() then return orig_send(self, event, ...) end
                    local t0 = nowMs()
                    local res = pk(orig_send(self, event, ...))
                    local dt = nowMs() - t0
                    if dt >= 15 and type(event) == "table" then
                        local h = tostring(event.handler or "?"):gsub("^on", "")
                        local ges = h == "Gesture" and event.args and event.args[1]
                        if type(ges) == "table" and ges.ges then h = "Gesture " .. tostring(ges.ges) end
                        emit("event", h, dt)
                    end
                    return unpack(res, 1, res.n)
                end
            end

            -- Sleep: the timers still waiting after every plugin handled it.
            local orig_bc = UIM.broadcastEvent
            if type(orig_bc) == "function" then
                UIM.broadcastEvent = function(self, event, ...)
                    local h = type(event) == "table" and event.handler
                    if not (anyOn() and (h == "onSuspend" or h == "onResume")) then
                        return orig_bc(self, event, ...)
                    end
                    local res = pk(orig_bc(self, event, ...))
                    if h == "onSuspend" then
                        local actions = {}
                        for _i, task in ipairs(self._task_queue or {}) do actions[#actions + 1] = task.action end
                        emit("sleep", actions)
                    else
                        emit("wake")
                    end
                    return unpack(res, 1, res.n)
                end
            end

            -- Warnings and errors, with the file that wrote them.
            local ok_l, logger = pcall(require, "logger")
            if ok_l and type(logger) == "table" then
                for _i, lvl in ipairs({ "warn", "err" }) do
                    local orig = logger[lvl]
                    if type(orig) == "function" then
                        logger[lvl] = function(...)
                            if anyOn() then
                                local src = caller(2)
                                local parts = {}
                                for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
                                local msg = table.concat(parts, " ")
                                if #msg > 300 then msg = msg:sub(1, 300) .. "..." end
                                emit("warn", lvl, src, msg)
                            end
                            return orig(...)
                        end
                    end
                end
            end
        end
        UIM:nextTick(function() pcall(install) end)
    end

    function DiagCore.register(client)
        table.insert(DiagCore.clients, client)
    end

    -- A standard client: everything the core sees that comes from the
    -- patch's own files (o.targets: parts of a path, e.g. "2-network-tweaks.lua").
    --   o.name     label in the lines ("ShelfSync Tweaks")
    --   o.log, o.on  the diagnostic's own log and "logging now?" functions
    --   o.errors   also log the patch's warnings/errors (when the
    --              diagnostic doesn't catch them itself)
    --   o.busy     optional: while it returns true, a timer of anyone's that
    --              holds the screen 250 ms+ or a tap/swipe 1 s+ is logged
    --              (replaces a freeze heartbeat; the patch was busy then, it
    --              isn't necessarily the cause)
    --   o.extra    optional: a few words added to the once-a-minute line
    --   o.summary  optional: where the once-a-minute line goes (default
    --              o.log; a diagnostic that only writes inside its own
    --              windows passes a function that drops it otherwise)
    function DiagCore.client(o)
        local SLOW_MS = o.slow_ms or 80
        local BUSY_TIMER_MS, BUSY_EVENT_MS = o.busy_timer_ms or 250, o.busy_event_ms or 1000
        local function mine(src)
            src = tostring(src or "")
            for _i, t in ipairs(o.targets) do
                if src:find(t, 1, true) then return true end
            end
            return false
        end
        local st = { since = os.time(), runs = 0, ms = 0, max = 0, max_src = nil, dirty = 0, flashes = 0 }
        local function summary(force)
            if not force and os.time() - st.since < 60 then return end
            if st.runs > 0 or st.dirty > 0 then
                local extra = o.extra and o.extra() or nil
                ;(o.summary or o.log)("perf (last %d s): %s timers ran %d times, %d ms in all, slowest %d ms%s | screen updates asked %d, flashes %d | Lua memory %.1f MB%s",
                    os.time() - st.since, o.name, st.runs, st.ms, st.max,
                    st.max_src and (" (" .. st.max_src .. ")") or "", st.dirty, st.flashes,
                    collectgarbage("count") / 1024, extra and (" | " .. extra) or "")
            end
            st.since, st.runs, st.ms, st.max, st.max_src, st.dirty, st.flashes = os.time(), 0, 0, 0, nil, 0, 0
        end
        local FLASH = { flashui = true, full = true, flashpartial = true }
        local client = { on = o.on }
        function client.handle(kind, a, b, c)
            if kind == "timer" then
                local src = DiagCore.where(a)
                if mine(src) then
                    st.runs, st.ms = st.runs + 1, st.ms + b
                    if b > st.max then st.max, st.max_src = b, src end
                    if b >= SLOW_MS then o.log("slow: %s timer %s took %d ms", o.name, src, b) end
                elseif o.busy and b >= BUSY_TIMER_MS and o.busy() then
                    o.log("screen held %d ms by timer %s while %s was busy", b, src, o.name)
                end
            elseif kind == "dirty" then
                if mine(a) then
                    st.dirty = st.dirty + 1
                    if FLASH[b] then
                        st.flashes = st.flashes + 1
                        o.log("FLASH %s asked by %s", tostring(b), a)
                    end
                end
            elseif kind == "event" then
                if o.busy and b >= BUSY_EVENT_MS and o.busy() then
                    o.log("screen held %d ms by a %s while %s was busy", b, a, o.name)
                end
            elseif kind == "sleep" then
                summary(true)
                local by, n = {}, 0
                for _i, fn in ipairs(a or {}) do
                    local src = DiagCore.where(fn)
                    if mine(src) then by[src] = (by[src] or 0) + 1; n = n + 1 end
                end
                if n == 0 then
                    o.log("going to sleep: no %s timers left waiting", o.name)
                else
                    local bits = {}
                    for src, k in pairs(by) do bits[#bits + 1] = k .. " x " .. src end
                    table.sort(bits)
                    o.log("going to sleep: %d %s timers still waiting (!): %s", n, o.name, table.concat(bits, ", "))
                end
                return
            elseif kind == "warn" then
                -- a = level, b = the file that wrote it, c = the message
                if o.errors and mine(b) then
                    o.log("%s from %s: %s", a == "err" and "ERROR" or "warning", b, tostring(c))
                end
            end
            summary(false)
        end
        DiagCore.register(client)
        return client
    end
end


-- Reading Log Tweaks: its timers that hold the screen 80 ms+, flashes it asks
-- for, its warnings and errors, and timers it leaves waiting at sleep, plus a
-- once-a-minute perf line, all inside the 15-minute window.
DiagCore.client({
    name = "Reading Log Tweaks",
    targets = { MAIN_TAG },
    on = function() return active() end,
    log = log,
    errors = true,
})

logger.info("readinglog tweaks diagnostics " .. DIAG_VERSION .. " loaded")
