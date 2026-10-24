--[[
2-screenshot-timer.lua - TEMPORARY helper patch
Version 1.0.0

Menu: Tools → Add-ons → Screenshot in 10 s
      (or Tools → Screenshot in 10 s, without 2-tweaks-menu.lua)

Tap it and the menu closes. 10 seconds later the screen is saved to
KOReader's screenshots folder (the one set in Screenshot settings, or
koreader/screenshots) as Screenshot_YYYY-MM-DD_HHMMSS.png. One shot per tap:
it turns itself off after the shot.
  - Tap it again before the 10 s are up to cancel (it shows a check mark
    while it's waiting).
  - Going to sleep cancels it, so no timer waits through sleep.
  - Nothing runs until you tap it. Delete the file when you're done.

Changelog:
  1.0.0 - First version.
]]

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Screen = Device.screen

local VERSION = "1.0.0"
local DELAY_S = 10
local ID = "screenshot_timer"
local TAG = "screenshot-timer:"

local pending -- the scheduled function while waiting, else nil

local function shotDir()
    local dir = G_reader_settings:readSetting("screenshot_dir")
    if type(dir) ~= "string" or dir == "" or lfs.attributes(dir, "mode") ~= "directory" then
        dir = DataStorage:getFullDataDir() .. "/screenshots"
        if lfs.attributes(dir, "mode") ~= "directory" then lfs.mkdir(dir) end
    end
    return dir
end

local function say(text)
    local NetworkMgr = package.loaded["ui/network/manager"]
    local note = NetworkMgr and NetworkMgr.__network_tweaks_note
    if type(note) == "function" and note(text, text, 2) ~= false then return end
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{ text = text, timeout = 2 })
end

local function cancel()
    if pending then
        UIManager:unschedule(pending)
        pending = nil
        return true
    end
    return false
end

local function take()
    pending = nil
    local path = os.date(shotDir() .. "/Screenshot_%Y-%m-%d_%H%M%S.png")
    local ok, err = pcall(function()
        local done, why = Screen:shot(path)
        if not done and lfs.attributes(path, "mode") ~= "file" then error(why or "screenshot failed", 0) end
    end)
    if ok then
        logger.info(TAG, "saved", path)
        say("Screenshot saved")
    else
        logger.warn(TAG, "failed:", err)
        say("Screenshot failed")
    end
end

local function item()
    return {
        text_func = function()
            return pending and "Screenshot in 10 s (waiting · tap to cancel)" or "Screenshot in 10 s"
        end,
        checked_func = function() return pending ~= nil end,
        callback = function()
            if cancel() then
                say("Screenshot cancelled")
                return
            end
            pending = take
            UIManager:scheduleIn(DELAY_S, pending)
        end,
    }
end

-- Sleep cancels a waiting shot: nothing left waiting through sleep.
if type(Device._beforeSuspend) == "function" then
    local orig = Device._beforeSuspend
    Device._beforeSuspend = function(...)
        if cancel() then logger.info(TAG, "cancelled for sleep") end
        return orig(...)
    end
end

-- Add-ons entry (2-tweaks-menu.lua), library and reader.
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries[ID] = { text = "Screenshot in 10 s", order = 950, build = item }

-- Fallback: Tools menu when the Add-ons patch isn't there (or hides it).
local function addToOrder(order_mod)
    local ok, order = pcall(require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for _i, v in ipairs(order.tools) do if v == ID then return end end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:find("^%-%-%-") then pos = i break end
    end
    table.insert(order.tools, pos, ID)
end

for _i, pair in ipairs({
    { "apps/filemanager/filemanagermenu", "ui/elements/filemanager_menu_order" },
    { "apps/reader/modules/readermenu", "ui/elements/reader_menu_order" },
}) do
    local ok, M = pcall(require, pair[1])
    if ok and type(M) == "table" and type(M.setUpdateItemTable) == "function" then
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

logger.info("screenshot timer " .. VERSION .. " loaded")
