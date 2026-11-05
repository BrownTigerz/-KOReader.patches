--[[
2-zz-orbitshelf-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.2.2

Watches 2-orbitshelf-tweaks.lua from the outside and writes tagged lines
([orbitshelf]) to the shared diagnostics log (shared log contract v1):
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It changes nothing in OrbitShelf Tweaks, Bookshelf, or BookOrbit. It records:
  • Startup: whether OrbitShelf Tweaks loaded, Bookshelf present (SOURCE_API),
    BookOrbit installed / signed in (yes/no only, never credentials), current
    OrbitShelf settings (use_bookorbit, auto_rewrite_stock, hero_pills,
    close_only_menu, close side).
  • Source registration: registerSource / unregisterSource success or refusal
    reason, how long it took, retries.
  • Shelf list / fetch: each catalogBooks-driven page load, age of cache hits,
    item counts, missing covers queued, time taken (50 ms+ always logged;
    under that counted for the summary).
  • Covers: path hits vs misses, background thumbnail fetches (batch size,
    ms, success count), Clean Up Cache results.
  • Open / download / remove: entry, on-device or not, timing, failures.
  • Hero: hold menu / pill row shown for BookOrbit books; whether hero hook
    attached.
  • Close-only menu: StartMenu open with side, whether items were stripped.
  • Footer critter (1.2.0): each line it picks (kind page / witty / picks /
    sayings, mood, page / pages, shelf, books on the page) and a count per
    kind in the summary.
  • Flat close (1.1.0): footer button built as close X vs stock hamburger,
    and every direct close (footer tap, focus, gesture) that skipped the menu.
  • Auto-rewrite: when stock Series/Authors/Genres/Recent paths are touched
    (if the main patch hooks them).
  • Shared-style timings: slow taps near Bookshelf, Lua memory once a minute
    while active, warnings tagged orbitshelf / bookshelf / bookorbit.
  • A summary with hints when the log window ends.

Battery safety (in case you forget to delete it):
  • Logs for 30 minutes after KOReader starts (time asleep counts). Then every
    hook goes idle.
  • After 3 days from first install it stops for good (one line per start).
    State file: orbitshelf-diagnostics.state. Delete that file (or use
    Debugging Menu → Delete all logs) for a fresh window.
  • No repeating timers of its own.

Install: copy next to 2-orbitshelf-tweaks.lua in koreader/patches/ and restart.
The "zz" loads it after the main patch. Delete the file when done.

Changelog:
  1.2.2  2026-11-01  Fix: the catalogBooks wrapper named its query argument q, which hid the
                     log helper q(). Any catalog call slower than the slow threshold then
                     died with "attempt to call local 'q' (a table value)", so OrbitShelf
                     Tweaks saw a failed fetch and showed empty BookOrbit shelves while this
                     file was installed. The argument is now called query.
  1.2.1  2026-11-01  Boot snapshot says where the OrbitShelf Tweaks menu is registered
                     (Add-ons entry, Tools hook) and how many BookOrbit lists are cached.
  1.2.0  2026-11-01  Footer critter: logs each pick (kind, mood, page, shelf) and
                     counts per kind.
  1.1.0  2026-11-01  Flat close: logs close X vs hamburger and direct closes.
  1.0.0  2026-10-31  First version.
]]

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local WINDOW_MIN = 30
local WINDOW_S = WINDOW_MIN * 60
local EXPIRE_S = 3 * 24 * 3600
local STATE = DataStorage:getDataDir() .. "/orbitshelf-diagnostics.state"
local DIAG_VERSION = "1.2.2"
local DIAG_TAG = "orbitshelf"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024

local SLOW_MS = 50          -- list/fetch/cover path always logged at or above
local SLOW_COVER_MS = 80
local SLOW_OPEN_MS = 100
local SLOW_REG_MS = 30

if package.loaded["orbitshelf_diagnostics_patch"] then
    return
end
package.loaded["orbitshelf_diagnostics_patch"] = true

local started = os.time()
local active = true
local expired = false

-- ---- time helpers ---------------------------------------------------------------

local now_ms
do
    local ok, time = pcall(require, "ui/time")
    if ok and type(time) == "table" and time.now and time.to_ms then
        now_ms = function() return time.to_ms(time.now()) end
    else
        now_ms = function() return math.floor(os.clock() * 1000) end
    end
end

local function mem_kb()
    local ok, m = pcall(collectgarbage, "count")
    return ok and m or 0
end

-- ---- log ------------------------------------------------------------------------

local BIDI = { "\226\129\166", "\226\129\167", "\226\129\168", "\226\129\169",
    "\226\128\170", "\226\128\171", "\226\128\172", "\226\128\173", "\226\128\174" }

local function scrub(s)
    s = tostring(s)
    s = s:gsub("userkey%s*=%s*[^,%s}]+", "userkey=[redacted]")
    s = s:gsub("password%s*=%s*[^,%s}]+", "password=[redacted]")
    s = s:gsub("x%-auth%-key%s*:%s*[^,%s}]+", "x-auth-key: [redacted]")
    s = s:gsub("Authorization%s*:%s*[^,%s}]+", "Authorization: [redacted]")
    if #s > 1200 then s = s:sub(1, 1200) .. "...(truncated)" end
    return s
end

local function oneLine(s)
    s = scrub(s)
    for i = 1, #BIDI do s = s:gsub(BIDI[i], "") end
    s = s:gsub("%s*[\r\n]+%s*", " / ")
    return s
end

local function shared_log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    line = oneLine(line)
    pcall(function()
        if (lfs.attributes(SHARED_LOG, "size") or 0) > SHARED_MAX_BYTES then
            os.remove(SHARED_LOG .. ".old")
            os.rename(SHARED_LOG, SHARED_LOG .. ".old")
        end
        local f = io.open(SHARED_LOG, "a")
        if not f then return end
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", line, "\n")
        f:close()
    end)
end

local function write(line)
    shared_log("%s", line)
end

local function on()
    if expired or not active then return false end
    if os.time() - started > WINDOW_S then
        active = false
        write("==== " .. WINDOW_MIN .. " minutes up: logging stopped, every hook is idle now ====")
        summary("window ended")
        return false
    end
    return true
end

local function log(fmt, ...)
    if not on() then return end
    local ok, line = pcall(string.format, fmt, ...)
    write(ok and line or tostring(fmt))
end

local function q(v)
    if v == nil then return "(none)" end
    if type(v) == "boolean" then return v and "yes" or "no" end
    return tostring(v)
end

-- ---- hard expiry ----------------------------------------------------------------

do
    local first
    local f = io.open(STATE, "r")
    if f then
        local v, t = f:read("*l"), tonumber(f:read("*l") or "")
        f:close()
        if v == DIAG_VERSION and t and t <= os.time() then first = t end
    end
    if not first then
        first = os.time()
        local w = io.open(STATE, "w")
        if w then
            w:write(DIAG_VERSION, "\n", tostring(first), "\n")
            w:close()
        end
    end
    if os.time() - first > EXPIRE_S then
        expired = true
        active = false
        write("==== orbitshelf diagnostics expired (3 days since first install); delete "
            .. "orbitshelf-diagnostics.state or use Debugging Menu for a fresh window ====")
        return
    end
end

-- ---- counters -------------------------------------------------------------------

local function bucket() return { n = 0, ms = 0, max = 0 } end
local function add(b, ms)
    b.n = b.n + 1
    b.ms = b.ms + ms
    if ms > b.max then b.max = ms end
end
local function avg(b)
    return b.n > 0 and string.format("%.1f", b.ms / b.n) or "0.0"
end

local stats = {
    register = bucket(),
    list_cache = bucket(),
    list_net = bucket(),
    cover_hit = 0,
    cover_miss = 0,
    cover_fetch = bucket(),
    cover_fetch_ok = 0,
    open = bucket(),
    download = bucket(),
    remove = 0,
    hero_hold = 0,
    hero_pills = 0,
    menu_close_only = 0,
    close_direct = 0,
    critter = { page = 0, witty = 0, recs = 0, quotes = 0 },
    critter_builds = 0,
    close_x_built = 0,
    source_refused = 0,
    errors = 0,
    mem_start = mem_kb(),
}

function summary(why)
    write("---- summary (" .. tostring(why) .. ") ----")
    write(string.format("registerSource: %d, avg %s ms, max %.0f ms | refusals: %d",
        stats.register.n, avg(stats.register), stats.register.max, stats.source_refused))
    write(string.format("list cache hits: %d, avg %s ms, max %.0f | network lists: %d, avg %s ms, max %.0f",
        stats.list_cache.n, avg(stats.list_cache), stats.list_cache.max,
        stats.list_net.n, avg(stats.list_net), stats.list_net.max))
    write(string.format("covers: %d hit, %d miss | thumbnail fetches: %d batches, avg %s ms, max %.0f, ok files %d",
        stats.cover_hit, stats.cover_miss,
        stats.cover_fetch.n, avg(stats.cover_fetch), stats.cover_fetch.max, stats.cover_fetch_ok))
    write(string.format("open: %d, avg %s ms, max %.0f | download: %d, avg %s ms, max %.0f | remove: %d",
        stats.open.n, avg(stats.open), stats.open.max,
        stats.download.n, avg(stats.download), stats.download.max, stats.remove))
    write(string.format("hero holds: %d | hero pill builds: %d | close-only menu opens: %d | direct closes: %d | close X builds: %d | errors: %d",
        stats.hero_hold, stats.hero_pills, stats.menu_close_only, stats.close_direct, stats.close_x_built, stats.errors))
    write(string.format("footer critter: %d builds | page %d, witty %d, picks %d, sayings %d",
        stats.critter_builds, stats.critter.page, stats.critter.witty, stats.critter.recs, stats.critter.quotes))
    write(string.format("Lua memory: %.0f KB (was %.0f KB at start)", mem_kb(), stats.mem_start))

    local hints = {}
    if stats.register.n == 0 then
        hints[#hints + 1] = "registerSource never ran: Bookshelf may load late, or Use BookOrbit is off / not signed in"
    end
    if stats.source_refused > 0 then
        hints[#hints + 1] = "registerSource was refused (see earlier lines for the reason)"
    end
    if stats.list_net.n > 0 and stats.list_net.ms / stats.list_net.n >= 800 then
        hints[#hints + 1] = string.format("BookOrbit list fetch is slow (avg %s ms): network or large library", avg(stats.list_net))
    end
    if stats.cover_miss > 20 and stats.cover_fetch_ok == 0 then
        hints[#hints + 1] = "many cover misses and no successful thumbnail fetch: Wi-Fi off, or downloadCatalogThumbnail failed"
    end
    if stats.cover_fetch.n > 0 and stats.cover_fetch.ms / stats.cover_fetch.n >= 2000 then
        hints[#hints + 1] = string.format("cover batches slow (avg %s ms)", avg(stats.cover_fetch))
    end
    if stats.open.n > 0 and stats.open.max >= 2000 then
        hints[#hints + 1] = string.format("an open took %.0f ms", stats.open.max)
    end
    if stats.errors > 0 then
        hints[#hints + 1] = string.format("%d errors logged above", stats.errors)
    end
    if mem_kb() - stats.mem_start > 8192 then
        hints[#hints + 1] = string.format("Lua memory grew %.0f KB during the window", mem_kb() - stats.mem_start)
    end
    if #hints == 0 then hints[1] = "Nothing slow enough to worry about" end
    for i, h in ipairs(hints) do
        write(string.format("hint %d: %s", i, h))
    end
end

-- ---- wrap helper ----------------------------------------------------------------

local function wrap(tbl, key, label, after_fn)
    if type(tbl) ~= "table" then return false end
    local f = tbl[key]
    if type(f) ~= "function" then
        log("hook %s: not found", label)
        return false
    end
    local mark = "_orbitshelf_diag_" .. key
    if tbl[mark] then return true end
    tbl[mark] = true
    tbl[key] = function(...)
        if not on() then return f(...) end
        local t0 = now_ms()
        local res = { pcall(f, ...) }
        local took = now_ms() - t0
        if not res[1] then
            stats.errors = stats.errors + 1
            log("ERROR %s failed after %d ms: %s", label, took, tostring(res[2]))
            error(res[2], 0)
        end
        if after_fn then
            pcall(after_fn, took, res, ...)
        elseif took >= SLOW_MS then
            log("%s done in %d ms", label, took)
        end
        return unpack(res, 2)
    end
    log("hook %s: applied", label)
    return true
end

-- ---- environment snapshot -------------------------------------------------------

local function bookOrbitInstalled()
    if lfs.attributes("plugins/bookorbit.koplugin/main.lua", "mode") == "file" then return true end
    if lfs.attributes("plugins/BookOrbit.koplugin/main.lua", "mode") == "file" then return true end
    local ok = pcall(require, "bookorbit_api")
    return ok
end

local function bookOrbitSignedIn()
    local s = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    return type(s) == "table" and s.server_url and s.username and s.userkey and true or false
end

local function orbitshelfCfg()
    local c = G_reader_settings and G_reader_settings:readSetting("orbitshelf_tweaks")
    return type(c) == "table" and c or {}
end

local function getBookshelf()
    local FM = package.loaded["apps/filemanager/filemanager"]
    local fm = type(FM) == "table" and FM.instance
    if type(fm) == "table" and type(fm.bookshelf) == "table" then return fm.bookshelf end
    local ReaderUI = package.loaded["apps/reader/readerui"]
    if type(ReaderUI) == "table" and type(ReaderUI.instance) == "table"
            and type(ReaderUI.instance.bookshelf) == "table" then
        return ReaderUI.instance.bookshelf
    end
    return nil
end

local function snapshot(why)
    local c = orbitshelfCfg()
    local bs = getBookshelf()
    local patch_loaded = package.loaded["orbitshelf_tweaks_patch"] and true or false
    log("---- snapshot (%s) ----", why)
    log("OrbitShelf Tweaks loaded: %s | diagnostic %s", q(patch_loaded), DIAG_VERSION)
    log("Bookshelf present: %s | SOURCE_API: %s",
        q(bs ~= nil),
        q(bs and bs.SOURCE_API))
    log("BookOrbit installed: %s | signed in: %s",
        q(bookOrbitInstalled()), q(bookOrbitSignedIn()))
    log("settings: use_bookorbit=%s auto_rewrite=%s hero_pills=%s close_only=%s close_side=%s",
        q(c.use_bookorbit), q(c.auto_rewrite_stock), q(c.hero_pills),
        q(c.close_only_menu), q(c.close_menu_side))
    pcall(function()
        local TM = package.loaded.tweaks_mods
        local entry = type(TM) == "table" and type(TM.entries) == "table" and TM.entries.orbitshelf_tweaks
        local okm, FMmenu = pcall(require, "apps/filemanager/filemanagermenu")
        local lists = 0
        local saved = G_reader_settings and G_reader_settings:readSetting("orbitshelf_tweaks_pages")
        if type(saved) == "table" then for _k in pairs(saved) do lists = lists + 1 end end
        log("settings menu: Add-ons entry=%s (Add-ons patch active=%s) | Tools hook=%s | cached BookOrbit lists=%d",
            q(entry and true or false), q(type(TM) == "table" and TM.active and true or false),
            q(okm and type(FMmenu) == "table" and FMmenu._orbitshelf_menu and true or false), lists)
    end)
    -- cover cache size
    pcall(function()
        local dir = DataStorage:getDataDir() .. "/cache/bookorbit"
        local n, bytes = 0, 0
        if lfs.attributes(dir, "mode") == "directory" then
            for name in lfs.dir(dir) do
                if name:match("%.jpg$") then
                    n = n + 1
                    bytes = bytes + (lfs.attributes(dir .. "/" .. name, "size") or 0)
                end
            end
        end
        log("cover cache: %d jpg files, %.1f MB in cache/bookorbit/", n, bytes / 1048576)
    end)
end

-- ---- instrument Bookshelf registerSource ----------------------------------------

local function hookBookshelf(bs)
    if type(bs) ~= "table" or bs._orbitshelf_diag_reg then return end
    if type(bs.registerSource) ~= "function" then
        log("Bookshelf has no registerSource yet")
        return
    end
    bs._orbitshelf_diag_reg = true

    local orig_reg = bs.registerSource
    bs.registerSource = function(self, id, spec, ...)
        if not on() then return orig_reg(self, id, spec, ...) end
        local t0 = now_ms()
        local res = { pcall(orig_reg, self, id, spec, ...) }
        local took = now_ms() - t0
        if tostring(id) == "bookorbit" or (type(id) == "string" and id:find("bookorbit", 1, true)) then
            add(stats.register, took)
            if not res[1] then
                stats.errors = stats.errors + 1
                stats.source_refused = stats.source_refused + 1
                log("ERROR registerSource(%s) threw after %d ms: %s", q(id), took, tostring(res[2]))
                error(res[2], 0)
            end
            local ok_ret, why = res[2], res[3]
            if ok_ret then
                log("registerSource(%s) ok in %d ms (list=%s fetch=%s)",
                    q(id), took,
                    q(type(spec) == "table" and type(spec.list) == "function"),
                    q(type(spec) == "table" and type(spec.fetch) == "function"))
                -- Wrap spec hooks for timing
                if type(spec) == "table" then
                    if type(spec.list) == "function" and not spec._orbitshelf_diag_list then
                        spec._orbitshelf_diag_list = true
                        local L = spec.list
                        spec.list = function(source, ...)
                            if not on() then return L(source, ...) end
                            local t1 = now_ms()
                            local r = { pcall(L, source, ...) }
                            local ms = now_ms() - t1
                            if not r[1] then
                                stats.errors = stats.errors + 1
                                log("ERROR source.list failed after %d ms: %s", ms, tostring(r[2]))
                                error(r[2], 0)
                            end
                            local items = r[2]
                            local n = type(items) == "table" and #items or 0
                            -- cache vs net heuristic: under 20 ms with items is almost always cache
                            if ms < 20 then add(stats.list_cache, ms)
                            else add(stats.list_net, ms) end
                            local mode = type(source) == "table" and source.mode or "?"
                            if ms >= SLOW_MS or n > 0 then
                                log("list mode=%s items=%d in %d ms", q(mode), n, ms)
                            end
                            return unpack(r, 2)
                        end
                    end
                    if type(spec.fetch) == "function" and not spec._orbitshelf_diag_fetch then
                        spec._orbitshelf_diag_fetch = true
                        local F = spec.fetch
                        spec.fetch = function(source, drill, offset, limit, ...)
                            if not on() then return F(source, drill, offset, limit, ...) end
                            local t1 = now_ms()
                            local r = { pcall(F, source, drill, offset, limit, ...) }
                            local ms = now_ms() - t1
                            if not r[1] then
                                stats.errors = stats.errors + 1
                                log("ERROR source.fetch failed after %d ms: %s", ms, tostring(r[2]))
                                error(r[2], 0)
                            end
                            local items, total = r[2], r[3]
                            local n = type(items) == "table" and #items or 0
                            if ms < 20 then add(stats.list_cache, ms) else add(stats.list_net, ms) end
                            local mode = type(source) == "table" and source.mode or "?"
                            local drill_s = type(drill) == "table"
                                and (drill.label or drill.series_id or drill.author or drill.genre or "folder")
                                or "(top)"
                            log("fetch mode=%s drill=%s offset=%s limit=%s items=%d total=%s in %d ms",
                                q(mode), q(drill_s), q(offset), q(limit), n, q(total), ms)
                            return unpack(r, 2)
                        end
                    end
                    if type(spec.open) == "function" and not spec._orbitshelf_diag_open then
                        spec._orbitshelf_diag_open = true
                        local O = spec.open
                        spec.open = function(book, ctx, ...)
                            if not on() then return O(book, ctx, ...) end
                            local t1 = now_ms()
                            local r = { pcall(O, book, ctx, ...) }
                            local ms = now_ms() - t1
                            add(stats.open, ms)
                            if not r[1] then
                                stats.errors = stats.errors + 1
                                log("ERROR source.open failed after %d ms: %s", ms, tostring(r[2]))
                                error(r[2], 0)
                            end
                            local title = type(book) == "table" and book.title or "?"
                            local on_dev = type(book) == "table" and type(book.filepath) == "string"
                                and not tostring(book.filepath):match("^bookorbit://")
                            log("open %q on_device=%s result=%s in %d ms",
                                tostring(title), q(on_dev), q(r[2]), ms)
                            return unpack(r, 2)
                        end
                    end
                    if type(spec.refresh) == "function" and not spec._orbitshelf_diag_refresh then
                        spec._orbitshelf_diag_refresh = true
                        local R = spec.refresh
                        spec.refresh = function(...)
                            if not on() then return R(...) end
                            local t1 = now_ms()
                            local r = { pcall(R, ...) }
                            local ms = now_ms() - t1
                            if not r[1] then
                                stats.errors = stats.errors + 1
                                log("ERROR source.refresh failed after %d ms: %s", ms, tostring(r[2]))
                                error(r[2], 0)
                            end
                            log("refresh done in %d ms", ms)
                            return unpack(r, 2)
                        end
                    end
                end
            else
                stats.source_refused = stats.source_refused + 1
                log("registerSource(%s) REFUSED in %d ms: %s", q(id), took, q(why))
            end
            return unpack(res, 2)
        end
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end

    if type(bs.unregisterSource) == "function" and not bs._orbitshelf_diag_unreg then
        bs._orbitshelf_diag_unreg = true
        local orig_un = bs.unregisterSource
        bs.unregisterSource = function(self, id, ...)
            if on() and tostring(id) == "bookorbit" then
                log("unregisterSource(%s)", q(id))
            end
            return orig_un(self, id, ...)
        end
    end

    if type(bs.sourceChanged) == "function" and not bs._orbitshelf_diag_changed then
        bs._orbitshelf_diag_changed = true
        local orig_ch = bs.sourceChanged
        bs.sourceChanged = function(self, id, ...)
            if on() and (tostring(id) == "bookorbit" or id == nil) then
                log("sourceChanged(%s)", q(id))
            end
            return orig_ch(self, id, ...)
        end
    end

    log("Bookshelf registerSource / sourceChanged hooks applied")
end

-- ---- BookOrbit API (catalog list + thumbnails) ----------------------------------

local function hookApiClient()
    local ok, Api = pcall(require, "bookorbit_api")
    if not ok or type(Api) ~= "table" then
        log("bookorbit_api not loadable yet")
        return false
    end
    if Api._orbitshelf_diag_new then return true end

    if type(Api.new) == "function" then
        Api._orbitshelf_diag_new = true
        local orig_new = Api.new
        Api.new = function(...)
            local client = orig_new(...)
            if type(client) ~= "table" or client._orbitshelf_diag then return client end
            client._orbitshelf_diag = true

            if type(client.catalogBooks) == "function" then
                local C = client.catalogBooks
                client.catalogBooks = function(self, query, ...)
                    if not on() then return C(self, query, ...) end
                    local t0 = now_ms()
                    local r = { pcall(C, self, query, ...) }
                    local ms = now_ms() - t0
                    if not r[1] then
                        stats.errors = stats.errors + 1
                        log("ERROR catalogBooks failed after %d ms: %s", ms, tostring(r[2]))
                        error(r[2], 0)
                    end
                    local body = r[2]
                    local n = 0
                    if type(body) == "table" then
                        local items = body.items or body.books or body.entries
                        n = type(items) == "table" and #items or 0
                    end
                    local sort = type(query) == "table" and (query.sort or query.collectionId or "default") or "?"
                    if ms >= SLOW_MS then
                        log("api catalogBooks sort=%s page=%s items=%d in %d ms",
                            q(sort), q(type(query) == "table" and query.page), n, ms)
                    end
                    return unpack(r, 2)
                end
            end

            if type(client.downloadCatalogThumbnail) == "function" then
                local D = client.downloadCatalogThumbnail
                client.downloadCatalogThumbnail = function(self, id, path, opts, ...)
                    if not on() then return D(self, id, path, opts, ...) end
                    local t0 = now_ms()
                    local r = { pcall(D, self, id, path, opts, ...) }
                    local ms = now_ms() - t0
                    add(stats.cover_fetch, ms)
                    if not r[1] then
                        stats.errors = stats.errors + 1
                        log("ERROR downloadCatalogThumbnail id=%s failed after %d ms: %s",
                            q(id), ms, tostring(r[2]))
                        error(r[2], 0)
                    end
                    local ok_dl = r[2]
                    if ok_dl then stats.cover_fetch_ok = stats.cover_fetch_ok + 1 end
                    if ms >= SLOW_COVER_MS or not ok_dl then
                        log("thumbnail id=%s ok=%s in %d ms", q(id), q(ok_dl and true or false), ms)
                    end
                    return unpack(r, 2)
                end
            end

            if type(client.catalogBook) == "function" then
                local B = client.catalogBook
                client.catalogBook = function(self, id, ...)
                    if not on() then return B(self, id, ...) end
                    local t0 = now_ms()
                    local r = { pcall(B, self, id, ...) }
                    local ms = now_ms() - t0
                    if not r[1] then
                        stats.errors = stats.errors + 1
                        log("ERROR catalogBook id=%s failed after %d ms: %s", q(id), ms, tostring(r[2]))
                        error(r[2], 0)
                    end
                    if ms >= SLOW_MS then
                        log("api catalogBook id=%s in %d ms", q(id), ms)
                    end
                    return unpack(r, 2)
                end
            end

            return client
        end
        log("hook bookorbit_api.new: applied (catalogBooks / thumbnail / catalogBook)")
        return true
    end
    return false
end

-- ---- HeroCard -------------------------------------------------------------------

local function hookHero()
    local ok, HeroCard = pcall(require, "lib/bookshelf_hero_card")
    if not ok or type(HeroCard) ~= "table" then
        log("HeroCard not loadable (Bookshelf not ready)")
        return false
    end
    if HeroCard._orbitshelf_diag_hold then return true end
    HeroCard._orbitshelf_diag_hold = true

    if type(HeroCard.onHold) == "function" then
        local H = HeroCard.onHold
        HeroCard.onHold = function(self, ...)
            if not on() then return H(self, ...) end
            local book = self and self.book
            local is_bo = type(book) == "table" and (book.is_bookorbit or book.bookorbit_id
                or book.source_kind == "bookorbit")
            if is_bo then
                stats.hero_hold = stats.hero_hold + 1
                log("hero hold: %q bookorbit_id=%s filepath=%s",
                    q(book.title), q(book.bookorbit_id),
                    q(type(book.filepath) == "string" and book.filepath:sub(1, 40)))
            end
            return H(self, ...)
        end
        log("hook HeroCard.onHold: applied")
    end

    if type(HeroCard._buildRightColumn) == "function" then
        local B = HeroCard._buildRightColumn
        HeroCard._buildRightColumn = function(self, book, ...)
            if not on() then return B(self, book, ...) end
            local t0 = now_ms()
            local r = { pcall(B, self, book, ...) }
            local ms = now_ms() - t0
            if not r[1] then
                stats.errors = stats.errors + 1
                log("ERROR HeroCard._buildRightColumn failed after %d ms: %s", ms, tostring(r[2]))
                error(r[2], 0)
            end
            local is_bo = type(book) == "table" and (book.is_bookorbit or book.bookorbit_id
                or book.source_kind == "bookorbit")
            if is_bo then
                stats.hero_pills = stats.hero_pills + 1
                if ms >= SLOW_MS then
                    log("hero column for BookOrbit book %q in %d ms", q(book.title), ms)
                end
            elseif ms >= 80 then
                log("hero column slow %d ms title=%s", ms, q(type(book) == "table" and book.title))
            end
            return unpack(r, 2)
        end
        log("hook HeroCard._buildRightColumn: applied")
    end
    return true
end

-- ---- Start menu (close-only) ----------------------------------------------------

local function hookStartMenu()
    local ok, StartMenu = pcall(require, "lib/bookshelf_start_menu")
    if not ok or type(StartMenu) ~= "table" then
        log("StartMenu not loadable yet")
        return false
    end
    if StartMenu._orbitshelf_diag_open then return true end
    StartMenu._orbitshelf_diag_open = true

    if type(StartMenu.open) == "function" then
        local O = StartMenu.open
        StartMenu.open = function(bw, bottom_inset, burger_dimen, context, burger_art, anchor_top, side_override, ...)
            if not on() then
                return O(bw, bottom_inset, burger_dimen, context, burger_art, anchor_top, side_override, ...)
            end
            local c = orbitshelfCfg()
            if c.close_only_menu then
                stats.menu_close_only = stats.menu_close_only + 1
                log("StartMenu.open close_only=yes side=%s override=%s context=%s",
                    q(c.close_menu_side), q(side_override), q(context))
            else
                log("StartMenu.open close_only=no context=%s", q(context))
            end
            local t0 = now_ms()
            local r = { pcall(O, bw, bottom_inset, burger_dimen, context, burger_art, anchor_top, side_override, ...) }
            local ms = now_ms() - t0
            if not r[1] then
                stats.errors = stats.errors + 1
                log("ERROR StartMenu.open failed after %d ms: %s", ms, tostring(r[2]))
                error(r[2], 0)
            end
            if ms >= SLOW_MS then log("StartMenu.open done in %d ms", ms) end
            return unpack(r, 2)
        end
        log("hook StartMenu.open: applied")
    end

    if type(StartMenu._loadItems) == "function" then
        local L = StartMenu._loadItems
        StartMenu._loadItems = function(self, ...)
            if not on() then return L(self, ...) end
            local items = L(self, ...)
            local c = orbitshelfCfg()
            local n = type(items) == "table" and #items or 0
            if c.close_only_menu then
                log("StartMenu._loadItems close_only: %d entries", n)
            end
            return items
        end
        log("hook StartMenu._loadItems: applied")
    end
    return true
end

-- ---- Flat close (close X replaces hamburger) -------------------------------------

local function hookFooterClose()
    local ok, BW = pcall(require, "lib/bookshelf_widget")
    if not ok or type(BW) ~= "table" then
        log("Bookshelf widget not loadable yet")
        return false
    end
    if BW._orbitshelf_diag_flat then return true end
    BW._orbitshelf_diag_flat = true

    if type(BW._buildStartMenuIcon) == "function" then
        local O = BW._buildStartMenuIcon
        BW._buildStartMenuIcon = function(self, ...)
            if not on() then return O(self, ...) end
            local c = orbitshelfCfg()
            if c.close_only_menu then
                stats.close_x_built = stats.close_x_built + 1
                if stats.close_x_built <= 3 then
                    log("footer button: close X (close_only=yes side=%s)", q(c.close_menu_side))
                end
            end
            return O(self, ...)
        end
        log("hook BookshelfWidget._buildStartMenuIcon: applied")
    end

    if type(BW._openStartMenu) == "function" then
        local O = BW._openStartMenu
        BW._openStartMenu = function(self, force, ...)
            if not on() then return O(self, force, ...) end
            local c = orbitshelfCfg()
            if c.close_only_menu then
                stats.close_direct = stats.close_direct + 1
                log("start menu request -> direct close (force=%s)", q(force))
            end
            return O(self, force, ...)
        end
        log("hook BookshelfWidget._openStartMenu: applied")
    end

    if type(BW.onClose) == "function" then
        local O = BW.onClose
        BW.onClose = function(self, ...)
            if on() and orbitshelfCfg().close_only_menu then
                log("BookshelfWidget:onClose (close_only=yes)")
            end
            return O(self, ...)
        end
        log("hook BookshelfWidget.onClose: applied")
    end
    return true
end

-- ---- Footer critter (what it picked) ----------------------------------------------

local function hookFooterCritterLog()
    local ok, BW = pcall(require, "lib/bookshelf_widget")
    if not ok or type(BW) ~= "table" then return false end
    if BW._orbitshelf_diag_critter then return true end
    if type(BW._buildPaginationFooter) ~= "function" then return false end
    BW._orbitshelf_diag_critter = true
    local O = BW._buildPaginationFooter
    local last_text
    BW._buildPaginationFooter = function(self, ...)
        local r = { pcall(O, self, ...) }
        if not r[1] then
            stats.errors = stats.errors + 1
            log("ERROR footer build failed: %s", tostring(r[2]))
            error(r[2], 0)
        end
        if on() and orbitshelfCfg().footer_critter then
            local c = package.loaded["orbitshelf_critter_last"]
            if type(c) == "table" and c.text ~= last_text then
                last_text = c.text
                stats.critter_builds = stats.critter_builds + 1
                if stats.critter[c.kind] then stats.critter[c.kind] = stats.critter[c.kind] + 1 end
                log("critter [%s] mood=%s page=%s/%s shelf=%s books=%s on_page=%s | %s | %s",
                    q(c.kind), q(c.mood), q(c.page), q(c.pages), q(c.shelf), q(c.books), q(c.on_page),
                    q(c.text), q(c.sub))
            end
        end
        return unpack(r, 2)
    end
    log("hook BookshelfWidget._buildPaginationFooter: applied")
    return true
end

-- ---- logger.warn/error catch for our tags ---------------------------------------

local function hookLogger()
    if logger._orbitshelf_diag then return end
    logger._orbitshelf_diag = true
    for _, meth in ipairs({ "warn", "err", "error" }) do
        local orig = logger[meth]
        if type(orig) == "function" then
            logger[meth] = function(...)
                if on() then
                    local parts = {}
                    for i = 1, select("#", ...) do
                        parts[#parts + 1] = tostring(select(i, ...))
                    end
                    local line = table.concat(parts, " ")
                    if line:find("orbitshelf", 1, true) or line:find("OrbitShelf", 1, true)
                            or line:find("bookorbit source", 1, true) then
                        stats.errors = stats.errors + 1
                        log("logger.%s: %s", meth, line)
                    end
                end
                return orig(...)
            end
        end
    end
end

-- ---- minute heartbeat (via UIManager schedule, cancelled when idle) ------------

local function schedulePulse()
    local UIManager = require("ui/uimanager")
    local function pulse()
        if not on() then return end
        log("perf: mem=%.0f KB list_cache=%d list_net=%d covers hit/miss=%d/%d fetch_batches=%d",
            mem_kb(), stats.list_cache.n, stats.list_net.n,
            stats.cover_hit, stats.cover_miss, stats.cover_fetch.n)
        UIManager:scheduleIn(60, pulse)
    end
    UIManager:scheduleIn(60, pulse)
end

-- ---- boot -----------------------------------------------------------------------

write(string.format("==== orbitshelf diagnostics %s starting (log %d min, expire 3 days) ====",
    DIAG_VERSION, WINDOW_MIN))

local function tryHooks()
    snapshot("boot")
    hookLogger()
    hookApiClient()
    local bs = getBookshelf()
    if bs then hookBookshelf(bs) else log("Bookshelf not ready at boot; will retry") end
    hookHero()
    hookStartMenu()
    hookFooterClose()
    hookFooterCritterLog()

    if not package.loaded["orbitshelf_tweaks_patch"] then
        log("WARNING: 2-orbitshelf-tweaks.lua did not set orbitshelf_tweaks_patch — is the main patch installed?")
    end
end

local UIManager = require("ui/uimanager")
UIManager:nextTick(function()
    local ok, err = pcall(tryHooks)
    if not ok then write("boot hooks failed: " .. tostring(err)) end
end)

-- Retry Bookshelf attachment (loads after patches)
for _, delay in ipairs({ 1, 3, 8 }) do
    UIManager:scheduleIn(delay, function()
        if not on() then return end
        local bs = getBookshelf()
        if bs then
            hookBookshelf(bs)
            hookHero()
            hookStartMenu()
            hookFooterClose()
            hookFooterCritterLog()
            hookApiClient()
        else
            log("retry %ds: Bookshelf still missing", delay)
        end
    end)
end

schedulePulse()
write("orbitshelf diagnostics ready")
