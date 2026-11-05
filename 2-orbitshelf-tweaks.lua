--[[
2-orbitshelf-tweaks.lua
OrbitShelf Tweaks — BookOrbit shelves inside Bookshelf (AndyHazz/bookshelf.koplugin).

Requires:
  * bookshelf.koplugin (SOURCE_API >= 1; best with Bookshelf 5.4+ / 6.x)
  * bookorbit.koplugin signed in (server_url + username + userkey)

Version: 1.5.11

What it does
  * Toggle **Use BookOrbit In Bookshelf**. Registers a **BookOrbit** fetch-mode
    shelf source (books not on device included).
  * Source modes: Library, Recently added, Recently read, **Series**,
    **Authors**, **Genres**, and **Collections** (fetched from BookOrbit when
    Wi-Fi is on, the saved list otherwise). Series/Authors/Genres are folder
    drills (tap a group → its books), ordered the way Bookshelf orders its own
    Series / Authors / Genres stacks.
  * Toggle **Rewrite Stock Series/Author/Genre**: points the built-in Series,
    Authors, Genres, Recent and Latest chips at BookOrbit (restored when off).
  * Covers: shared cache/bookorbit/ folder with Side Panel; Clean Up Cache
    matches Reading Log Tweaks.
  * Hero: hold menu and, at the bottom of the banner, **Download / Open In
    BookOrbit** pills for a BookOrbit book not on the device; small round icons
    (Remove From Device, Open In BookOrbit, Sync) at the bottom right for one
    that is, so its description keeps the room.
  * Toggle **Close Only (No Hamburger)**: the footer hamburger is replaced by a
    plain close X. One tap closes Bookshelf, no menu in between. Placement is
    still **left / right / bottom** (Close Control). Gesture / keyboard
    "open start menu" closes the shelf too while this is on.
  * Toggle **Footer Critter**: replaces the bottom page nav with your SimpleUI
    Tiny Critter (same critters as Quick Shelf / Reading Log). The bubble always
    carries where you are (page, pages, shelf) and says one of four things,
    moving to the next kind on every tap or page turn:
      Page    - "Page 3 of 9", "Books 25-36 of 104".
      Witty   - short remarks that know the page, shelf size and time of day.
      Picks   - recommendations from the books on this page: one to get back to,
                one nearly finished, the next in a series, two by one author.
      Sayings - original one-liners about books and shelves; add your own in
                koreader/settings/orbitshelf-quotes.txt (one per line, or
                `quote | author`).
    Each kind has its own switch (at least one stays on). Left/right edges
    still page; swipe still pages.

  * **Genres**: BookOrbit's lists carry no genres, so they are built once from each
    book's BookOrbit page (genres + tags), in the background, after a Start / Later
    question the first time the Genres shelf opens. Books on the device use their
    file's own genres. Wi-Fi off pauses it; it carries on when Wi-Fi is back.
    Shelf > Build Genres / Rebuild Genres.
  * **Flash** (both off by default): Hero > Flash When It Changes flashes the hero
    clean when it shows another book; Shelf > Flash On Every Page Turn makes every
    shelf page turn a full refresh. Both clear e-ink ghosting.

Settings: Tools → OrbitShelf Tweaks (or Add-ons with 2-tweaks-menu.lua):
  Use BookOrbit In Bookshelf, Rewrite Stock Series / Authors / Genres, then
  Hero, Shelf and Footer sub-menus, and Clean Up Cache at the end.

Install: koreader/patches/2-orbitshelf-tweaks.lua, restart.

Changelog:
  1.5.11 2026-11-05  Footer > Close Control: "Bottom" did nothing, because the close X is
                     always in a bottom corner and Bottom just left it where Bookshelf
                     puts its Start menu button. Renamed to Bookshelf's Side and listed
                     after Left and Right, with help text. The saved setting is unchanged.
  1.5.10 2026-11-05  Building genres no longer makes the screen look frozen. Each batch
                     waited inside BookOrbit's background helper, which holds the screen
                     until it's done. Now the lookups run in OrbitShelf's own background
                     process, checked every half second, so the shelf redraws and takes
                     taps the whole time. 10 books a batch. Sleep stops it; it carries on
                     when Wi-Fi is back.
  1.5.9  2026-11-05  Genres fill in. BookOrbit's book lists carry no genres (only a book's
                     own page has its genres and tags), so the Genres shelf was always
                     empty. The first time it opens, a question asks to build them: Start
                     looks each book up once in the background (a separate process, the
                     shelf stays usable), 20 at a time, saving after each batch, with a
                     corner note for progress and "Genres ready" at the end. Books on the
                     device use the genres in their own file, no network. Wi-Fi off, sleep
                     or a restart pauses it; it carries on when Wi-Fi is back. After that
                     only new or changed books are looked up, quietly. Shelf > Build
                     Genres (shows how many are left) and Rebuild Genres. Clean Up Cache
                     keeps them.
  1.5.8  2026-11-05  New: Flash When It Changes (Hero) flashes the hero clean when it shows
                     another book, so the old cover doesn't stay faintly behind the new one
                     (Bookshelf redraws it without a flash). Flash On Every Page Turn
                     (Shelf) makes every shelf page turn a full refresh. Both off by
                     default.
                     Settings are a normal grouped menu now (was one long button list):
                     the two main switches, then Hero, Shelf and Footer, then Clean Up
                     Cache. Each entry has a hold-for-help text. Nothing you set changes.
  1.5.7  2026-11-05  Fix: after a download the hero kept the BookOrbit look (no description)
                     until another book was picked and this one again; it now shows the
                     book from the file straight away. Removing it puts the hero back to
                     the BookOrbit book (Download / Open In BookOrbit).
                     Fix: once a book was on the device the hero lost its Remove From Device,
                     Open In BookOrbit and Sync buttons (Bookshelf rebuilds the hero's record
                     from the file, without the BookOrbit id; the file now tells which
                     BookOrbit book it is). For a book on the device they are small round
                     icons at the bottom right of the hero, so the description keeps its
                     room. Sync moved there too (it was top right), next to the pills for a
                     book not on the device.
                     Footer critter: the critter keeps its own shape (a big critter image was
                     stretched to the box), and the page line under the message is light
                     grey on a dark bar, dark grey on a light one (it was dark on dark and
                     faded out).
  1.5.6  2026-11-03  The hero's Download / Remove / Open In BookOrbit buttons now sit inside
                     the hero card, at the bottom of its right column (they were pushed down
                     under the tab bar). The footer critter is redrawn to sit in the bar:
                     the message and detail are written on the bar in its own ink, the
                     critter sits at the right end, both sized to the bar (the speech box
                     was taller than the bar and hung over its edge).
                     New: a Sync button on the hero card's top right (under the status
                     strip), on BookOrbit shelves. One tap throws away the saved BookOrbit
                     lists, pulls them fresh, and runs BookOrbit's own "sync all books"
                     (which relinks books on the device and syncs progress), then redraws
                     the shelf. Settings: Hero Sync Button on / off.
  1.5.5  2026-11-02  Choosing a BookOrbit list or collection for a shelf no longer renames
                     the shelf. Whatever title it already has is kept.
                     Holding a book that is on the device now has Remove From Device in
                     Bookshelf's book menu (and in the file browser's long-press menu),
                     for BookOrbit books. Holding one that is not on the device still shows
                     Download / Open In BookOrbit.
                     After a download the shelf is refreshed as soon as the file is saved,
                     before the book is linked to BookOrbit (a network call), so the hero
                     card and the downloaded mark update sooner. The linking then runs
                     right after, in the background of the Open or Later prompt.
  1.5.4  2026-11-01  Fix: a download started from the hero card's Download pill did not
                     refresh the shelf, so the book kept showing as not on the device
                     (and the pill kept saying Download) until something else refreshed
                     it. Every download now refreshes the shelf when it finishes, whoever
                     started it.
  1.5.3  2026-11-01  Tapping a BookOrbit book that is not on the device no longer
                     downloads and opens it. It shows a small window (title, author,
                     "Not On Device") with Download, Open In BookOrbit and Cancel; long-press
                     shows the same. After a download the book is not opened: it asks
                     Open or Later, like the Side Panel.
                     Downloads now work like the Side Panel's: BookOrbit's download folder
                     and folder layout, hash-checked, linked so it syncs, with the
                     "Downloading" pill.
                     Books on the device carry Bookshelf's own downloaded mark, and the
                     file path and mark are re-read every time a list is shown, so a book
                     downloaded or removed shows its new state without a refresh.
  1.5.2  2026-11-01  Fix: tapping a BookOrbit book, or opening a list of them, crashed
                     KOReader (bookshelf_tokens.lua:230). Bookshelf wants `authors` as a
                     list of names and `author` as the first name; both were one joined
                     string. Genres are a list too. Saved BookOrbit lists from older
                     versions are dropped once (new cache key) so they cannot crash it.
                     Fix: Authors groups now use BookOrbit's author list instead of
                     splitting a joined string on commas and slashes.
                     Fix: collections could not be picked unless the Side Panel had
                     already saved them. The picker and the shelf editor's List row now
                     fetch them from BookOrbit (Wi-Fi on), falling back to the saved
                     list, and the editor can pick a Collection. A Collection shelf with
                     no collection id now stays empty and logs why, instead of showing
                     the whole library.
                     Series / Authors / Genres groups and the books inside them are
                     ordered by Bookshelf's own sort rules (surname, articles ignored,
                     last opened, book count). Books carry last opened and added times.
  1.5.1  2026-11-01  Fix: the OrbitShelf Tweaks menu never showed up (not in Tools, not
                     in Add-ons), so Close Only and the critter switches couldn't be
                     reached. Registered the way the other patches do it, at load time.
                     Fix: a failed BookOrbit catalog fetch was cached as an empty shelf
                     (and an empty one saved from earlier is dropped); failures are
                     now logged and never cached.
  1.5.0  2026-11-01  Footer critter: page / witty / picks / sayings. Fixes the
                     page number and shelf name, which read the wrong Bookshelf
                     fields and showed page 1 and "this shelf".
  1.4.0  2026-11-01  Close Only is flat: hamburger becomes a close X, one tap
                     closes (no menu to open first).
  1.3.0  2026-10-31  Footer critter replaces page nav (shelf / page / count).
  1.2.0  2026-10-31  Fetch-mode Series/Authors/Genres; auto-rewrite; hero pills;
                     true left/right close.
  1.0.1  2026-10-31  Shared cover cache + Clean Up Cache (Reading Log style).
  1.0.0  2026-10-31  First cut: BookOrbit source, hero hold, close-only menu.
]]

local VERSION = "1.5.11"
local TAG = "orbitshelf-tweaks " .. VERSION .. ":"
local SETTINGS_KEY = "orbitshelf_tweaks"
local MENU_ID = "orbitshelf_tweaks"
local SOURCE_ID = "bookorbit"

local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

if package.loaded["orbitshelf_tweaks_patch"] then
    logger.warn(TAG, "duplicate patch skipped")
    return
end
package.loaded["orbitshelf_tweaks_patch"] = true

local DEFAULTS = {
    use_bookorbit = true,          -- register BookOrbit as a shelf source
    auto_rewrite_stock = true,     -- Series / Authors / Genres / Recent use BO data
    close_only_menu = false,       -- footer hamburger becomes a one-tap close X
    close_menu_side = "bottom",    -- "left" | "right" | "bottom" (= Bookshelf's own side)
    cache_ttl = 30 * 60,           -- soft refresh window (seconds)
    offline_ttl = 6 * 3600,        -- keep offline lists this long
    hero_pills = true,             -- Download / Remove / Open In BookOrbit on hero
    hero_sync = true,              -- Sync icon at the hero's bottom right
    footer_critter = true,         -- replace bottom page nav with a critter
    critter_say_page = true,       -- critter says which page / books you're on
    critter_say_witty = true,      -- witty remarks
    critter_say_recs = true,       -- picks from the books on this page
    critter_say_quotes = true,     -- shelf sayings (plus your own file)
    flash_hero = false,            -- flash the hero clean when it shows another book
    flash_shelf = false,           -- flash the shelf clean on every page turn
}

local cfg = {}
for k, v in pairs(DEFAULTS) do cfg[k] = v end
do
    local saved = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY)
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            if DEFAULTS[k] ~= nil then cfg[k] = v end
        end
    end
end

local function saveConfig()
    if not G_reader_settings then return end
    G_reader_settings:saveSetting(SETTINGS_KEY, {
        use_bookorbit = cfg.use_bookorbit,
        auto_rewrite_stock = cfg.auto_rewrite_stock,
        close_only_menu = cfg.close_only_menu,
        close_menu_side = cfg.close_menu_side,
        cache_ttl = cfg.cache_ttl,
        offline_ttl = cfg.offline_ttl,
        hero_pills = cfg.hero_pills,
        hero_sync = cfg.hero_sync,
        footer_critter = cfg.footer_critter,
        critter_say_page = cfg.critter_say_page,
        critter_say_witty = cfg.critter_say_witty,
        critter_say_recs = cfg.critter_say_recs,
        critter_say_quotes = cfg.critter_say_quotes,
    })
    if G_reader_settings.flush then pcall(G_reader_settings.flush, G_reader_settings) end
end

-- ---- Presence checks --------------------------------------------------------------

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

local function getBookshelf(ui)
    ui = ui or (package.loaded["apps/filemanager/filemanager"]
        and package.loaded["apps/filemanager/filemanager"].instance)
    if type(ui) == "table" and type(ui.bookshelf) == "table" then return ui.bookshelf end
    -- Reader context
    local ReaderUI = package.loaded["apps/reader/readerui"]
    if type(ReaderUI) == "table" and type(ReaderUI.instance) == "table"
            and type(ReaderUI.instance.bookshelf) == "table" then
        return ReaderUI.instance.bookshelf
    end
    return nil
end

-- ---- BookOrbit API helpers (aligned with 2-simpleui-sidepanel) --------------------

local function boApiClient()
    local s = G_reader_settings and G_reader_settings:readSetting("bookorbit")
    if type(s) ~= "table" or not s.server_url or not s.username or not s.userkey then
        return nil, "not signed in"
    end
    local ok, BookOrbitApi = pcall(require, "bookorbit_api")
    if not ok or type(BookOrbitApi) ~= "table" or type(BookOrbitApi.new) ~= "function" then
        return nil, "BookOrbit not installed"
    end
    return BookOrbitApi.new({
        server_url = s.server_url,
        username = s.username,
        userkey = s.userkey,
        device_id = s.device_id,
    })
end

local function isWifiOn()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if ok and type(NetworkMgr) == "table" then
        if type(NetworkMgr.isWifiOn) == "function" then
            local a, b = pcall(NetworkMgr.isWifiOn, NetworkMgr)
            if a then return b end
        end
        if type(NetworkMgr.isConnected) == "function" then
            local a, b = pcall(NetworkMgr.isConnected, NetworkMgr)
            if a then return b end
        end
    end
    return false
end

local function onDeviceByBookId(refresh)
    local ok, SM = pcall(require, "bookorbit_state_manager")
    if not (ok and type(SM) == "table") then return {} end
    if refresh and type(SM.invalidate) == "function" then pcall(SM.invalidate) end
    if type(SM.onDeviceMaps) == "function" then
        local okm, maps = pcall(SM.onDeviceMaps)
        if okm and type(maps) == "table" and type(maps.byBookId) == "table" then
            return maps.byBookId
        end
    end
    return {}
end

local function liveBookPath(book_id)
    if book_id == nil then return nil end
    local on_device = onDeviceByBookId(false)
    local fp = on_device[book_id] or on_device[tostring(book_id)] or on_device[tonumber(book_id)]
    if type(fp) == "string" and fp ~= "" and lfs.attributes(fp, "mode") == "file" then
        return fp
    end
    -- Side Panel local downloads waiting to be linked
    local mine = G_reader_settings and G_reader_settings:readSetting("simpleui_sidepanel_bo_local")
    local own = type(mine) == "table" and mine[tostring(book_id)] or nil
    if type(own) == "string" and lfs.attributes(own, "mode") == "file" then return own end
    return nil
end

-- Bookshelf wants `authors` as a list of names and `author` as the first one.
local function authorList(book)
    local out = {}
    if type(book.authors) == "table" then
        for _j, a in ipairs(book.authors) do
            if type(a) == "string" and a ~= "" then out[#out + 1] = a
            elseif type(a) == "table" and type(a.name) == "string" and a.name ~= "" then out[#out + 1] = a.name end
        end
    elseif type(book.authors) == "string" and book.authors ~= "" then
        out[1] = book.authors
    end
    if #out == 0 and type(book.author) == "string" and book.author ~= "" then out[1] = book.author end
    return out
end

-- "2026-10-31T14:03:22.000Z" -> unix time (UTC), nil when it does not parse
local function isoToUnix(str)
    if type(str) ~= "string" then return nil end
    local y, mo, d, h, mi, se = str:match("^(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):(%d+)")
    if not y then return nil end
    y, mo, d, h, mi, se = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(se)
    local yy = mo <= 2 and y - 1 or y
    local era = math.floor(yy / 400)
    local yoe = yy - era * 400
    local doy = math.floor((153 * (mo + (mo > 2 and -3 or 9)) + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return (era * 146097 + doe - 719468) * 86400 + h * 3600 + mi * 60 + se
end

local function coverVersion(book)
    local t = tostring(book.updatedAt or book.coverUpdatedAt or ""):gsub("%D", "")
    if #t > 32 then t = t:sub(1, 16) .. t:sub(-16) end
    return t ~= "" and t or "0"
end

-- Covers live in the same folder BookOrbit and Side Panel use:
--   <datadir>/cache/bookorbit/<id>_<cv>.jpg
-- Prefer an already-cached cover; missing ones are fetched in the background
-- (Wi-Fi only, up to 8 at a time) via downloadCatalogThumbnail, so BookOrbit
-- sees them too. Clean Up Cache matches Reading Log Tweaks: newest of each
-- book kept, at most 600, half-finished .part files dropped.
local BoCovers = {}
do
    local index, index_at
    local wanted, tried, busy = {}, {}, false

    local function dir()
        return require("datastorage"):getDataDir() .. "/cache/bookorbit"
    end

    local function buildIndex()
        index = {}
        local d = dir()
        if lfs.attributes(d, "mode") ~= "directory" then return end
        for f in lfs.dir(d) do
            -- same pattern Side Panel / Reading Log use
            local id, tok = f:match("^(%d+)_(%d+)%.jpg$")
            if id and (not index[id] or tok > index[id].tok) then
                index[id] = { tok = tok, path = d .. "/" .. f }
            end
        end
    end

    function BoCovers.forget()
        index, tried, wanted = nil, {}, {}
    end

    function BoCovers.path(book_id, cv)
        if book_id == nil then return nil end
        if not index or os.time() - (index_at or 0) > 600 then
            buildIndex()
            index_at = os.time()
        end
        local id = tostring(book_id)
        local hit = index[id]
        if hit and lfs.attributes(hit.path, "mode") ~= "file" then
            index[id] = nil
            tried[tonumber(book_id)] = nil
            hit = nil
        end
        if hit then return hit.path end
        -- exact version path (even if index is stale)
        if cv then
            local exact = string.format("%s/%s_%s.jpg", dir(), id, tostring(cv))
            if lfs.attributes(exact, "mode") == "file" then return exact end
        end
        return nil
    end

    function BoCovers.want(book_id, cv)
        local id = tonumber(book_id)
        if id and not tried[id] and not BoCovers.path(id, cv) then
            wanted[id] = tostring(cv or "0")
        end
    end

    function BoCovers.fetch(on_done)
        if busy or next(wanted) == nil or not isWifiOn() then return end
        local client = boApiClient()
        if not client then wanted = {} return end
        local jobs, d = {}, dir()
        for id, cv in pairs(wanted) do
            if #jobs < 8 then
                tried[id] = true
                jobs[#jobs + 1] = { id = id, path = string.format("%s/%d_%s.jpg", d, id, cv) }
            end
        end
        for _i, j in ipairs(jobs) do wanted[j.id] = nil end
        if #jobs == 0 then return end
        busy = true
        require("util").makePath(d)
        require("ui/trapper"):wrap(function()
            local got = 0
            local ok_run, completed, result = pcall(client.runInSubprocess, client, function()
                local n = 0
                for _i, j in ipairs(jobs) do
                    local ok = client:downloadCatalogThumbnail(j.id, j.path, {
                        temp_path = j.path .. ".part",
                        max_bytes = 4 * 1024 * 1024,
                        background = false,
                    })
                    if ok then n = n + 1 end
                end
                return n
            end)
            busy = false
            if ok_run and completed and type(result) == "table" then
                got = tonumber(result.body) or 0
            elseif ok_run and type(result) == "number" then
                got = result
            end
            if next(wanted) ~= nil then
                UIManager:nextTick(function() BoCovers.fetch(on_done) end)
            end
            if got > 0 then
                index = nil
                local bs = getBookshelf()
                if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
                if on_done then pcall(on_done, got) end
            end
        end)
    end

    -- Reading Log style: newest cover per book, max 600, drop old + .part leftovers
    function BoCovers.cleanUp()
        local res = { files = 0, bytes = 0, entries = 0 }
        local function gone(path)
            local size = lfs.attributes(path, "size") or 0
            if os.remove(path) then
                res.files = res.files + 1
                res.bytes = res.bytes + size
            end
        end
        local d = dir()
        local newest, all = {}, {}
        if lfs.attributes(d, "mode") == "directory" then
            for name in lfs.dir(d) do
                -- half-finished downloads, ten minutes old or more
                if name:match("%.part$") then
                    local path = d .. "/" .. name
                    local at = lfs.attributes(path, "modification") or 0
                    if os.time() - at >= 600 then gone(path) end
                else
                    local id = name:match("^a?(%d+)_[%w]+%.jpg$")
                    if id then
                        local path = d .. "/" .. name
                        local at = lfs.attributes(path, "modification") or 0
                        local who = (name:sub(1, 1) == "a" and "a" or "") .. id
                        local e = { path = path, at = at }
                        all[#all + 1] = e
                        local cur = newest[who]
                        if not cur or at > cur.at then
                            if cur then cur.old = true end
                            newest[who] = e
                        else
                            e.old = true
                        end
                    end
                end
            end
            for _, e in ipairs(all) do
                if e.old then gone(e.path) end
            end
            local keep = {}
            for _, e in pairs(newest) do
                if not e.old then keep[#keep + 1] = e end
            end
            table.sort(keep, function(a, b) return a.at > b.at end)
            for i = 601, #keep do gone(keep[i].path) end
        end
        -- Side Panel local downloads whose file is gone
        local mine = G_reader_settings and G_reader_settings:readSetting("simpleui_sidepanel_bo_local")
        if type(mine) == "table" then
            local changed = false
            for k, path in pairs(mine) do
                if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then
                    mine[k] = nil
                    changed = true
                    res.entries = res.entries + 1
                end
            end
            if changed then G_reader_settings:saveSetting("simpleui_sidepanel_bo_local", mine) end
        end
        BoCovers.forget()
        -- Side Panel / Reading Log forget hooks when present
        pcall(function()
            local SP = package.loaded.simpleui_sidepanel
            if type(SP) == "table" and type(SP.boCoverForget) == "function" then SP.boCoverForget() end
        end)
        pcall(function()
            local side = package.loaded["simpleui_sidepanel_bo"]
            -- nothing required
        end)
        return res
    end
end

local function coverPathFor(book_id, cv)
    return BoCovers.path(book_id, cv)
end

-- In-memory + settings-backed page cache: key -> { t=, items=, total= }
local page_cache = {}
local CACHE_KEY = "orbitshelf_tweaks_pages_2"
local OLD_CACHE_KEY = "orbitshelf_tweaks_pages" -- 1.5.1 and older: authors saved as one string

local function loadPageCache()
    if G_reader_settings and G_reader_settings:readSetting(OLD_CACHE_KEY) ~= nil then
        G_reader_settings:delSetting(OLD_CACHE_KEY)
    end
    local saved = G_reader_settings and G_reader_settings:readSetting(CACHE_KEY)
    if type(saved) == "table" then
        page_cache = saved
        -- an empty list saved from a failed fetch must not hide the shelf
        for k, v in pairs(page_cache) do
            if type(v) ~= "table" or type(v.items) ~= "table" or #v.items == 0 then
                page_cache[k] = nil
            end
        end
    end
end
loadPageCache()

local function savePageCache()
    if not G_reader_settings then return end
    -- Keep the cache small: drop entries older than offline_ttl
    local now = os.time()
    local slim = {}
    for k, v in pairs(page_cache) do
        if type(v) == "table" and type(v.t) == "number" and (now - v.t) < (cfg.offline_ttl or 21600) then
            slim[k] = v
        end
    end
    page_cache = slim
    G_reader_settings:saveSetting(CACHE_KEY, page_cache)
end

local function recordFromBo(book)
    local id = book.id
    local fp = liveBookPath(id)
    local cv = coverVersion(book)
    local cover = coverPathFor(id, cv)
    if not cover then
        -- queue background fetch into the shared BookOrbit cache folder
        BoCovers.want(id, cv)
    end
    local series = book.seriesName or book.series or ""
    local series_index = tonumber(book.seriesIndex) or tonumber(book.series_index)
    local genres
    if type(book.genres) == "table" then
        genres = {}
        for _i, g in ipairs(book.genres) do
            if type(g) == "string" then genres[#genres + 1] = g
            elseif type(g) == "table" and g.name then genres[#genres + 1] = g.name end
        end
    elseif type(book.genre) == "string" and book.genre ~= "" then
        genres = { book.genre }
    elseif type(book.tags) == "table" then
        genres = {}
        for _i, t in ipairs(book.tags) do
            if type(t) == "string" then genres[#genres + 1] = t
            elseif type(t) == "table" and t.name then genres[#genres + 1] = t.name end
        end
    end
    local remote = "bookorbit://" .. tostring(id)
    local authors = authorList(book)
    return {
        filepath = fp or remote,
        title = book.title or book.name or _("Untitled"),
        authors = authors,
        author = authors[1] or "",
        series = series,
        series_name = series,
        series_index = series_index,
        series_num = series_index and tostring(series_index) or nil,
        genres = genres,
        description = book.description or book.summary,
        cover_image_path = cover,
        pages = tonumber(book.pageCount) or tonumber(book.pages),
        last_opened = isoToUnix(book.lastReadAt),
        last_read_time = isoToUnix(book.lastReadAt),
        added_time = isoToUnix(book.addedAt),
        downloaded = fp and true or nil,
        bookorbit_id = id,
        bookorbit_cv = cv,
        is_bookorbit = true,
        -- Bookshelf stamps source_kind itself; we also mark for owns()
        source_kind = SOURCE_ID,
    }
end

local function refreshCoverPaths(items)
    if type(items) ~= "table" then return items end
    for _i, rec in ipairs(items) do
        if type(rec) == "table" and rec.bookorbit_id then
            -- on the device or not, as of now (a download or a removal since the list was saved)
            local live = liveBookPath(rec.bookorbit_id)
            if live then
                rec.filepath, rec.downloaded = live, true
            else
                rec.filepath, rec.downloaded = "bookorbit://" .. tostring(rec.bookorbit_id), nil
            end
            local path = coverPathFor(rec.bookorbit_id, rec.bookorbit_cv)
            if path then
                rec.cover_image_path = path
            else
                BoCovers.want(rec.bookorbit_id, rec.bookorbit_cv)
            end
        end
    end
    return items
end

local function fetchBoPage(api_params, force)
    local client, err = boApiClient()
    if not client then return {}, nil, err end

    local key_parts = {}
    for k, v in pairs(api_params or {}) do
        key_parts[#key_parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(key_parts)
    local key = table.concat(key_parts, "&")
    local now = os.time()
    local entry = page_cache[key]
    local wifi = isWifiOn()

    if not force and type(entry) == "table" and type(entry.items) == "table" then
        local age = now - (entry.t or 0)
        if (not wifi and age < (cfg.offline_ttl or 21600))
                or (wifi and age < (cfg.cache_ttl or 1800)) then
            local items = refreshCoverPaths(entry.items)
            BoCovers.fetch()
            return items, entry.total
        end
    end

    if not wifi and type(entry) == "table" and type(entry.items) == "table" then
        return refreshCoverPaths(entry.items), entry.total
    end

    local books, seen, page, page_size = {}, {}, 1, 100
    local total
    local failed = false
    for _guard = 1, 20 do
        local q = {}
        for k, v in pairs(api_params or {}) do q[k] = v end
        q.page, q.size = page, page_size
        local ok_body, body = pcall(function() return client:catalogBooks(q) end)
        if not ok_body or type(body) ~= "table" then
            failed = true
            logger.warn(TAG, "catalog fetch failed on page", page, "-", ok_body and "no usable reply" or tostring(body),
                "(wifi " .. (wifi and "on" or "off") .. ")")
            break
        end
        local items = body.items or body.books or body.entries or {}
        if type(items) ~= "table" or #items == 0 then break end
        for _i, book in ipairs(items) do
            if type(book) == "table" and book.id and not seen[book.id] then
                seen[book.id] = true
                books[#books + 1] = recordFromBo(book)
            end
        end
        total = tonumber(body.total) or tonumber(body.totalCount) or total
        if total and page * page_size >= total then break end
        if #items < page_size then break end
        page = page + 1
    end

    if failed then
        -- never cache a failed fetch: keep the last good list, or show what came in
        if #books == 0 and type(entry) == "table" and type(entry.items) == "table" and #entry.items > 0 then
            return refreshCoverPaths(entry.items), entry.total, "catalog fetch failed"
        end
        return books, total or #books, "catalog fetch failed"
    end
    if #books == 0 then
        logger.info(TAG, "catalog returned no books for", key ~= "" and key or "(all)")
    end
    page_cache[key] = { t = now, items = books, total = total or #books }
    savePageCache()
    -- pull missing covers into the shared cache (Side Panel / BookOrbit folder)
    BoCovers.fetch()
    return books, total or #books
end

-- ---- Download / remove (Side Panel style) -----------------------------------------

local function rememberLocalDownload(book_id, path)
    if not G_reader_settings or not book_id or not path then return end
    local mine = G_reader_settings:readSetting("simpleui_sidepanel_bo_local")
    if type(mine) ~= "table" then mine = {} end
    mine[tostring(book_id)] = path
    G_reader_settings:saveSetting("simpleui_sidepanel_bo_local", mine)
end

local function forgetLocalDownload(book_id)
    if not G_reader_settings or not book_id then return end
    local mine = G_reader_settings:readSetting("simpleui_sidepanel_bo_local")
    if type(mine) ~= "table" then return end
    mine[tostring(book_id)] = nil
    G_reader_settings:saveSetting("simpleui_sidepanel_bo_local", mine)
end

-- The hero shows a book picked on the shelf as Bookshelf's preview record. After a
-- download (or a removal) that record still points at the old place, so the hero kept
-- its old look until another book was picked and this one again. It is pointed at the
-- book's new place here, before the shelf redraws.
local function retargetHeroPreview(id, local_path)
    pcall(function()
        local bs = getBookshelf()
        local w = bs and bs._widget
        local pb = w and w._preview_book
        -- a record rebuilt from the file gets its id back when the hero draws it
        -- (asBookOrbit), so the id is enough
        if type(pb) ~= "table" or tonumber(pb.bookorbit_id) ~= tonumber(id) then return end
        if local_path then
            -- read from the file now, the way Bookshelf does for a book on the device
            local fresh = type(w._hydrateBook) == "function" and w:_hydrateBook({ filepath = local_path }) or nil
            if type(fresh) == "table" then
                fresh.bookorbit_id = tonumber(id) or id
                fresh.is_bookorbit = true
                w._preview_book = fresh
            else
                pb.filepath = local_path
                pb.downloaded = true
            end
        else
            -- back to the BookOrbit record (Download / Open In BookOrbit)
            local rec
            for _k, entry in pairs(page_cache) do
                for _i, r in ipairs(type(entry) == "table" and entry.items or {}) do
                    if type(r) == "table" and tonumber(r.bookorbit_id) == tonumber(id) then rec = r break end
                end
                if rec then break end
            end
            local remote = "bookorbit://" .. tostring(id)
            local copy = {}
            for k, v in pairs(rec or pb) do copy[k] = v end
            copy.filepath, copy.downloaded = remote, nil
            copy.bookorbit_id, copy.is_bookorbit, copy.source_kind = tonumber(id) or id, true, SOURCE_ID
            w._preview_book = copy
        end
        w._hero_book_cache = nil
    end)
end

local function downloadBookOrbitBook(book, on_done)
    local id = tonumber(book and (book.bookorbit_id or book.id))
    if not id then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("No BookOrbit id") })
        return
    end
    local client = boApiClient()
    if not client then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("BookOrbit is not signed in") })
        return
    end
    local function fail(msg)
        UIManager:show(require("ui/widget/infomessage"):new{ text = msg })
    end

    -- the file a download takes: the main supported one
    local function pickFile(detail)
        local okU, CU = pcall(require, "bookorbit_catalog_util")
        local function usable(f) return type(f) == "table" and f.id and (not okU or CU.isSupportedFormat(f.format)) end
        for _i, f in ipairs(type(detail) == "table" and detail.files or {}) do
            if usable(f) and f.role == "primary" then return f end
        end
        for _i, f in ipairs(type(detail) == "table" and detail.files or {}) do
            if usable(f) then return f end
        end
        return nil
    end

    -- Same way the Side Panel and BookOrbit's own book page download: BookOrbit's
    -- download folder and layout, checked against the server's hash, then linked.
    local function run()
        local Trapper = require("ui/trapper")
        Trapper:wrap(function()
            local okT, Toast = pcall(require, "bookorbit_toast")
            local pill = okT and Toast.loading and Toast.loading(T(_("Downloading %1…"), tostring(book.title or _("book")))) or nil
            local function done() if pill and pill.close then pcall(pill.close, pill) end end

            local ok_run, completed, result = pcall(client.runInSubprocess, client, function() return client:catalogBook(id) end)
            local detail = ok_run and completed and type(result) == "table" and result.body or nil
            if type(detail) ~= "table" then
                local ok_d, d = pcall(function() return client:catalogBook(id) end)
                detail = ok_d and type(d) == "table" and d or nil
            end
            if type(detail) ~= "table" then
                done()
                return fail(_("Could not load book details"))
            end
            local file = pickFile(detail)
            if not file then done() return fail(_("No file this reader can open")) end

            local okR, Root = pcall(require, "bookorbit_download_root")
            local root = okR and type(Root) == "table" and Root.get and Root.get()
                or (G_reader_settings and G_reader_settings:readSetting("home_dir"))
            if type(root) ~= "string" or root == "" then
                done()
                return fail(_("Set a download folder in BookOrbit first."))
            end
            local util = require("util")
            -- the server's folder layout under the download folder
            local rel
            local dp = tostring(file.devicePath or ""):gsub("\\", "/"):gsub("^/+", "")
            if dp ~= "" then
                local segs, bad = {}, false
                for seg in dp:gmatch("[^/]+") do
                    if seg == ".." then bad = true break end
                    if seg ~= "." then segs[#segs + 1] = util.getSafeFilename(seg, root) end
                end
                if not bad and #segs > 0 then rel = table.concat(segs, "/") end
            end
            if not rel then
                local okC, CU = pcall(require, "bookorbit_catalog_util")
                local base = okC and CU.safeFilenameBase(detail) or tostring(detail.title or ("book-" .. id))
                rel = util.getSafeFilename(base .. "." .. tostring(file.format or "epub"):lower(), root)
            end
            local dest = (root ~= "/" and root or "") .. "/" .. rel
            local parent = dest:match("^(.*)/[^/]+$")
            if parent then util.makePath(parent) end

            if lfs.attributes(dest, "mode") ~= "file" then
                local okX, Transfer = pcall(require, "bookorbit_download_transfer")
                if not okX then done() return fail(_("This BookOrbit version can't download from here.")) end
                pcall(Transfer.sweepStale, root)
                local ok_t, ok, err = pcall(Transfer.run, {
                    root = root, destination = dest, generation = os.time(),
                    expected_bytes = file.sizeBytes, expected_hash = file.fileHash, hash = "partial_md5",
                    perform = function(o)
                        o.variant = file.selection and (file.requestedVariant or file.downloadVariant) or nil
                        o.selection = file.selection
                        return client:downloadCatalogFile(file.id, dest, o)
                    end,
                })
                if not (ok_t and ok) then
                    done()
                    logger.warn(TAG, "download failed:", ok_t and err or ok)
                    if err ~= "cancelled" then
                        fail(T(_("Couldn't download it:\n%1"), tostring(ok_t and err or ok)))
                    end
                    return
                end
            end

            -- on the device straight away, before BookOrbit links it
            rememberLocalDownload(id, dest)

            done()
            if on_done then pcall(on_done, dest) end
            -- the shelf shows it as on the device now, whoever started the download;
            -- before the link below, which is a network call
            retargetHeroPreview(id, dest)
            local bs = getBookshelf()
            if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end

            -- linked to its BookOrbit book, so it syncs: a moment later, after the shelf
            -- has redrawn
            UIManager:scheduleIn(0.5, function()
                pcall(function()
                    local digest = util.partialMD5(dest)
                    if not digest then return end
                    local body = client:matchCheck({ digest }, { [digest] = { source = "file", book_file_id = file.id } })
                    local SM = require("bookorbit_state_manager")
                    if type(body) ~= "table" then return end
                    if SM.applyLibraryVersion then SM.applyLibraryVersion(body.libraryVersion) end
                    for _i, m in ipairs(body.matches or {}) do
                        if m.hash == digest then
                            SM.linkFile(digest, m.bookFileId, m.bookId, dest)
                            return
                        end
                    end
                end)
            end)

            -- it is not opened by itself: the reader chooses
            UIManager:show(require("ui/widget/confirmbox"):new{
                text = T(_("Downloaded %1.\n\nOpen it now?"), tostring(detail.title or book.title or "")),
                ok_text = _("Open"),
                cancel_text = _("Later"),
                ok_callback = function()
                    require("apps/reader/readerui"):showReader(dest)
                end,
            })
        end)
    end

    local okN, NetworkMgr = pcall(require, "ui/network/manager")
    if okN and NetworkMgr.runWhenConnected then
        NetworkMgr:runWhenConnected(run)
    else
        run()
    end
end

local function removeFromDevice(book)
    local path = book and book.filepath
    if type(path) ~= "string" or path:match("^bookorbit://") then
        path = liveBookPath(book and book.bookorbit_id)
    end
    if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("Not on this device") })
        return
    end
    UIManager:show(require("ui/widget/confirmbox"):new{
        text = T(_("Remove %1 from this device?\n\nIt stays in BookOrbit."), tostring(book.title or path)),
        ok_text = _("Remove"),
        ok_callback = function()
            pcall(os.remove, path)
            -- sidecar
            local sdr = path:match("^(.*)%.[^.]+$")
            if sdr then
                local dir = sdr .. ".sdr"
                if lfs.attributes(dir, "mode") == "directory" then
                    pcall(function()
                        for f in lfs.dir(dir) do
                            if f ~= "." and f ~= ".." then pcall(os.remove, dir .. "/" .. f) end
                        end
                        lfs.rmdir(dir)
                    end)
                end
            end
            -- history / collections best-effort
            pcall(function()
                local ReadHistory = require("readhistory")
                if ReadHistory and ReadHistory.removeItemByPath then
                    ReadHistory:removeItemByPath(path)
                end
            end)
            pcall(function()
                local RC = require("readcollection")
                if type(RC) == "table" and type(RC.coll) == "table" then
                    for name, _ in pairs(RC.coll) do
                        if RC.removeItem then pcall(RC.removeItem, RC, path, name) end
                    end
                end
            end)
            forgetLocalDownload(book.bookorbit_id)
            if book.bookorbit_id then retargetHeroPreview(book.bookorbit_id, nil) end
            UIManager:show(require("ui/widget/infomessage"):new{
                text = _("Removed from device"),
                timeout = 2,
            })
            local bs = getBookshelf()
            if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
        end,
    })
end

-- BookOrbit book id for a file on the device, or nil when it is not one of theirs
local function bookIdForPath(file)
    if type(file) ~= "string" or file == "" then return nil end
    for id, fp in pairs(onDeviceByBookId(false)) do
        if fp == file then return tonumber(id) or id end
    end
    local mine = G_reader_settings and G_reader_settings:readSetting("simpleui_sidepanel_bo_local")
    if type(mine) == "table" then
        for id, fp in pairs(mine) do
            if fp == file then return tonumber(id) or id end
        end
    end
    return nil
end

-- Remove From Device in the long-press menu of a BookOrbit book that is on the device.
-- Bookshelf shows buttons registered here in its own book menu; the file browser's
-- long-press menu shows them too.
local FILE_DIALOG_ID = "orbitshelf_remove_from_device"
local function registerFileDialogButton()
    local okFM, FileManager = pcall(require, "apps/filemanager/filemanager")
    if not (okFM and type(FileManager) == "table" and type(FileManager.addFileDialogButtons) == "function") then
        return false
    end
    FileManager.addFileDialogButtons(FileManager, FILE_DIALOG_ID, function(file, is_file, book_props)
        if not is_file then return nil end
        local id = bookIdForPath(file)
        if not id then return nil end
        return {{
            text = _("Remove From Device"),
            callback = function()
                -- close the book menu this was tapped in (the top window that has a
                -- rebuildTab), like Bookshelf's own Delete does
                pcall(function()
                    local stack = UIManager._window_stack or {}
                    for i = #stack, 1, -1 do
                        local w = stack[i].widget
                        if type(w) == "table" and type(w.rebuildTab) == "function" then
                            UIManager:close(w)
                            break
                        end
                    end
                end)
                local title = type(book_props) == "table" and book_props.title or nil
                removeFromDevice({
                    bookorbit_id = id,
                    filepath = file,
                    title = title or (file:match("([^/]+)%.[^./]+$") or file:match("([^/]+)$") or file),
                })
            end,
        }}
    end)
    return true
end

local function openInBookOrbit(book)
    local id = book and book.bookorbit_id
    if not id then return false end
    local plugin
    pcall(function()
        local FM = package.loaded["apps/filemanager/filemanager"]
        local fm = type(FM) == "table" and FM.instance
        if type(fm) == "table" then
            plugin = fm.bookorbit or fm._bookorbit_plugin
        end
    end)
    if not plugin then
        -- discover via package
        local ok, main = pcall(require, "bookorbit")
        if ok and type(main) == "table" then plugin = main end
    end
    -- Try common open paths (same as Side Panel)
    local function tryOpenDetail(p)
        if type(p) ~= "table" then return false end
        if not p.catalog_browser then
            if type(p.openBookOrbit) == "function" then pcall(p.openBookOrbit, p) end
            if not p.catalog_browser and type(p.browseCatalog) == "function" then
                pcall(p.browseCatalog, p, false)
            end
            if not p.catalog_browser and type(p.openCatalogBrowser) == "function" then
                pcall(p.openCatalogBrowser, p)
            end
        end
        local catalog = p.catalog_browser
        if type(catalog) == "table" and type(catalog.loadBookDetail) == "function" then
            return pcall(catalog.loadBookDetail, catalog, id)
        end
        return false
    end
    if tryOpenDetail(plugin) then return true end
    -- Dispatcher / global
    local okD, Dispatcher = pcall(require, "dispatcher")
    if okD and Dispatcher and Dispatcher.execute then
        pcall(Dispatcher.execute, { "BookOrbit" })
    end
    return false
end

-- A tap or a long-press on a book that is not on the device: say so and offer
-- Download. Nothing downloads or opens until a button is pressed.
local function showNotOnDevice(book)
    local ButtonDialog = require("ui/widget/buttondialog")
    local lines = { tostring(book.display_title or book.title or "") }
    local who = book.author
    if type(who) ~= "string" or who == "" then who = type(book.authors) == "table" and book.authors[1] or "" end
    if type(who) == "string" and who ~= "" then lines[#lines + 1] = who end
    if type(book.series) == "string" and book.series ~= "" then
        local n = tonumber(book.series_index)
        lines[#lines + 1] = n and T(_("%1 #%2"), book.series, tostring(n)) or book.series
    end
    lines[#lines + 1] = _("Not On Device")
    local dialog
    dialog = ButtonDialog:new{
        title = table.concat(lines, "\n"),
        buttons = {
            {{ text = _("Download"), callback = function()
                UIManager:close(dialog)
                downloadBookOrbitBook(book)
            end }},
            {{ text = _("Open In BookOrbit"), callback = function()
                UIManager:close(dialog)
                openInBookOrbit(book)
            end }},
            {{ text = _("Cancel"), callback = function() UIManager:close(dialog) end }},
        },
    }
    UIManager:show(dialog)
end

-- ---- Genres: built once from each book's details --------------------------------
-- BookOrbit's book lists carry no genres (only a book's own detail page has its
-- genres and tags), so the Genres shelf needs them looked up once per book. It asks
-- first, then runs in the background in a separate process (the shelf stays usable),
-- 10 books at a time, saving after each batch. Wi-Fi off, sleep or a restart pauses
-- it; it carries on when Wi-Fi is back. A book on the device uses the genres in its
-- own file, no network. Afterwards only new or changed books are looked up.
local GENRES_KEY = "orbitshelf_genres"
local Genres = { store = nil, running = false, paused = false, asked = false, total = 0, done = 0 }

-- the whole library as saved (no network: the menu and the checks must not wait)
function Genres.library()
    local e = page_cache["sort=title"]
    if type(e) == "table" and type(e.items) == "table" and #e.items > 0 then return e.items end
    return nil
end

function Genres.load()
    if Genres.store then return Genres.store end
    local saved = G_reader_settings and G_reader_settings:readSetting(GENRES_KEY)
    Genres.store = type(saved) == "table" and saved or {}
    return Genres.store
end

function Genres.save()
    if G_reader_settings and Genres.store then
        G_reader_settings:saveSetting(GENRES_KEY, Genres.store)
    end
end

-- genres then tags, no repeats (any case), not an author's own name
function Genres.fromDetail(detail)
    local seen, out, authors = {}, {}, {}
    for _i, a in ipairs(type(detail.authors) == "table" and detail.authors or {}) do
        local name = type(a) == "table" and a.name or a
        if type(name) == "string" then authors[name:lower()] = true end
    end
    for _i, list in ipairs({ detail.genres or {}, detail.tags or {} }) do
        for _j, v in ipairs(type(list) == "table" and list or {}) do
            local text = type(v) == "table" and v.name or v
            text = type(text) == "string" and text:match("^%s*(.-)%s*$") or nil
            local key = text and text:lower()
            if key and key ~= "" and not seen[key] and not authors[key] then
                seen[key] = true
                out[#out + 1] = text
            end
        end
    end
    return out
end

-- the file's own keywords, for a book on the device (no network)
function Genres.fromFile(path)
    local out = {}
    pcall(function()
        local ds = require("docsettings"):open(path)
        local props = ds and ds:readSetting("doc_props")
        local kw = type(props) == "table" and props.keywords or nil
        if type(kw) == "string" then
            for part in kw:gmatch("[^\n,;]+") do
                local t = part:match("^%s*(.-)%s*$")
                if t and t ~= "" then out[#out + 1] = t end
            end
        end
    end)
    return out
end

-- a book's genres, as saved (nil when not built yet)
function Genres.of(rec)
    local id = rec and rec.bookorbit_id
    if not id then return nil end
    local e = Genres.load()[tostring(id)]
    return type(e) == "table" and e.g or nil
end

-- books still to look up: not saved yet, or changed in BookOrbit since
function Genres.missing(books)
    local store, out = Genres.load(), {}
    for _i, rec in ipairs(books or {}) do
        local id = rec.bookorbit_id
        if id then
            local e = store[tostring(id)]
            if type(e) ~= "table" or (rec.bookorbit_cv and e.cv ~= tostring(rec.bookorbit_cv)) then
                out[#out + 1] = rec
            end
        end
    end
    return out
end

-- a note in the corner (Network Tweaks style), never over the sleep screen
function Genres.note(text)
    pcall(function()
        if require("device").screen_saver_mode then return end
        local NM = package.loaded["ui/network/manager"]
        if type(NM) == "table" and type(NM.__network_tweaks_note) == "function" then
            local ok, handled = pcall(NM.__network_tweaks_note, text, text, 3)
            if ok and handled then return end
        end
        require("ui/widget/notification"):notify(text)
    end)
end

function Genres.build(silent)
    if Genres.running then return end
    local books = Genres.library() or fetchBoPage({ sort = "title" }, false) or {}
    local todo = Genres.missing(books)
    if #todo == 0 then Genres.paused = false return end
    -- books on the device first, from their files
    local store, net = Genres.load(), {}
    for _i, rec in ipairs(todo) do
        local path = liveBookPath(rec.bookorbit_id)
        local g = path and Genres.fromFile(path) or {}
        if #g > 0 then
            store[tostring(rec.bookorbit_id)] = { cv = tostring(rec.bookorbit_cv or ""), g = g }
        else
            net[#net + 1] = rec
        end
    end
    Genres.save()
    if #net == 0 then
        local bs = getBookshelf()
        if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
        return
    end
    if not isWifiOn() then
        Genres.paused = true
        if not silent then Genres.note(_("Genres paused: Wi-Fi is off. They'll finish when it's back.")) end
        return
    end
    local client = boApiClient()
    if not client then return end
    Genres.running, Genres.paused = true, false
    Genres.total, Genres.done = #net, 0
    if not silent then Genres.note(T(_("Building genres: 0 of %1"), #net)) end
    Genres.step(client, net, 1)
end

-- One line per book back from the worker: id, cover version, genres (unit-separated)
local GSEP, USEP = "\t", "\31"
function Genres.encode(got)
    local lines = {}
    for _k, e in ipairs(got) do
        local g = {}
        for _j, t in ipairs(e.g or {}) do g[#g + 1] = (tostring(t):gsub("[\t\n\31]", " ")) end
        lines[#lines + 1] = tostring(e.id) .. GSEP .. tostring(e.cv or "") .. GSEP .. table.concat(g, USEP)
    end
    return table.concat(lines, "\n") .. "\n"
end

function Genres.decode(data)
    local out = {}
    for line in tostring(data or ""):gmatch("[^\n]+") do
        local id, cv, rest = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
        if id and id ~= "" then
            local g = {}
            for t in rest:gmatch("[^\31]+") do g[#g + 1] = t end
            out[#out + 1] = { id = tonumber(id) or id, cv = cv, g = g }
        end
    end
    return out
end

-- the detail calls for one batch (runs in the worker, or inline when it can't fork)
function Genres.fetchBatch(client, batch)
    local got = {}
    for _k, b in ipairs(batch) do
        local okD, d = pcall(function() return client:catalogBook(b.id) end)
        if okD and type(d) == "table" then
            got[#got + 1] = { id = b.id, cv = b.cv, g = Genres.fromDetail(d) }
        end
    end
    return got
end

function Genres.stop(paused)
    if Genres.pid then
        local util = require("ffi/util")
        pcall(util.terminateSubProcess, Genres.pid)
        -- the worker is gone, so this only closes our end of the pipe
        if Genres.fd then pcall(util.readAllFromFD, Genres.fd) end
        Genres.pid, Genres.fd = nil, nil
    end
    Genres.running = false
    Genres.paused = paused and true or false
end

-- One batch, then the next. The detail calls run in a forked worker that is checked
-- every half second, so the screen and taps keep working while it waits on the network.
-- Sleep or Wi-Fi off stops the worker; Wi-Fi back carries on from the next book.
local GENRES_BATCH = 10
function Genres.step(client, net, i)
    if i > #net then
        Genres.stop(false)
        Genres.note(_("Genres ready"))
        return
    end
    if not isWifiOn() then
        Genres.stop(true)
        Genres.note(T(_("Genres paused at %1 of %2: Wi-Fi is off."), Genres.done, Genres.total))
        return
    end
    local batch = {}
    for k = i, math.min(i + GENRES_BATCH - 1, #net) do
        batch[#batch + 1] = { id = net[k].bookorbit_id, cv = tostring(net[k].bookorbit_cv or "") }
    end
    local function finish(got)
        if type(got) ~= "table" then
            -- the batch failed (network, server): stop for now, pick up later
            Genres.stop(true)
            return
        end
        local store = Genres.load()
        for _k, e in ipairs(got) do
            store[tostring(e.id)] = { cv = e.cv, g = type(e.g) == "table" and e.g or {} }
        end
        Genres.save()
        Genres.done = math.min(Genres.total, Genres.done + #batch)
        local bs = getBookshelf()
        if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
        local nxt = i + #batch
        if nxt <= #net then Genres.note(T(_("Building genres: %1 of %2"), Genres.done, Genres.total)) end
        UIManager:scheduleIn(0.2, function() Genres.step(client, net, nxt) end)
    end
    local ok_util, util = pcall(require, "ffi/util")
    local can_fork = ok_util and type(util.runInSubProcess) == "function"
        and type(util.isSubProcessDone) == "function" and client.background_requests ~= false
    if not can_fork then
        -- no worker on this device: one book per tick so taps still get through
        local got = {}
        local function one(k)
            if k > #batch then finish(got) return end
            for _j, e in ipairs(Genres.fetchBatch(client, { batch[k] })) do got[#got + 1] = e end
            UIManager:scheduleIn(0.1, function() one(k + 1) end)
        end
        one(1)
        return
    end
    local pid, fd = util.runInSubProcess(function(_pid, wfd)
        -- in the worker: run the calls inline, no second worker
        client.subprocess_depth = (client.subprocess_depth or 0) + 1
        local okB, got = pcall(Genres.fetchBatch, client, batch)
        util.writeToFD(wfd, okB and Genres.encode(got) or "", true)
    end, true)
    if not pid then finish(nil) return end
    Genres.pid, Genres.fd = pid, fd
    local data, waited = "", 0
    local function poll()
        if Genres.pid ~= pid then return end -- stopped meanwhile
        local ok_dev, Device = pcall(require, "device")
        if ok_dev and Device.screen_saver_mode then
            -- going to sleep: stop the worker, Wi-Fi back carries on
            Genres.stop(true)
            return
        end
        if fd and util.getNonBlockingReadSize(fd) ~= 0 then
            data = data .. (util.readAllFromFD(fd) or "")
            fd, Genres.fd = nil, nil
        end
        if util.isSubProcessDone(pid) then
            if fd then data = data .. (util.readAllFromFD(fd) or ""); fd = nil end
            Genres.pid, Genres.fd = nil, nil
            finish(Genres.decode(data))
            return
        end
        waited = waited + 0.5
        if waited > 120 then
            Genres.stop(true)
            return
        end
        UIManager:scheduleIn(0.5, poll)
    end
    UIManager:scheduleIn(0.5, poll)
end

-- Opening the Genres shelf: when books still need looking up, ask once per start.
-- Once you have said Start (genres saved before), the rest - a build that was cut
-- short, or new books since - just carries on, quietly.
function Genres.offer()
    if Genres.running or Genres.asked then return end
    local books = Genres.library() or {}
    local todo = Genres.missing(books)
    if #todo == 0 then return end
    local store = Genres.load()
    if next(store) ~= nil then
        Genres.asked = true
        UIManager:nextTick(function() Genres.build(true) end)
        return
    end
    Genres.asked = true
    UIManager:nextTick(function()
        local mins = math.max(1, math.floor(#todo * 0.8 / 60 + 0.5))
        UIManager:show(require("ui/widget/confirmbox"):new{
            text = T(_("Genres need building first.\n\nBookOrbit doesn't send genres with its book lists, so each book's genres are looked up once: %1 books, about %2 min with Wi-Fi on. It runs in the background; the shelf fills in as it goes. Wi-Fi off pauses it, and it carries on when Wi-Fi is back."), #todo, mins),
            ok_text = _("Start"),
            cancel_text = _("Later"),
            ok_callback = function() Genres.build(false) end,
        })
    end)
end

-- Wi-Fi back on: a paused build carries on (KOReader sends NetworkConnected to the
-- file manager's modules)
function Genres.listen()
    pcall(function()
        local FM = package.loaded["apps/filemanager/filemanager"]
        local fm = type(FM) == "table" and FM.instance
        if not (type(fm) == "table" and type(fm.registerModule) == "function") or fm.orbitshelf_genres then return end
        local Widget = require("ui/widget/widget")
        local listener = Widget:new{}
        function listener:onNetworkConnected()
            if Genres.paused and not Genres.running then
                UIManager:scheduleIn(5, function() Genres.build(false) end)
            end
        end
        fm:registerModule("orbitshelf_genres", listener)
    end)
end

-- ---- Grouping (Series / Authors / Genres) from the BookOrbit library -------------

local function modeParams(source)
    local mode = type(source) == "table" and source.mode or "library"
    if mode == "recently_added" then
        return { sort = "recently_added" }
    elseif mode == "recently_read" then
        return { sort = "recently_read" }
    elseif mode == "collection" and source.collection_id then
        return { collectionId = source.collection_id }
    end
    -- library / series / authors / genres all page the full library once
    return { sort = "title" }
end

local function splitNames(s)
    if type(s) ~= "string" or s == "" then return {} end
    local out = {}
    for part in s:gmatch("[^\n,;|/]+") do
        local t = part:match("^%s*(.-)%s*$")
        if t and t ~= "" then out[#out + 1] = t end
    end
    return out
end

local function groupKeysFor(rec, mode)
    if mode == "series" then
        local s = rec.series or rec.series_name
        if type(s) == "string" and s ~= "" then return { s } end
        return {}
    elseif mode == "authors" then
        if type(rec.authors) == "table" then
            local out = {}
            for _i, a in ipairs(rec.authors) do
                if type(a) == "string" and a ~= "" then out[#out + 1] = a end
            end
            if #out > 0 then return out end
        end
        if type(rec.author) == "string" and rec.author ~= "" then return { rec.author } end
        return {}
    elseif mode == "genres" then
        local built = Genres.of(rec)
        if built and #built > 0 then return built end
        if type(rec.genres) == "table" then
            local out = {}
            for _i, g in ipairs(rec.genres) do
                if type(g) == "string" and g ~= "" then out[#out + 1] = g end
            end
            if #out > 0 then return out end
        end
        return splitNames(rec.genres or rec.genre or "")
    end
    return {}
end

-- Fetch mode skips Bookshelf's own sort, so the groups are put in order here with
-- Bookshelf's sort engine (surname, articles ignored, missing values last). The
-- plain comparator is only the fallback when that module cannot be loaded.
local function sortWith(items, priority, fallback)
    local okE, Engine = pcall(require, "lib/bookshelf_sort_engine")
    if okE and type(Engine) == "table" and type(Engine.chainedComparator) == "function" then
        local okC, cmp = pcall(Engine.chainedComparator, priority)
        if okC and type(cmp) == "function" and pcall(table.sort, items, cmp) then return end
    end
    table.sort(items, fallback)
end

-- Stock Bookshelf orders: Series cards by last opened, Authors by surname,
-- Genres by book count; inside a group, series order (Series), series then
-- number (Authors / Genres).
local GROUP_CARD_ORDER = {
    series  = { { key = "last_opened", reverse = true }, { key = "series_name", reverse = false } },
    authors = { { key = "author_surname", reverse = false }, { key = "series_name", reverse = false } },
    genres  = { { key = "book_count", reverse = true }, { key = "series_name", reverse = false } },
}
local GROUP_BOOK_ORDER = {
    series  = { { key = "series_index", reverse = false }, { key = "title", reverse = false } },
    authors = { { key = "series_name", reverse = false }, { key = "series_index", reverse = false },
                { key = "title", reverse = false } },
    genres  = { { key = "series_name", reverse = false }, { key = "series_index", reverse = false },
                { key = "title", reverse = false } },
}

-- Build folder records for series/authors/genres from the (cached) library list.
local function groupFolders(mode)
    local books = fetchBoPage({ sort = "title" }, false) or {}
    local buckets, order = {}, {}
    for _i, rec in ipairs(books) do
        for _j, key in ipairs(groupKeysFor(rec, mode)) do
            local lk = key:lower()
            local b = buckets[lk]
            if not b then
                b = { title = key, books = {}, cover = nil }
                buckets[lk] = b
                order[#order + 1] = lk
            end
            b.books[#b.books + 1] = rec
            if not b.cover and rec.cover_image_path then b.cover = rec.cover_image_path end
        end
    end
    local folders = {}
    for _i, lk in ipairs(order) do
        local b = buckets[lk]
        local id = mode .. ":" .. lk
        local last
        for _j, rec in ipairs(b.books) do
            if rec.last_opened and (not last or rec.last_opened > last) then last = rec.last_opened end
        end
        folders[#folders + 1] = {
            is_folder = true,
            title = b.title,
            label = b.title,
            display_title = b.title,
            -- the fields Bookshelf's own group cards carry, so its sort keys read them
            name = b.title,
            series_name = b.title,
            last_opened = last,
            book_count = #b.books,
            cover_image_path = b.cover,
            filepath = "bookorbit://nav/" .. id,
            bookorbit_group = mode,
            bookorbit_group_key = b.title,
            source_kind = SOURCE_ID,
        }
    end
    sortWith(folders, GROUP_CARD_ORDER[mode] or GROUP_CARD_ORDER.series, function(a, b)
        return (a.title or ""):lower() < (b.title or ""):lower()
    end)
    return folders, #folders
end

local function booksInGroup(mode, key)
    local books = fetchBoPage({ sort = "title" }, false) or {}
    local want = (key or ""):lower()
    local out = {}
    for _i, rec in ipairs(books) do
        for _j, k in ipairs(groupKeysFor(rec, mode)) do
            if k:lower() == want then
                out[#out + 1] = rec
                break
            end
        end
    end
    sortWith(out, GROUP_BOOK_ORDER[mode] or GROUP_BOOK_ORDER.series, function(a, b)
        local na = tonumber(a.series_index) or tonumber(a.series_num) or 1e9
        local nb = tonumber(b.series_index) or tonumber(b.series_num) or 1e9
        if na ~= nb then return na < nb end
        return tostring(a.title or ""):lower() < tostring(b.title or ""):lower()
    end)
    return out
end

local function slice(items, offset, limit)
    offset = math.max(0, tonumber(offset) or 0)
    limit = tonumber(limit) or 50
    local total = #items
    local out = {}
    for i = offset + 1, math.min(offset + limit, total) do
        out[#out + 1] = items[i]
    end
    return out, total
end

-- Collections: from BookOrbit when Wi-Fi is on, else the list saved from the last
-- time, plus whatever the Side Panel has saved.
local COLLS_KEY = "orbitshelf_tweaks_collections"

local function fetchBoCollections()
    local client = boApiClient()
    if not client then return nil end
    local ok, body = pcall(function() return client:catalogSection("collections") end)
    if not ok or type(body) ~= "table" then
        logger.warn(TAG, "collections fetch failed -", ok and "no usable reply" or tostring(body))
        return nil
    end
    local out = {}
    for _i, e in ipairs(body.items or body.collections or body.entries or {}) do
        local id = type(e) == "table" and tonumber(e.id) or nil
        if id then out[#out + 1] = { id = id, title = e.title or e.name or tostring(id) } end
    end
    if #out > 0 and G_reader_settings then G_reader_settings:saveSetting(COLLS_KEY, out) end
    return out
end

local function listCollections()
    local out, seen = {}, {}
    local function add(list)
        for _i, c in ipairs(type(list) == "table" and list or {}) do
            local id = type(c) == "table" and tonumber(c.id) or nil
            if id and not seen[id] then
                seen[id] = true
                out[#out + 1] = { id = id, title = c.title or tostring(id) }
            end
        end
    end
    if isWifiOn() then add(fetchBoCollections()) end
    add(G_reader_settings and G_reader_settings:readSetting(COLLS_KEY))
    local okP, side = pcall(function() return package.loaded["simpleui_sidepanel_bo"] end)
    if okP and type(side) == "table" and type(side.collections) == "function" then
        local okC, colls = pcall(side.collections)
        if okC then add(colls) end
    end
    table.sort(out, function(a, b) return tostring(a.title):lower() < tostring(b.title):lower() end)
    return out
end

local function pickCollection(target, c)
    target.source = target.source or {}
    target.source.kind = SOURCE_ID
    target.source.mode = "collection"
    target.source.collection_id = c.id
    target.source.collection_title = c.title
    -- the shelf keeps its own title
end

local function setPickMode(draft, mode, label)
    draft.source = draft.source or {}
    draft.source.kind = SOURCE_ID
    draft.source.mode = mode
    -- the shelf keeps its own title (label is no longer written)
end

local function buildSpec()
    return {
        api = 1,
        label = function() return _("BookOrbit") end,
        available = function()
            return cfg.use_bookorbit and bookOrbitInstalled() and bookOrbitSignedIn()
        end,
        remote_prefix = "bookorbit://",
        -- fetch mode: server-style paging + folder drill for Series/Authors/Genres
        picker = true,

        pick = function(draft, done)
            local ButtonDialog = require("ui/widget/buttondialog")
            local dialog
            local function choose(mode, label)
                return {{
                    text = label,
                    callback = function()
                        UIManager:close(dialog)
                        setPickMode(draft, mode, label)
                        done()
                    end,
                }}
            end
            local buttons = {
                choose("library", _("BookOrbit · Library")),
                choose("recently_added", _("BookOrbit · Recently added")),
                choose("recently_read", _("BookOrbit · Recently read")),
                choose("series", _("BookOrbit · Series")),
                choose("authors", _("BookOrbit · Authors")),
                choose("genres", _("BookOrbit · Genres")),
                {{
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                        done(false)
                    end,
                }},
            }
            for i, c in ipairs(listCollections()) do
                if i > 20 then break end
                table.insert(buttons, #buttons, {{
                    text = T(_("Collection: %1"), c.title),
                    callback = function()
                        UIManager:close(dialog)
                        pickCollection(draft, c)
                        done()
                    end,
                }})
            end
            dialog = ButtonDialog:new{
                title = _("BookOrbit shelf"),
                buttons = buttons,
            }
            UIManager:show(dialog)
        end,

        -- fetch mode: folders for series/authors/genres, flat lists otherwise
        fetch = function(source, drill, offset, limit)
            local mode = type(source) == "table" and source.mode or "library"
            if mode == "collection" and not (type(source) == "table" and source.collection_id) then
                logger.warn(TAG, "collection shelf has no collection id; edit the shelf and pick the collection again")
                return {}, 0
            end
            if drill and (drill.group == "series" or drill.group == "authors" or drill.group == "genres") then
                local items = booksInGroup(drill.group, drill.key)
                return slice(items, offset, limit)
            end
            if mode == "series" or mode == "authors" or mode == "genres" then
                local folders = groupFolders(mode)
                if mode == "genres" then
                    -- after the list is in, so the count is right
                    Genres.listen()
                    Genres.offer()
                end
                return slice(folders, offset, limit)
            end
            local items = fetchBoPage(modeParams(source), false) or {}
            return slice(items, offset, limit)
        end,

        open_folder = function(folder)
            if type(folder) ~= "table" then return nil end
            return {
                label = folder.title or folder.label,
                group = folder.bookorbit_group,
                key = folder.bookorbit_group_key or folder.title,
            }
        end,

        owns = function(book)
            return book and (book.is_bookorbit or book.source_kind == SOURCE_ID
                or (type(book.filepath) == "string" and book.filepath:match("^bookorbit://"))) and true or false
        end,

        open = function(book, ctx)
            if not book or book.is_folder then return false end
            local path = book.filepath
            if type(path) == "string" and not path:match("^bookorbit://")
                    and lfs.attributes(path, "mode") == "file" then
                return path
            end
            local live = liveBookPath(book.bookorbit_id)
            if live then return live end
            showNotOnDevice(book)
            return true
        end,

        -- long-press on a book that is not on the device
        info = function(book, ctx)
            if not book or book.is_folder then return false end
            local live = liveBookPath(book.bookorbit_id)
            if live then
                if ctx and type(ctx.open) == "function" then ctx.open(live) end
                return true
            end
            showNotOnDevice(book)
            return true
        end,

        refresh = function(source, drill, done)
            if drill and drill.group then
                fetchBoPage({ sort = "title" }, true)
            else
                fetchBoPage(modeParams(source), true)
            end
            if type(done) == "function" then done() end
        end,

        editor_rows = function(draft)
            local mode = type(draft.source) == "table" and draft.source.mode or "library"
            local names = {
                library = _("Library"),
                recently_added = _("Recently added"),
                recently_read = _("Recently read"),
                series = _("Series"),
                authors = _("Authors"),
                genres = _("Genres"),
                collection = _("Collection"),
            }
            return {
                {{
                    text = function(d)
                        local m = type(d.source) == "table" and d.source.mode or "library"
                        if m == "collection" and type(d.source) == "table" and d.source.collection_title then
                            return T(_("List: Collection · %1"), d.source.collection_title)
                        end
                        return T(_("List: %1"), names[m] or m)
                    end,
                    callback = function(d, done_row)
                        local ButtonDialog = require("ui/widget/buttondialog")
                        local dialog
                        local function go(m, label)
                            return {{
                                text = label,
                                callback = function()
                                    UIManager:close(dialog)
                                    d.source = d.source or {}
                                    d.source.mode = m
                                    if m ~= "collection" then d.source.collection_id = nil d.source.collection_title = nil end
                                    done_row()
                                end,
                            }}
                        end
                        local buttons = {
                            go("library", _("Library")),
                            go("recently_added", _("Recently added")),
                            go("recently_read", _("Recently read")),
                            go("series", _("Series")),
                            go("authors", _("Authors")),
                            go("genres", _("Genres")),
                        }
                        for i, c in ipairs(listCollections()) do
                            if i > 20 then break end
                            buttons[#buttons + 1] = {{
                                text = T(_("Collection: %1"), c.title),
                                callback = function()
                                    UIManager:close(dialog)
                                    pickCollection(d, c)
                                    done_row()
                                end,
                            }}
                        end
                        buttons[#buttons + 1] = {{ text = _("Cancel"), callback = function() UIManager:close(dialog) end }}
                        dialog = ButtonDialog:new{
                            title = _("BookOrbit list"),
                            buttons = buttons,
                        }
                        UIManager:show(dialog)
                    end,
                }},
            }
        end,

        new_shelf = function(draft)
            draft.source = draft.source or {}
            draft.source.kind = SOURCE_ID
            draft.source.mode = draft.source.mode or "library"
            if not draft.label then draft.label = _("BookOrbit") end
        end,
    }
end

-- ---- Auto-rewrite stock Series / Authors / Genres / Recent / Latest chips ---------
-- When on, those chips' source becomes BookOrbit with the matching mode.
-- Previous sources are saved and restored when the toggle is turned off.

local STOCK_REWRITE = {
    series  = { mode = "series",         label = "BookOrbit · Series" },
    authors = { mode = "authors",        label = "BookOrbit · Authors" },
    genres  = { mode = "genres",         label = "BookOrbit · Genres" },
    recent  = { mode = "recently_read",  label = "BookOrbit · Recently read" },
    latest  = { mode = "recently_added", label = "BookOrbit · Recently added" },
}
local ORIG_TABS_KEY = "orbitshelf_tweaks_orig_tabs"

local function applyAutoRewrite()
    local ok, TabModel = pcall(require, "lib/bookshelf_tab_model")
    if not ok or type(TabModel) ~= "table" then return end
    local okS, Store = pcall(require, "lib/bookshelf_settings_store")
    if not okS or type(Store) ~= "table" then return end

    local tabs = Store.read(TabModel.STORAGE_KEY or "tabs")
    if type(tabs) ~= "table" then
        if type(TabModel.load) == "function" then
            tabs = TabModel.load()
        elseif type(TabModel.get) == "function" then
            tabs = TabModel.get()
        end
    end
    if type(tabs) ~= "table" then return end

    if cfg.auto_rewrite_stock and cfg.use_bookorbit then
        -- Save originals once
        if not G_reader_settings:readSetting(ORIG_TABS_KEY) then
            local orig = {}
            for i, tab in ipairs(tabs) do
                if type(tab) == "table" and tab.id and STOCK_REWRITE[tab.id] then
                    orig[tab.id] = {
                        source = tab.source and { kind = tab.source.kind, mode = tab.source.mode, id = tab.source.id } or nil,
                        label = tab.label,
                    }
                end
            end
            G_reader_settings:saveSetting(ORIG_TABS_KEY, orig)
        end
        local changed = false
        for _i, tab in ipairs(tabs) do
            local map = tab and tab.id and STOCK_REWRITE[tab.id]
            if map then
                local sk = tab.source and tab.source.kind
                if sk ~= SOURCE_ID or (tab.source and tab.source.mode) ~= map.mode then
                    tab.source = { kind = SOURCE_ID, mode = map.mode }
                    changed = true
                end
            end
        end
        if changed then
            Store.save(TabModel.STORAGE_KEY or "tabs", tabs)
            logger.info(TAG, "auto-rewrite: stock chips -> BookOrbit")
        end
    else
        local orig = G_reader_settings:readSetting(ORIG_TABS_KEY)
        if type(orig) == "table" then
            local changed = false
            for _i, tab in ipairs(tabs) do
                local o = tab and tab.id and orig[tab.id]
                if o and tab.source and tab.source.kind == SOURCE_ID then
                    tab.source = o.source or { kind = tab.id }
                    changed = true
                end
            end
            if changed then
                Store.save(TabModel.STORAGE_KEY or "tabs", tabs)
                logger.info(TAG, "auto-rewrite: restored stock chip sources")
            end
            G_reader_settings:delSetting(ORIG_TABS_KEY)
        end
    end
end

local registered = false

local function unregisterSource()
    local bs = getBookshelf()
    if bs and type(bs.unregisterSource) == "function" then
        pcall(bs.unregisterSource, bs, SOURCE_ID)
    end
    registered = false
end

local function registerSource(ui)
    if not cfg.use_bookorbit or not bookOrbitInstalled() then
        unregisterSource()
        pcall(applyAutoRewrite)
        return false
    end
    local bs = getBookshelf(ui)
    if not (bs and bs.registerSource and (bs.SOURCE_API or 0) >= 1) then
        return false
    end
    local ok, why = bs:registerSource(SOURCE_ID, buildSpec())
    if not ok then
        logger.warn(TAG, "registerSource refused:", why)
        return false
    end
    registered = true
    logger.info(TAG, "BookOrbit source registered (fetch mode)")
    pcall(applyAutoRewrite)
    return true
end

-- ---- Hero banner actions (hold menu + inline pills) -------------------------------

local function bookOnDevice(book)
    if not book then return false end
    local path = book.filepath
    if type(path) == "string" and not path:match("^bookorbit://")
            and lfs.attributes(path, "mode") == "file" then
        return true
    end
    return liveBookPath(book.bookorbit_id) and true or false
end

-- A BookOrbit book once it is on the device: Bookshelf rebuilds the hero's record
-- from the file (title, description...), which drops our fields. The file tells us
-- which BookOrbit book it is, and the record gets its id back.
local function asBookOrbit(book)
    if type(book) ~= "table" then return false end
    if book.is_bookorbit or book.bookorbit_id or book.source_kind == SOURCE_ID then return true end
    local fp = book.filepath
    if type(fp) ~= "string" or fp:match("^bookorbit://") then return false end
    local id = bookIdForPath(fp)
    if not id then return false end
    book.bookorbit_id = id
    book.is_bookorbit = true
    return true
end

local function heroActionsFor(book)
    if not asBookOrbit(book) then
        return nil
    end
    if book.is_folder then return nil end
    local actions = {}
    if bookOnDevice(book) then
        actions[#actions + 1] = {
            text = _("Remove From Device"),
            callback = function() removeFromDevice(book) end,
        }
    else
        actions[#actions + 1] = {
            text = _("Download"),
            callback = function() downloadBookOrbitBook(book) end,
        }
    end
    actions[#actions + 1] = {
        text = _("Open In BookOrbit"),
        callback = function() openInBookOrbit(book) end,
    }
    return actions
end

-- Sync: the saved BookOrbit lists are thrown away and pulled fresh, then BookOrbit's
-- own "sync all books" runs (it relinks books on the device and syncs progress), then
-- the shelf is redrawn again.
local sync_running = false
local function syncBookOrbit()
    if sync_running then return end
    local okT, Toast = pcall(require, "bookorbit_toast")
    local function say(msg, is_error)
        if okT and Toast then
            if is_error and Toast.error then Toast.error(msg) elseif Toast.show then Toast.show(msg) end
        else
            UIManager:show(require("ui/widget/infomessage"):new{ text = msg, timeout = 3 })
        end
    end
    local function redraw()
        local bs = getBookshelf()
        if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
    end
    local function run()
        sync_running = true
        local finished = false
        local function finish(msg, is_error)
            if finished then return end
            finished = true
            sync_running = false
            pcall(function()
                local SM = require("bookorbit_state_manager")
                if type(SM.invalidate) == "function" then SM.invalidate() end
            end)
            redraw()
            say(msg, is_error)
        end
        -- fresh lists first
        page_cache = {}
        savePageCache()
        redraw()

        local bo
        pcall(function()
            local FM = package.loaded["apps/filemanager/filemanager"]
            bo = type(FM) == "table" and FM.instance and FM.instance.bookorbit or nil
        end)
        local signed_in = false
        if bo and type(bo.isLoggedIn) == "function" then
            local okL, v = pcall(bo.isLoggedIn, bo)
            signed_in = okL and v and true or false
        end
        if not (bo and type(bo.startSweep) == "function" and signed_in) then
            finish(_("BookOrbit lists refreshed"))
            return
        end
        say(_("Syncing BookOrbit…"))
        -- never leave the button stuck if the sync never reports back
        UIManager:scheduleIn(300, function() finish(_("BookOrbit sync did not finish"), true) end)
        local okS, errS = pcall(bo.startSweep, bo, {
            quiet = true,
            on_done = function(err)
                if err then
                    finish(T(_("Sync stopped: %1"), tostring(err)), true)
                else
                    finish(_("BookOrbit synced"))
                end
            end,
        })
        if not okS then
            logger.warn(TAG, "sync failed:", tostring(errS))
            finish(_("Sync could not start"), true)
        end
    end
    local okN, NetworkMgr = pcall(require, "ui/network/manager")
    if okN and NetworkMgr.runWhenConnected then
        NetworkMgr:runWhenConnected(run)
    else
        run()
    end
end

-- A small round icon button (KOReader's symbols font), white with a thin border like
-- the pills. Returns the button (with getSize) or nil.
local function makeIconButton(glyph_char, on_tap)
    local ok_ic, InputContainer = pcall(require, "ui/widget/container/inputcontainer")
    local ok_fc, FrameContainer = pcall(require, "ui/widget/container/framecontainer")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local ok_iw, TextWidget = pcall(require, "ui/widget/textwidget")
    local ok_ft, Font = pcall(require, "ui/font")
    local ok_geom, Geom = pcall(require, "ui/geometry")
    local ok_gr, GestureRange = pcall(require, "ui/gesturerange")
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    local ok_sc, Screen = pcall(function() return require("device").screen end)
    if not (ok_ic and ok_fc and ok_iw and ok_ft and ok_geom and ok_gr and ok_bb and ok_sc) then return nil end
    local glyph = TextWidget:new{
        text = glyph_char,
        face = Font:getFace("symbols", 15),
        fgcolor = Blitbuffer.COLOR_BLACK,
    }
    local gsz = glyph:getSize()
    local side = math.max(gsz.w, gsz.h) + Screen:scaleBySize(8)
    local frame = FrameContainer:new{
        bordersize = 1,
        padding = 0,
        margin = 0,
        radius = math.floor(side / 2),
        background = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{ dimen = Geom:new{ w = side, h = side }, glyph },
    }
    local sz = frame:getSize()
    local Button = InputContainer:extend{}
    function Button:onTap()
        on_tap()
        return true
    end
    local button = Button:new{ dimen = Geom:new{ w = sz.w, h = sz.h }, frame }
    button.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = button.dimen } } }
    return button
end

local ICON_SYNC, ICON_REMOVE, ICON_ORBIT = "\u{F021}", "\u{F1F8}", "\u{F08E}"

local function buildHeroPills(book, width)
    -- on the device: small icons instead (heroIconsFor), so the description has room
    if bookOnDevice(book) then return nil end
    local actions = heroActionsFor(book)
    if not actions or #actions == 0 then return nil end
    local ok_ic, InputContainer = pcall(require, "ui/widget/container/inputcontainer")
    local ok_hg, HorizontalGroup = pcall(require, "ui/widget/horizontalgroup")
    local ok_tw, TextWidget = pcall(require, "ui/widget/textwidget")
    local ok_fc, FrameContainer = pcall(require, "ui/widget/container/framecontainer")
    local ok_font, Font = pcall(require, "ui/font")
    local ok_geom, Geom = pcall(require, "ui/geometry")
    local ok_gr, GestureRange = pcall(require, "ui/gesturerange")
    local ok_hs, HorizontalSpan = pcall(require, "ui/widget/horizontalspan")
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    if not (ok_ic and ok_hg and ok_tw and ok_fc and ok_font and ok_geom and ok_gr) then
        return nil
    end
    local face = Font:getFace("xx_smallinfofont")
    local Screen = require("device").screen
    local gap = Screen:scaleBySize(8)
    local row = HorizontalGroup:new{ align = "center" }
    for i, a in ipairs(actions) do
        if i > 1 and ok_hs then
            row[#row + 1] = HorizontalSpan:new{ width = gap }
        end
        local pad = Screen:scaleBySize(5)
        local label = TextWidget:new{
            text = a.text,
            face = face,
            max_width = math.floor(((width or 200) - gap * (#actions - 1)) / #actions) - 2 * pad - 2,
        }
        local frame = FrameContainer:new{
            bordersize = 1,
            padding = pad,
            margin = 0,
            background = ok_bb and Blitbuffer.COLOR_WHITE or nil,
            radius = Screen:scaleBySize(10),
            label,
        }
        local sz = frame:getSize()
        local Pill = InputContainer:extend{}
        function Pill:onTap()
            a.callback()
            return true
        end
        local pill = Pill:new{
            dimen = Geom:new{ w = sz.w, h = sz.h },
            frame,
        }
        pill.ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = pill.dimen,
                },
            },
        }
        row[#row + 1] = pill
    end
    return row
end

-- The small icons at the bottom right of the hero's right column: for a book on the
-- device Remove From Device and Open In BookOrbit, and Sync for any BookOrbit book.
local function heroIconsFor(book)
    local icons = {}
    if cfg.hero_pills and bookOnDevice(book) then
        icons[#icons + 1] = makeIconButton(ICON_REMOVE, function() removeFromDevice(book) end)
        icons[#icons + 1] = makeIconButton(ICON_ORBIT, function() openInBookOrbit(book) end)
    end
    if cfg.hero_sync then
        icons[#icons + 1] = makeIconButton(ICON_SYNC, syncBookOrbit)
    end
    if #icons == 0 then return nil end
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local gap = require("device").screen:scaleBySize(8)
    local row = HorizontalGroup:new{ align = "center" }
    for i, w in ipairs(icons) do
        if i > 1 then row[#row + 1] = HorizontalSpan:new{ width = gap } end
        row[#row + 1] = w
    end
    return row
end

local function hookHero()
    local ok, HeroCard = pcall(require, "lib/bookshelf_hero_card")
    if not ok or type(HeroCard) ~= "table" then return end
    if HeroCard._orbitshelf_hooked then return end
    HeroCard._orbitshelf_hooked = true

    -- Hold menu
    local orig_hold = HeroCard.onHold
    if type(orig_hold) == "function" then
        HeroCard.onHold = function(self, ...)
            local book = self.book
            local extra = heroActionsFor(book)
            if extra and #extra > 0 then
                local ButtonDialog = require("ui/widget/buttondialog")
                local dlg
                local rows = {}
                for _i, a in ipairs(extra) do
                    rows[#rows + 1] = {{ text = a.text, callback = function()
                        UIManager:close(dlg)
                        a.callback()
                    end }}
                end
                rows[#rows + 1] = {{ text = _("Cancel"), callback = function() UIManager:close(dlg) end }}
                dlg = ButtonDialog:new{ title = book.title or _("Book"), buttons = rows }
                UIManager:show(dlg)
                return true
            end
            if orig_hold then return orig_hold(self, ...) end
        end
    end

    -- One row at the bottom of the hero's right column: text pills on the left (a book
    -- not on the device), small icons on the right (Remove, BookOrbit, Sync). The column
    -- is built that much shorter so the row sits inside the card (not under the tab
    -- bar), and all go in one OverlapGroup.
    if type(HeroCard._buildRightColumn) == "function" then
        local orig_col = HeroCard._buildRightColumn
        HeroCard._buildRightColumn = function(self, book, regions, state, dimen, ...)
            if not asBookOrbit(book) then return orig_col(self, book, regions, state, dimen, ...) end

            local okG, Geom = pcall(require, "ui/geometry")
            local okO, OverlapGroup = pcall(require, "ui/widget/overlapgroup")
            local have_dimen = okG and okO and type(dimen) == "table" and dimen.w and dimen.h

            local pills, icons
            if not book.is_folder then
                local okI, row = pcall(heroIconsFor, book)
                icons = okI and row or nil
                local icons_w = 0
                if icons then
                    local okS, isz = pcall(icons.getSize, icons)
                    icons_w = okS and isz and isz.w or 0
                end
                if cfg.hero_pills then
                    -- the text pills share the bottom row with the icons, to their left
                    local w = ((dimen and dimen.w) or self.width or 200) - (icons_w > 0 and icons_w + 12 or 0)
                    pills = buildHeroPills(book, math.max(60, w))
                end
            end

            -- no size to work with: the old way, pills stacked under the column
            if not have_dimen then
                local column = orig_col(self, book, regions, state, dimen, ...)
                if not pills and not icons then return column end
                local ok_vg, VerticalGroup = pcall(require, "ui/widget/verticalgroup")
                local ok_vs, VerticalSpan = pcall(require, "ui/widget/verticalspan")
                if not ok_vg then return column end
                local vg = VerticalGroup:new{ align = "left" }
                if column then vg[#vg + 1] = column end
                if ok_vs then vg[#vg + 1] = VerticalSpan:new{ width = 6 } end
                if pills then vg[#vg + 1] = pills end
                if icons then vg[#vg + 1] = icons end
                return vg
            end

            -- one row at the bottom: text pills on the left, icons on the right; the
            -- column is built that much shorter, so nothing overlaps
            local function sizeOf(w)
                if not w then return nil end
                local okS, sz = pcall(w.getSize, w)
                return okS and sz or nil
            end
            local psz, isz = sizeOf(pills), sizeOf(icons)
            local row_h = math.max(psz and psz.h or 0, isz and isz.h or 0)
            local col_dimen = dimen
            if row_h > 0 then
                col_dimen = Geom:new{ w = dimen.w, h = math.max(math.floor(dimen.h / 2), dimen.h - row_h - 6) }
            end
            local column = orig_col(self, book, regions, state, col_dimen, ...)
            local extras = {}
            if pills and psz then
                pills.overlap_offset = { 0, math.max(0, dimen.h - row_h + math.floor((row_h - psz.h) / 2)) }
                extras[#extras + 1] = pills
            end
            if icons and isz then
                -- OverlapGroup ignores the offset when a child is aligned "right"
                icons.overlap_offset = { math.max(0, dimen.w - isz.w),
                    math.max(0, dimen.h - row_h + math.floor((row_h - isz.h) / 2)) }
                extras[#extras + 1] = icons
            end
            if #extras == 0 then return column end
            local group = OverlapGroup:new{ dimen = Geom:new{ w = dimen.w, h = dimen.h } }
            if column then group[#group + 1] = column end
            for _i, w in ipairs(extras) do group[#group + 1] = w end
            return group
        end
    end
end

-- ---- Close-only menu (true left / right / bottom via StartMenu) -------------------
-- Close control stays on the chosen side even when the footer critter owns the
-- centre strip: the hamburger / Close sits in the footer's side band, and the
-- start-menu panel hangs off left or right via side_override.

local function closeBookshelf()
    local bs = getBookshelf()
    if bs and type(bs.close) == "function" then
        pcall(bs.close, bs)
        return
    end
    pcall(function()
        local FM = package.loaded["apps/filemanager/filemanager"]
        local fm = type(FM) == "table" and FM.instance
        if fm and fm.bookshelf and type(fm.bookshelf.onClose) == "function" then
            fm.bookshelf:onClose()
        end
    end)
    pcall(function()
        local ReaderUI = package.loaded["apps/reader/readerui"]
        local r = type(ReaderUI) == "table" and ReaderUI.instance
        if r and r.bookshelf and type(r.bookshelf.onClose) == "function" then
            r.bookshelf:onClose()
        end
    end)
end

local function closeMenuSide()
    local side = cfg.close_menu_side or "bottom"
    if side == "left" or side == "right" then return side end
    return nil -- "bottom" (the saved value for Bookshelf's Side): no override
end

local function isCloseEntry(entry)
    return type(entry) == "table" and (
        entry.id == "orbitshelf_close"
        or entry.internal == "close"
        or (type(entry.label) == "string" and entry.label:find("Close Bookshelf", 1, true))
    )
end

-- Flat close: with Close Only on, the footer hamburger is painted as a close X
-- (same slot, same stroke weight as Bookshelf's own start-menu X) and a tap
-- closes the shelf directly. Anything else that would open the start menu
-- (gesture action, keyboard focus on the footer button) closes the shelf too.
local function closeShelfFrom(bw)
    local done = false
    if type(bw) == "table" and type(bw.onClose) == "function" then
        done = pcall(bw.onClose, bw)
    end
    if not done then closeBookshelf() end
    pcall(function() UIManager:setDirty("all", "full") end)
end

local function buildCloseXIcon(bw, focused, frame_width)
    local Device = require("device")
    local Screen = Device.screen
    local Geom = require("ui/geometry")
    local Widget = require("ui/widget/widget")
    local Color = require("lib/bookshelf_color")
    local art = Screen:scaleBySize(32)
    frame_width = frame_width or art
    local stroke = (bw.FOOTER_STROKE_W) or math.max(1, math.floor(art / 14))
    local span = math.floor(art * 0.62)
    local ink = bw:_chromeInk()
    local XWidget = Widget:extend{}
    function XWidget:getSize() return Geom:new{ w = art, h = art } end
    function XWidget:paintTo(bb, x, y)
        self.dimen = Geom:new{ x = x, y = y, w = art, h = art }
        local ox = x + math.floor((art - span) / 2)
        local oy = y + math.floor((art - span) / 2)
        local last = span - stroke
        for t = 0, last do
            Color.paintRect(bb, ox + t, oy + t, stroke, stroke, ink)
            Color.paintRect(bb, ox + last - t, oy + t, stroke, stroke, ink)
        end
    end
    local btn = bw:_wrapAsFooterButton(XWidget:new{}, frame_width, focused, function()
        closeShelfFrom(bw)
        return true
    end)
    bw._burger_dimen = btn.dimen
    return btn
end

local function hookFlatClose(BW)
    if BW._orbitshelf_flat_close then return end
    BW._orbitshelf_flat_close = true

    if type(BW._buildStartMenuIcon) == "function" then
        local orig_icon = BW._buildStartMenuIcon
        BW._buildStartMenuIcon = function(self, focused, frame_width, ...)
            if cfg.close_only_menu then
                local ok, btn = pcall(buildCloseXIcon, self, focused, frame_width)
                if ok and btn then return btn end
                logger.warn(TAG, "close X build failed, using stock hamburger:", btn)
            end
            return orig_icon(self, focused, frame_width, ...)
        end
    end

    if type(BW._openStartMenu) == "function" then
        local orig_open = BW._openStartMenu
        BW._openStartMenu = function(self, force, ...)
            if cfg.close_only_menu and (force or self:_startMenuPosition() ~= "off") then
                closeShelfFrom(self)
                return
            end
            return orig_open(self, force, ...)
        end
    end
end

local function hookCloseOnlyMenu()
    local ok, StartMenu = pcall(require, "lib/bookshelf_start_menu")
    if not ok or type(StartMenu) ~= "table" then return end
    if not StartMenu._orbitshelf_close_hooked then
        StartMenu._orbitshelf_close_hooked = true

        -- Hamburger menu → only "Close Bookshelf"
        if type(StartMenu._loadItems) == "function" then
            local orig_load = StartMenu._loadItems
            StartMenu._loadItems = function(self, ...)
                if not cfg.close_only_menu then
                    return orig_load(self, ...)
                end
                return {
                    {
                        id = "orbitshelf_close",
                        type = "action",
                        label = _("Close Bookshelf"),
                        internal = "close", -- stock path also closes the shelf
                    },
                }
            end
        end

        -- Tap Close → dismiss menu, then close Bookshelf (always)
        if type(StartMenu._activate) == "function" then
            local orig_act = StartMenu._activate
            StartMenu._activate = function(self, entry, ...)
                if cfg.close_only_menu and isCloseEntry(entry) then
                    local bw = self.bw
                    if type(self._close) == "function" then
                        pcall(self._close, self)
                    else
                        pcall(UIManager.close, UIManager, self)
                    end
                    UIManager:nextTick(function()
                        if bw and type(bw.onClose) == "function" then
                            pcall(function() bw:onClose() end)
                            pcall(function() UIManager:setDirty("all", "full") end)
                        else
                            closeBookshelf()
                        end
                    end)
                    return
                end
                return orig_act(self, entry, ...)
            end
        end

        -- Panel hangs left / right when Close Control says so
        if type(StartMenu.open) == "function" then
            local orig_open = StartMenu.open
            StartMenu.open = function(bw, bottom_inset, burger_dimen, context, burger_art, anchor_top, side_override, ...)
                if cfg.close_only_menu then
                    local side = closeMenuSide()
                    if side then side_override = side end
                end
                return orig_open(bw, bottom_inset, burger_dimen, context, burger_art, anchor_top, side_override, ...)
            end
        end
    end

    -- Hamburger on the same side as Close Control (left/right)
    local okW, BW = pcall(require, "lib/bookshelf_widget")
    if okW and type(BW) == "table" then
        hookFlatClose(BW)
    end
    if okW and type(BW) == "table" and type(BW._startMenuPosition) == "function"
            and not BW._orbitshelf_close_side then
        BW._orbitshelf_close_side = true
        local orig_pos = BW._startMenuPosition
        BW._startMenuPosition = function(self, ...)
            if cfg.close_only_menu then
                local side = closeMenuSide()
                if side then return side end
            end
            return orig_pos(self, ...)
        end
    end
end

-- ---- Footer critter (replaces bottom page nav) ------------------------------------
-- Same sprite/bubble path as Quick Shelf / SimpleUI. Says page, book count,
-- and which shelf you're on. Swipe still pages the shelf; tap the critter for
-- another remark; left/right edges of the strip still step pages.

local function sui(name)
    local m = package.loaded[name]
    if m ~= nil then return m end
    local ok, mod = pcall(require, name)
    return ok and mod or nil
end

local BASE_MOOD = {
    reading = "neutral", proud = "cheer", hungry = "curious", cozy = "sleepy",
    dreamy = "sleepy", sipping = "happy", festive = "happy", spooky = "surprised",
}

local function critterId(Assets)
    local tw = G_reader_settings and G_reader_settings:readSetting("simpleui_mod")
    local mix = type(tw) == "table" and type(tw.critter_mix) == "table" and tw.critter_mix or nil
    if mix and #mix >= 2 then
        local turn = type(Assets.tw_turn) == "number" and Assets.tw_turn or (tonumber(os.date("%j")) or 0)
        return mix[(turn % #mix) + 1]
    end
    local CS = sui("modules/critter/settings")
    if type(CS) == "table" and type(CS.pick) == "function" then
        local ok, id = pcall(CS.pick)
        if ok and id ~= nil then return id end
    end
    local Store = sui("infra/sui_store")
    if type(Store) == "table" and type(Store.get) == "function" then
        local ok, id = pcall(Store.get, Store, "simpleui_hs_critter_pick")
        if ok then return id end
    end
end

local _footer_remark_i = 0
local _session_seed = os.time() % 9973
local _recent, RECENT_MAX = {}, 10
local _pick_cache = nil -- { key = ..., line = ... }: one pick per page / tap / shelf

-- UTF-8 safe clip with an ellipsis.
local function clip(s, n)
    s = tostring(s or "")
    local count, i, len = 0, 1, #s
    while i <= len do
        count = count + 1
        if count > n then
            return (s:sub(1, i - 1):gsub("%s+$", "")) .. "…"
        end
        local c = s:byte(i)
        i = i + (c >= 240 and 4 or c >= 224 and 3 or c >= 192 and 2 or 1)
    end
    return s
end

local function quoted(t) return "“" .. clip(t, 22) .. "”" end

local function strHash(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 100003 end
    return h
end

-- Where the shelf is right now, read from the fields Bookshelf really keeps:
-- page (set by _syncPageFromCursor), _total_pages, _total_items, _cursor,
-- _viewSize(), _chipLabel() and _page_items.
local function shelfFacts(bw)
    local f = { page = 1, pages = 1, books = 0, first = 1, last = 1, shelf = "", items = {} }
    pcall(function()
        f.pages = math.max(1, tonumber(bw._total_pages) or 1)
        f.books = math.max(tonumber(bw._spine_books_total) or 0, tonumber(bw._total_items) or 0)
        local view = 0
        if type(bw._viewSize) == "function" then view = tonumber(bw:_viewSize()) or 0 end
        local cursor = tonumber(bw._cursor) or 1
        f.first = cursor
        local last = view > 0 and (cursor + view - 1) or cursor
        if f.books > 0 and last > f.books then last = f.books end
        f.last = math.max(last, f.first)
        local page = tonumber(bw.page)
        if not page and view > 0 then page = math.ceil(f.last / view) end
        f.page = math.max(1, math.min(page or 1, f.pages))
        if type(bw._chipLabel) == "function" then
            f.shelf = tostring(bw:_chipLabel() or "")
        end
        if type(bw._page_items) == "table" then f.items = bw._page_items end
    end)
    if f.shelf == "" then f.shelf = _("this shelf") end
    f.total_pages = f.pages -- the nav-state code below still reads this name
    return f
end

local function pageInfo(f)
    return string.format(_("Page %d of %d · %s"), f.page, f.pages, clip(f.shelf, 16))
end

-- ---- Kind 1: where you are -------------------------------------------------------

local function pageLines(f)
    local L = {}
    local function add(mood, text, sub) L[#L + 1] = { mood = mood, text = text, sub = sub } end
    add("curious", string.format(_("Page %d of %d."), f.page, f.pages), f.books > 0
        and string.format(_("%d books on %s"), f.books, clip(f.shelf, 16)) or nil)
    add("reading", string.format(_("You're on page %d."), f.page))
    add("happy", T(_("Browsing %1."), clip(f.shelf, 20)), string.format(_("Page %d / %d"), f.page, f.pages))
    if f.books > 0 then
        add("neutral", string.format(_("Books %d–%d of %d."), f.first, f.last, f.books),
            string.format(_("Page %d · %s"), f.page, clip(f.shelf, 16)))
    end
    if f.page <= 1 then add("curious", _("Page 1. The very beginning."), pageInfo(f)) end
    if f.page >= f.pages and f.pages > 1 then add("party", string.format(_("Page %d. That's the last one!"), f.page), pageInfo(f)) end
    return L
end

-- ---- Kind 2: witty ---------------------------------------------------------------

local function wittyLines(f)
    local p, pages, n = f.page, f.pages, f.books
    local shelf = clip(f.shelf, 18)
    local L = {}
    local function add(mood, text) L[#L + 1] = { mood = mood, text = text } end
    add("playful", string.format(_("Page %d. The books are behaving."), p))
    add("playful", _("I judge books by their covers. Sorry."))
    add("neutral", _("Browsing is just reading's warm-up."))
    add("happy", _("Another page, another maybe."))
    add("curious", T(_("%1 sends its regards."), shelf))
    add("playful", _("Tap me again. I have opinions."))
    add("neutral", _("Somebody has to keep the spines in line."))
    add("curious", string.format(_("Page %d of %d. Still counting."), p, pages))
    add("happy", _("No dust here. I checked."))
    add("playful", _("You can't read them all tonight. Try anyway."))
    add("cheer", _("Every one of these started as someone's idea."))
    add("curious", _("That cover is doing a lot of work."))
    add("playful", _("Shelves don't judge. I do, a little."))
    add("reading", _("Pick one. The others will understand."))
    add("neutral", T(_("%1 again? Loyal."), shelf))
    if p == 1 then add("curious", _("Page one. Where every good pile starts.")) end
    if pages > 1 and p >= pages then add("party", _("Last page. The shelf ran out before the books did.")) end
    if pages >= 10 then add("surprised", string.format(_("%d pages of shelf. Brave."), pages)) end
    if n > 0 and n <= 3 then add("cozy", _("Tiny shelf. Very curated.")) end
    if n == 0 then add("sad", _("Empty shelf. So much potential.")) end
    if n >= 100 then add("playful", string.format(_("%d books. Bold of you to keep browsing."), n)) end
    local h = tonumber(os.date("%H")) or 12
    if h < 5 then add("sleepy", _("Browsing at this hour? Respect."))
    elseif h < 11 then add("happy", _("Morning browse. Tea first?"))
    elseif h >= 21 then add("dreamy", _("One more chapter, you said.")) end
    return L
end

-- ---- Kind 3: picks from what's on this shelf page --------------------------------

local function bookInfo(it)
    if type(it) ~= "table" or it.is_folder then return nil end
    local title = it.display_title or it.title
    if type(title) ~= "string" or title == "" then return nil end
    local author = it.author
    if (not author or author == "") and type(it.authors) == "table" then author = it.authors[1] end
    if type(author) ~= "string" or author == "" then author = nil end
    local pct = tonumber(it.percent_finished or it.book_pct)
    local st = it.status or it.read_status
    local state
    if st == "finished" or st == "complete" then state = "finished"
    elseif st == "on_hold" or st == "abandoned" then state = "hold"
    elseif st == "reading" or (pct and pct > 0 and pct < 1) then state = "reading"
    else state = "unread" end
    local series = type(it.series_name) == "string" and it.series_name ~= "" and it.series_name or nil
    return {
        title = title, author = author, pct = pct, state = state,
        series = series, series_num = it.series_num and tostring(it.series_num) or nil,
    }
end

local function recommendLines(f)
    local L = {}
    local function add(mood, text) L[#L + 1] = { mood = mood, text = text } end
    local books = {}
    for _i, it in ipairs(f.items or {}) do
        local b = bookInfo(it)
        if b then books[#books + 1] = b end
    end
    if #books == 0 then return L end

    local by_author, finished = {}, 0
    for _i, b in ipairs(books) do
        local t = quoted(b.title)
        if b.state == "reading" and b.pct then
            local pc = math.floor(b.pct * 100 + 0.5)
            if pc >= 80 then
                add("cheer", string.format(_("%s is %d%% done. One more push?"), t, pc))
            else
                add("reading", string.format(_("Back to %s? You're %d%% in."), t, pc))
            end
        elseif b.state == "hold" then
            add("sad", string.format(_("%s is on hold. It misses you."), t))
        elseif b.state == "unread" then
            if b.series and b.series_num and b.series_num ~= "1" and b.series_num ~= "0" then
                add("curious", string.format(_("%s #%s is still unread."), clip(b.series, 18), b.series_num))
            elseif b.series then
                add("hungry", string.format(_("Start the %s series?"), clip(b.series, 18)))
            elseif b.author then
                add("curious", string.format(_("%s by %s. Still unread."), t, clip(b.author, 20)))
            else
                add("curious", string.format(_("Still unread: %s."), t))
            end
            if b.author then
                by_author[b.author] = by_author[b.author] or {}
                table.insert(by_author[b.author], b.title)
            end
        else
            finished = finished + 1
        end
    end
    for author, titles in pairs(by_author) do
        if #titles >= 2 then
            add("playful", string.format(_("Two by %s: %s or %s?"), clip(author, 20), quoted(titles[1]), quoted(titles[2])))
        end
    end
    if #books >= 3 and finished == #books then
        add("proud", _("All read on this page. Impressive."))
    end
    return L
end

-- ---- Kind 4: shelf sayings (written for Bookshelf, no real person's words) --------

local SAYINGS = {
    "A shelf is a promise you keep making.",
    "Every book is a door with a spine.",
    "Unread books are just future evenings.",
    "Somewhere on this shelf is your next favourite.",
    "A good book leaves the light on for you.",
    "Read slowly. The ending isn't going anywhere.",
    "Books don't mind waiting. They're good at it.",
    "One more chapter is how every night begins.",
    "A full shelf is a quiet kind of wealth.",
    "Dog-ears are just love with a crease.",
    "The best bookmark is a good excuse.",
    "Every cover hides a weather system.",
    "A page is a small room with a big window.",
    "Borrowed books always know the way home.",
    "Rainy day, tall stack. That's the plan.",
    "Some books are meals. Some are snacks. Both count.",
    "It's fine to quit a book. Shelves forgive.",
    "A shelf remembers everything you meant to read.",
    "Spines in a row, stories in a crowd.",
    "Your to-read pile is optimism, stacked.",
    "The first line is a handshake.",
    "Every library starts with one more book.",
    "Quiet rooms are where books talk loudest.",
    "Stories keep. Take your time.",
    "Browse like you have all afternoon.",
    "Reading is time travel with better seats.",
    "A bookmark is a pause button made of paper.",
    "Don't rush the ending. It's earned.",
    "The right book finds you on the right page.",
    "Coffee cools. Good chapters stay warm.",
    "Browsing is choosing in slow motion.",
    "Every story started as someone's quiet hour.",
    "Small screen, big world.",
    "Future you will thank you for this pile.",
    "Comfort is a book you've already read twice.",
    "The shelf is full. The evening is free.",
}

-- Optional: add your own to koreader/settings/orbitshelf-quotes.txt, one per
-- line, as `quote` or `quote | author`. Re-read when the file changes.
local _user_quotes = { mtime = nil, list = {} }
local function userQuotes()
    local ok, DataStorage = pcall(require, "datastorage")
    if not ok or type(DataStorage) ~= "table" or type(DataStorage.getSettingsDir) ~= "function" then
        return _user_quotes.list
    end
    local path = DataStorage:getSettingsDir() .. "/orbitshelf-quotes.txt"
    local attr = lfs.attributes(path)
    local mtime = attr and attr.modification or false
    if mtime == _user_quotes.mtime then return _user_quotes.list end
    _user_quotes.mtime = mtime
    _user_quotes.list = {}
    if not attr then return _user_quotes.list end
    pcall(function()
        for line in io.lines(path) do
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if line ~= "" and line:sub(1, 1) ~= "#" then
                local text, author = line:match("^(.-)%s*|%s*(.+)$")
                table.insert(_user_quotes.list, { text = text or line, author = author })
            end
        end
    end)
    return _user_quotes.list
end

local function quoteLines(f)
    local L = {}
    for _i, s in ipairs(SAYINGS) do
        L[#L + 1] = { mood = (#L % 3 == 0) and "dreamy" or "reading", text = "“" .. s .. "”" }
    end
    for _i, q in ipairs(userQuotes()) do
        L[#L + 1] = {
            mood = "reading", text = "“" .. q.text .. "”",
            sub = q.author and ("— " .. clip(q.author, 18) .. " · " .. string.format(_("p. %d/%d"), f.page, f.pages)) or nil,
        }
    end
    return L
end

-- ---- Pick one line ----------------------------------------------------------------

local function recentHas(text)
    for _i, t in ipairs(_recent) do if t == text then return true end end
    return false
end

local function remember(text)
    table.insert(_recent, text)
    while #_recent > RECENT_MAX do table.remove(_recent, 1) end
end

local KIND_POOLS = {
    page = pageLines, witty = wittyLines, recs = recommendLines, quotes = quoteLines,
}

local function enabledKinds()
    local order = {}
    if cfg.critter_say_page then order[#order + 1] = "page" end
    if cfg.critter_say_witty then order[#order + 1] = "witty" end
    if cfg.critter_say_recs then order[#order + 1] = "recs" end
    if cfg.critter_say_quotes then order[#order + 1] = "quotes" end
    if #order == 0 then order[1] = "page" end
    return order
end

-- One line per (page, tap, shelf) so a repaint doesn't change what it says; every
-- tap or page turn moves to the next kind (page → witty → picks → sayings) and
-- steps over anything said in the last few lines.
local function pickFooterLine(bw)
    local f = shelfFacts(bw)
    local order = enabledKinds()
    local key = table.concat({
        f.page, f.pages, f.books, f.shelf, _footer_remark_i, table.concat(order, ","),
    }, "|")
    if _pick_cache and _pick_cache.key == key then return _pick_cache.line end

    local shelf_h = strHash(f.shelf)
    local start = (_footer_remark_i + f.page + shelf_h + _session_seed) % #order
    local chosen, chosen_kind
    for k = 0, #order - 1 do
        local kind = order[((start + k) % #order) + 1]
        local pool = KIND_POOLS[kind](f)
        if #pool > 0 then
            local base = (_session_seed + f.page * 31 + _footer_remark_i * 17 + shelf_h + #pool * 7) % #pool
            for j = 0, #pool - 1 do
                local cand = pool[((base + j) % #pool) + 1]
                if not recentHas(cand.text) then chosen = cand break end
            end
            chosen = chosen or pool[base + 1]
            chosen_kind = kind
            break
        end
    end
    chosen = chosen or { mood = "happy", text = string.format(_("Page %d of %d."), f.page, f.pages) }
    chosen_kind = chosen_kind or "page"
    local line = { mood = chosen.mood, text = chosen.text, sub = chosen.sub or pageInfo(f) }
    remember(line.text)
    _pick_cache = { key = key, line = line }
    package.loaded["orbitshelf_critter_last"] = {
        kind = chosen_kind, text = line.text, sub = line.sub, mood = line.mood,
        page = f.page, pages = f.pages, books = f.books, shelf = f.shelf,
        on_page = #(f.items or {}),
    }
    return line
end

-- The critter strip: the message and its detail written straight onto the footer bar
-- (the bar's own ink, centred in the visible bar), and the critter at the right end,
-- sized to the bar. h is the footer row's height; the visible bar is its top part, the
-- rest is tap area below it (Bookshelf's 12 dp).
-- width / height of a critter image, read once per file (nil when it can't be read)
local critter_aspects = {}
local function critterAspect(path)
    local a = critter_aspects[path]
    if a ~= nil then return a or nil end
    local ok, bb = pcall(function() return require("ui/renderimage"):renderImageFile(path, false) end)
    if ok and bb then
        local w, h = bb:getWidth(), bb:getHeight()
        pcall(bb.free, bb)
        a = (h > 0) and (w / h) or false
    else
        a = false
    end
    critter_aspects[path] = a
    return a or nil
end

local function buildFooterCritter(bw, max_w, h)
    local Screen = require("device").screen
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local LeftContainer = require("ui/widget/container/leftcontainer")
    local TextWidget = require("ui/widget/textwidget")
    local Blitbuffer = require("ffi/blitbuffer")
    local Font = require("ui/font")
    local Geom = require("ui/geometry")
    local line = pickFooterLine(bw)
    local mood = line.mood or "happy"
    local message, detail = line.text, line.sub

    local cap_h = h - Screen:scaleBySize(12)
    local pad = Screen:scaleBySize(3)
    local inner_h = math.max(Screen:scaleBySize(16), cap_h - 2 * pad)

    -- the critter, when SimpleUI's modules are there
    local sprite
    pcall(function()
        local Sprite = sui("modules/critter/sprite")
        local Assets = sui("modules/critter/assets")
        if not (type(Sprite) == "table" and type(Assets) == "table" and type(Assets.get) == "function") then return end
        local want = critterId(Assets)
        local entry = Assets.get(want)
        if type(entry) == "table" and want and entry.id ~= want and type(Assets.list) == "function" then
            for _i, e in ipairs(Assets.list()) do
                if e.id == want then entry = e break end
            end
        end
        local path = entry and (Assets.imagePath(entry, mood)
            or (BASE_MOOD[mood] and Assets.imagePath(entry, BASE_MOOD[mood]))
            or Assets.imagePath(entry, "happy"))
        if not path then return end
        -- SimpleUI scales a big critter image to exactly the box it is given, so the
        -- box keeps the image's own shape (a wide box stretched the critter)
        local box_w = math.floor(max_w * 0.22)
        local aspect = critterAspect(path)
        if aspect then box_w = math.min(box_w, math.max(1, math.floor(inner_h * aspect + 0.5))) end
        local sp = Sprite:new{ path = path, max_w = box_w, max_h = inner_h }
        if sp.dimen and sp.dimen.w > 0 then sprite = sp end
    end)

    local gap = Screen:scaleBySize(6)
    local text_w = max_w - (sprite and (sprite.dimen.w + gap) or 0) - pad
    if text_w < Screen:scaleBySize(40) then
        sprite = nil
        text_w = max_w - pad
    end

    -- the bar's ink, so it reads on a dark or a light bar
    local ink = Blitbuffer.COLOR_BLACK
    pcall(function() if bw and type(bw._chromeInk) == "function" then ink = bw:_chromeInk() or ink end end)
    -- the detail a little softer than the message, but still easy to read: light
    -- grey on a dark bar, dark grey on a light one (it was the other way round,
    -- dark on dark, and faded out)
    local detail_ink = ink
    pcall(function()
        local a = ink.getColor8 and ink:getColor8().a or 0
        detail_ink = Blitbuffer.gray(a >= 128 and 0.15 or 0.75)
    end)

    -- the biggest type that fits the bar: message over detail
    local text_block
    for size = 15, 8, -1 do
        local msg = TextWidget:new{ text = message or "", face = Font:getFace("xx_smallinfofont", size),
                                    bold = true, fgcolor = ink, max_width = text_w }
        local det = detail and detail ~= "" and TextWidget:new{ text = detail,
                                    face = Font:getFace("xx_smallinfofont", math.max(7, size - 3)),
                                    fgcolor = detail_ink, max_width = text_w } or nil
        local total = msg:getSize().h + (det and det:getSize().h or 0)
        if total <= inner_h or size == 8 then
            local vg = VerticalGroup:new{ align = "left", msg }
            if det then vg[#vg + 1] = det end
            text_block = vg
            break
        end
        msg:free()
        if det then det:free() end
    end

    local row = HorizontalGroup:new{ align = "center" }
    row[#row + 1] = LeftContainer:new{ dimen = Geom:new{ w = text_w, h = inner_h }, text_block }
    if sprite then
        row[#row + 1] = HorizontalSpan:new{ width = gap }
        row[#row + 1] = sprite
    end
    -- centred in the visible bar; the tap area below it is left as space
    local strip = VerticalGroup:new{ align = "left" }
    strip[#strip + 1] = CenterContainer:new{ dimen = Geom:new{ w = max_w, h = cap_h }, row }
    if h > cap_h then strip[#strip + 1] = VerticalSpan:new{ width = h - cap_h } end
    return strip, line
end

local function hookFooterCritter()
    local ok, BW = pcall(require, "lib/bookshelf_widget")
    if not ok or type(BW) ~= "table" then return end
    if BW._orbitshelf_footer_critter then return end
    BW._orbitshelf_footer_critter = true

    local orig = BW._buildPaginationFooter
    if type(orig) ~= "function" then return end

    BW._buildPaginationFooter = function(self, content_w, label_h, total_pages, ...)
        if not cfg.footer_critter then
            return orig(self, content_w, label_h, total_pages, ...)
        end

        local Screen = require("device").screen
        local CenterContainer = require("ui/widget/container/centercontainer")
        local InputContainer = require("ui/widget/container/inputcontainer")
        local Geom = require("ui/geometry")
        local GestureRange = require("ui/gesturerange")
        local HorizontalGroup = require("ui/widget/horizontalgroup")

        local h = label_h or Screen:scaleBySize(36)
        local strip_w = math.floor((content_w or Screen:getWidth()) * 0.90)
        local edge_w = math.floor(strip_w * 0.12)
        local mid_w = strip_w - 2 * edge_w

        local critter, _line = buildFooterCritter(self, mid_w, h)

        -- Invisible edge buttons: still page with left/right taps
        local function step(dir)
            return function()
                if type(self._footerStep) == "function" then
                    pcall(self._footerStep, self, dir)
                elseif type(self.onNextPage) == "function" and dir > 0 then
                    pcall(self.onNextPage, self)
                elseif type(self.onPrevPage) == "function" and dir < 0 then
                    pcall(self.onPrevPage, self)
                end
            end
        end

        local function edgeBtn(w, on_tap)
            local Btn = InputContainer:extend{}
            function Btn:onTap()
                if on_tap then on_tap() end
                return true
            end
            local b = Btn:new{ dimen = Geom:new{ w = w, h = h } }
            b.ges_events = {
                Tap = { GestureRange:new{ ges = "tap", range = b.dimen } },
            }
            return b
        end

        local Mid = InputContainer:extend{}
        function Mid:onTap()
            _footer_remark_i = _footer_remark_i + 1
            local bw = self.host
            pcall(function()
                if not (bw and bw._overlap_group and type(bw._buildFooterRow) == "function") then return end
                local d = bw._layout_dims or bw._dims
                local content_w = (d and d.content_w) or content_w
                local footer_h = (d and d.FOOTER_H) or h
                local pages = bw._total_pages or total_pages or 1
                local new_row = bw:_buildFooterRow(content_w, pages, footer_h)
                local BottomContainer = require("ui/widget/container/bottomcontainer")
                local Geom2 = require("ui/geometry")
                local idx = d and d.footer_overlap_idx
                if idx and bw._overlap_group then
                    local margin = (d and d.FOOTER_BOTTOM_MARGIN) or 0
                    bw._overlap_group[idx] = BottomContainer:new{
                        dimen = Geom2:new{ w = bw.width, h = (bw.height or Screen:getHeight()) - margin },
                        new_row,
                    }
                    UIManager:setDirty(bw, "ui")
                elseif type(bw._rebuild) == "function" then
                    bw:_rebuild()
                end
            end)
            return true
        end

        local mid = Mid:new{
            dimen = Geom:new{ w = mid_w, h = h },
            CenterContainer:new{
                dimen = Geom:new{ w = mid_w, h = h },
                critter,
            },
        }
        mid.host = self
        mid.ges_events = {
            Tap = { GestureRange:new{ ges = "tap", range = mid.dimen } },
        }

        local row = HorizontalGroup:new{ align = "center" }
        row[#row + 1] = edgeBtn(edge_w, step(-1))
        row[#row + 1] = mid
        row[#row + 1] = edgeBtn(edge_w, step(1))

        -- Keep nav state so key/D-pad paths still know back/fwd
        local page = 1
        local pages = tonumber(total_pages) or 1
        pcall(function()
            local f = shelfFacts(self)
            page, pages = f.page, f.total_pages
        end)
        self._footer_nav_state = { back = page > 1, fwd = page < pages }

        return CenterContainer:new{
            dimen = Geom:new{ w = content_w, h = h },
            row,
        }
    end
    logger.info(TAG, "footer critter hooked")
end

-- ---- Flash (clears e-ink ghosting) ---------------------------------------------------
-- Bookshelf redraws the hero and the shelf rows in "ui" mode, which never flashes, so a
-- new cover can show the old one faintly behind it. Flash Hero: the hero's own rect gets
-- a flash when it shows another book (not on the clock tick). Flash Shelf: every page
-- turn is a full refresh (Bookshelf's own "Use E-ink refresh rate for shelf pages" only
-- flashes as often as KOReader's Full refresh rate). Both off by default: a flash takes
-- a moment and a little battery.
local function hookFlash()
    local ok, BW = pcall(require, "lib/bookshelf_widget")
    if not ok or type(BW) ~= "table" or BW._orbitshelf_flash then return end
    BW._orbitshelf_flash = true
    local orig_swap = BW._swapHeroInPlace
    if type(orig_swap) == "function" then
        BW._swapHeroInPlace = function(self, ...)
            local scope
            if cfg.flash_hero then
                pcall(function()
                    local old = self._hero_parent and self._hero_parent[1]
                    local d = old and old.dimen
                    if d and d.w and d.w > 0 then
                        scope = require("ui/geometry"):new{ x = d.x, y = d.y, w = d.w, h = d.h }
                    end
                end)
            end
            local r = { orig_swap(self, ...) }
            if scope then
                UIManager:setDirty(self, function() return "flashui", scope, self.dithered end)
            end
            return unpack(r)
        end
    end
    local orig_due = BW._pageTurnFlashDue
    if type(orig_due) == "function" then
        BW._pageTurnFlashDue = function(...)
            if cfg.flash_shelf then
                local Device = require("device")
                if Device.hasEinkScreen and Device:hasEinkScreen() then return true end
            end
            return orig_due(...)
        end
    end
end

-- ---- Settings menu ----------------------------------------------------------------

-- Grouped like the other patches: the two main switches first, then Hero, Shelf,
-- Footer, and Clean Up Cache at the end.
local function rebuildShelf()
    local bs = getBookshelf()
    if bs and type(bs._rebuild) == "function" then pcall(bs._rebuild, bs) end
end

local function toggle(key, label, help, after, enabled_func)
    return {
        text = label,
        help_text = help,
        checked_func = function() return cfg[key] and true or false end,
        enabled_func = enabled_func,
        keep_menu_open = true,
        callback = function()
            cfg[key] = not cfg[key]
            saveConfig()
            if after then pcall(after) end
        end,
    }
end

local function critterSays(key, label)
    return {
        text = label,
        checked_func = function() return cfg[key] and true or false end,
        enabled_func = function() return cfg.footer_critter end,
        keep_menu_open = true,
        callback = function()
            local on = 0
            for _i, k in ipairs({ "critter_say_page", "critter_say_witty", "critter_say_recs", "critter_say_quotes" }) do
                if cfg[k] then on = on + 1 end
            end
            if cfg[key] and on <= 1 then return end -- keep at least one
            cfg[key] = not cfg[key]
            saveConfig()
            _pick_cache = nil
            rebuildShelf()
        end,
    }
end

local function cleanUpCacheItem()
    return {
        text = _("Clean Up Cache…"),
        help_text = _("Old covers and leftovers go. The newest cover of each book is kept (at most 600). Half-finished downloads and deleted Side Panel downloads are removed. The saved BookOrbit lists are pulled fresh. Nothing you set changes, and nothing on your BookOrbit server."),
        keep_menu_open = true,
        callback = function()
            UIManager:show(require("ui/widget/confirmbox"):new{
                text = _("Clean up the cache?\n\nOld covers and leftovers go. Newest cover of each book is kept (at most 600). Half-finished downloads and deleted Side Panel downloads are removed. Nothing you set changes, and nothing on your BookOrbit server."),
                ok_text = _("Clean Up"),
                ok_callback = function()
                    local res = BoCovers.cleanUp()
                    page_cache = {}
                    savePageCache()
                    local bs = getBookshelf()
                    if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
                    collectgarbage()
                    local msg
                    if (res.files or 0) + (res.entries or 0) == 0 then
                        msg = _("Cache already clean")
                    else
                        local bits = {}
                        if res.files > 0 then
                            bits[#bits + 1] = string.format("%d old files (%.1f MB)", res.files, (res.bytes or 0) / 1048576)
                        end
                        if res.entries > 0 then
                            bits[#bits + 1] = string.format("%d stale downloads", res.entries)
                        end
                        msg = _("Cleaned: ") .. table.concat(bits, ", ")
                    end
                    UIManager:show(require("ui/widget/infomessage"):new{ text = msg, timeout = 3 })
                end,
            })
        end,
    }
end

local function menuItems()
    local bo_ok = function() return bookOrbitInstalled() end
    local items = {}
    if not bookOrbitInstalled() then
        items[#items + 1] = { text = _("BookOrbit plugin not found"), enabled_func = function() return false end, separator = true }
    elseif not bookOrbitSignedIn() then
        items[#items + 1] = { text = _("Sign in to BookOrbit first"), enabled_func = function() return false end, separator = true }
    end
    items[#items + 1] = toggle("use_bookorbit", _("Use BookOrbit In Bookshelf"),
        _("Adds a BookOrbit shelf source to Bookshelf: Library, Recently added, Recently read, Series, Authors, Genres and Collections, books not on the device included."),
        function()
            if cfg.use_bookorbit then registerSource() else unregisterSource() end
        end, bo_ok)
    items[#items + 1] = toggle("auto_rewrite_stock", _("Rewrite Stock Series / Authors / Genres"),
        _("Points Bookshelf's own Series, Authors, Genres, Recent and Latest chips at BookOrbit. Off puts the stock chips back."),
        function()
            pcall(applyAutoRewrite)
            local bs = getBookshelf()
            if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
        end, function() return cfg.use_bookorbit and bookOrbitInstalled() end)
    items[#items].separator = true
    items[#items + 1] = {
        text = _("Hero"),
        sub_item_table = {
            toggle("hero_pills", _("Download / Remove Buttons"),
                _("A BookOrbit book not on the device: Download and Open In BookOrbit at the bottom of the hero. One on the device: small Remove From Device and Open In BookOrbit icons at the bottom right."),
                rebuildShelf),
            toggle("hero_sync", _("Sync Button"),
                _("A small Sync icon at the bottom right of the hero for BookOrbit books: pulls the BookOrbit lists fresh and runs BookOrbit's sync all books."),
                rebuildShelf),
            toggle("flash_hero", _("Flash When It Changes"),
                _("Flashes the hero clean when it shows another book, so the last cover doesn't show faintly behind the new one. Takes a moment longer. Off by default."),
                nil),
        },
    }
    items[#items + 1] = {
        text = _("Shelf"),
        sub_item_table = {
            {
                text_func = function()
                    local books = Genres.library() or {}
                    local left = #Genres.missing(books)
                    if Genres.running then
                        return T(_("Genres: building, %1 of %2"), Genres.done, Genres.total)
                    elseif left == 0 and #books > 0 then
                        return _("Genres: ready")
                    end
                    return T(_("Build Genres (%1 books)"), left)
                end,
                help_text = _("BookOrbit doesn't send genres with its book lists, so each book's genres and tags are looked up once from its BookOrbit page, in the background (about 2 minutes for 130 books, Wi-Fi on). Books on the device use the genres in their own file. Wi-Fi off pauses it; it carries on when Wi-Fi is back. Afterwards only new or changed books are looked up."),
                enabled_func = function() return bookOrbitInstalled() and not Genres.running end,
                keep_menu_open = true,
                callback = function() Genres.asked = true; Genres.build(false) end,
            },
            {
                text = _("Rebuild Genres"),
                help_text = _("Forgets the saved genres and looks every book up again. Use it after changing genres or tags in BookOrbit for many books at once."),
                enabled_func = function() return bookOrbitInstalled() and not Genres.running end,
                keep_menu_open = true,
                callback = function()
                    UIManager:show(require("ui/widget/confirmbox"):new{
                        text = _("Rebuild genres?\n\nEvery book's genres are looked up again, in the background."),
                        ok_text = _("Rebuild"),
                        ok_callback = function()
                            Genres.store = {}
                            Genres.save()
                            Genres.asked = true
                            Genres.build(false)
                        end,
                    })
                end,
                separator = true,
            },
            toggle("flash_shelf", _("Flash On Every Page Turn"),
                _("Every page turn of the shelf is a full refresh, to clear ghosting. Page turns skip their animation and take a little longer. Bookshelf's own \"Use E-ink refresh rate for shelf pages\" flashes only as often as KOReader's Full refresh rate. Off by default."),
                nil),
        },
    }
    items[#items + 1] = {
        text = _("Footer"),
        sub_item_table = {
            toggle("footer_critter", _("Footer Critter"),
                _("Your SimpleUI critter in place of the page numbers at the bottom. Tap it for another line; the left and right edges still turn the page."),
                function() hookFooterCritter() rebuildShelf() end),
            {
                text = _("Critter Says"),
                enabled_func = function() return cfg.footer_critter end,
                sub_item_table = {
                    critterSays("critter_say_page", _("Page")),
                    critterSays("critter_say_witty", _("Witty")),
                    critterSays("critter_say_recs", _("Picks")),
                    critterSays("critter_say_quotes", _("Sayings")),
                },
                separator = true,
            },
            toggle("close_only_menu", _("Close Only (No Hamburger)"),
                _("The hamburger becomes a close X: one tap closes Bookshelf, no menu first."),
                function() hookCloseOnlyMenu() rebuildShelf() end),
            {
                text_func = function()
                    return T(_("Close Control: %1"),
                        cfg.close_menu_side == "left" and _("Left")
                        or cfg.close_menu_side == "right" and _("Right")
                        or _("Bookshelf's Side"))
                end,
                enabled_func = function() return cfg.close_only_menu end,
                help_text = _("Which bottom corner the close X sits in. Bookshelf's Side follows Bookshelf's own Start menu position (left unless you changed it there)."),
                sub_item_table = (function()
                    local t = {}
                    for _i, side in ipairs({ { "left", _("Left") }, { "right", _("Right") }, { "bottom", _("Bookshelf's Side") } }) do
                        t[#t + 1] = {
                            text = side[2],
                            radio = true,
                            keep_menu_open = true,
                            checked_func = function() return (cfg.close_menu_side or "bottom") == side[1] end,
                            callback = function()
                                cfg.close_menu_side = side[1]
                                saveConfig()
                                hookCloseOnlyMenu()
                                rebuildShelf()
                            end,
                        }
                    end
                    return t
                end)(),
            },
        },
        separator = true,
    }
    items[#items + 1] = cleanUpCacheItem()
    return items
end

local function menuItem()
    return {
        text = _("OrbitShelf Tweaks"),
        sub_item_table_func = menuItems,
    }
end

-- Registered at load time, the way Screenshot Timer does it: the file manager menu
-- is built once and then kept, so hooking it later (or editing its items after it
-- was sorted) never shows anything.
local function addToolsMenu()
    -- Add-ons (2-tweaks-menu.lua): shared registry.
    local TM = package.loaded.tweaks_mods or {}
    package.loaded.tweaks_mods = TM
    TM.entries = TM.entries or {}
    TM.entries[MENU_ID] = {
        text = _("OrbitShelf Tweaks"),
        order = 120,
        where = "filemanager",
        group = "Home & Library",
        build = menuItem,
    }

    -- Fallback: Tools, when the Add-ons patch isn't there (or the entry is turned off).
    local function addToOrder()
        local ok, order = pcall(require, "ui/elements/filemanager_menu_order")
        if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
        for _i, v in ipairs(order.tools) do if v == MENU_ID then return end end
        local pos = #order.tools + 1
        for i, v in ipairs(order.tools) do
            if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
        end
        table.insert(order.tools, pos, MENU_ID)
    end
    local okf, FMmenu = pcall(require, "apps/filemanager/filemanagermenu")
    if okf and type(FMmenu) == "table" and type(FMmenu.setUpdateItemTable) == "function"
            and not FMmenu._orbitshelf_menu then
        FMmenu._orbitshelf_menu = true
        local orig = FMmenu.setUpdateItemTable
        FMmenu.setUpdateItemTable = function(self, ...)
            local in_addons = TM.active and (type(TM.shows) ~= "function" or TM.shows(MENU_ID))
            if type(self.menu_items) == "table" and not in_addons then
                addToOrder()
                local m = menuItem()
                m.sorting_hint = "tools"
                self.menu_items[MENU_ID] = m
            end
            return orig(self, ...)
        end
    end
end

pcall(addToolsMenu)

-- ---- Boot -------------------------------------------------------------------------

local function boot(ui)
    if cfg.use_bookorbit and bookOrbitInstalled() then
        if not registerSource(ui) then
            UIManager:nextTick(function() registerSource(ui) end)
            -- Bookshelf may load after patches
            UIManager:scheduleIn(1, function() registerSource() end)
            UIManager:scheduleIn(3, function() registerSource() end)
        end
    end
    hookHero()
    pcall(hookFlash)
    pcall(Genres.listen)
    pcall(registerFileDialogButton)
    hookCloseOnlyMenu()
    hookFooterCritter()
    pcall(applyAutoRewrite)
end

-- Run after UI is ready (patch priority 2-)
UIManager:nextTick(function()
    local ok, err = pcall(boot)
    if not ok then logger.warn(TAG, "boot failed:", err) end
end)

logger.info(TAG, "loaded")
