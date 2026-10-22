--[[
2-zz-network-tweaks-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.2.5

Changelog:
  1.2.5 - One line per entry: messages and popups with line breaks are
          joined with " / " (they used to split into untagged lines), and
          the invisible text-direction marks around file paths are
          removed.
  1.2.4 - Shared-log rotation cap raised 256 KB -> 2 MB
          (SHARED_MAX_BYTES = 2 * 1024 * 1024, identical across all
          diagnostics per TK).
  1.2.3 - Adopted the shared log contract v1: lines now go to the shared
          koreader/diagnostics.log (tag [network-tweaks]) instead of the
          file's own network-tweaks-diagnostics.log. Rotation (2 MB,
          .old) moved with it. Per-line +Nms offset kept on the content.
  1.2.2 - Removed the 0.25s frozen-screen heartbeat (banned by the
          no-timers rule); slow redraws are still timed from the
          repaint hook. Fixed inside() never matching full-width
          (x=0) banners. Suspend/wake/list-opener/NetworkMgr wrappers
          now pcall their own logging, so a diagnostic error can never
          break the original. Log lines carry the full date
          (%Y-%m-%d %I:%M:%S %p). First line per start matches the
          contract format; after expiry one line is written per start
          and no note is shown. Expiry stamp moved to
          network-tweaks-diagnostics.state (the old reader-settings
          key is deleted on upgrade). Startup note uses the shared
          Network Tweaks note style when Network Tweaks is present.
          readAllEvents now preserves all of the original's return
          values, like every other wrapper.
  1.2.1 - Previous version (reviewed 2026-10-11).

Watches Network Tweaks from the outside and writes what it sees, tagged
[network-tweaks], to the shared koreader/diagnostics.log
(shared log contract v1; Kobo: .adds/koreader/diagnostics.log)

It changes nothing, it only writes the log. It doesn't touch Network Tweaks
itself. The "zz" makes it load after 2-network-tweaks.lua.

Switches itself off, in case it's forgotten:
  - logs for the first 5 minutes after each KOReader start, then goes quiet
    (every hook just passes straight through)
  - 24 hours after it was first installed it stops hooking anything at all:
    one line in the log per start, then nothing. Copying the file in again
    starts a fresh 24 hours.

Files it writes (KOReader data dir, Kobo: .adds/koreader/):
  - diagnostics.log                (the shared log, tagged [network-tweaks])
  - diagnostics.log.old            (previous 2 MB on rotation)
  - network-tweaks-diagnostics.state (first-run stamp for the 24h expiry)

What it logs (12-hour clock, +ms = time since the current test began):
  - Network list: every step and how long it took (radio power-up, the
    scan, Wi-Fi client calls, connect / disconnect), popups and banners
    shown or closed.
  - Shell commands Network Tweaks runs (enable-wifi.sh, wpa_cli, pkill...).
  - Network events (connecting, connected, disconnected, SSH/Calibre
    state changes).
  - Sleep and wake: how long going to sleep took, SSH and Wi-Fi state
    before and after, and any note drawn over the sleep screen (shouldn't
    happen).
  - Taps and holds, what was on top, and TAP WENT THROUGH if a tap on a
    banner or corner note also reached a button underneath (it shouldn't).
  - Tap highlights (the brief invert on touch) that land under a banner or
    note: the same leak, seen from the screen side.
  - Slow screen redraws (over 250ms, timed from the repaint hook, only
    while a test is running).

How to use:
  1. Put this file in koreader/patches/ and restart KOReader.
  2. Within 5 minutes: hold the toolbar Wi-Fi icon (Wi-Fi off, then on),
     cancel one scan, tap a banner, put the device to sleep and wake it.
  3. Send diagnostics.log, then delete this file and restart.
]]

local ACTIVE_MINUTES = 5   -- logging window after each KOReader start
local EXPIRES_HOURS = 24   -- after first install: no hooks at all

local DataStorage = require("datastorage")
local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local ok_time, ktime = pcall(require, "ui/time")

local STATE = DataStorage:getDataDir() .. "/network-tweaks-diagnostics.state"
local SSH_PID_FILE = "/tmp/dropbear_koreader.pid"

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "network-tweaks"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
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
-- Expiry
-- --------------------------------------------------------------------------

-- Keyed to this file's timestamp: copying a fresh copy in starts a new 24h.
-- Kept in network-tweaks-diagnostics.state (per the diagnostics contract).
local me = DataStorage:getDataDir() .. "/patches/2-zz-network-tweaks-diagnostics.lua"
local mtime = lfs.attributes(me, "modification") or 0
-- One-time cleanup of the v1.2.1 settings key.
pcall(function() G_reader_settings:delSetting("network_tweaks_diagnostics_first_run") end)
local first
do
    local f = io.open(STATE, "r")
    if f then
        local a, b = f:read("*a"):match("^(%d+) (%d+)$")
        f:close()
        if a and tonumber(b) == mtime then first = tonumber(a) end
    end
    if not first then
        first = os.time()
        local w = io.open(STATE, "w")
        if w then w:write(string.format("%d %d", first, mtime)) w:close() end
    end
end
if os.time() - first > EXPIRES_HOURS * 3600 then
    -- Contract: one line in the log per start, then no hooks at all.
    -- shared_log is fully self-contained (pcall-wrapped), so this early
    -- path needs nothing else from the file.
    shared_log("network-tweaks diagnostics expired: delete 2-zz-network-tweaks-diagnostics.lua")
    return -- no hooks at all
end

local stop_at = os.time() + ACTIVE_MINUTES * 60
local function on() return os.time() <= stop_at end

-- --------------------------------------------------------------------------
-- Log
-- --------------------------------------------------------------------------

local t0 -- start of the current test (list opened, sleep, etc.)
local test_until = 0 -- slow-redraw timing only runs while a test is recent

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

local function log(fmt, ...)
    -- shared_log adds the date, 12-hour time and [network-tweaks] tag;
    -- the +Nms offset (time since the current test began) stays on the
    -- line content as before.
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    local dt = t0 and ms(t0) or 0
    if dt < 0 then dt = 0 end
    shared_log("+%6dms  %s", dt, line)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

local function sshOn() return lfs.attributes(SSH_PID_FILE, "mode") == "file" end

-- One note per start, only while logging, in the shared Network Tweaks
-- note style when Network Tweaks is present (plain notification otherwise).
local function note(text)
    local nt_note = NetworkMgr.__network_tweaks_note
    if type(nt_note) == "function" then
        pcall(nt_note, text, text, 2)
    else
        pcall(function() require("ui/widget/notification"):notify(text) end)
    end
end

local function describe(w)
    if type(w) ~= "table" then return q(w) end
    local text = w.text or w.title or w.name or ""
    text = tostring(text):gsub("\n", " "):sub(1, 60)
    local kind = w.toast and "note/banner" or (w.buttons and "dialog" or (w.name or "widget"))
    return string.format("%s \"%s\"", kind, text)
end

local function topWidget()
    local st = UIManager._window_stack
    return st and st[#st] and st[#st].widget
end

-- Area of the toast on top (banner / corner note), if any.
local function toastArea()
    local w = topWidget()
    if not (w and w.toast) then return nil end
    return (w.frame and w.frame.dimen) or w.dimen, w
end

local function inside(pos, d)
    if type(pos) ~= "table" or type(d) ~= "table" then return false end
    local px, py, dx, dy, dw, dh = pos.x, pos.y, d.x, d.y, d.w, d.h
    -- Explicit nil checks: 0 is falsy in Lua, and full-width banners
    -- sit at x=0 — a truthiness chain would never match them.
    if px == nil or py == nil or dx == nil or dy == nil or dw == nil or dh == nil then
        return false
    end
    return px >= dx and px < dx + dw and py >= dy and py < dy + dh
end

local function startTest(what)
    t0 = now()
    test_until = os.time() + 90
    log("==================== %s ====================", what)
    local ok_c, connected = pcall(NetworkMgr.isConnected, NetworkMgr)
    local nt = G_reader_settings:readSetting("network_tweaks") or {}
    log("Wi-Fi radio %s | connected %s | connecting %s | SSH %s | style %s",
        NetworkMgr:isWifiOn() and "on" or "off", ok_c and q(connected) or "?",
        q(NetworkMgr.pending_connection), sshOn() and "on" or "off",
        q(nt.connect_style or "banner (default)"))
end

log("==================== network-tweaks diagnostics 1.2.5 started ====================")
log("logging for %d min (until %s) | expires %s | log %s",
    ACTIVE_MINUTES, os.date("%I:%M %p", stop_at),
    os.date("%b %d %I:%M %p", first + EXPIRES_HOURS * 3600), SHARED_LOG)

-- --------------------------------------------------------------------------
-- Network list opener (toolbar hold looks it up at call time)
-- --------------------------------------------------------------------------

local orig_choose = NetworkMgr.__network_tweaks_choose_network
if type(orig_choose) == "function" then
    NetworkMgr.__network_tweaks_choose_network = function(...)
        if not on() then return orig_choose(...) end
        pcall(startTest, "network list opened")
        local t = now()
        local res = { pcall(orig_choose, ...) }
        pcall(log, "opener returned after %dms%s", ms(t), res[1] and "" or ("  ERROR: " .. q(res[2])))
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
    end
else
    pcall(log, "Network Tweaks 1.6.0+ not found: no network list to watch")
end

-- --------------------------------------------------------------------------
-- Shell commands
-- --------------------------------------------------------------------------

local NET_CMD = { "wifi", "wpa", "dhcp", "obtain", "release%-ip", "pkill", "dropbear", "iptables" }
local orig_exec = os.execute
os.execute = function(cmd, ...)
    if not on() or type(cmd) ~= "string" then return orig_exec(cmd, ...) end
    local relevant = false
    for _i, p in ipairs(NET_CMD) do if cmd:find(p) then relevant = true break end end
    if not relevant then return orig_exec(cmd, ...) end
    local t = now()
    local r1, r2, r3 = orig_exec(cmd, ...)
    pcall(log, "shell: %s  -> %s (%dms)", cmd, q(r1), ms(t))
    return r1, r2, r3
end

-- --------------------------------------------------------------------------
-- Wi-Fi client (wpa_supplicant) calls
-- --------------------------------------------------------------------------

local ok_w, WpaClient = pcall(require, "lj-wpaclient/wpaclient")
if ok_w and type(WpaClient) == "table" and type(WpaClient.__index) == "table" then
    local M = WpaClient.__index
    local orig_new = WpaClient.new
    WpaClient.new = function(ctrl, ...)
        local t = now()
        local c, err = orig_new(ctrl, ...)
        if on() then pcall(log, "wpa: open %s -> %s %s (%dms)", q(ctrl), c and "ok" or "FAILED", q(err), ms(t)) end
        return c, err
    end
    local function timed(name, fmt)
        local orig = M[name]
        if type(orig) ~= "function" then return end
        M[name] = function(self, ...)
            if not on() then return orig(self, ...) end
            local t = now()
            local r = { orig(self, ...) }
            pcall(function()
                log("wpa: %s -> %s (%dms)", name, fmt and fmt(r) or (q(r[1]) .. " " .. q(r[2])), ms(t))
            end)
            return unpack(r)
        end
    end
    -- Names that would show blank or broken: empty, \x00/control bytes
    -- (hidden networks pad with zeros), or not valid UTF-8 once decoded.
    -- Logged raw, as wpa_supplicant sends them.
    local ok_u, util = pcall(require, "util")
    local function oddNames(list)
        local odd = {}
        for _i, ap in ipairs(list) do
            local n = tostring(ap.ssid or "")
            local bad = n == "" or n:find("\\x[01]%x") ~= nil or n:find("[%z\1-\31]") ~= nil
            if not bad and n:find("\\x%x%x") and ok_u then
                local dec = n:gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
                bad = util.fixUtf8(dec, "?") ~= dec
            end
            if bad then odd[#odd + 1] = string.format("[%s] %q", tostring(ap.bssid), n) end
        end
        return odd
    end
    local function count(r)
        if type(r[1]) ~= "table" then return "nothing: " .. q(r[2]) end
        local odd = oddNames(r[1])
        local s = #r[1] .. " access points"
        if #odd > 0 then s = s .. " | odd names: " .. table.concat(odd, ", ") end
        return s
    end
    local function ssid(r) return type(r[1]) == "table" and q(r[1].ssid) or "none" end
    timed("attach"); timed("detach"); timed("doScan")
    timed("getScanResults", count); timed("scanThenGetResults", count)
    timed("getConnectedNetwork", ssid); timed("getCurrentNetwork", ssid)
    -- Only the events that matter (a scan also sends one BSS-ADDED per AP).
    local orig_read = M.readAllEvents
    if type(orig_read) == "function" then
        M.readAllEvents = function(self, evs, ...)
            local r = { orig_read(self, evs, ...) }
            if on() and type(evs) == "table" then
                local added = 0
                for _i, ev in ipairs(evs) do
                    local m = tostring(ev.msg)
                    if m:find("BSS%-ADDED") or m:find("BSS%-REMOVED") then added = added + 1
                    else pcall(log, "wpa: event %s", m) end
                end
                if added > 0 then pcall(log, "wpa: %d access point add/remove events", added) end
            end
            return unpack(r)
        end
    end
end

-- --------------------------------------------------------------------------
-- NetworkMgr steps
-- --------------------------------------------------------------------------

for _i, name in ipairs({
    "getNetworkList", "authenticateNetwork", "obtainIP", "releaseIP",
    "disconnectNetwork", "disableWifi", "toggleWifiOn", "toggleWifiOff",
    "turnOnWifi", "turnOffWifi", "reconnectOrShowNetworkMenu", "restoreWifiAsync",
    "_abortWifiConnection", "scheduleConnectivityCheck", "unscheduleConnectivityCheck",
}) do
    local orig = NetworkMgr[name]
    if type(orig) == "function" then
        NetworkMgr[name] = function(self, ...)
            if not on() then return orig(self, ...) end
            local t = now()
            pcall(log, "NetworkMgr:%s started", name)
            if name == "_abortWifiConnection" then
                -- Who gave up on the connection (it turns Wi-Fi off).
                pcall(log, "  called from:%s", debug.traceback("", 2):gsub("\n%s*", "\n      "))
            end
            local r = { orig(self, ...) }
            pcall(log, "NetworkMgr:%s done (%dms) -> %s", name, ms(t), q(r[1]))
            return unpack(r)
        end
    end
end

-- --------------------------------------------------------------------------
-- Sleep / wake and network events
-- --------------------------------------------------------------------------

local NET_EVENTS = {
    onNetworkConnecting = true, onNetworkConnected = true, onNetworkDisconnected = true,
    onNetworkTweaksStateChanged = true,
}
local orig_bc = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, ev, ...)
    local h = on() and type(ev) == "table" and ev.handler
    if h == "onSuspend" then
        -- The diagnostic's own logging must never break the original,
        -- least of all on the suspend path: original always runs.
        pcall(startTest, "going to sleep")
        local t = now()
        local r = orig_bc(self, ev, ...)
        pcall(function()
            log("sleep handled in %dms | Wi-Fi radio %s | SSH %s%s", ms(t),
                NetworkMgr:isWifiOn() and "on (!)" or "off", sshOn() and "STILL ON" or "off",
                NetworkMgr.pending_connection and " | a connect was still pending (!)" or "")
        end)
        return r
    elseif h == "onResume" then
        pcall(startTest, "woke up")
        local r = orig_bc(self, ev, ...)
        pcall(function()
            log("wake handled | Wi-Fi radio %s | SSH %s (expected off after sleep)",
                NetworkMgr:isWifiOn() and "on" or "off", sshOn() and "ON (!)" or "off")
        end)
        return r
    elseif h and NET_EVENTS[h] then
        pcall(function()
            log("event: %s | Wi-Fi radio %s | SSH %s", h:sub(3), NetworkMgr:isWifiOn() and "on" or "off",
                sshOn() and "on" or "off")
        end)
    end
    return orig_bc(self, ev, ...)
end

-- --------------------------------------------------------------------------
-- Screen: popups, taps, tap-through, highlights, slow redraws
-- --------------------------------------------------------------------------

local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    if on() and type(w) == "table" and (w.text or w.title) then
        pcall(function()
            log("show %s%s", describe(w), Device.screen_saver_mode and "  <-- OVER THE SLEEP SCREEN (!)" or "")
        end)
    end
    return orig_show(self, w, ...)
end

local orig_close = UIManager.close
UIManager.close = function(self, w, ...)
    if on() and type(w) == "table" and (w.text or w.title) then pcall(log, "close %s", describe(w)) end
    return orig_close(self, w, ...)
end

-- The last tap, and whether it landed on a banner / note on top.
local last_tap = { at = 0 }
local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    if on() and type(ev) == "table" and ev.handler == "onGesture" then
        local g = ev.args and ev.args[1]
        if type(g) == "table" and (g.ges == "tap" or g.ges == "hold") then
            local area, toast = toastArea()
            local on_toast = inside(g.pos, area)
            last_tap = { at = os.time(), on_toast = on_toast, toast = toast }
            pcall(function()
                log("%s at %s,%s (on top: %s%s)", g.ges, q(g.pos and g.pos.x), q(g.pos and g.pos.y),
                    describe(topWidget()), on_toast and ", tap is ON it" or "")
            end)
        end
    end
    return orig_send(self, ev, ...)
end

-- A button that fires right after a tap on a banner = the tap leaked through.
local function leakCheck(kind, label)
    if on() and last_tap.on_toast and os.time() - last_tap.at <= 1 then
        pcall(log, "TAP WENT THROUGH %s to %s \"%s\" underneath (!)", describe(last_tap.toast), kind, q(label))
    end
end
local ok_b, Button = pcall(require, "ui/widget/button")
if ok_b and type(Button) == "table" and Button.onTapSelectButton then
    local orig = Button.onTapSelectButton
    Button.onTapSelectButton = function(self, ...)
        leakCheck("button", self.text or self.icon)
        return orig(self, ...)
    end
end
local ok_i, IconButton = pcall(require, "ui/widget/iconbutton")
if ok_i and type(IconButton) == "table" and IconButton.onTapIconButton then
    local orig = IconButton.onTapIconButton
    IconButton.onTapIconButton = function(self, ...)
        leakCheck("icon", self.icon)
        return orig(self, ...)
    end
end

-- Touch highlight (invert) drawn under a banner / note.
local orig_invert = UIManager.widgetInvert
if type(orig_invert) == "function" then
    UIManager.widgetInvert = function(self, w, x, y, wd, ht, ...)
        if on() then
            local area, toast = toastArea()
            local d = { x = x or (w and w.dimen and w.dimen.x), y = y or (w and w.dimen and w.dimen.y) }
            if area and inside(d, area) and w ~= toast then
                pcall(log, "TOUCH HIGHLIGHT under %s (a tap reached the screen behind it) (!)", describe(toast))
            end
        end
        return orig_invert(self, w, x, y, wd, ht, ...)
    end
end

-- Slow redraws, timed from the repaint hook (no timers): only reported
-- while a test is recent.
local orig_repaint = UIManager._repaint
if type(orig_repaint) == "function" then
    UIManager._repaint = function(self, ...)
        if not on() or os.time() > test_until then return orig_repaint(self, ...) end
        local t = now()
        local r = orig_repaint(self, ...)
        local d = ms(t)
        if d > 250 then pcall(log, "slow redraw: %dms (on top: %s)", d, describe(topWidget())) end
        return r
    end
end

-- One notice so you know it's on (only while logging).
UIManager:nextTick(function()
    note(string.format("Network Tweaks diagnostics: logging for %d min", ACTIVE_MINUTES))
end)
