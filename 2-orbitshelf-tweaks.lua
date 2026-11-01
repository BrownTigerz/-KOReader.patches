--[[
2-orbitshelf-tweaks.lua
OrbitShelf Tweaks — BookOrbit shelves inside Bookshelf (AndyHazz/bookshelf.koplugin).

Requires:
  * bookshelf.koplugin (SOURCE_API >= 1; best with Bookshelf 5.4+ / 6.x)
  * bookorbit.koplugin signed in (server_url + username + userkey)

Version: 1.3.0

What it does
  * Toggle **Use BookOrbit In Bookshelf**. Registers a **BookOrbit** fetch-mode
    shelf source (books not on device included).
  * Source modes: Library, Recently added, Recently read, **Series**,
    **Authors**, **Genres**, and cached collections. Series/Authors/Genres are
    folder drills (tap a group → its books).
  * Toggle **Rewrite Stock Series/Author/Genre**: points the built-in Series,
    Authors, Genres, Recent and Latest chips at BookOrbit (restored when off).
  * Covers: shared cache/bookorbit/ folder with Side Panel; Clean Up Cache
    matches Reading Log Tweaks.
  * Hero: hold menu **and** inline **Download / Remove / Open In BookOrbit**
    pills on the banner for BookOrbit books.
  * Toggle **Close Only Menu**: start menu becomes only Close Bookshelf, with
    true **left / right / bottom** placement via StartMenu side_override.
  * Toggle **Footer Critter**: replaces bottom page nav with your SimpleUI
    Tiny Critter (same modules as Quick Shelf / Reading Log). Says shelf name,
    page, and book count. Tap for another remark; left/right edges still page;
    swipe still pages.

Settings: Tools → OrbitShelf Tweaks (or Add-ons with 2-tweaks-menu.lua).

Install: koreader/patches/2-orbitshelf-tweaks.lua, restart.

Changelog:
  1.3.0  2026-10-31  Footer critter replaces page nav (shelf / page / count).
  1.2.0  2026-10-31  Fetch-mode Series/Authors/Genres; auto-rewrite; hero pills;
                     true left/right close.
  1.0.1  2026-10-31  Shared cover cache + Clean Up Cache (Reading Log style).
  1.0.0  2026-10-31  First cut: BookOrbit source, hero hold, close-only menu.
]]

local VERSION = "1.3.0"
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
    close_only_menu = false,       -- strip start menu down to Close
    close_menu_side = "bottom",    -- "left" | "right" | "bottom"
    cache_ttl = 30 * 60,           -- soft refresh window (seconds)
    offline_ttl = 6 * 3600,        -- keep offline lists this long
    hero_pills = true,             -- Download / Remove / Open In BookOrbit on hero
    footer_critter = true,         -- replace bottom page nav with a critter
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
        footer_critter = cfg.footer_critter,
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

local function authorsString(book)
    if type(book.authors) == "table" then
        local parts = {}
        for _j, a in ipairs(book.authors) do
            if type(a) == "string" then parts[#parts + 1] = a
            elseif type(a) == "table" and a.name then parts[#parts + 1] = a.name end
        end
        return table.concat(parts, ", ")
    elseif type(book.author) == "string" then
        return book.author
    end
    return ""
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
local CACHE_KEY = "orbitshelf_tweaks_pages"

local function loadPageCache()
    local saved = G_reader_settings and G_reader_settings:readSetting(CACHE_KEY)
    if type(saved) == "table" then page_cache = saved end
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
    elseif type(book.genre) == "string" then
        genres = book.genre
    elseif type(book.tags) == "table" then
        genres = {}
        for _i, t in ipairs(book.tags) do
            if type(t) == "string" then genres[#genres + 1] = t
            elseif type(t) == "table" and t.name then genres[#genres + 1] = t.name end
        end
    end
    local remote = "bookorbit://" .. tostring(id)
    return {
        filepath = fp or remote,
        title = book.title or book.name or _("Untitled"),
        authors = authorsString(book),
        author = authorsString(book),
        series = series,
        series_name = series,
        series_index = series_index,
        series_num = series_index and tostring(series_index) or nil,
        genres = genres,
        description = book.description or book.summary,
        cover_image_path = cover,
        pages = tonumber(book.pageCount) or tonumber(book.pages),
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
    for _guard = 1, 20 do
        local q = {}
        for k, v in pairs(api_params or {}) do q[k] = v end
        q.page, q.size = page, page_size
        local ok_body, body = pcall(function() return client:catalogBooks(q) end)
        if not ok_body or type(body) ~= "table" then break end
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

local function downloadBookOrbitBook(book, on_done)
    local id = book and (book.bookorbit_id or book.id)
    if not id then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("No BookOrbit id") })
        return
    end
    local client = boApiClient()
    if not client then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("BookOrbit is not signed in") })
        return
    end

    local function run()
        local Trapper = require("ui/trapper")
        Trapper:wrap(function()
            local ok_d, detail = pcall(function() return client:catalogBook(id) end)
            if not ok_d or type(detail) ~= "table" then
                UIManager:show(require("ui/widget/infomessage"):new{ text = _("Could not load book details") })
                return
            end
            local okU, CU = pcall(require, "bookorbit_catalog_util")
            local file
            local function okf(f)
                return type(f) == "table" and f.id and (not okU or CU.isSupportedFormat(f.format))
            end
            for _i, f in ipairs(detail.files or {}) do
                if okf(f) and f.role == "primary" then file = f break end
            end
            if not file then
                for _i, f in ipairs(detail.files or {}) do
                    if okf(f) then file = f break end
                end
            end
            if not file then
                UIManager:show(require("ui/widget/infomessage"):new{ text = _("No file this reader can open") })
                return
            end

            local download_dir = G_reader_settings and G_reader_settings:readSetting("download_dir")
            if type(download_dir) ~= "string" or download_dir == "" then
                download_dir = require("datastorage"):getDataDir() .. "/downloads"
            end
            require("util").makePath(download_dir)

            local okDR, DownloadRoot = pcall(require, "bookorbit_download_root")
            if okDR and type(DownloadRoot) == "table" and type(DownloadRoot.get) == "function" then
                local d = DownloadRoot.get()
                if type(d) == "string" and d ~= "" then download_dir = d end
            end

            local safe = require("util").getSafeFilename
            local base = (detail.title or book.title or "book"):gsub("[/\\]", "_")
            local ext = string.lower(tostring(file.format or "epub"))
            local dest = download_dir .. "/" .. (safe and safe(base .. "." .. ext, download_dir) or (base .. "." .. ext))

            UIManager:show(require("ui/widget/infomessage"):new{
                text = T(_("Downloading %1…"), tostring(detail.title or book.title or "")),
                timeout = 2,
            })

            local ok_dl, err = pcall(function()
                -- Prefer catalog download helper when present
                if type(client.downloadCatalogFile) == "function" then
                    return client:downloadCatalogFile(file.id, dest)
                end
                if type(client.downloadFile) == "function" then
                    return client:downloadFile(file.id, dest)
                end
                -- Fallback: HTTP path via api if exposed
                error("no download method on BookOrbit API client")
            end)
            if not ok_dl then
                logger.warn(TAG, "download failed:", err)
                UIManager:show(require("ui/widget/infomessage"):new{ text = _("Download failed") })
                return
            end
            if lfs.attributes(dest, "mode") ~= "file" then
                UIManager:show(require("ui/widget/infomessage"):new{ text = _("Download failed") })
                return
            end

            rememberLocalDownload(id, dest)

            -- Link for sync when possible
            pcall(function()
                local util = require("util")
                local digest = util.partialMD5 and util.partialMD5(dest)
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

            if on_done then pcall(on_done, dest) end
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
            UIManager:show(require("ui/widget/infomessage"):new{
                text = _("Removed from device"),
                timeout = 2,
            })
            local bs = getBookshelf()
            if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
        end,
    })
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
        return splitNames(rec.authors or rec.author or "")
    elseif mode == "genres" then
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
    table.sort(order, function(a, b)
        return (buckets[a].title or ""):lower() < (buckets[b].title or ""):lower()
    end)
    local folders = {}
    for _i, lk in ipairs(order) do
        local b = buckets[lk]
        local id = mode .. ":" .. lk
        folders[#folders + 1] = {
            is_folder = true,
            title = b.title,
            label = b.title,
            display_title = b.title,
            book_count = #b.books,
            cover_image_path = b.cover,
            filepath = "bookorbit://nav/" .. id,
            bookorbit_group = mode,
            bookorbit_group_key = b.title,
            source_kind = SOURCE_ID,
        }
    end
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
    table.sort(out, function(a, b)
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

local function setPickMode(draft, mode, label)
    draft.source = draft.source or {}
    draft.source.kind = SOURCE_ID
    draft.source.mode = mode
    draft.label = label
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
            local okP, side = pcall(function() return package.loaded["simpleui_sidepanel_bo"] end)
            if okP and type(side) == "table" and type(side.collections) == "function" then
                local colls = side.collections() or {}
                for i, c in ipairs(colls) do
                    if i > 8 then break end
                    local cid, ctitle = c.id, c.title or tostring(c.id)
                    table.insert(buttons, #buttons, {{
                        text = T(_("Collection: %1"), ctitle),
                        callback = function()
                            UIManager:close(dialog)
                            draft.source = draft.source or {}
                            draft.source.kind = SOURCE_ID
                            draft.source.mode = "collection"
                            draft.source.collection_id = cid
                            draft.label = T(_("BookOrbit · %1"), ctitle)
                            done()
                        end,
                    }})
                end
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
            if drill and (drill.group == "series" or drill.group == "authors" or drill.group == "genres") then
                local items = booksInGroup(drill.group, drill.key)
                return slice(items, offset, limit)
            end
            if mode == "series" or mode == "authors" or mode == "genres" then
                local folders = groupFolders(mode)
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
            downloadBookOrbitBook(book, function(p)
                if ctx and type(ctx.open) == "function" and p then ctx.open(p) end
            end)
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
                                    if m ~= "collection" then d.source.collection_id = nil end
                                    d.label = "BookOrbit · " .. label
                                    done_row()
                                end,
                            }}
                        end
                        dialog = ButtonDialog:new{
                            title = _("BookOrbit list"),
                            buttons = {
                                go("library", _("Library")),
                                go("recently_added", _("Recently added")),
                                go("recently_read", _("Recently read")),
                                go("series", _("Series")),
                                go("authors", _("Authors")),
                                go("genres", _("Genres")),
                                {{ text = _("Cancel"), callback = function() UIManager:close(dialog) end }},
                            },
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

local function heroActionsFor(book)
    if not book or not (book.is_bookorbit or book.bookorbit_id or book.source_kind == SOURCE_ID) then
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

local function buildHeroPills(book, width)
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
    local row = HorizontalGroup:new{ align = "center" }
    for i, a in ipairs(actions) do
        if i > 1 and ok_hs then
            row[#row + 1] = HorizontalSpan:new{ width = 8 }
        end
        local label = TextWidget:new{
            text = a.text,
            face = face,
            max_width = math.floor((width or 200) / #actions) - 12,
        }
        local frame = FrameContainer:new{
            bordersize = 1,
            padding = 4,
            margin = 0,
            background = ok_bb and Blitbuffer.COLOR_WHITE or nil,
            radius = 4,
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

    -- Inline pills on the hero right column (bottom)
    if cfg.hero_pills and type(HeroCard._buildRightColumn) == "function" then
        local orig_col = HeroCard._buildRightColumn
        HeroCard._buildRightColumn = function(self, book, regions, state, dimen, ...)
            local column = orig_col(self, book, regions, state, dimen, ...)
            if not cfg.hero_pills then return column end
            local is_bo = book and (book.is_bookorbit or book.bookorbit_id or book.source_kind == SOURCE_ID)
            if not is_bo or (book and book.is_folder) then return column end
            local w = (dimen and dimen.w) or (self.width) or 200
            local pills = buildHeroPills(book, w)
            if not pills then return column end
            -- Attach under the existing column via a VerticalGroup when possible
            local ok_vg, VerticalGroup = pcall(require, "ui/widget/verticalgroup")
            local ok_vs, VerticalSpan = pcall(require, "ui/widget/verticalspan")
            if not ok_vg then return column end
            local vg = VerticalGroup:new{ align = "left" }
            if column then vg[#vg + 1] = column end
            if ok_vs then vg[#vg + 1] = VerticalSpan:new{ width = 6 } end
            vg[#vg + 1] = pills
            return vg
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
    return nil -- bottom / default: no override
end

local function isCloseEntry(entry)
    return type(entry) == "table" and (
        entry.id == "orbitshelf_close"
        or entry.internal == "close"
        or (type(entry.label) == "string" and entry.label:find("Close Bookshelf", 1, true))
    )
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

local function shelfFacts(bw)
    local page = tonumber(bw and (bw._page or bw._current_page)) or 1
    local total_pages = tonumber(bw and bw._total_pages) or 1
    if total_pages < 1 then total_pages = 1 end
    local items = tonumber(bw and (bw._total_items or bw._spine_books_total)) or 0
    local label = ""
    pcall(function()
        if type(bw.getActiveChipLabel) == "function" then
            label = tostring(bw:getActiveChipLabel() or "")
        elseif type(bw._active_chip_label) == "string" then
            label = bw._active_chip_label
        elseif type(bw.active_chip) == "string" then
            label = bw.active_chip
        end
        if label == "" and type(bw._tabs) == "table" then
            local id = bw._active_chip or bw.active_chip
            for _i, t in ipairs(bw._tabs) do
                if type(t) == "table" and t.id == id then
                    label = t.label or t.id or ""
                    break
                end
            end
        end
    end)
    if label == "" then label = _("this shelf") end
    -- Prefer live page counter if Bookshelf exposes one
    pcall(function()
        if type(bw._pageCounterText) == "function" then
            -- don't use as primary; just ensure page vars are sane
        end
        if type(bw._cursor) == "number" and type(bw._page_size) == "number" and bw._page_size > 0 then
            page = math.floor((bw._cursor - 1) / bw._page_size) + 1
        end
    end)
    return {
        page = page,
        total_pages = total_pages,
        books = items,
        shelf = label,
    }
end

local function footerRemarks(f)
    local shelf = f.shelf or _("this shelf")
    local page, pages, books = f.page or 1, f.total_pages or 1, f.books or 0
    local lines = {
        { mood = "curious", text = string.format(_("Page %d of %d."), page, pages),
          sub = books > 0 and string.format(_("%d books on %s."), books, shelf) or shelf },
        { mood = "happy", text = T(_("You're on %1."), shelf),
          sub = string.format(_("Page %d / %d"), page, pages) },
        { mood = "reading", text = books > 0 and string.format(_("%d books here."), books) or _("Empty shelf for now."),
          sub = string.format(_("Page %d of %d · %s"), page, pages, shelf) },
        { mood = "cheer", text = pages > 1 and string.format(_("Halfway? Page %d."), page) or _("One page, all set."),
          sub = shelf },
        { mood = "playful", text = T(_("Still browsing %1."), shelf),
          sub = books > 0 and string.format(_("%d books · page %d"), books, page) or string.format(_("Page %d"), page) },
        { mood = "neutral", text = string.format(_("%d of %d"), page, pages),
          sub = T(_("· %1"), shelf) },
    }
    if page >= pages and pages > 1 then
        lines[#lines + 1] = { mood = "party", text = _("Last page of the shelf!"), sub = shelf }
    elseif page == 1 then
        lines[#lines + 1] = { mood = "curious", text = _("Start of the shelf."), sub = shelf }
    end
    return lines
end

local function buildFooterCritter(bw, max_w, h)
    local Screen = require("device").screen
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local f = shelfFacts(bw)
    local remarks = footerRemarks(f)
    local i = ((_footer_remark_i + (f.page or 1) - 1) % #remarks) + 1
    local line = remarks[i]
    local mood = line.mood or "happy"
    local message, detail = line.text, line.sub

    local Sprite = sui("modules/critter/sprite")
    local Bubble = sui("modules/critter/bubble")
    local Assets = sui("modules/critter/assets")
    local CS = sui("modules/critter/settings")

    if type(Sprite) == "table" and type(Bubble) == "table" and type(Assets) == "table"
            and type(Bubble.build) == "function" and type(Assets.get) == "function" then
        local ok, group = pcall(function()
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
            if not path then return nil end
            local sprite = Sprite:new{ path = path, max_w = math.floor(max_w * 0.28), max_h = h }
            if not (sprite.dimen and sprite.dimen.w > 0) then return nil end
            local style = (type(CS) == "table" and type(CS.bubbleStyle) == "function") and CS.bubbleStyle() or "pixel"
            if style ~= "smooth" then style = "pixel" end
            local gap = Screen:scaleBySize(4)
            local bw_w = max_w - sprite.dimen.w - gap
            local Font = require("ui/font")
            local scale = math.max(0.6, math.min(1, h / Screen:scaleBySize(56)))
            local mf = Font:getFace("xx_smallinfofont", math.floor(14 * scale))
            local df = Font:getFace("xx_smallinfofont", math.floor(12 * scale))
            local o = {
                w = bw_w, h = h, side = "right", message = message,
                msg_face = mf, msg_bold = false, det_face = df, det_bold = false,
                scale = scale, style = style, unit = sprite.pixel or Screen:scaleBySize(2),
                detail = detail,
            }
            local bubble = bw_w > 0 and Bubble.build(o) or nil
            local g = HorizontalGroup:new{ align = "center" }
            if bubble then
                g[#g + 1] = bubble
                g[#g + 1] = HorizontalSpan:new{ width = gap }
            end
            g[#g + 1] = sprite
            return g
        end)
        if ok and group then return group, line end
    end

    -- Fallback: text only
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local Font = require("ui/font")
    local text = detail and (message .. "\n" .. detail) or message
    return TextBoxWidget:new{
        text = text,
        face = Font:getFace("xx_smallinfofont"),
        width = max_w,
        alignment = "center",
        height = h,
        height_adjust = true,
        height_overflow_show_ellipsis = true,
    }, line
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

        local critter, _line = buildFooterCritter(self, mid_w, h - 4)

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

-- ---- Settings menu ----------------------------------------------------------------

local function showMenu()
    local ButtonDialog = require("ui/widget/buttondialog")
    local dlg
    local function refresh()
        UIManager:close(dlg)
        showMenu()
    end
    local buttons = {
        {{
            text = (cfg.use_bookorbit and "✓ " or "☐ ") .. _("Use BookOrbit In Bookshelf"),
            enabled = bookOrbitInstalled(),
            callback = function()
                cfg.use_bookorbit = not cfg.use_bookorbit
                saveConfig()
                if cfg.use_bookorbit then
                    registerSource()
                else
                    unregisterSource()
                end
                refresh()
            end,
        }},
        {{
            text = (cfg.auto_rewrite_stock and "✓ " or "☐ ") .. _("Rewrite Stock Series/Author/Genre"),
            enabled = cfg.use_bookorbit and bookOrbitInstalled(),
            callback = function()
                cfg.auto_rewrite_stock = not cfg.auto_rewrite_stock
                saveConfig()
                pcall(applyAutoRewrite)
                local bs = getBookshelf()
                if bs and bs.sourceChanged then pcall(bs.sourceChanged, bs, SOURCE_ID) end
                refresh()
            end,
        }},
        {{
            text = (cfg.hero_pills and "✓ " or "☐ ") .. _("Hero Download / Remove Pills"),
            callback = function()
                cfg.hero_pills = not cfg.hero_pills
                saveConfig()
                refresh()
            end,
        }},
        {{
            text = (cfg.footer_critter and "✓ " or "☐ ") .. _("Footer Critter (replaces page nav)"),
            callback = function()
                cfg.footer_critter = not cfg.footer_critter
                saveConfig()
                hookFooterCritter()
                local bs = getBookshelf()
                if bs and type(bs._rebuild) == "function" then pcall(bs._rebuild, bs) end
                refresh()
            end,
        }},
        {{
            text = (cfg.close_only_menu and "✓ " or "☐ ") .. _("Close Only Menu"),
            callback = function()
                cfg.close_only_menu = not cfg.close_only_menu
                saveConfig()
                hookCloseOnlyMenu()
                local bs = getBookshelf()
                if bs and type(bs._rebuild) == "function" then pcall(bs._rebuild, bs) end
                refresh()
            end,
        }},
        {{
            text = T(_("Close Control: %1"),
                cfg.close_menu_side == "left" and _("Left")
                or cfg.close_menu_side == "right" and _("Right")
                or _("Bottom")),
            enabled = cfg.close_only_menu,
            callback = function()
                local order = { "bottom", "left", "right" }
                local i = 1
                for n, s in ipairs(order) do if s == cfg.close_menu_side then i = n break end end
                cfg.close_menu_side = order[(i % #order) + 1]
                saveConfig()
                hookCloseOnlyMenu()
                -- Move the footer hamburger to the new side (critter stays centre)
                local bs = getBookshelf()
                if bs and type(bs._rebuild) == "function" then pcall(bs._rebuild, bs) end
                refresh()
            end,
        }},
        {{
            text = _("Clean Up Cache…"),
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
        }},
        {{
            text = _("Close"),
            callback = function() UIManager:close(dlg) end,
        }},
    }
    local note = ""
    if not bookOrbitInstalled() then
        note = _("\nBookOrbit plugin not found.")
    elseif not bookOrbitSignedIn() then
        note = _("\nSign in to BookOrbit first.")
    end
    dlg = ButtonDialog:new{
        title = T(_("OrbitShelf Tweaks  %1%2"), VERSION, note),
        buttons = buttons,
    }
    UIManager:show(dlg)
end

local function addToolsMenu()
    local ok, order = pcall(require, "ui/elements/filemanager_menu_order")
    -- Prefer Dispatcher / main menu patch via FileManager menu
    local function inject(menu_items)
        if type(menu_items) ~= "table" then return end
        if menu_items[MENU_ID] then return end
        menu_items[MENU_ID] = {
            text = _("OrbitShelf Tweaks"),
            sorting_hint = "more_tools",
            callback = function() showMenu() end,
        }
    end

    -- FileManager
    local FM = require("apps/filemanager/filemanager")
    if type(FM) == "table" and type(FM.menu_items) == "table" then
        inject(FM.menu_items)
    end
    -- Also catch menu builder
    local okm, Menu = pcall(require, "ui/widget/menu")
    -- Hook FileManager showMainMenu path used by most patches
    local okf, FMmenu = pcall(require, "apps/filemanager/filemanagermenu")
    if okf and type(FMmenu) == "table" and type(FMmenu.setUpdateItemTable) == "function"
            and not FMmenu._orbitshelf_menu then
        FMmenu._orbitshelf_menu = true
        local orig = FMmenu.setUpdateItemTable
        FMmenu.setUpdateItemTable = function(self, ...)
            orig(self, ...)
            if type(self.menu_items) == "table" then inject(self.menu_items) end
        end
    end

    -- Add-ons menu (2-tweaks-menu.lua) if present
    pcall(function()
        local addons = package.loaded["tweaks_menu_addons"]
        if type(addons) == "table" and type(addons.register) == "function" then
            addons.register({
                id = MENU_ID,
                text = _("OrbitShelf Tweaks"),
                group = "library",
                callback = showMenu,
            })
        end
    end)
end

-- ---- Boot -------------------------------------------------------------------------

local function boot(ui)
    addToolsMenu()
    if cfg.use_bookorbit and bookOrbitInstalled() then
        if not registerSource(ui) then
            UIManager:nextTick(function() registerSource(ui) end)
            -- Bookshelf may load after patches
            UIManager:scheduleIn(1, function() registerSource() end)
            UIManager:scheduleIn(3, function() registerSource() end)
        end
    end
    hookHero()
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
