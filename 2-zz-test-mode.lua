--[[
    Test Mode
    Version: 1.0.2

    One switch for trying things out on the device without anything counting:
    open books, turn pages, finish them, and none of it syncs or lands in your
    stats. When you're done, the books you opened go back to how they were.

    While Test Mode is on (and for any book opened during it, until it's reset):
      - ShelfSync: no progress, status, notes or "finished" to StoryGraph,
        Goodreads, Hardcover or the others, and no auto-linking; nothing is
        queued to go out later either.
      - BookOrbit: no progress push or pull, book sync, highlight exchange,
        library sweep or close/sleep sync; nothing queued.
      - KOSync (Progress sync): no push or pull.
      - Statistics: the book is treated as if statistics were off, so no
        reading time, pages or book entry reach statistics.sqlite3. Reading
        Insights and Reading Log read from there, so they don't see it either.
      - ReadMastery (and ReadMastery Quests): no session, XP or quest progress.
      - SimpleUI: the critter doesn't react to the session and the daily
        challenge doesn't count it.
    Everything local still works as normal, so you can test it: the book's
    position, status (finished), highlights and anything else that lives in
    its sidecar, History, and plugins like OrbitShelf's Next In Series.

    Turning it off (or Reset Test Books) offers to put those books back: each
    one's sidecar (position, status, highlights...) is restored to what it was
    before you first opened it in Test Mode, or removed if it had none, and a
    book that wasn't in History before leaves it again. Choose Keep instead
    and they stay as they are and sync normally from then on.

    So you don't forget it's on: a corner note when a book opens, a note at
    start-up, and it turns itself off after 24 hours (the reset stays on offer).

    Menu: with the Debugging Menu patch, at the top of Add-ons -> Debugging
    (1.4.4+); otherwise Tools -> Add-ons -> Test Mode (Maintenance), or Tools
    when the Add-ons patch isn't installed. Gesture: "Toggle Test Mode" (General).

    Named 2-zz- so it loads after every other patch and sits on top of their
    hooks (ReadMastery Quests, ShelfSync Tweaks, BookOrbit Tweaks). Anything it
    can't find to hold back (a plugin update renamed it) is written to crash.log
    at start-up, so a gap never goes unnoticed. No timers.

    Settings: test_mode, test_mode_since, test_mode_books (G_reader_settings).
    Sidecar backups: <koreader>/test-mode/ (removed by the reset).

    Changelog
      1.0.2 2026-11-10  With the Debugging Menu patch (1.4.4+) the Test Mode menu
                        moves to the top of Add-ons -> Debugging and leaves Add-ons
                        -> Maintenance and Tools. Without it, nothing changes.
      1.0.1 2026-11-10  Statistics' and BookOrbit's (and Progress sync's) on... handlers
                        weren't held back: KOReader wraps a plugin's event handlers in
                        a callable table, which 1.0.0 took for "not there" (crash.log:
                        "couldn't find ..."). They're held back now.
      1.0.0 2026-11-10  First version.

    https://github.com/BrownTigerz/-KOReader.patches
]]

local VERSION = "1.0.2"
local ID = "test_mode"
local TAG = "test mode:"
local MAX_AGE = 24 * 3600

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local userpatch = require("userpatch")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")
local T = require("ffi/util").template

local BACKUP_DIR = DataStorage:getDataDir() .. "/test-mode"

local on = G_reader_settings:isTrue("test_mode")
local books = G_reader_settings:readSetting("test_mode_books") or {}
local held = {} -- what was held back this session: label -> count

local function saveBooks()
    if next(books) then
        G_reader_settings:saveSetting("test_mode_books", books)
    else
        G_reader_settings:delSetting("test_mode_books")
    end
end

local function bookCount()
    local n = 0
    for k in pairs(books) do n = n + 1 end
    return n
end

local function note(text)
    pcall(function()
        require("ui/widget/notification"):notify(text)
    end)
end

local function openFile(inst)
    local ui = type(inst) == "table" and inst.ui
    local doc = type(ui) == "table" and ui.document
    if type(doc) ~= "table" then
        local ReaderUI = package.loaded["apps/reader/readerui"]
        local r = type(ReaderUI) == "table" and ReaderUI.instance
        doc = type(r) == "table" and r.document
    end
    return type(doc) == "table" and doc.file or nil
end

-- Test Mode on, or the book in question was opened during it (until reset)
local function testing(inst)
    if on then return true end
    local f = openFile(inst)
    return f ~= nil and books[f] ~= nil
end

---------------------------------------------------------------------------
-- Holding things back
---------------------------------------------------------------------------

local missing = {}

-- KOReader turns a plugin's on* handlers into callable tables (its handler
-- sandbox), so "a function" isn't enough to tell a method is there
local function callable(v)
    if type(v) == "function" then return true end
    local mt = type(v) == "table" and getmetatable(v)
    return type(mt) == "table" and mt.__call ~= nil
end

local ours = setmetatable({}, { __mode = "k" }) -- the wrappers below
local warned = {}

-- Replace cls[name]: while testing, it doesn't run (blocked(self, ...) instead,
-- when given, for callers that wait for an answer). Checked again at every
-- instantiation, so a patch that redefines a method later still gets wrapped.
local function gate(cls, name, label, blocked, optional)
    local orig = cls[name]
    if ours[orig] then return end
    if not callable(orig) then
        if not optional then missing[#missing + 1] = label .. "." .. name end
        return
    end
    local wrapper
    wrapper = function(self, ...)
        if testing(self) then
            held[label] = (held[label] or 0) + 1
            if blocked then return blocked(self, ...) end
            return nil
        end
        return orig(self, ...)
    end
    ours[wrapper] = true
    cls[name] = wrapper
end

local function reportMissing(label)
    if #missing > 0 then
        local text = label .. ": couldn't find " .. table.concat(missing, ", ")
            .. " - not held back in Test Mode (plugin changed?)"
        if not warned[text] then
            warned[text] = true
            logger.warn(TAG, text)
        end
        missing = {}
    end
end

-- at every instantiation of the plugin (gate() skips what's already wrapped)
local function once(plugin, fn, label)
    if type(plugin) ~= "table" then return end
    local ok, err = pcall(fn, plugin)
    if not ok then logger.warn(TAG, label .. " hooks failed:", err) end
    reportMissing(label)
end

-- Statistics: the book opens as if statistics were off (no book row, no page
-- times); nothing is written while testing.
userpatch.registerPatchPluginFunc("statistics", function(plugin)
    once(plugin, function(cls)
        local orig_ready = cls.onReaderReady
        if ours[orig_ready] then
            -- already wrapped
        elseif not callable(orig_ready) then
            missing[#missing + 1] = "Statistics.onReaderReady"
        else
            local wrapper
            wrapper = function(self, ...)
                if testing(self) and type(self.settings) == "table" then
                    held.Statistics = (held.Statistics or 0) + 1
                    self._test_mode = true
                    local was = self.settings.is_enabled
                    self.settings.is_enabled = false
                    local ok, ret = pcall(orig_ready, self, ...)
                    self.settings.is_enabled = was
                    self.is_doc_not_frozen = false
                    if not ok then logger.warn(TAG, "statistics ready:", ret) end
                    return ret
                end
                return orig_ready(self, ...)
            end
            ours[wrapper] = true
            cls.onReaderReady = wrapper
        end
        for i, name in ipairs({ "insertDB", "onPageUpdate", "onPosUpdate", "onAnnotationsModified",
                "onBookMetadataChanged" }) do
            local orig = cls[name]
            if ours[orig] then
                -- already wrapped
            elseif not callable(orig) then
                missing[#missing + 1] = "Statistics." .. name
            else
                local wrapper = function(self, ...)
                    if self._test_mode or testing(self) then return nil end
                    return orig(self, ...)
                end
                ours[wrapper] = true
                cls[name] = wrapper
            end
        end
    end, "Statistics")
end)

-- KOSync (Progress sync)
userpatch.registerPatchPluginFunc("kosync", function(plugin)
    once(plugin, function(cls)
        for i, name in ipairs({ "onReaderReady", "updateProgress", "getProgress", "_onCloseDocument",
                "_onPageUpdate", "onKOSyncPushProgress", "onKOSyncPullProgress" }) do
            gate(cls, name, "KOSync")
        end
    end, "KOSync")
end)

-- ShelfSync: every provider's engine (StoryGraph, Goodreads, Hardcover, ...)
local function shelfsyncAnswer(cb_index)
    return function(self, ...)
        local cb = select(cb_index, ...)
        if type(cb) == "function" then pcall(cb, nil, _("Test Mode")) end
        return nil
    end
end

userpatch.registerPatchPluginFunc("shelfsync", function(plugin)
    once(plugin, function()
        local ok, SyncEngine = pcall(require, "shelfsync/lib/common/sync_engine")
        if not ok or type(SyncEngine) ~= "table" then
            missing[#missing + 1] = "shelfsync/lib/common/sync_engine"
            return
        end
        -- (onSuspend is left alone: it only cancels what's waiting)
        for i, name in ipairs({ "onReaderReady", "onPageUpdate", "onPosUpdate", "onUpdatePos",
                "onDocumentClose", "onEndOfBook", "onNote", "onPullPosition",
                "_queueClosingProgress", "startReadCache" }) do
            gate(SyncEngine, name, "ShelfSync")
        end
        gate(SyncEngine, "onUpdateProgress", "ShelfSync", shelfsyncAnswer(1))   -- (cb, ...)
        gate(SyncEngine, "updatePageNow", "ShelfSync", shelfsyncAnswer(1))      -- (cb, value, type)
        gate(SyncEngine, "_saveBookStatus", "ShelfSync", shelfsyncAnswer(3))    -- (file, status, cb)
        gate(SyncEngine, "_handlePageUpdate", "ShelfSync", shelfsyncAnswer(4))  -- (file, value, now, cb)
        -- a status changed from the file browser (Bookshelf's book menu): that
        -- book's own test state decides, or Test Mode itself
        local orig = SyncEngine.onDocSettingsItemsChanged
        if ours[orig] then
            -- already wrapped
        elseif not callable(orig) then
            missing[#missing + 1] = "ShelfSync.onDocSettingsItemsChanged"
        else
            local wrapper = function(self, file, ...)
                if on or (file and books[file]) then
                    held.ShelfSync = (held.ShelfSync or 0) + 1
                    return nil
                end
                return orig(self, file, ...)
            end
            ours[wrapper] = true
            SyncEngine.onDocSettingsItemsChanged = wrapper
        end
        -- the manual actions (gestures, ShelfSync Tweaks' Link & Update / Sync All):
        -- a note instead, and no Wi-Fi switched on for nothing
        local function manual()
            note(_("Test Mode: ShelfSync held back"))
            return true
        end
        gate(plugin, "onShelfSyncUpdateAllProgress", "ShelfSync", manual)
        for i, name in ipairs({ "onShelfSyncAllUpdateProgress", "onShelfSyncHub", "onShelfSyncHubLink",
                "onShelfSyncHubStatus" }) do
            gate(plugin, name, "ShelfSync", manual, true)
        end
    end, "ShelfSync")
end)

-- BookOrbit
userpatch.registerPatchPluginFunc("bookorbit", function(plugin)
    once(plugin, function(cls)
        for i, name in ipairs({ "onReaderReady", "_onCloseDocument", "_onPageUpdate", "_onSuspend",
                "_onNetworkDisconnecting", "enqueueLifecycleSnapshot", "requestProgressPush",
                "requestProgressPull", "requestAnnotationExchange", "scheduleOpenAnnotationSync",
                "exchangeAnnotationsForOpenBook", "requestOpenBookMatch", "requestManualBookSync",
                "requestSweep", "updateProgress", "getProgress", "onBookOrbitSyncBook",
                "onBookOrbitPushProgress", "onBookOrbitPullProgress", "onBookOrbitSyncNow" }) do
            gate(cls, name, "BookOrbit")
        end
        -- book sync started from anywhere else (OrbitShelf's Sync, the Side Panel)
        local okS, BookSync = pcall(require, "bookorbit_book_sync")
        if okS and type(BookSync) == "table" and ours[BookSync.run] then
            -- already wrapped
        elseif okS and type(BookSync) == "table" and callable(BookSync.run) then
            local orig = BookSync.run
            local wrapper
            wrapper = function(opts, ...)
                if testing(nil) then
                    held.BookOrbit = (held.BookOrbit or 0) + 1
                    if type(opts) == "table" and opts.interactive then note(_("Test Mode: BookOrbit sync held back")) end
                    return false
                end
                return orig(opts, ...)
            end
            ours[wrapper] = true
            BookSync.run = wrapper
        else
            missing[#missing + 1] = "bookorbit_book_sync.run"
        end
    end, "BookOrbit")
end)

-- ReadMastery (+ ReadMastery Quests, which wraps the same handlers)
local function readmastery(plugin)
    once(plugin, function(cls)
        for i, name in ipairs({ "onReaderReady", "onPageUpdate", "onCloseDocument" }) do
            gate(cls, name, "ReadMastery")
        end
        gate(cls, "onEndOfBook", "ReadMastery", nil, true)
    end, "ReadMastery")
end
userpatch.registerPatchPluginFunc("ReadMastery", readmastery)
userpatch.registerPatchPluginFunc("readmastery", readmastery)

-- SimpleUI: no critter reaction / daily challenge from a test session
userpatch.registerPatchPluginFunc("simpleui", function(plugin)
    once(plugin, function(cls)
        gate(cls, "_recordCritterReactions", "SimpleUI", function(self)
            self._critter_session = nil
            return nil
        end)
    end, "SimpleUI")
end)

---------------------------------------------------------------------------
-- Test books: what each looked like before, and putting it back
---------------------------------------------------------------------------

local function readAll(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function writeAll(path, s)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(s)
    f:close()
    return true
end

local function snapshot(file)
    if books[file] then return end
    local rec = { at = os.time() }
    pcall(function()
        local DocSettings = require("docsettings")
        local sidecar = DocSettings:findSidecarFile(file)
        if sidecar then
            local data = readAll(sidecar)
            if data then
                if lfs.attributes(BACKUP_DIR, "mode") ~= "directory" then lfs.mkdir(BACKUP_DIR) end
                local backup = BACKUP_DIR .. "/" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999)) .. ".lua"
                if writeAll(backup, data) then
                    rec.sidecar, rec.backup = sidecar, backup
                end
            end
        end
    end)
    pcall(function()
        rec.history = require("readhistory"):getIndexByFile(file) ~= nil
    end)
    books[file] = rec
    saveBooks()
end

local function bookOpen()
    local ReaderUI = package.loaded["apps/reader/readerui"]
    return type(ReaderUI) == "table" and ReaderUI.instance ~= nil
end

local function resetBooks()
    if bookOpen() then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("Close the book first.") })
        return
    end
    local DocSettings = require("docsettings")
    local ok_n, failed = 0, {}
    for file, rec in pairs(books) do
        local ok, err = pcall(function()
            if rec.sidecar and rec.backup then
                local data = readAll(rec.backup)
                if not data or not writeAll(rec.sidecar, data) then error("couldn't restore " .. rec.sidecar) end
                -- a sidecar written somewhere else meanwhile (another location) goes
                local now_at = DocSettings:findSidecarFile(file)
                if now_at and now_at ~= rec.sidecar then os.remove(now_at) end
                os.remove(rec.backup)
            else
                local ds = DocSettings:open(file)
                ds:purge(nil, { doc_settings = true })
            end
            if rec.history == false then
                require("readhistory"):removeItemByPath(file)
            end
        end)
        if ok then
            ok_n = ok_n + 1
        else
            failed[#failed + 1] = (file:match("([^/]+)$") or file) .. ": " .. tostring(err)
            logger.warn(TAG, "reset failed for", file, err)
        end
    end
    books = {}
    saveBooks()
    pcall(function()
        local FileManager = require("apps/filemanager/filemanager")
        if FileManager.instance then FileManager.instance:onRefresh() end
    end)
    if #failed == 0 then
        note(ok_n == 1 and _("Test Mode: 1 book reset") or T(_("Test Mode: %1 books reset"), ok_n))
    else
        UIManager:show(require("ui/widget/infomessage"):new{
            text = T(_("Reset %1 books. These couldn't be reset:\n%2"), ok_n, table.concat(failed, "\n")),
        })
    end
end

local function keepBooks()
    for file, rec in pairs(books) do
        if rec.backup then os.remove(rec.backup) end
    end
    books = {}
    saveBooks()
end

local function offerReset(head)
    local n = bookCount()
    if n == 0 then return end
    UIManager:show(require("ui/widget/confirmbox"):new{
        text = (head and (head .. "\n\n") or "")
            .. (n == 1 and _("Reset the book you opened while testing?") or T(_("Reset the %1 books you opened while testing?"), n))
            .. "\n\n" .. _("Reset puts their position, status and highlights back to before testing.\nKeep leaves them as they are; they sync normally again from now on."),
        ok_text = _("Reset"),
        cancel_text = _("Keep"),
        ok_callback = resetBooks,
        cancel_callback = keepBooks,
    })
end

---------------------------------------------------------------------------
-- On / off
---------------------------------------------------------------------------

local function setOn(value)
    on = value and true or false
    if on then
        G_reader_settings:saveSetting("test_mode", true)
        G_reader_settings:saveSetting("test_mode_since", os.time())
        -- the book open now becomes a test book too
        local f = openFile(nil)
        if f then snapshot(f) end
        note(_("Test Mode on: nothing syncs or counts"))
    else
        G_reader_settings:delSetting("test_mode")
        G_reader_settings:delSetting("test_mode_since")
        note(_("Test Mode off"))
        if not bookOpen() then
            offerReset()
        end
    end
end

local function toggle()
    setOn(not on)
end

-- start-up: turned itself off after 24 h; otherwise say it's still on
do
    local since = G_reader_settings:readSetting("test_mode_since")
    if on and type(since) == "number" and os.time() - since > MAX_AGE then
        on = false
        G_reader_settings:delSetting("test_mode")
        G_reader_settings:delSetting("test_mode_since")
        logger.info(TAG, "turned off after 24 h")
        UIManager:nextTick(function()
            if bookCount() > 0 and not bookOpen() then
                offerReset(_("Test Mode turned itself off after 24 hours."))
            else
                note(_("Test Mode turned itself off after 24 hours"))
            end
        end)
    elseif on then
        UIManager:nextTick(function() note(_("Test Mode is on: nothing syncs or counts")) end)
    end
end

-- every book opened while it's on: remember how it was; a note in the corner
do
    local ReaderUI = require("apps/reader/readerui")
    local orig_init = ReaderUI.init
    ReaderUI.init = function(self, ...)
        local file = type(self.document) == "table" and self.document.file
        if on and file then pcall(snapshot, file) end
        local ret = orig_init(self, ...)
        if file and (on or books[file]) then
            UIManager:nextTick(function() note(_("Test Mode: nothing syncs or counts")) end)
        end
        return ret
    end
end

---------------------------------------------------------------------------
-- Gesture and menu
---------------------------------------------------------------------------

pcall(function()
    local Dispatcher = require("dispatcher")
    Dispatcher:registerAction("test_mode_toggle", {
        category = "none", event = "ToggleTestMode", title = _("Toggle Test Mode"), general = true,
    })
end)
for i, path in ipairs({ "apps/filemanager/filemanager", "apps/reader/readerui" }) do
    local ok, M = pcall(require, path)
    if ok and type(M) == "table" then
        M.onToggleTestMode = function()
            toggle()
            return true
        end
    end
end

local function heldText()
    local parts = {}
    for label, n in pairs(held) do parts[#parts + 1] = label .. " " .. n end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or _("nothing yet")
end

local function item()
    return {
        text = _("Test Mode"),
        sub_item_table_func = function()
            return {
                {
                    text = _("Test Mode"),
                    help_text = _("While on: ShelfSync, BookOrbit and Progress sync send nothing, and Statistics, ReadMastery and the SimpleUI critter don't count anything, for every book you open. Everything on the device still works so you can test it. Turns itself off after 24 hours."),
                    checked_func = function() return on end,
                    callback = function() toggle() end,
                },
                {
                    text_func = function()
                        local n = bookCount()
                        return n == 0 and _("Reset Test Books") or T(_("Reset Test Books (%1)"), n)
                    end,
                    enabled_func = function() return bookCount() > 0 and not bookOpen() end,
                    help_text = _("Puts the books you opened while testing back to how they were before: position, status, highlights. Books that weren't in History leave it."),
                    keep_menu_open = true,
                    callback = function() offerReset() end,
                },
                {
                    text_func = function() return T(_("Held back this session: %1"), heldText()) end,
                    enabled_func = function() return false end,
                },
                {
                    text = T(_("Version %1"), VERSION),
                    enabled_func = function() return false end,
                    separator = true,
                },
            }
        end,
    }
end

-- With the Debugging Menu patch (1.4.4+), the menu lives there, at the top; it
-- loads before this one (2-debugging-menu.lua). Otherwise: Add-ons entry
-- (2-tweaks-menu.lua), or the Tools menu.
package.loaded.test_mode_menu = item
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
local in_debugging = type(TM.entries.debugging_menu) == "table"
    and TM.entries.debugging_menu.test_mode_home == true
if not in_debugging then
    TM.entries[ID] = { text = _("Test Mode"), order = 960, group = "Maintenance", build = item }
end

-- Fallback: Tools menu when the Add-ons patch isn't there (or hides it)
local function addToOrder(order_mod)
    local ok, order = pcall(require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for i, v in ipairs(order.tools) do if v == ID then return end end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then
            pos = i
            break
        end
    end
    table.insert(order.tools, pos, ID)
end

for i, pair in ipairs({
    { "apps/filemanager/filemanagermenu", "ui/elements/filemanager_menu_order" },
    { "apps/reader/modules/readermenu", "ui/elements/reader_menu_order" },
}) do
    local ok, M = pcall(require, pair[1])
    if not in_debugging and ok and type(M) == "table" and type(M.setUpdateItemTable) == "function" then
        local orig = M.setUpdateItemTable
        M.setUpdateItemTable = function(self, ...)
            local in_addons = TM.active and (type(TM.shows) ~= "function" or TM.shows(ID))
            if self.menu_items and not in_addons then
                addToOrder(pair[2])
                local m = item()
                m.sorting_hint = "tools"
                self.menu_items[ID] = m
            end
            return orig(self, ...)
        end
    end
end

logger.info(TAG, VERSION .. " loaded" .. (on and " (ON)" or "") .. ", test books: " .. bookCount())
