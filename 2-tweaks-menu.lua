--[[
2-tweaks-menu.lua
KOReader user patch: one "Add-ons" menu under Tools, for plugins and patches.

Version: 1.1.2

  Tools > Add-ons   your plugins and your patches' settings in one list,
                    grouped: each patch sits with the plugin it tweaks
                    (SimpleUI Tweaks under Home & Library, BookOrbit Tweaks
                    under Sync & Network...), Patch Backup & Restore next
                    to Device Backup & Restore in System, and Check For
                    Patch Updates, Debugging and Screenshot under
                    Maintenance.

Moved plugins work exactly the same, they're just shown here instead of their
usual spot.

Newly installed plugins and patches (anything that adds a menu) show up
automatically (AUTO_COLLECT), marked "New", with a one-time notice. A patch
that says where it belongs goes in that group, otherwise under Patches; a
new plugin goes under Other. "New Add-ons Show Up Automatically" off: they're
listed unticked instead, for you to choose.

"Arrange Add-ons" (bottom of the list):
  - tap an item to turn it on or off (off puts it back where it originally was)
  - hold an item: move it up or down, to the top or bottom, or to another group
  - tap a group name: move the group up or down, rename it, or delete it
    (groups you added)
  - Add Group: your own group header, then hold items to move them in
  - Sort Items: Custom (your order) or A To Z (inside each group)
  - Reset Layout: groups, names and order back to the defaults
  - Reset Everything To Default: also turns every item back on, as on a
    fresh install
  - Put Tweaks Inside Their Plugin (on): SimpleUI Tweaks and SimpleUI Side
    Panel inside Simple UI, BookOrbit Tweaks inside BookOrbit, Reading
    Insights Tweaks inside Reading Insights, Reading Log Tweaks inside
    Reading Log (COMBINE below)
  Changes apply after a restart.

KOReader's menu order stays untouched: each menu build works on a copy, so
delete this file and restart, and every menu goes back where it was. Only your
Add-ons choices are saved (in settings.reader.lua). An id that doesn't exist
(not installed, renamed by an update) is skipped. Items hidden with a
menu-order file / Menu Disabler ("KOMenu:disabled") stay hidden. A built-in
submenu left empty by moving all its items out is hidden.

Install: koreader/patches/2-tweaks-menu.lua (Kobo: .adds/koreader/patches/), then restart.

Versioning: 1.0.x fixes (e.g. a KOReader or plugin menu id rename),
            1.x.0 new features, 2.0.0 changes to how saved Add-ons choices work.

Changelog:
  1.1.2  2026-10-30  Fix: Simple UI, BookOrbit, Reading Insights and their
                     tweaks also showed in Tools (and the tweaks as "NEW:
                     ..." in the first tab), and a patch's own Tools copy
                     stayed in Tools. KOReader puts back whatever no menu
                     list places, so those now leave its list too.
                     Reading Log Tweaks goes inside Reading Log; Patch
                     Backup & Restore moves to System next to Device Backup
                     & Restore; ReadMastery is off by default (stays in
                     Tools until you tick it).
  1.1.1  2026-10-30  Tweaks inside their plugin: Simple UI becomes one entry
                     (Open Simple UI, SimpleUI Tweaks, SimpleUI Side Panel),
                     BookOrbit Tweaks goes at the bottom of BookOrbit's menu,
                     Reading Insights Tweaks inside Reading Insights. The
                     plugins' own menus aren't changed. "Put Tweaks Inside
                     Their Plugin" in Arrange Add-ons turns it off; moving a
                     patch to another group takes it out.
  1.1.0  2026-10-30  Layout: patches sit with the plugin they tweak, and
                     Debugging, Check For Patch Updates, Patch Backup &
                     Restore and Screenshot get their own Maintenance group.
                     "Choose what's in Add-ons" is now "Arrange Add-ons":
                     move items up/down/top/bottom or to another group, add,
                     rename, reorder and delete group headers, sort each
                     group by Custom order or A To Z, Reset Layout, and
                     Reset Everything To Default. New add-ons now show up
                     ticked (switchable). Registry entries can name their
                     group (group = "..."). A patch that also adds its own
                     copy to Tools has that copy moved out too.
  1.0.0  2026-10-02  First release.
  1.0.1  2026-10-02  "New" tags clear per menu (reader-only add-ons keep theirs);
                     group lists tracked per menu; labels computed once when
                     sorting; full traceback in crash.log on sort errors;
                     version logged on startup and exposed as TM.version.
  1.0.2  2026-10-09  A patch entry with a bad label or order can no longer
                     turn off the whole Add-ons menu; a patch entry whose menu
                     fails to build stays in "Choose what's in Add-ons" (marked
                     Error) so you can turn it off; patch entries that only
                     set text_func no longer show as "nil" in the chooser.
  1.0.3  2026-10-11  Shared notification contract v1: status notes (new add-on
                     notices, the restart reminder fallback) first try Network
                     Tweaks' then ReadMastery's notification style, falling
                     back to this patch's own; nothing is shown over the sleep
                     screen. Menus and dialogs untouched.
  1.0.4  2026-10-11  Title case for menu texts: group headers, the chooser
                     entry and its rows, and toggle-row labels now capitalize
                     the first letter of every word (rest of each word
                     preserved, so SimpleUI/X-Ray/Wi-Fi are unchanged).
                     Notification, toast, and dialog strings untouched; moved
                     plugin items keep their own text.
  1.0.7  2026-10-27  Wording only (TK-approved review): chooser header
                     "Tap: in or out" -> "Tap to turn on or off"; header
                     "are found automatically" -> "get picked up
                     automatically", "menu order is never modified" ->
                     "menu order stays untouched"; notification "New
                     add-on(s)" -> "New add-on". No behavior change.
  1.0.6  2026-10-23  New "Check For Patch Updates" entry in Patches (below
                     Debugging, order 950), shown only when Backup Patches
                     is installed; invokes Backup's updater global directly.
  1.0.5  2026-10-21  Crash fix: a plugin whose sorting_hint points at a menu
                     that isn't shown (e.g. kobo.koplugin's "Kobo Library" ->
                     File browser settings, with that tab hidden) crashed
                     KOReader's menu build on opening the menu. Such entries
                     now land in Tools (or the first tab) instead.
]]

local PATCH_VERSION = "1.1.2"

-- ---- Settings ---------------------------------------------------------------------
local MENU_TEXT    = "Add-ons"   -- name shown in Tools
local SHOW_HEADERS = true        -- group names above each group (false = separators only)
local AUTO_COLLECT = true        -- find add-ons not listed below (new installs) and
                                 -- offer them in "Choose what's in Add-ons"
local NEW_GO_IN    = true        -- true: newly found add-ons go straight into
                                 -- Add-ons; false: listed unticked, you choose
                                 -- (Arrange Add-ons can switch this)

-- Default groups, shown in this order (Arrange Add-ons can reorder, rename
-- and add to them without editing this file). An id is the key a plugin uses
-- in addToMainMenu (menu_items.<id>), a built-in id from KOReader's
-- frontend/ui/elements/*_menu_order.lua, or "patch:<id>" for a patch that
-- registers below (package.loaded.tweaks_mods). Ids that aren't installed are
-- skipped.
local PLUGINS = {
    { header = "Home & Library",
        "simpleui",                     -- SimpleUI
        "patch:simpleui_mod",           -- SimpleUI Tweaks
        "patch:simpleui_sidepanel",     -- SimpleUI Side Panel
        "bookshelf_tab",                -- Bookshelf (its whole menu tab moves here)
        "shortcutstoolbar",             -- Shortcuts Toolbar (+ Quick Shelf, Icon Tweaks)
    },
    { header = "Reading",
        "xray",                         -- X-Ray
        "page_scrubber",                -- Page Scrubber
        "glimpse",                      -- Glimpse
        "foot_cream",                   -- Footcream
        "go_to_furthest_reading_location", -- Track Reading Location (reader only)
    },
    { header = "Stats & Progress",
        "readmastery",                  -- ReadMastery (off by default, see DEFAULT_OFF)
        "reading_insights_popup",       -- Reading Insights
        "patch:ri_tweaks",              -- Reading Insights Tweaks
        "readinglog",                   -- Reading Log
        "patch:readinglog_tweaks",      -- Reading Log Tweaks
        "bookcard",                     -- Book Card
    },
    { header = "Sync & Network",
        "shelfsync",                    -- ShelfSync (+ ShelfSync Tweaks)
        "bookorbit",                    -- BookOrbit
        "patch:bookorbit_tweaks",       -- BookOrbit Tweaks
        "patch:network_tweaks",         -- Network Tweaks
    },
    { header = "System",
        "Storefront",                   -- Storefront
        "backup",                       -- Device Backup & Restore
        "backup_patches",               -- Patch Backup & Restore
        "menu_disabler",                -- Menu Disabler (Menu customizer)
    },
    { header = "Maintenance",
        "patch:check_patch_updates",    -- Check For Patch Updates
        "patch:debugging_menu",         -- Debugging
        "patch:screenshot_timer",       -- Screenshot in 10 s
    },
}

-- A plugin and the patches that tweak it, shown as one entry: the plugin's
-- own menu with the patches' settings at the bottom (a plugin that's just a
-- button gets an "Open ..." row first). Only while both are shown and the
-- patch hasn't been moved to another group; "Put Tweaks Inside Their Plugin"
-- in Arrange Add-ons turns it off.
local COMBINE = {
    simpleui               = { "patch:simpleui_mod", "patch:simpleui_sidepanel" },
    bookorbit              = { "patch:bookorbit_tweaks" },
    reading_insights_popup = { "patch:ri_tweaks" },
    readinglog             = { "patch:readinglog_tweaks" },
}

-- Listed in a group above but left in their usual spot until you tick them
-- in Arrange Add-ons (Reset Everything To Default puts them back out).
local DEFAULT_OFF = {
    readmastery = true,
}

-- Top-level menus that patches add without registering (ids KOReader would
-- otherwise see as new plugins). Placed by PLUGINS above when listed there,
-- otherwise under "Patches".
local PATCH_MENUS = {
    "go_to_furthest_reading_location", -- Track Reading Location (reader only)
}

--[[ For patch authors - shared registry at package.loaded.tweaks_mods:
    local TM = package.loaded.tweaks_mods or {}
    package.loaded.tweaks_mods = TM
    TM.entries = TM.entries or {}
    TM.entries.my_id = {
        text  = "My Patch",              -- fallback label
        order = 100,                      -- optional, lower = higher up (ties sort by name)
        where = "filemanager",            -- optional: "filemanager" or "reader" only (default: both)
        group = "Reading",                -- optional: default group (a header above); else "Patches"
        build = function(where) return { text = "My Patch", sub_item_table = {...} } end,
    }
  Entries listed in PLUGINS as "patch:<id>" go there; others go in their
  group, or under "Patches". build() runs every time the menu is
  built, so keep it cheap: return an item with sub_item_table_func to build the
  submenu only when it's opened.
  TM.shows(id) is false when the user turned your entry off in "Choose what's in
  Add-ons": show your own menu entry then, as if this patch weren't installed.
  TM.active is true once this patch has loaded. Check it inside your own menu hook
  (menu build time), not at load time, so patch file order doesn't matter.
  TM.version is this patch's version string.
]]

local logger = require("logger")
local _ = require("gettext")

local MENU_ID    = "tweaks_mods"             -- kept for compatibility with other patches
local ENTRY_ID   = MENU_ID .. ":"            -- prefix for rows we create
local SEPARATOR  = "----------------------------"
local TAG        = "tweaks-menu:"

-- shared registry (other patches may have created it already)
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.active  = true
TM.menu_id = MENU_ID
TM.version = PATCH_VERSION

logger.info(TAG, "v" .. PATCH_VERSION .. " loaded")

-- "Check for Patch Updates" entry (Backup Patches updater): shows in Patches
-- below the Debug Menu entry, only when Backup's updater global is available.
-- (2-backup-patches.lua loads before this file and sets the global at load.)
do
    local fn = _G.__backup_patches_check_updates
    if type(fn) == "function" then
        TM.entries.check_patch_updates = {
            text = "Check For Patch Updates",
            order = 950,  -- below Debugging (900)
            where = "filemanager",
            build = function()
                return {
                    text = "Check For Patch Updates",
                    callback = function()
                        local f = _G.__backup_patches_check_updates
                        if type(f) == "function" then f() end
                    end,
                }
            end,
        }
    end
end

-- Items turned off in "Choose what's in Add-ons" (kept in their original spot).
-- Plugins by menu id, patches as "patch:<id>".
local SETTINGS_KEY = "addons_menu_excluded"
local excluded = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY) or {}

-- excluded[key]: true = turned off, false = turned on (a DEFAULT_OFF item),
-- nil = its default.
local function isOff(key)
    local v = excluded[key]
    if v == nil then return DEFAULT_OFF[key] == true end
    return v == true
end
local function setOff(key, off)
    if off then excluded[key] = true
    elseif DEFAULT_OFF[key] then excluded[key] = false
    else excluded[key] = nil end
end

-- Group chosen in "Choose what's in Add-ons" (hold an item): [key] = group name.
local GROUPS_KEY = "addons_menu_groups"
local group_of = G_reader_settings and G_reader_settings:readSetting(GROUPS_KEY) or {}

-- Add-ons found so far ([id] = true), and ones not yet seen in the chooser.
local KNOWN_KEY, NEW_KEY = "addons_menu_known", "addons_menu_new"
local known_ids = G_reader_settings and G_reader_settings:readSetting(KNOWN_KEY)
local new_ids = G_reader_settings and G_reader_settings:readSetting(NEW_KEY) or {}

-- KOReader's own menu ids, read from its files on disk, so ids other patches
-- added to the menu order at load time don't count as built in.
local stock_cache = {}
local function stockIds(where)
    if stock_cache[where] ~= nil then return stock_cache[where] end
    local ids = false
    local chunk = loadfile("frontend/ui/elements/" .. where .. "_menu_order.lua")
    if chunk then
        local ok, order = pcall(chunk)
        if ok and type(order) == "table" then
            ids = {}
            for k, l in pairs(order) do
                ids[k] = true
                if type(l) == "table" then
                    for _i, v in ipairs(l) do ids[v] = true end
                end
            end
        end
    end
    stock_cache[where] = ids
    return ids
end

function TM.shows(id)
    return not isOff("patch:" .. tostring(id))
end

-- What the last menu build found, per menu ("filemanager" / "reader"), for
-- Arrange Add-ons: seen[where] = { { key, id, label, default, broken }, ... }.
local seen = {}

local function pack(...) return { n = select("#", ...), ... } end

-- Menu items use title case: the first letter of every word capitalized
-- ("clear crash.log" -> "Clear Crash.log"). The rest of each word is
-- preserved, so SimpleUI, X-Ray, Wi-Fi and the like survive unchanged.
local function titlecase(s)
    return (s:gsub("%S+", function(w)
        local i = w:find("%a")
        if i and w:sub(i, i):match("%l") then
            return w:sub(1, i - 1) .. w:sub(i, i):upper() .. w:sub(i + 1)
        end
        return w
    end))
end

-- Shared notification contract v1: user-facing status notes first try the
-- installed patches' styles (Network Tweaks, then ReadMastery notify),
-- falling back to this patch's own default at each call site. Checked at
-- call time, so patch load order doesn't matter. Returns true when the note
-- was handled (or deliberately hidden, e.g. over the sleep screen).
local function shared_note(banner_text, minimal_text, timeout)
    local okd, Device = pcall(require, "device")
    if okd and Device.screen_saver_mode then return true end -- never over the sleep screen
    local okn, NetworkMgr = pcall(require, "ui/network/manager")
    if okn and type(NetworkMgr) == "table"
        and type(NetworkMgr.__network_tweaks_note) == "function" then
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

-- ---- Layout ("Arrange Add-ons") ------------------------------------------------------
-- Everything here is optional; missing fields mean the defaults above.
--   order  = { group id, ... }               group order
--   custom = { group id, ... }               groups you added
--   names  = { [group id] = shown name }     renamed groups
--   items  = { [group id] = { key, ... } }   item order (Custom sort)
--   sort   = "custom" | "alpha"
--   auto   = true | false                    new add-ons show up ticked
-- A group id is its default header (or the name you gave a new group), so
-- the group choices in addons_menu_groups keep working across renames.
local LAYOUT_KEY = "addons_menu_layout"
local layout = G_reader_settings and G_reader_settings:readSetting(LAYOUT_KEY) or {}
if type(layout) ~= "table" then layout = {} end

local function list(field)
    if type(layout[field]) ~= "table" then layout[field] = {} end
    return layout[field]
end
local function groupName(id)
    local n = type(layout.names) == "table" and layout.names[id]
    return (type(n) == "string" and n ~= "") and n or id
end
local function alphaSort() return layout.sort == "alpha" end
local function newGoIn()
    if layout.auto == nil then return NEW_GO_IN end
    return layout.auto == true
end
local function combineOn() return layout.combine ~= false end

-- Which patches go inside which plugin right now: { [plugin key] = { cand, ... } },
-- and { [patch key] = plugin cand }. Both have to be on and not broken, and
-- the patch still in its default group.
local function combinations(cands)
    local hosts, inside = {}, {}
    if not combineOn() then return hosts, inside end
    local by_key = {}
    for _i, c in ipairs(cands) do by_key[c.key] = c end
    for host_key, kids in pairs(COMBINE) do
        local h = by_key[host_key]
        if h and not isOff(h.key) and not h.broken then
            for _i, k in ipairs(kids) do
                local c = by_key[k]
                if c and not isOff(c.key) and not c.broken and group_of[c.key] == nil then
                    hosts[h.key] = hosts[h.key] or {}
                    table.insert(hosts[h.key], c)
                    inside[c.key] = h
                end
            end
        end
    end
    return hosts, inside
end

local function isCustom(id)
    for _i, g in ipairs(list("custom")) do if g == id then return true end end
    return false
end

local OTHER, PATCHES = _("Other"), _("Patches")
local DEFAULT_GROUPS = {}
do
    local known = {}
    for _i, g in ipairs(PLUGINS) do
        if g.header and not known[g.header] then DEFAULT_GROUPS[#DEFAULT_GROUPS + 1] = g.header; known[g.header] = true end
    end
    for _i, n in ipairs({ OTHER, PATCHES }) do
        if not known[n] then DEFAULT_GROUPS[#DEFAULT_GROUPS + 1] = n; known[n] = true end
    end
end

-- Every group in display order (saved order first, then the rest), plus a
-- set of them.
local function groupOrder()
    local exists = {}
    for _i, g in ipairs(DEFAULT_GROUPS) do exists[g] = true end
    for _i, g in ipairs(list("custom")) do exists[g] = true end
    local all, known = {}, {}
    local function push(g)
        if exists[g] and not known[g] then known[g] = true; all[#all + 1] = g end
    end
    for _i, g in ipairs(list("order")) do push(g) end
    for _i, g in ipairs(DEFAULT_GROUPS) do push(g) end
    for _i, g in ipairs(list("custom")) do push(g) end
    return all, known
end

-- Candidates { key, id, label, default, broken } -> { { id = group, items = {...} }, ... }
-- in display order. A group's own items come first, then ones moved into it;
-- Custom sort then applies your saved order, A To Z sorts by name.
local function arrange(cands)
    local order, known = groupOrder()
    local buckets = {}
    for pass = 1, 2 do
        for _i, c in ipairs(cands) do
            local g = group_of[c.key]
            local default = known[c.default] and c.default or PATCHES
            c.group = (g and known[g]) and g or default
            if (pass == 1) == (c.group == default) then
                buckets[c.group] = buckets[c.group] or {}
                table.insert(buckets[c.group], c)
            end
        end
    end
    local out = {}
    for _i, g in ipairs(order) do
        local items = buckets[g] or {}
        for i, c in ipairs(items) do c._pos = i end
        if alphaSort() then
            table.sort(items, function(x, y)
                local lx, ly = x.label:lower(), y.label:lower()
                if lx ~= ly then return lx < ly end
                return x._pos < y._pos
            end)
        else
            local saved = type(layout.items) == "table" and layout.items[g]
            if type(saved) == "table" and #saved > 0 then
                local rank = {}
                for i, k in ipairs(saved) do rank[k] = i end
                table.sort(items, function(x, y)
                    return (rank[x.key] or 10000 + x._pos) < (rank[y.key] or 10000 + y._pos)
                end)
            end
        end
        out[#out + 1] = { id = g, items = items }
    end
    return out
end

-- KOReader builds its main menu once per file browser / book and can't safely
-- rebuild it in place (the base entries are used up by the first build), so a
-- change applies after a restart.
local function askRestart()
    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager) ~= "table" then return end
    if UIManager.askForRestart then
        UIManager:askForRestart(_("Restart KOReader to apply your Add-ons choices."))
    else
        local okm, InfoMessage = pcall(require, "ui/widget/infomessage")
        if okm then
            if not shared_note(_("Restart KOReader to apply."), _("Restart to apply")) then
                UIManager:show(InfoMessage:new{ text = _("Restart KOReader to apply.") })
            end
        end
    end
end

local restart_asked = false   -- one prompt per visit to Arrange Add-ons

local function saveAndAsk(key, value, no_restart)
    if G_reader_settings then
        G_reader_settings:saveSetting(key, value)
        if G_reader_settings.flush then G_reader_settings:flush() end
    end
    if not restart_asked and not no_restart then
        restart_asked = true
        askRestart()
    end
end
local function saveLayout(no_restart) saveAndAsk(LAYOUT_KEY, layout, no_restart) end

local chooserItems   -- defined below; the dialogs refresh the open list with it

-- Rebuilds the open Arrange Add-ons list in place after a change.
local function refresh(where, touchmenu)
    if type(touchmenu) ~= "table" or type(touchmenu.item_table) ~= "table" then return end
    local fresh = chooserItems(where)
    local t = touchmenu.item_table
    for i = #t, 1, -1 do t[i] = nil end
    for i, v in ipairs(fresh) do t[i] = v end
    if touchmenu.updateItems then touchmenu:updateItems() end
end

local function ui()
    local UIManager = require("ui/uimanager")
    return UIManager, require("ui/widget/buttondialog")
end

-- Asks for a group name: on_done(name) with a non-empty, trimmed name.
local function askName(title, current, on_done)
    local UIManager = require("ui/uimanager")
    local InputDialog = require("ui/widget/inputdialog")
    local dlg
    dlg = InputDialog:new{
        title = title,
        input = current or "",
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                local name = (dlg:getInputText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                UIManager:close(dlg)
                if name ~= "" then on_done(name) end
            end },
        }},
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

-- An item's group, its position there, and the group's keys in order.
local function placeOf(where, key)
    for _i, g in ipairs(arrange(seen[where] or {})) do
        for i, c in ipairs(g.items) do
            if c.key == key then
                local keys = {}
                for j, x in ipairs(g.items) do keys[j] = x.key end
                return g.id, i, keys
            end
        end
    end
end

local function forgetOrder(key)
    for _g, keys in pairs(list("items")) do
        if type(keys) == "table" then
            for i = #keys, 1, -1 do if keys[i] == key then table.remove(keys, i) end end
        end
    end
end

-- Hold an item: pick the group it goes in.
local function pickGroup(where, c, touchmenu)
    local UIManager, ButtonDialog = ui()
    local dlg
    local buttons = {}
    local current = c.group or group_of[c.key] or c.default
    for _i, id in ipairs((groupOrder())) do
        buttons[#buttons + 1] = {{
            text = (current == id and "\u{2713} " or "") .. groupName(id)
                .. (id == c.default and ("  " .. titlecase(_("(default)"))) or ""),
            callback = function()
                UIManager:close(dlg)
                local value = (id ~= c.default) and id or nil
                if group_of[c.key] == value then return end
                group_of[c.key] = value
                forgetOrder(c.key)
                saveAndAsk(GROUPS_KEY, group_of)
                saveLayout()
                refresh(where, touchmenu)
            end,
        }}
    end
    dlg = ButtonDialog:new{ title = titlecase(_("move to group")) .. ": " .. c.label, buttons = buttons }
    UIManager:show(dlg)
end

-- Hold an item: move it inside its group, or to another group.
local function itemDialog(where, c, touchmenu)
    local UIManager, ButtonDialog = ui()
    local gid, pos, keys = placeOf(where, c.key)
    local dlg
    local function moveTo(new_pos)
        UIManager:close(dlg)
        if not keys or new_pos == pos then return end
        table.remove(keys, pos)
        table.insert(keys, new_pos, c.key)
        list("items")[gid] = keys
        saveLayout()
        refresh(where, touchmenu)
    end
    local n = keys and #keys or 0
    local buttons = {}
    if alphaSort() then
        buttons[#buttons + 1] = {{ text = titlecase(_("sorted A to Z: set Sort Items to Custom to reorder")), enabled = false }}
    elseif gid then
        buttons[#buttons + 1] = {
            { text = titlecase(_("move up")), enabled = pos > 1, callback = function() moveTo(pos - 1) end },
            { text = titlecase(_("move down")), enabled = pos < n, callback = function() moveTo(pos + 1) end },
        }
        buttons[#buttons + 1] = {
            { text = titlecase(_("move to top")), enabled = pos > 1, callback = function() moveTo(1) end },
            { text = titlecase(_("move to bottom")), enabled = pos < n, callback = function() moveTo(n) end },
        }
    end
    buttons[#buttons + 1] = {{ text = titlecase(_("move to another group…")), callback = function()
        UIManager:close(dlg)
        pickGroup(where, c, touchmenu)
    end }}
    dlg = ButtonDialog:new{ title = c.label, buttons = buttons }
    UIManager:show(dlg)
end

-- Tap a group name: move it, rename it, delete it (your own groups).
local function groupDialog(where, gid, touchmenu)
    local UIManager, ButtonDialog = ui()
    local order = groupOrder()
    local idx = 1
    for i, g in ipairs(order) do if g == gid then idx = i break end end
    local dlg
    local function move(to)
        UIManager:close(dlg)
        table.remove(order, idx)
        table.insert(order, to, gid)
        layout.order = order
        saveLayout()
        refresh(where, touchmenu)
    end
    local buttons = {
        {
            { text = titlecase(_("move up")), enabled = idx > 1, callback = function() move(idx - 1) end },
            { text = titlecase(_("move down")), enabled = idx < #order, callback = function() move(idx + 1) end },
        },
        {{ text = titlecase(_("rename…")), callback = function()
            UIManager:close(dlg)
            askName(titlecase(_("group name")), groupName(gid), function(name)
                list("names")[gid] = (name ~= gid) and name or nil
                saveLayout()
                refresh(where, touchmenu)
            end)
        end }},
    }
    if isCustom(gid) then
        buttons[#buttons + 1] = {{ text = titlecase(_("delete group")), callback = function()
            UIManager:close(dlg)
            local ConfirmBox = require("ui/widget/confirmbox")
            UIManager:show(ConfirmBox:new{
                text = groupName(gid) .. "\n\n" .. _("Delete this group? Its items go back to their usual groups."),
                ok_text = _("Delete"),
                ok_callback = function()
                    for _l, field in ipairs({ "custom", "order" }) do
                        local l = list(field)
                        for i = #l, 1, -1 do if l[i] == gid then table.remove(l, i) end end
                    end
                    list("items")[gid] = nil
                    list("names")[gid] = nil
                    for k, g in pairs(group_of) do if g == gid then group_of[k] = nil end end
                    saveAndAsk(GROUPS_KEY, group_of)
                    saveLayout()
                    refresh(where, touchmenu)
                end,
            })
        end }}
    elseif groupName(gid) ~= gid then
        buttons[#buttons + 1] = {{ text = titlecase(_("use original name")) .. ": " .. gid, callback = function()
            UIManager:close(dlg)
            list("names")[gid] = nil
            saveLayout()
            refresh(where, touchmenu)
        end }}
    end
    dlg = ButtonDialog:new{ title = groupName(gid), buttons = buttons }
    UIManager:show(dlg)
end

local function addGroup(where, touchmenu)
    askName(titlecase(_("new group name")), "", function(name)
        local order = groupOrder()
        for _i, g in ipairs(order) do
            if g == name or groupName(g) == name then
                if not shared_note(_("That group already exists."), _("Already exists")) then
                    local UIManager = require("ui/uimanager")
                    UIManager:show(require("ui/widget/infomessage"):new{ text = _("That group already exists."), timeout = 3 })
                end
                return
            end
        end
        local custom = list("custom")
        custom[#custom + 1] = name
        -- new groups go above Other and Patches
        local pos = #order + 1
        for i, g in ipairs(order) do if g == OTHER or g == PATCHES then pos = i break end end
        table.insert(order, pos, name)
        layout.order = order
        saveLayout()
        refresh(where, touchmenu)
    end)
end

local function resetLayout(where, touchmenu)
    local UIManager = require("ui/uimanager")
    local ConfirmBox = require("ui/widget/confirmbox")
    UIManager:show(ConfirmBox:new{
        text = _("Put groups, group names, item order and moved items back to the defaults?\n\nWhat's turned on or off stays as it is."),
        ok_text = _("Reset"),
        ok_callback = function()
            layout = { auto = layout.auto }
            for k in pairs(group_of) do group_of[k] = nil end
            saveAndAsk(GROUPS_KEY, group_of)
            saveLayout()
            refresh(where, touchmenu)
        end,
    })
end

-- Everything back to a fresh install: on/off choices, groups, names, order,
-- moved items, "New" tags. What's installed is looked at again on the next
-- start, like the first time.
local function resetAll(where, touchmenu)
    local UIManager = require("ui/uimanager")
    local ConfirmBox = require("ui/widget/confirmbox")
    UIManager:show(ConfirmBox:new{
        text = _("Put the whole Add-ons menu back to the defaults?\n\nEvery plugin and patch goes back to its usual group and is turned on again, your own groups and names are removed, and the order goes back to the default."),
        ok_text = _("Reset"),
        ok_callback = function()
            layout = {}
            for _i, t in ipairs({ excluded, group_of, new_ids }) do
                for k in pairs(t) do t[k] = nil end
            end
            known_ids = nil
            if G_reader_settings then
                G_reader_settings:delSetting(KNOWN_KEY)
                G_reader_settings:saveSetting(NEW_KEY, new_ids)
                G_reader_settings:saveSetting(SETTINGS_KEY, excluded)
            end
            saveAndAsk(GROUPS_KEY, group_of)
            saveLayout()
            refresh(where, touchmenu)
        end,
    })
end

chooserItems = function(where)
    local cands = seen[where] or {}
    local out = {
        { text = titlecase(_("tap an item to turn it on or off, hold it to move it")), enabled = false },
        { text = titlecase(_("tap a group name to move, rename or delete it")), enabled = false, separator = true },
        {
            text_func = function()
                return titlecase(_("sort items")) .. ": " .. (alphaSort() and titlecase(_("A to Z")) or titlecase(_("custom")))
            end,
            sub_item_table = {
                { text = titlecase(_("custom (your order)")), radio = true,
                  checked_func = function() return not alphaSort() end,
                  callback = function(tm) layout.sort = nil; saveLayout() end },
                { text = titlecase(_("A to Z (inside each group)")), radio = true,
                  checked_func = alphaSort,
                  callback = function(tm) layout.sort = "alpha"; saveLayout() end },
            },
        },
        {
            text = titlecase(_("new add-ons show up automatically")),
            help_text = _("On: newly installed plugins and patches go straight into Add-ons. Off: they're listed here unticked, for you to choose."),
            checked_func = newGoIn,
            keep_menu_open = true,
            callback = function() layout.auto = not newGoIn(); saveLayout(true) end,
        },
        {
            text = titlecase(_("put tweaks inside their plugin")),
            help_text = _("SimpleUI Tweaks and SimpleUI Side Panel inside Simple UI, BookOrbit Tweaks inside BookOrbit, Reading Insights Tweaks inside Reading Insights, Reading Log Tweaks inside Reading Log. Moving one of them to another group takes it out again."),
            checked_func = combineOn,
            keep_menu_open = true,
            callback = function() layout.combine = (not combineOn()) and nil or false; saveLayout() end,
        },
        { text = titlecase(_("add group…")), keep_menu_open = true,
          callback = function(tm) addGroup(where, tm) end, separator = true },
    }
    local any = false
    local _hosts, inside = combinations(cands)
    for _i, g in ipairs(arrange(cands)) do
        if #g.items > 0 or isCustom(g.id) then
            any = true
            local gid = g.id
            out[#out + 1] = { text = groupName(gid), bold = true, keep_menu_open = true,
                              callback = function(tm) groupDialog(where, gid, tm) end }
            if #g.items == 0 then
                out[#out + 1] = { text = "   " .. titlecase(_("empty: hold an item to move it here")), enabled = false }
            end
            for _j, c in ipairs(g.items) do
                local label = c.broken and (c.label .. "  • " .. _("Error"))
                    or (new_ids[c.key] and (c.label .. "  • " .. _("New")) or c.label)
                if inside[c.key] then label = "   " .. label .. "  (" .. _("in") .. " " .. inside[c.key].label .. ")" end
                out[#out + 1] = {
                    text = label,
                    checked_func = function() return not isOff(c.key) end,
                    keep_menu_open = true,
                    callback = function()
                        setOff(c.key, not isOff(c.key))
                        saveAndAsk(SETTINGS_KEY, excluded)
                    end,
                    hold_callback = function(tm) itemDialog(where, c, tm) end,
                }
            end
            out[#out].separator = true
        end
    end
    if not any then out[#out + 1] = { text = titlecase(_("nothing to arrange yet")), enabled = false, separator = true } end
    out[#out + 1] = { text = titlecase(_("reset layout")),
                      help_text = _("Groups, group names, item order and moved items back to the defaults. What's turned on or off stays as it is."),
                      keep_menu_open = true,
                      callback = function(tm) resetLayout(where, tm) end }
    out[#out + 1] = { text = titlecase(_("reset everything to default")),
                      help_text = _("The whole Add-ons menu back to a fresh install: every item in its usual group and turned on, your own groups and names gone, default order."),
                      keep_menu_open = true,
                      callback = function(tm) resetAll(where, tm) end }
    return out
end

-- Opening the list: one restart prompt per visit, and "New" tags shown once.
-- Only clear what this menu actually showed, so a reader-only add-on keeps
-- its tag until you open the list in the reader.
local function openChooser(where)
    restart_asked = false
    local out = chooserItems(where)
    local cleared = false
    for _i, c in ipairs(seen[where] or {}) do
        if new_ids[c.key] then
            new_ids[c.key] = nil
            cleared = true
        end
    end
    if cleared and G_reader_settings then G_reader_settings:saveSetting(NEW_KEY, new_ids) end
    return out
end

local function isSeparator(v)
    return type(v) == "string" and v:find("^%-%-%-") ~= nil
end

local function indexOf(list, id)
    for i, v in ipairs(list) do if v == id then return i end end
end

local function hasRealItems(list)
    for _i, v in ipairs(list) do
        if not isSeparator(v) then return true end
    end
    return false
end

local function itemLabel(item, id)
    if type(item) ~= "table" then return tostring(id) end
    if type(item.text) == "string" then return item.text end
    if type(item.text_func) == "function" then
        local ok, t = pcall(item.text_func)
        if ok and type(t) == "string" then return t end
    end
    return tostring(id)
end

-- patch entries, sorted: { { id = ..., item = ... }, ... }
-- A bad entry (odd text/order, failing build) only affects itself.
local function buildEntries(where)
    local list = {}
    for id, e in pairs(TM.entries) do
        if type(id) == "string" and type(e) == "table" and type(e.build) == "function"
           and (e.where == nil or e.where == where) then
            local order = tonumber(e.order) or 100
            local named = type(e.text) == "string"
            local label = named and e.text or id
            if isOff("patch:" .. id) then
                -- turned off: listed in the chooser only, not built
                list[#list + 1] = { id = id, order = order, text = label, off = true, group = e.group }
            else
                -- one broken patch must not take the whole menu (or KOReader) down
                local ok, item = pcall(e.build, where)
                if ok and type(item) == "table" then
                    if not item.text and not item.text_func then item.text = label end
                    list[#list + 1] = { id = id, order = order, item = item, group = e.group,
                                        text = named and label or itemLabel(item, id) }
                else
                    logger.warn(TAG, "menu build failed for", id, ok and "build() returned no menu item" or item)
                    -- still listed in the chooser (marked), so it can be turned off
                    list[#list + 1] = { id = id, order = order, text = label, broken = true, group = e.group }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.text < b.text
    end)
    return list
end

-- Builds the order KOReader should sort with: a copy of `order` with the moved
-- items taken out and the Add-ons submenus added. `order` itself is never
-- modified (only lists that change are copied). Returns nil to leave it as is.
local function inject(where, items, order)
    if type(order.tools) ~= "table" then return nil end

    local disabled = {}
    if type(order["KOMenu:disabled"]) == "table" then
        for _i, id in ipairs(order["KOMenu:disabled"]) do disabled[id] = true end
    end

    local moved, claimed, found = {}, {}, {}
    local function usable(id)
        return type(id) == "string" and id:sub(1, #MENU_ID) ~= MENU_ID
           and items[id] ~= nil and not disabled[id] and not claimed[id]
    end

    -- Rows of the Add-ons list
    local plist = {}
    local function addRows(gid, ids)
        if #ids == 0 then return end
        if #plist > 0 then plist[#plist + 1] = SEPARATOR end
        if SHOW_HEADERS and gid then
            local hid = ENTRY_ID .. "h:" .. gid
            items[hid] = { text = groupName(gid), enabled = false }
            plist[#plist + 1] = hid
        end
        for _i, id in ipairs(ids) do plist[#plist + 1] = id end
    end

    -- Every candidate in its default order: { key, id, label, default }
    local cands = {}
    local function add(key, id, label, group, broken)
        claimed[id] = true
        -- title case for the chooser rows (display only; the items themselves
        -- are shared with their original menus and keep their own text)
        cands[#cands + 1] = { key = key, id = id, label = titlecase(label), default = group, broken = broken }
    end
    -- patch settings that register (built once per menu build)
    local entries, entry_by_id = buildEntries(where), {}
    for _i, e in ipairs(entries) do entry_by_id[e.id] = e end
    local function addEntry(e, group)
        e.placed = true
        local cid = ENTRY_ID .. "p:" .. e.id
        items[cid] = e.item
        add("patch:" .. e.id, cid, e.text, group, e.broken)
    end
    for _i, g in ipairs(PLUGINS) do
        for _j, id in ipairs(g) do
            if id:sub(1, 6) == "patch:" then
                local e = entry_by_id[id:sub(7)]
                if e and not e.placed then addEntry(e, g.header) end
            elseif usable(id) then
                add(id, id, itemLabel(items[id], id), g.header)
            end
        end
    end

    -- Add-ons not listed above (new installs): every top-level menu that isn't
    -- KOReader's own, ours, a patch menu listed below, or a submenu inside
    -- another add-on's menu. Falls back to plugins with a Tools placement hint
    -- if KOReader's menu files can't be read.
    if AUTO_COLLECT then
        local stock = stockIds(where)
        local skip = {}
        for _i, id in ipairs(PATCH_MENUS) do skip[id] = true end
        for id in pairs(TM.entries) do skip[id] = true end
        local in_order, children = {}, {}
        for k, l in pairs(order) do
            if type(l) == "table" then
                local add_on_list = stock and not stock[k] and k ~= MENU_ID
                for _i, v in ipairs(l) do
                    in_order[v] = true
                    if add_on_list then children[v] = true end
                end
            end
        end
        local others, labels = {}, {}
        for id, item in pairs(items) do
            if usable(id) and not skip[id] and type(item) == "table"
               and not id:find("^KOMenu:") and (item.text or item.text_func) then
                local addon
                if stock then
                    addon = not stock[id] and not children[id]
                else
                    addon = not in_order[id] and (item.sorting_hint == "tools" or item.sorting_hint == "more_tools")
                end
                if addon then
                    others[#others + 1] = id
                    labels[id] = itemLabel(item, id)   -- once, not per comparison
                end
            end
        end
        table.sort(others, function(a, b) return labels[a] < labels[b] end)

        -- first run with this feature, per menu (file browser and reader are
        -- built separately, often in different sessions): what's installed
        -- now isn't "new"
        known_ids = known_ids or {}
        local run_flag = "@first_run_done:" .. where
        local first_run = not known_ids[run_flag]
        known_ids[run_flag] = true
        local fresh = {}
        for _i, id in ipairs(others) do
            if not known_ids[id] then
                known_ids[id] = true
                if first_run then
                    -- keep today's layout: only what was already collected
                    -- (Tools entries KOReader didn't place) starts ticked
                    local it = items[id]
                    if in_order[id] or not (it.sorting_hint == "tools" or it.sorting_hint == "more_tools") then
                        excluded[id] = true
                    end
                else
                    fresh[#fresh + 1] = id
                    new_ids[id] = true
                    if not newGoIn() then excluded[id] = true end
                end
            end
            add(id, id, labels[id], OTHER)
        end
        if first_run or #fresh > 0 then
            if G_reader_settings then
                G_reader_settings:saveSetting(KNOWN_KEY, known_ids)
                G_reader_settings:saveSetting(NEW_KEY, new_ids)
                G_reader_settings:saveSetting(SETTINGS_KEY, excluded)
                if G_reader_settings.flush then G_reader_settings:flush() end
            end
        end
        if #fresh > 0 then
            local names = {}
            for _i, id in ipairs(fresh) do names[#names + 1] = labels[id] end
            local text = (#fresh == 1 and _("New add-on: ") or _("New add-ons: ")) .. table.concat(names, ", ")
            if not shared_note(text, _("New add-on")) then
                local ok, Notification = pcall(require, "ui/widget/notification")
                if ok and type(Notification) == "table" and Notification.notify then
                    pcall(Notification.notify, Notification, text)
                end
            end
        end
    end

    -- menus added by patches, then patch settings not placed above: in the
    -- group they ask for, else under Patches (sorted by their order field).
    -- A patch seen for the first time is tagged "New", like a new plugin.
    for _i, id in ipairs(PATCH_MENUS) do
        if usable(id) then add(id, id, itemLabel(items[id], id), PATCHES) end
    end
    known_ids = known_ids or {}
    local new_patches = false
    for _i, e in ipairs(entries) do
        if not e.placed then addEntry(e, type(e.group) == "string" and e.group or PATCHES) end
        local k = "patch:" .. e.id
        if not known_ids[k] then
            known_ids[k] = true
            new_patches = true
            if known_ids["@patches_seen"] then new_ids[k] = true end
        end
    end
    if not known_ids["@patches_seen"] then known_ids["@patches_seen"] = true; new_patches = true end
    if new_patches and G_reader_settings then
        G_reader_settings:saveSetting(KNOWN_KEY, known_ids)
        G_reader_settings:saveSetting(NEW_KEY, new_ids)
    end

    -- Entries that must leave the menu KOReader sorts: KOReader puts back
    -- anything left in it that no list places (in Tools by its sorting
    -- hint, else marked "NEW:" in the first tab).
    local drop = {}

    -- a plugin with its tweaks inside: a new entry wrapping the plugin's own
    -- item (never changed), with the patches' items at the bottom. Skipped
    -- for a plugin whose menu KOReader builds from its own order list.
    local hosts, inside = combinations(cands)
    for hkey, kids in pairs(hosts) do
        local h
        for _i, c in ipairs(cands) do if c.key == hkey then h = c break end end
        local it = h and items[h.id]
        if type(it) ~= "table" or type(order[h.id]) == "table"
           or not (it.sub_item_table or it.sub_item_table_func or it.callback) then
            hosts[hkey] = nil
            for _i, k in ipairs(kids) do inside[k.key] = nil end
        else
            local kid_items = {}
            for _i, k in ipairs(kids) do
                kid_items[#kid_items + 1] = items[k.id]
                drop[k.id] = true
            end
            drop[h.id] = true
            local host_label = h.label
            items[ENTRY_ID .. "c:" .. h.id] = {
                text = it.text, text_func = it.text_func, help_text = it.help_text,
                sub_item_table_func = function()
                    local out, base = {}, it.sub_item_table
                    if not base and type(it.sub_item_table_func) == "function" then
                        local ok, t = pcall(it.sub_item_table_func)
                        if ok and type(t) == "table" then base = t end
                    end
                    if base then
                        for i, v in ipairs(base) do out[i] = v end
                    elseif it.callback then
                        out[1] = { text = titlecase(_("open")) .. " " .. host_label, callback = it.callback,
                                   keep_menu_open = it.keep_menu_open }
                    end
                    if #out > 0 then
                        -- a copy of the last row carries the separator
                        local last = {}
                        for k, v in pairs(out[#out]) do last[k] = v end
                        last.separator = true
                        out[#out] = last
                    end
                    for _i, k in ipairs(kid_items) do out[#out + 1] = k end
                    return out
                end,
            }
        end
    end

    for _i, g in ipairs(arrange(cands)) do
        local ids = {}
        for _j, c in ipairs(g.items) do
            found[#found + 1] = c
            if not isOff(c.key) and not c.broken then
                moved[c.id] = true
                if hosts[c.key] then
                    ids[#ids + 1] = ENTRY_ID .. "c:" .. c.id
                elseif not inside[c.key] then
                    ids[#ids + 1] = c.id
                end
                -- a patch that also adds its own copy to Tools (older
                -- versions, or ones that always do): that copy goes too
                local pid = c.key:match("^patch:(.+)$")
                if pid and items[pid] ~= nil then
                    moved[pid] = true
                    drop[pid] = true
                end
            end
        end
        addRows(g.id, ids)
    end
    for id in pairs(drop) do items[id] = nil end

    if #found == 0 then return nil end
    seen[where] = cands

    -- the chooser, always last, so turned-off items can be turned back on
    local cid = ENTRY_ID .. "choose"
    items[cid] = {
        text = titlecase(_("Arrange Add-ons")),
        sub_item_table_func = function() return openChooser(where) end,
    }
    if #plist > 0 then plist[#plist + 1] = SEPARATOR end
    plist[#plist + 1] = cid

    -- shallow copy; lists are copied only when we change them
    local new = {}
    for k, v in pairs(order) do new[k] = v end

    local function without(remove)
        for key, l in pairs(new) do
            if key ~= "KOMenu:disabled" and type(l) == "table" then
                local copy
                for i, v in ipairs(l) do
                    if remove[v] then
                        if not copy then
                            copy = {}
                            for j = 1, i - 1 do copy[j] = l[j] end
                        end
                    elseif copy then
                        copy[#copy + 1] = v
                    end
                end
                if copy then new[key] = copy end
            end
        end
    end

    -- take moved menus out of their usual spot
    without(moved)

    -- hide built-in submenus we emptied (repeat: hiding one can empty its parent)
    local top = {}
    if type(order["KOMenu:menu_buttons"]) == "table" then
        for _i, id in ipairs(order["KOMenu:menu_buttons"]) do top[id] = true end
    end
    local hidden = {}
    while true do
        local emptied = {}
        for key, l in pairs(new) do
            if not hidden[key] and not top[key] and not moved[key]
               and key ~= "KOMenu:menu_buttons" and key ~= "KOMenu:disabled"
               and type(l) == "table" and not hasRealItems(l)
               and type(order[key]) == "table" and hasRealItems(order[key]) then
                emptied[key] = true
            end
        end
        if next(emptied) == nil then break end
        for key in pairs(emptied) do hidden[key] = true end
        without(emptied)   -- may empty a parent: caught on the next pass
    end
    if next(hidden) ~= nil then
        -- mark them disabled (in our copy) so KOReader doesn't re-add them as "NEW:"
        local dis = {}
        if type(order["KOMenu:disabled"]) == "table" then
            for i, v in ipairs(order["KOMenu:disabled"]) do dis[i] = v end
        end
        for key in pairs(hidden) do dis[#dis + 1] = key end
        new["KOMenu:disabled"] = dis
    end

    new[MENU_ID] = plist
    items[MENU_ID] = { text = MENU_TEXT }

    if not indexOf(new.tools, MENU_ID) then
        -- above the separator, next to the built-in tools
        local tools = {}
        for i, v in ipairs(new.tools) do tools[i] = v end
        local pos = #tools + 1
        for i, v in ipairs(tools) do
            if isSeparator(v) then pos = i break end
        end
        table.insert(tools, pos, MENU_ID)
        new.tools = tools
    end
    return new
end

local ok_ms, MenuSorter = pcall(require, "ui/menusorter")
if ok_ms and type(MenuSorter) == "table" and not MenuSorter._tweaks_mods_hooked
   and type(MenuSorter.mergeAndSort) == "function" and type(MenuSorter.sort) == "function" then
    MenuSorter._tweaks_mods_hooked = true

    -- mergeAndSort("filemanager" | "reader", ...) tells us which menu is being built
    local cur_where
    local orig_mas = MenuSorter.mergeAndSort
    MenuSorter.mergeAndSort = function(self, prefix, ...)
        local prev = cur_where
        cur_where = prefix
        -- xpcall + traceback: if KOReader's own sort fails, crash.log still
        -- shows where, not just this wrapper
        local res = pack(xpcall(orig_mas, debug.traceback, self, prefix, ...))
        cur_where = prev
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end

    -- KOReader files an unplaced item under its sorting_hint menu, and crashes
    -- (findById -> nil) when that menu isn't in the tree: its tab hidden by a
    -- menu-order file / Menu Disabler / SimpleUI, or the hint names a menu
    -- that doesn't exist in this menu (file browser vs reader). Point such
    -- hints at a menu that is there. Original hints are kept on the item
    -- (_tm_hint) so each build decides again.
    local FALLBACK_HINTS = { "tools", "setting", "main" }
    local function fixSortingHints(item_table, order)
        local buttons = order["KOMenu:menu_buttons"]
        if type(buttons) ~= "table" then return end
        -- ids that end up placed in the tree (same rules as MenuSorter.sort:
        -- a submenu needs an item and an order list; an entry needs an item)
        local placed, visited = {}, {}
        local function walk(list)
            for _i, id in ipairs(list) do
                if type(id) == "string" and item_table[id] ~= nil and not placed[id] then
                    placed[id] = true
                    if type(order[id]) == "table" and not visited[id] then
                        visited[id] = true
                        walk(order[id])
                    end
                end
            end
        end
        walk(buttons)
        local fallback
        for _i, id in ipairs(FALLBACK_HINTS) do
            if placed[id] and type(order[id]) == "table" then fallback = id break end
        end
        if not fallback then
            for _i, id in ipairs(buttons) do
                if placed[id] then fallback = id break end
            end
        end
        if not fallback then return end
        for id, item in pairs(item_table) do
            if type(item) == "table" and not placed[id] then
                local hint = item._tm_hint or item.sorting_hint
                if type(hint) == "string" then
                    if placed[hint] then
                        item.sorting_hint = hint
                    else
                        if item._tm_hint == nil then
                            logger.info(TAG, "menu", hint, "isn't shown;", id, "goes in", fallback)
                        end
                        item._tm_hint = hint
                        item.sorting_hint = fallback
                    end
                end
            end
        end
    end

    local orig_sort = MenuSorter.sort
    MenuSorter.sort = function(self, item_table, order, ...)
        if (cur_where == "filemanager" or cur_where == "reader")
           and type(item_table) == "table" and type(order) == "table" then
            local ok, new_order = pcall(inject, cur_where, item_table, order)
            if not ok then
                logger.warn(TAG, "failed, menu left as is:", new_order)
            elseif new_order then
                order = new_order
            end
        end
        if type(item_table) == "table" and type(order) == "table" then
            local ok_h, err_h = pcall(fixSortingHints, item_table, order)
            if not ok_h then logger.warn(TAG, "sorting hint check failed:", err_h) end
        end
        return orig_sort(self, item_table, order, ...)
    end
else
    logger.warn(TAG, "couldn't hook the menu sorter, menu left as is")
end
