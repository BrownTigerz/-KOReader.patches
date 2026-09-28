--[[
2-tweaks-menu.lua
KOReader user patch: one "Tweaks & Mods" menu under Tools.

It collects two things:
  1. Other menus you list in MOVE below (plugins, built-in items). They work
     exactly the same, they're just shown here instead of their usual spot.
  2. Settings from patches that support it (e.g. 2-simpleui-mod.lua).

Nothing is changed or saved: each menu build works on a copy of KOReader's
menu order, so delete this file and restart, and every menu goes back where it
was. A MOVE id that doesn't exist (not installed, renamed by an update) is
skipped and that item stays in its normal spot. Items hidden with a menu-order
file / Menu Disabler ("KOMenu:disabled") stay hidden. A built-in submenu left
empty by moving all its items out is hidden instead of shown empty.

Install: koreader/patches/2-tweaks-menu.lua (Kobo: .adds/koreader/patches/), then restart.
]]

-- ---- Menus to move into Tweaks & Mods (shown in this order) -----------------------
-- An id is the key a plugin uses in addToMainMenu (menu_items.<id>), or a built-in
-- id from KOReader's frontend/ui/elements/*_menu_order.lua.
local MOVE = {
    "simpleui",          -- SimpleUI
    "readmastery",       -- ReadMastery
    "shelfsync",         -- ShelfSync
    "shortcutstoolbar",  -- Shortcuts Toolbar
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
  build() runs every time the menu is built, so keep it cheap: return an item
  with sub_item_table_func to build the submenu only when it's opened.
  TM.active is true once this patch has loaded. Check it inside your own menu hook
  (menu build time), not at load time, so patch file order doesn't matter.
]]

local logger = require("logger")
local _ = require("gettext")

local MENU_ID   = "tweaks_mods"
local MENU_TEXT = _("Tweaks & Mods")
local SEPARATOR = "----------------------------"
local TAG       = "tweaks-menu:"

-- shared registry (other patches may have created it already)
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.active  = true
TM.menu_id = MENU_ID

local function pack(...) return { n = select("#", ...), ... } end

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

-- patch entries for this menu, sorted: { { id = ..., item = ... }, ... }
local function buildEntries(where)
    local list = {}
    for id, e in pairs(TM.entries) do
        if type(e) == "table" and type(e.build) == "function"
           and (e.where == nil or e.where == where) then
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
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.text < b.text
    end)
    return list
end

-- Builds the order KOReader should sort with: a copy of `order` with the moved
-- items taken out and the Tweaks & Mods submenu added. `order` itself is never
-- modified (only lists that change are copied). Returns nil to leave it as is.
local function inject(where, items, order)
    if type(order.tools) ~= "table" then return nil end

    local disabled = {}
    if type(order["KOMenu:disabled"]) == "table" then
        for _i, id in ipairs(order["KOMenu:disabled"]) do disabled[id] = true end
    end

    local list, moved = {}, {}
    for _i, id in ipairs(MOVE) do
        if type(id) == "string" and id ~= MENU_ID and items[id] ~= nil
           and not disabled[id] and not moved[id] then
            moved[id] = true
            list[#list + 1] = id
        end
    end

    local entries = buildEntries(where)
    if #list == 0 and #entries == 0 then return nil end
    if #list > 0 and #entries > 0 then list[#list + 1] = SEPARATOR end
    for _i, e in ipairs(entries) do
        local cid = MENU_ID .. ":" .. e.id
        items[cid] = e.item
        list[#list + 1] = cid
    end

    -- shallow copy; lists are copied only when we change them
    local new = {}
    for k, v in pairs(order) do new[k] = v end

    local function without(remove)
        for key, l in pairs(new) do
            if key ~= MENU_ID and key ~= "KOMenu:disabled" and type(l) == "table" then
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

    -- take moved menus out of their usual spot (only ones that exist, see above)
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
            if not hidden[key] and not top[key] and key ~= MENU_ID
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

    new[MENU_ID] = list
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
        local res = pack(pcall(orig_mas, self, prefix, ...))
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
