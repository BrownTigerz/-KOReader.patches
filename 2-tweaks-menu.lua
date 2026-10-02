--[[
2-tweaks-menu.lua
KOReader user patch: one "Add-ons" menu under Tools, for plugins and patches.

Version: 1.0.0

Changelog:
  1.0.0  2026-10-02  First release.

Versioning:
  1.0.x  fixes (e.g. adapting to a KOReader or plugin menu id rename)
  1.x.0  new features
  2.0.0  anything that changes how saved Add-ons choices work

  Tools > Add-ons   one list: your plugins, grouped (PLUGINS below), then
                    settings from patches that support it (e.g. 2-simpleui-mod.lua),
                    groups split by separators

Moved plugins work exactly the same, they're just shown here instead of their
usual spot.

Newly installed plugins and patches (anything that adds a menu) are found
automatically (AUTO_COLLECT): you get a one-time notice, and they show up
marked "New" in "Choose what's in Add-ons", under "Other", for you to tick.

"Choose what's in Add-ons" (bottom of the list): tap an item to turn it on or
off (off puts it back where it originally was), hold it to move it to another
group. Both apply after a restart.

KOReader's menu order is never modified: each menu build works on a copy, so
delete this file and restart, and every menu goes back where it was. Only your
Add-ons choices are saved (in settings.reader.lua). An id that doesn't exist
(not installed, renamed by an update) is skipped. Items hidden with a
menu-order file / Menu Disabler ("KOMenu:disabled") stay hidden. A built-in
submenu left empty by moving all its items out is hidden.

Install: koreader/patches/2-tweaks-menu.lua (Kobo: .adds/koreader/patches/), then restart.
]]

local VERSION = "1.0.0"

-- ---- Settings ---------------------------------------------------------------------
local MENU_TEXT    = "Add-ons"   -- name shown in Tools
local SHOW_HEADERS = true        -- group names above each group (false = separators only)
local AUTO_COLLECT = true        -- find add-ons not listed below (new installs) and
                                 -- offer them in "Choose what's in Add-ons"
local NEW_GO_IN    = false       -- true: newly found add-ons go straight into
                                 -- Add-ons; false: listed unticked, you choose

-- Plugins, by group, shown in this order. An id is the key a plugin uses in
-- addToMainMenu (menu_items.<id>), or a built-in id from KOReader's
-- frontend/ui/elements/*_menu_order.lua. Move lines between groups, add or
-- remove ids, or add groups - then restart.
local PLUGINS = {
    { header = "Home & library",
        "simpleui",               -- SimpleUI
        "bookshelf_tab",          -- Bookshelf (its whole menu tab moves here)
        "shortcutstoolbar",       -- Shortcuts Toolbar
    },
    { header = "Reading",
        "xray",                   -- X-Ray
        "page_scrubber",          -- Page Scrubber
        "glimpse",                -- Glimpse
        "foot_cream",             -- Footcream
    },
    { header = "Stats & progress",
        "readmastery",            -- ReadMastery
        "reading_insights_popup", -- Reading Insights
        "bookcard",               -- Book Card
        "shelfsync",              -- ShelfSync
    },
    { header = "System",
        "Storefront",             -- Storefront
        "backup",                 -- Device Backup & Restore
        "backup_patches",         -- Patch Backup & Restore (patch)
        "menu_disabler",          -- Menu Disabler (Menu customizer)
    },
}

-- Menus added by patches that aren't placed in a group above: they go in the
-- "Patches" group, with settings from patches that register themselves
-- (e.g. SimpleUI Mod). Any id - plugin or patch - can go in any group above.
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
        build = function(where) return { text = "My Patch", sub_item_table = {...} } end,
    }
  Entries show at the end of Add-ons, under "Patches". build() runs every time the menu is
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
TM.version = VERSION

-- Items turned off in "Choose what's in Add-ons" (kept in their original spot).
-- Plugins by menu id, patches as "patch:<id>".
local SETTINGS_KEY = "addons_menu_excluded"
local excluded = G_reader_settings and G_reader_settings:readSetting(SETTINGS_KEY) or {}

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
    return not excluded["patch:" .. tostring(id)]
end

-- What the last menu build found, per menu ("filemanager" / "reader"), for the
-- chooser: seen[where] = { { key, label, header, default }, ... },
-- seen_groups[where] = group names in display order.
local seen = {}
local seen_groups = {}

local function pack(...) return { n = select("#", ...), ... } end

-- ---- "Choose what's in Add-ons" ---------------------------------------------------
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
        if okm then UIManager:show(InfoMessage:new{ text = _("Restart KOReader to apply.") }) end
    end
end

local restart_asked = false   -- one prompt per visit to the chooser

local function saveAndAsk(key, value)
    if G_reader_settings then
        G_reader_settings:saveSetting(key, value)
        if G_reader_settings.flush then G_reader_settings:flush() end
    end
    if not restart_asked then
        restart_asked = true
        askRestart()
    end
end

-- Hold an item in the chooser: pick the group it goes in.
local function pickGroup(where, c, touchmenu)
    local ok, ButtonDialog = pcall(require, "ui/widget/buttondialog")
    local okm, UIManager = pcall(require, "ui/uimanager")
    if not (ok and okm) then return end
    local dlg
    local buttons = {}
    for _i, name in ipairs(seen_groups[where] or {}) do
        local current = (group_of[c.key] or c.default) == name
        buttons[#buttons + 1] = {{
            text = (current and "\u{2713} " or "") .. name
                .. (name == c.default and ("  " .. _("(default)")) or ""),
            callback = function()
                UIManager:close(dlg)
                local value = (name ~= c.default) and name or nil
                if group_of[c.key] == value then return end
                group_of[c.key] = value
                saveAndAsk(GROUPS_KEY, group_of)
                if touchmenu then touchmenu:updateItems() end
            end,
        }}
    end
    dlg = ButtonDialog:new{ title = c.label, buttons = buttons }
    UIManager:show(dlg)
end

local function chooserItems(where)
    restart_asked = false
    local list = seen[where] or {}
    local out, last_header = { { text = _("Tap: in or out · Hold: move to a group"), enabled = false, separator = true } }, nil
    for _i, c in ipairs(list) do
        if c.header ~= last_header then
            if #out > 0 then out[#out].separator = true end
            if SHOW_HEADERS and c.header then
                out[#out + 1] = { text = c.header, enabled = false }
            end
            last_header = c.header
        end
        local is_new = new_ids[c.key]
        out[#out + 1] = {
            text = is_new and (c.label .. "  • " .. _("New")) or c.label,
            checked_func = function() return not excluded[c.key] end,
            keep_menu_open = true,
            callback = function()
                excluded[c.key] = (not excluded[c.key]) or nil
                saveAndAsk(SETTINGS_KEY, excluded)
            end,
            hold_callback = function(touchmenu) pickGroup(where, c, touchmenu) end,
        }
    end
    if #out == 1 then out[1] = { text = _("Nothing to choose yet"), enabled = false } end
    -- shown once: the next time you open this list they're no longer "new".
    -- Only clear what this menu actually showed, so a reader-only add-on keeps
    -- its tag until you open the chooser in the reader.
    local cleared = false
    for _i, c in ipairs(list) do
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
local function buildEntries(where)
    local list = {}
    for id, e in pairs(TM.entries) do
        if type(e) == "table" and type(e.build) == "function"
           and (e.where == nil or e.where == where) then
            if excluded["patch:" .. id] then
                -- turned off: listed in the chooser only, not built
                list[#list + 1] = { id = id, order = e.order or 100, text = e.text or id, off = true }
            else
                -- one broken patch must not take the whole menu (or KOReader) down
                local ok, item = pcall(e.build, where)
                if ok and type(item) == "table" then
                    if not item.text and not item.text_func then item.text = e.text or id end
                    list[#list + 1] = { id = id, order = e.order or 100,
                                        text = e.text or tostring(item.text), item = item }
                elseif not ok then
                    logger.warn(TAG, "menu build failed for", id, item)
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
    local function addGroup(header, ids)
        if #ids == 0 then return end
        if #plist > 0 then plist[#plist + 1] = SEPARATOR end
        if SHOW_HEADERS and header then
            local hid = ENTRY_ID .. "h:" .. header
            items[hid] = { text = header, enabled = false }
            plist[#plist + 1] = hid
        end
        for _i, id in ipairs(ids) do plist[#plist + 1] = id end
    end

    -- Every candidate in its default order: { key, id, label, group }
    local OTHER, PATCHES = _("Other"), _("Patches")
    local cands = {}
    local function add(key, id, label, group)
        claimed[id] = true
        cands[#cands + 1] = { key = key, id = id, label = label, default = group }
    end
    for _i, g in ipairs(PLUGINS) do
        for _j, id in ipairs(g) do
            if usable(id) then add(id, id, itemLabel(items[id], id), g.header) end
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
                    if not NEW_GO_IN then excluded[id] = true end
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
            local ok, Notification = pcall(require, "ui/widget/notification")
            if ok and type(Notification) == "table" and Notification.notify then
                pcall(Notification.notify, Notification,
                    (#fresh == 1 and _("New add-on: ") or _("New add-ons: ")) .. table.concat(names, ", "))
            end
        end
    end

    -- menus added by patches, then settings from patches that register
    for _i, id in ipairs(PATCH_MENUS) do
        if usable(id) then add(id, id, itemLabel(items[id], id), PATCHES) end
    end
    for _i, e in ipairs(buildEntries(where)) do
        local cid = ENTRY_ID .. "p:" .. e.id
        items[cid] = e.item
        add("patch:" .. e.id, cid, e.text, PATCHES)
    end

    -- groups in display order; a group chosen by hold must be one of them
    -- (an unknown saved group, e.g. a renamed header, falls back to the default
    -- but is kept, so renaming it back restores your choice)
    local names, known = {}, {}
    for _i, g in ipairs(PLUGINS) do
        if g.header and not known[g.header] then names[#names + 1] = g.header; known[g.header] = true end
    end
    for _i, n in ipairs({ OTHER, PATCHES }) do
        if not known[n] then names[#names + 1] = n; known[n] = true end
    end
    -- a group's own items first, then ones moved into it (in the order listed)
    local buckets = {}
    for pass = 1, 2 do
        for _i, c in ipairs(cands) do
            local g = group_of[c.key]
            c.group = (g and known[g]) and g or c.default
            if (pass == 1) == (c.group == c.default) then
                buckets[c.group] = buckets[c.group] or {}
                table.insert(buckets[c.group], c)
            end
        end
    end
    for _i, name in ipairs(names) do
        local ids = {}
        for _j, c in ipairs(buckets[name] or {}) do
            found[#found + 1] = { key = c.key, label = c.label, header = name, default = c.default }
            if not excluded[c.key] then
                moved[c.id] = true
                ids[#ids + 1] = c.id
            end
        end
        addGroup(name, ids)
    end

    if #found == 0 then return nil end
    seen[where] = found
    seen_groups[where] = names

    -- the chooser, always last, so turned-off items can be turned back on
    local cid = ENTRY_ID .. "choose"
    items[cid] = {
        text = _("Choose what's in Add-ons"),
        sub_item_table_func = function() return chooserItems(where) end,
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
        return orig_sort(self, item_table, order, ...)
    end
else
    logger.warn(TAG, "couldn't hook the menu sorter, menu left as is")
end
