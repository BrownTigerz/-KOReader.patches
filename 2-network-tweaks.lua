--[[
Network Tweaks (userpatch)
==========================
Version: 1.5.2

Menu: Settings (gear) → Network → Network Tweaks
      (or Tools → Add-ons, if 2-tweaks-menu.lua is installed)

  Stop SSH server on sleep                      (default: on)
    Stops KOReader's SSH server when the device sleeps, like Wi-Fi. It is
    NOT restarted on wake. Without this, SSH quietly becomes reachable
    again as soon as Wi-Fi reconnects. Silent, closes open sessions.

  SSH follows Wi-Fi                             (default: off)
    SSH starts when you turn Wi-Fi on (toolbar, gesture, menu, prompts)
    and stops whenever Wi-Fi goes off, however that happens. Not started
    by the automatic reconnect after waking, so SSH stays off after sleep.
    Handy for pushing patches.

  Wi-Fi, SSH & Calibre notifications           (default: Banner)
    One style for Wi-Fi on/off, SSH on/off and the Calibre wireless
    connection, whichever way you trigger them (toolbar, gesture, menu,
    prompts, start-on-connect).
    - Normal:  stock KOReader. Popups; Wi-Fi waits until connected.
    - Minimal: Wi-Fi connects in the background. Small corner notes, top
               right: "Wi-Fi connected", "Wi-Fi off", "SSH on", "SSH off",
               "Calibre connected", "Calibre off".
    - Banner:  Wi-Fi connects in the background with a banner at the top
               ("Connecting to Wi-Fi… tap here to cancel"), then
               "Connected to <network>". SSH shows what you need to
               connect: "SSH on · 192.168.1.23:2222". Calibre shows the
               server it connected to.
    Calibre's own "Searching… / Connecting… (tap to cancel)" messages stay:
    they're how you cancel a Calibre connect. Set a fixed server address
    (Calibre → Wireless settings) to skip the search step.
    Popups and the UI freeze are gone in Minimal and Banner. A failed
    Wi-Fi connect always shows a note at the top: tap it to choose a
    network.
    Background connect uses the device's Wi-Fi config, the same one the
    automatic reconnect on wake uses. On Kobo that's networks joined in
    Kobo's own Wi-Fi settings; networks joined only in KOReader aren't in
    it. If that config has no networks, the Normal flow is used instead.
    Long-press the Wi-Fi toggle in the network menu for the normal flow
    with the network list. Background connect needs Kobo or Kindle.
    Other patches can use the same style (ShelfSync tweaks does).

  Cancel Wi-Fi connection
    Stops a background connect in progress. You can also tap the banner,
    or tap the Wi-Fi toggle (toolbar/gesture) again. A connect in progress
    is also cancelled when the device goes to sleep.

Changelog
  1.5.2  SSH start/stop in Minimal and Banner no longer builds the SSH
         plugin's popup (icon render, text layout) only to throw it away.
         Internal: note() and the shared hook are one function.
  1.5.1  Other patches can show notes in the chosen style
         (NetworkMgr.__network_tweaks_note). ShelfSync tweaks uses it for
         its sync messages, and its corner notes stack with these instead
         of overlapping.
  1.5.0  Fix: cancelling a background connect didn't stop it. KOReader
         kills the restore script by a name the system truncates, so it
         never matched and the connect carried on (more obvious once the
         network was known and connected fast). The connect scripts are
         now stopped properly before Wi-Fi is powered down. "Start SSH"
         becomes "SSH follows Wi-Fi": Wi-Fi off also turns SSH off, with
         one combined note. Toolbar indicators are told after Wi-Fi off
         and cancel. No notes drawn over the sleep screen. Menu renamed
         Network Tweaks.
  1.4.2  Fix: SSH failed to stop ("dropbear process did not exit"), on
         sleep and when toggling it off. KOReader's SSH plugin waits for
         dropbear with a sleep that rounds 0.1s down to nothing, so it gave
         up instantly. Replaced with a stop that really waits (also treats
         an unreaped zombie as stopped).
  1.4.1  Fix: SSH could stay on through sleep. KOReader stops delivering
         the sleep event inside a screen as soon as one module or plugin
         claims it, so depending on installed plugins the SSH plugin never
         heard about it. Sleep is now caught where it's sent. Toolbar
         indicators are told after waking. Version line removed from the
         menu (it's in crash.log on startup).
  1.4.0  Fix: with "Start SSH" on, the automatic Wi-Fi reconnect on wake
         restarted SSH right after it was stopped for sleep. It now only
         follows a Wi-Fi connect you asked for. Sleep logs SSH state.
         Calibre wireless connection: connected / disconnected notes in
         the chosen style (stock shows nothing on connect). Server-side
         disconnect popups replaced outside Normal. Sends a state-changed
         event so toolbar indicators update right away (Icon Tweaks 1.9.0).
  1.3.0  Notification style covers SSH and turning Wi-Fi off too. Silent
         becomes Minimal: small corner notes, top right. Banner shows the
         SSH address and port. SSH's 10s popup and the "Turning off
         Wi-Fi…" / "Wi-Fi off." popups are replaced outside Normal.
  1.2.0  Failure note is tappable: opens the normal connect flow with the
         network list. Normal flow is used straight away when the device
         has no saved networks to reconnect to (Kobo). Connected note
         names the network. New option: start SSH when Wi-Fi connects.
         Shows in Tools → Add-ons when 2-tweaks-menu.lua is installed.
  1.1.1  Silent style now shows the failure note too.
  1.1.0  Connect style choice (Normal / Silent / Banner). Cancel a
         background connect. Cancel on sleep.
  1.0.0  First release. Replaces ssh-stop-on-sleep 1.1.0.
--]]

local PATCH_VERSION = "1.5.2"

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local Notification = require("ui/widget/notification")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local userpatch = require("userpatch")
local _ = require("gettext")
local Screen = Device.screen

if NetworkMgr.__network_tweaks then return end
NetworkMgr.__network_tweaks = true

local ADDON_ID = "network_tweaks"

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local SETTINGS_KEY = "network_tweaks"
-- "silent" is Minimal (id kept so saved settings carry over).
local STYLES = { normal = true, silent = true, banner = true }

local function settings()
    return G_reader_settings:readSetting(SETTINGS_KEY) or {}
end

local function set(key, value)
    local t = settings()
    t[key] = value
    G_reader_settings:saveSetting(SETTINGS_KEY, t)
end

local function sshStopOnSleep()
    return settings().ssh_stop_on_sleep ~= false
end

local function sshStartOnConnect()
    return settings().ssh_start_on_connect == true
end

local function connectStyle()
    local t = settings()
    if STYLES[t.connect_style] then return t.connect_style end
    -- Carry over 1.0.0 settings.
    if t.quiet_connect == false then return "normal" end
    if t.quiet_toast == false then return "silent" end
    return "banner"
end

local function readLine(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line
end

---------------------------------------------------------------------------
-- Notes: top banner (Banner style) and small corner note (Minimal style)
---------------------------------------------------------------------------

local function flash(text, timeout)
    UIManager:show(Notification:new{ text = text, timeout = timeout or 2 })
end

-- Small toast in the top-right corner. Toasts never block input; this one
-- ignores it entirely and just times out. Several stack downwards.
local corner_open = {}

local CornerNote = WidgetContainer:extend{
    toast = true,
    text = "",
    timeout = 2,
}

function CornerNote:init()
    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.thin,
        radius = Size.radius.default,
        padding = Size.padding.small,
        padding_left = Size.padding.default,
        padding_right = Size.padding.default,
        TextWidget:new{ text = self.text, face = Font:getFace("x_smallinfofont") },
    }
    self[1] = self.frame
    local sz = self.frame:getSize()
    local margin = Screen:scaleBySize(6)
    local y = margin
    for _i, n in ipairs(corner_open) do y = y + n.dimen.h + margin end
    self.dimen = Geom:new{ x = Screen:getWidth() - sz.w - margin, y = y, w = sz.w, h = sz.h }
end

function CornerNote:onShow()
    table.insert(corner_open, self)
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    self._close = function() UIManager:close(self) end
    UIManager:scheduleIn(self.timeout, self._close)
    return true
end

function CornerNote:onCloseWidget()
    if self._close then UIManager:unschedule(self._close) end
    for i, n in ipairs(corner_open) do
        if n == self then table.remove(corner_open, i) break end
    end
    UIManager:setDirty(nil, function() return "ui", self.dimen end)
end

local function corner(text, timeout)
    UIManager:show(CornerNote:new{ text = text, timeout = timeout or 2 })
end

-- One call per event: Banner text, Minimal text (falls back to the Banner
-- text), timeout. Normal shows nothing here: the stock popups are left
-- alone in Normal, and other patches show their own popup there.
-- Shared with other patches (ShelfSync tweaks), so their notes use the same
-- style and their corner notes stack with these instead of overlapping.
local function note(banner_text, minimal_text, timeout)
    if Device.screen_saver_mode then return end -- never over the sleep screen
    local style = connectStyle()
    if style == "banner" then
        flash(banner_text, timeout)
    elseif style == "silent" then
        corner(minimal_text or banner_text, timeout)
    end
end
NetworkMgr.__network_tweaks_note = note

-- Tells toolbar indicators (Icon Tweaks) that SSH / Calibre changed, so
-- they repaint now instead of waiting for a catch-up timer.
local function stateChanged()
    UIManager:nextTick(function()
        UIManager:broadcastEvent(Event:new("NetworkTweaksStateChanged"))
    end)
end

-- Banner-like toast: persistent, tap on it to act, rest of screen usable.
local Banner = Notification:extend{
    timeout = false,
    on_tap = nil,
}

function Banner:onGesture(ev)
    local dimen = self.frame and self.frame.dimen
    if ev and ev.pos and dimen and ev.pos:intersectWith(dimen) then
        local is_tap = ev.ges == "tap"
        -- Toasts can't stop propagation, so neuter the gesture: otherwise
        -- the tap would also land on the page/menu under the banner.
        ev.ges = "network_tweaks_banner"
        if is_tap and self.on_tap then self.on_tap() end
    end
    return false
end

function Banner:onKeyPress() return false end
function Banner:onKeyRepeat() return false end

-- Run fn with plugin/stock popups swallowed (InfoMessage & co., never
-- toasts). Returns pcall's ok, err and whether a warning popup was
-- swallowed (that's how the SSH plugin reports failure).
-- InfoMessages aren't even built: the plugin just gets its own arguments
-- back (text, icon), which is all the show() check below looks at.
local function withoutPopups(fn, ...)
    local warned = false
    local own_new = rawget(InfoMessage, "new") -- normally nil (inherited)
    InfoMessage.new = function(_cls, o) return o or {} end
    local orig_show = UIManager.show
    UIManager.show = function(um, widget, ...)
        if type(widget) == "table" and widget.text and not widget.toast then
            if widget.icon == "notice-warning" then warned = true end
            return
        end
        return orig_show(um, widget, ...)
    end
    local ok, err = pcall(fn, ...)
    UIManager.show = orig_show
    InfoMessage.new = own_new
    return ok, err, warned
end

---------------------------------------------------------------------------
-- User-initiated Wi-Fi connects (vs the automatic reconnect on wake)
---------------------------------------------------------------------------

local USER_CONNECT_WINDOW_S = 90
local user_connect_at -- os.time() of the last Wi-Fi connect the user asked for

local function markUserConnect()
    user_connect_at = os.time()
end

local function recentUserConnect()
    return user_connect_at ~= nil
        and os.difftime(os.time(), user_connect_at) <= USER_CONNECT_WINDOW_S
end

---------------------------------------------------------------------------
-- SSH
---------------------------------------------------------------------------

local SSH_PID_FILE = "/tmp/dropbear_koreader.pid"
local SSH_DEFAULT_PORT = 2222

local function sshRunning()
    return lfs.attributes(SSH_PID_FILE, "mode") == "file"
end

local function sshInstance()
    local ok, PluginLoader = pcall(require, "pluginloader")
    if ok and type(PluginLoader) == "table" and PluginLoader.getPluginInstance then
        local ok2, inst = pcall(PluginLoader.getPluginInstance, PluginLoader, "SSH")
        if ok2 then return inst end
    end
end

-- First IPv4 address, preferring the wireless interface. Reads interfaces
-- directly (Device:retrieveNetworkInfo also pings the gateway).
local function localIPv4()
    local ok_ni, NetInfo = pcall(require, "ffi/netinfo")
    if not ok_ni then return nil end
    local ok, ip = pcall(function()
        local ni = NetInfo:new()
        local found
        for _i, iface in ipairs(ni:retrieve()) do
            if iface.ipv4 and iface.name ~= "lo" then
                if iface.wireless then found = iface.ipv4 break end
                found = found or iface.ipv4
            end
        end
        ni:free()
        return found
    end)
    return ok and ip or nil
end

-- Upstream SSH:stopPlugin() waits for dropbear with ffiutil.sleep(0.1), but
-- on Linux that's C sleep(), which takes whole seconds: 0.1 becomes 0, so it
-- never waits and reports "dropbear process did not exit" before dropbear has
-- had a moment to quit (the pid file stays, so SSH still looks on). This is a
-- drop-in replacement that actually waits.

-- Gone, or a zombie (dead, just not reaped yet). Reaps it if it's ours.
local function procGone(pid)
    pcall(ffiutil.isSubProcessDone, pid)
    local stat = readLine("/proc/" .. pid .. "/stat")
    if not stat then return true end
    return stat:match("^%d+ %b() (%a)") == "Z"
end

local function closeKindleFirewall(ssh)
    if not Device:isKindle() then return end
    local port = tonumber(ssh and ssh.SSH_port) or SSH_DEFAULT_PORT
    os.execute(string.format(
        "iptables -D INPUT -p tcp --dport %d -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null", port))
    os.execute(string.format(
        "iptables -D OUTPUT -p tcp --sport %d -m conntrack --ctstate ESTABLISHED -j ACCEPT 2>/dev/null", port))
end

-- force: also end open sessions, and SIGKILL if TERM isn't enough.
local function stopDropbear(ssh, force)
    if not sshRunning() then return true end

    local pid = tonumber(readLine(SSH_PID_FILE) or "")
    local comm = pid and readLine("/proc/" .. pid .. "/comm")
    if comm and not comm:find("dropbear", 1, true) then
        -- Never signal a PID that isn't dropbear (stale pid file, PID reuse).
        logger.warn("network-tweaks: stale SSH pid file, removed without signalling")
    elseif comm and not procGone(pid) then
        local function send(sig, children)
            os.execute(string.format("%skill -%s %d 2>/dev/null",
                children and string.format("pkill -%s -P %d 2>/dev/null; ", sig, pid) or "", sig, pid))
        end
        send("TERM", force)
        for _i = 1, 30 do -- up to 3s, usually done in well under 1s
            if procGone(pid) then break end
            ffiutil.usleep(100000)
        end
        if not procGone(pid) and force then
            send("KILL", true)
            for _i = 1, 10 do
                if procGone(pid) then break end
                ffiutil.usleep(100000)
            end
        end
        if not procGone(pid) then
            return false, "dropbear process did not exit"
        end
    end

    os.remove(SSH_PID_FILE)
    closeKindleFirewall(ssh)
    return true
end

local function stopSSHForSleep(ssh)
    if not sshRunning() then return end
    local ok, res, err = pcall(stopDropbear, ssh, true)
    if ok and res then
        logger.info("network-tweaks: SSH server stopped for sleep")
    else
        logger.warn("network-tweaks: could not stop SSH for sleep:", ok and err or res)
    end
end

userpatch.registerPatchPluginFunc("SSH", function(SSH)
    if SSH.__network_tweaks then return end
    SSH.__network_tweaks = true

    -- Replaces the upstream version (see stopDropbear). Also used by the
    -- plugin's own stop(), so toggling SSH off is fixed too.
    SSH.stopPlugin = function(self, force)
        return stopDropbear(self, force)
    end

    -- Start/stop from anywhere (toolbar, gesture, menu, start-on-connect):
    -- the plugin's popups are swapped for our note, except in Normal.
    local orig_start = SSH.start
    if orig_start then
        SSH.start = function(self, ...)
            if connectStyle() == "normal" then return orig_start(self, ...) end
            local ok, err, warned = withoutPopups(orig_start, self, ...)
            if ok and not warned then
                local port = tostring(self.SSH_port or SSH_DEFAULT_PORT)
                local ip = localIPv4()
                logger.info("network-tweaks: SSH server started")
                note(ip and (_("SSH on · ") .. ip .. ":" .. port) or (_("SSH on · port ") .. port),
                     _("SSH on"), 4)
            else
                logger.warn("network-tweaks: SSH start failed:", err)
                note(_("SSH server failed to start"), _("SSH failed"), 3)
            end
            stateChanged()
        end
    end

    local orig_stop = SSH.stop
    if orig_stop then
        SSH.stop = function(self, ...)
            if connectStyle() == "normal" then return orig_stop(self, ...) end
            local ok, err, warned = withoutPopups(orig_stop, self, ...)
            if not ok then
                logger.warn("network-tweaks: SSH stop failed:", err)
                note(_("SSH server failed to stop"), _("SSH stop failed"), 3)
            elseif warned or sshRunning() then
                note(_("SSH off · open sessions stay until closed"), _("SSH off (sessions open)"), 3)
            else
                note(_("SSH off"), _("SSH off"))
            end
            stateChanged()
        end
    end

    local orig_connected = SSH.onNetworkConnected
    SSH.onNetworkConnected = function(self, ...)
        if sshStartOnConnect() and recentUserConnect() then
            UIManager:nextTick(function()
                if not sshRunning() and type(self.start) == "function" then
                    local ok, err = pcall(self.start, self)
                    if not ok then logger.warn("network-tweaks: SSH start on connect failed:", err) end
                end
            end)
        end
        if orig_connected then return orig_connected(self, ...) end
    end
end)

---------------------------------------------------------------------------
-- Calibre wireless connection
---------------------------------------------------------------------------
-- Stock: nothing on connect, a 2s popup when calibre drops the connection,
-- nothing on a manual disconnect. Here: one note each way, in the chosen
-- style. The connect itself (search, handshake, cancel) is untouched.

local calibre = {
    co = nil,              -- the plugin's connect coroutine
    connected = false,
    quiet_disconnect = false, -- sleep / closing the reader: no note
    host = nil, port = nil,
}

-- The plugin's own "connection dropped" popups; replaced by our note.
local orig_ui_show = UIManager.show
UIManager.show = function(um, widget, ...)
    if calibre.connected and type(widget) == "table" and connectStyle() ~= "normal" then
        local t = widget.text
        if t == _("Disconnected by calibre") or t == _("Disconnected from calibre (no activity)") then
            return
        end
    end
    return orig_ui_show(um, widget, ...)
end

-- The plugin clears its "Connecting…" message right after the handshake.
local orig_trapper_clear = Trapper.clear
Trapper.clear = function(self, ...)
    local res = orig_trapper_clear(self, ...)
    if calibre.co and coroutine.running() == calibre.co and not calibre.connected then
        local CW = package.loaded["wireless"]
        if type(CW) == "table" and CW.calibre_socket ~= nil then
            calibre.connected = true
            logger.info("network-tweaks: calibre connected")
            local where = calibre.host and (tostring(calibre.host) .. ":" .. tostring(calibre.port))
            note(where and (_("Calibre connected · ") .. where) or _("Calibre connected"),
                 _("Calibre connected"), 3)
            stateChanged()
        end
    end
    return res
end

userpatch.registerPatchPluginFunc("calibre", function(Calibre)
    local ok, CW = pcall(require, "wireless")
    if ok and type(CW) == "table" and not CW.__network_tweaks then
        CW.__network_tweaks = true

        local orig_init_mq = CW.initCalibreMQ
        if orig_init_mq then
            CW.initCalibreMQ = function(self, host, port, ...)
                calibre.host, calibre.port = host, port
                return orig_init_mq(self, host, port, ...)
            end
        end

        local orig_connect = CW.connect
        if orig_connect then
            CW.connect = function(self, ...)
                local co = coroutine.running()
                if co then calibre.co = co end
                return orig_connect(self, ...)
            end
        end

        local orig_disconnect = CW.disconnect
        if orig_disconnect then
            CW.disconnect = function(self, ...)
                local was = calibre.connected and self.calibre_socket ~= nil
                local by_server = self.disconnected_by_server
                orig_disconnect(self, ...)
                if was then
                    calibre.connected = false
                    logger.info("network-tweaks: calibre disconnected")
                    if not calibre.quiet_disconnect then
                        note(by_server and _("Calibre disconnected (by calibre)") or _("Calibre disconnected"),
                             _("Calibre off"))
                    end
                    stateChanged()
                end
            end
        end
    end

    if Calibre.__network_tweaks then return end
    Calibre.__network_tweaks = true
    -- Disconnects from closing the reader stay silent, like stock (sleep is
    -- handled where the sleep event is sent, see the end of this file).
    for _i, name in ipairs({ "onClose", "onCloseWidget" }) do
        local orig = Calibre[name]
        if orig then
            Calibre[name] = function(self, ...)
                calibre.quiet_disconnect = true
                local ok_c, res = pcall(orig, self, ...)
                calibre.quiet_disconnect = false
                if not ok_c then error(res, 0) end
                return res
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Wi-Fi: background connect
---------------------------------------------------------------------------

local GIVE_UP_S = 20 -- restore script gives up after ~15s
local WATCH_S = 2
local quiet -- in-flight attempt: { started, style, banner }

-- Same lookup order as KOReader's platform/kobo/enable-wifi.sh.
local KOBO_WPA_CONFS = {
    "/mnt/onboard/.kobo/wpa_supplicant.conf",
    "/etc/wpa_supplicant/wpa_supplicant.conf",
}

-- Whether background restore has anything to reconnect to. Only checkable
-- on Kobo; elsewhere assume yes and let the attempt decide.
local function hasKnownNetworks()
    if not Device:isKobo() then return true end
    for _i, path in ipairs(KOBO_WPA_CONFS) do
        if lfs.attributes(path, "mode") == "file" then
            local f = io.open(path, "r")
            if not f then return true end
            local s = f:read("*a") or ""
            f:close()
            return s:find("network%s*=%s*{") ~= nil
        end
    end
    return true
end

local function quietSupported()
    return Device:hasWifiRestore() and NetworkMgr.restoreWifiAsync ~= nil
end

local function canQuiet()
    if connectStyle() == "normal" or not quietSupported() then return false end
    if not hasKnownNetworks() then
        logger.info("network-tweaks: no saved networks for background connect, using normal flow")
        return false
    end
    return true
end

local function currentSSID()
    local ok, nw = pcall(NetworkMgr.getCurrentNetwork, NetworkMgr)
    return ok and type(nw) == "table" and nw.ssid or nil
end

local function endQuiet()
    if quiet and quiet.banner then
        UIManager:close(quiet.banner)
        quiet.banner = nil
    end
    quiet = nil
end

local function cancelQuiet(silent)
    local attempt = quiet
    if not attempt then return end
    logger.info("network-tweaks: background connect cancelled")
    endQuiet()
    -- Kills the restore script, stops the check, powers Wi-Fi down,
    -- clears wifi_was_on (so it won't auto-restore on wake).
    NetworkMgr:disableWifi(nil, true)
    if not silent then
        note(_("Wi-Fi connection cancelled"), _("Wi-Fi cancelled"))
    end
    stateChanged()
end

-- Tappable failure note: opens the normal flow with the network list.
-- Shown at the top in every background style, so a failure is never missed.
local function failureNote()
    local fail
    fail = Banner:new{
        text = _("Wi-Fi: no known network in range · tap to choose one"),
        timeout = 6,
        on_tap = function()
            UIManager:close(fail)
            UIManager:nextTick(function()
                NetworkMgr:toggleWifiOn(nil, true, true) -- long-press: list
            end)
        end,
    }
    UIManager:show(fail)
end

local function watch(attempt)
    if quiet ~= attempt then return end
    if not NetworkMgr.pending_connection then
        -- Finished outside our callback (e.g. KOReader's blocking goOnlineToRun).
        endQuiet()
        return
    end
    if os.difftime(os.time(), attempt.started) >= GIVE_UP_S and not NetworkMgr:isWifiOn() then
        -- The restore script gave up and powered Wi-Fi down.
        logger.info("network-tweaks: background connect gave up")
        NetworkMgr:_abortWifiConnection()
        return
    end
    UIManager:scheduleIn(WATCH_S, watch, attempt)
end

local function quietConnect(callback)
    if quiet or NetworkMgr.pending_connection then
        logger.info("network-tweaks: connection attempt already in progress")
        return
    end

    local attempt = { started = os.time(), style = connectStyle() }
    quiet = attempt
    logger.info("network-tweaks: connecting Wi-Fi in the background (" .. attempt.style .. ")")

    UIManager:broadcastEvent(Event:new("NetworkConnecting"))
    NetworkMgr.pending_connection = true

    if attempt.style == "banner" then
        attempt.banner = Banner:new{
            text = _("Connecting to Wi-Fi… tap here to cancel"),
            on_tap = function() cancelQuiet() end,
        }
        UIManager:show(attempt.banner)
    end

    NetworkMgr:restoreWifiAsync()

    if NetworkMgr.pending_connectivity_check then
        NetworkMgr:unscheduleConnectivityCheck()
    end
    -- Upstream check handles NetworkConnected, wifi_was_on and pending_connection.
    NetworkMgr:scheduleConnectivityCheck(function()
        if quiet == attempt then
            endQuiet()
            local ssid = currentSSID()
            note(ssid and (_("Connected to ") .. ssid) or _("Wi-Fi connected"), _("Wi-Fi connected"))
        end
        if callback then callback() end
    end)

    UIManager:scheduleIn(WATCH_S, watch, attempt)
end

-- Turn Wi-Fi off without the "Turning off Wi-Fi…" / "Wi-Fi off." popups.
-- SSH stop that goes with Wi-Fi off ("SSH follows Wi-Fi"). Returns true if
-- SSH was running and is now stopped.
local function stopSSHWithWifi()
    if not (sshStartOnConnect() and sshRunning()) then return false end
    local ok, res, err = pcall(stopDropbear, sshInstance(), true)
    if ok and res then
        logger.info("network-tweaks: SSH stopped with Wi-Fi")
        return true
    end
    logger.warn("network-tweaks: could not stop SSH with Wi-Fi:", ok and err or res)
    note(_("SSH server failed to stop"), _("SSH stop failed"), 3)
    return false
end

local function quietOff(complete_callback)
    local ssh_stopped = stopSSHWithWifi()
    NetworkMgr:disableWifi(complete_callback, true)
    if ssh_stopped then
        note(_("Wi-Fi & SSH off"), _("Wi-Fi & SSH off"))
    else
        note(_("Wi-Fi off"), _("Wi-Fi off"))
    end
    stateChanged()
end

local orig_abort = NetworkMgr._abortWifiConnection
NetworkMgr._abortWifiConnection = function(self, ...)
    local attempt = quiet
    endQuiet()
    orig_abort(self, ...)
    if attempt then failureNote() end
end

local orig_disable = NetworkMgr.disableWifi
-- KOReader stops a background connect with `pkill restore-wifi-async.sh`,
-- but the kernel truncates process names to 15 characters
-- ("restore-wifi-as"), so that never matches and the connect carries on.
-- Match on the full command line instead (the [x] keeps pkill from matching
-- the shell running it), including the helper scripts it starts.
local function killConnectScripts()
    if not (Device:hasWifiRestore() and not Device:isKindle()) then return end
    os.execute("pkill -TERM -f '[r]estore-wifi-async.sh' 2>/dev/null;"
        .. " pkill -TERM -f '[e]nable-wifi.sh' 2>/dev/null;"
        .. " pkill -TERM -f '[o]btain-ip.sh' 2>/dev/null")
end

NetworkMgr.disableWifi = function(self, ...)
    local connecting = quiet ~= nil or self.pending_connection
    endQuiet()
    if connecting then
        killConnectScripts()
        ffiutil.usleep(200000) -- let them exit before Wi-Fi is torn down
    end
    return orig_disable(self, ...)
end

-- Menu toggle and the "Turn on Wi-Fi?" prompt. Long-press keeps the list.
local orig_toggle_on = NetworkMgr.toggleWifiOn
NetworkMgr.toggleWifiOn = function(self, complete_callback, long_press, interactive)
    if quiet then return end
    markUserConnect()
    if not long_press and not self:isWifiOn() and canQuiet() then
        return quietConnect(complete_callback)
    end
    return orig_toggle_on(self, complete_callback, long_press, interactive)
end

-- Menu toggle off.
local orig_toggle_off = NetworkMgr.toggleWifiOff
if orig_toggle_off then
    NetworkMgr.toggleWifiOff = function(self, complete_callback, interactive)
        if connectStyle() ~= "normal" then return quietOff(complete_callback) end
        return orig_toggle_off(self, complete_callback, interactive)
    end
end

-- "Action when Wi-Fi is off: Turn on" (runWhenOnline & co.).
local orig_wait = NetworkMgr.turnOnWifiAndWaitForConnection
NetworkMgr.turnOnWifiAndWaitForConnection = function(self, callback)
    if quiet then return end
    markUserConnect()
    if not self:isWifiOn() and canQuiet() then
        return quietConnect(callback)
    end
    return orig_wait(self, callback)
end

-- Toolbar / gesture actions. Toggle again while connecting = cancel.
local ok_nl, NetworkListener = pcall(require, "ui/network/networklistener")
if ok_nl and type(NetworkListener) == "table" then
    local orig_toggle = NetworkListener.onToggleWifi
    if orig_toggle then
        NetworkListener.onToggleWifi = function(self, ...)
            if quiet then cancelQuiet() return end
            if not NetworkMgr:isWifiOn() then
                markUserConnect()
                if canQuiet() then quietConnect() return end
            elseif connectStyle() ~= "normal" then
                quietOff()
                return
            end
            return orig_toggle(self, ...)
        end
    end

    local orig_info_on = NetworkListener.onInfoWifiOn
    if orig_info_on then
        NetworkListener.onInfoWifiOn = function(self, ...)
            if quiet then return end
            markUserConnect()
            if not NetworkMgr:isWifiOn() and canQuiet() then quietConnect() return end
            return orig_info_on(self, ...)
        end
    end

    local orig_info_off = NetworkListener.onInfoWifiOff
    if orig_info_off then
        NetworkListener.onInfoWifiOff = function(self, ...)
            if quiet then cancelQuiet() return end
            if connectStyle() ~= "normal" then quietOff() return end
            return orig_info_off(self, ...)
        end
    end
end

---------------------------------------------------------------------------
-- Menu: Settings → Network → Network tweaks (or Tools → Add-ons)
---------------------------------------------------------------------------

local function styleItem(style, text)
    return {
        text = text,
        radio = true,
        enabled_func = function() return style == "normal" or quietSupported() end,
        checked_func = function() return connectStyle() == style end,
        callback = function() set("connect_style", style) end,
        keep_menu_open = true,
    }
end

local function menuTable()
    return {
        text = _("Network Tweaks"),
        sub_item_table = {
            {
                text = _("Stop SSH server on sleep"),
                help_text = _("Stop the SSH server when the device sleeps. It is not restarted on wake."),
                checked_func = sshStopOnSleep,
                callback = function() set("ssh_stop_on_sleep", not sshStopOnSleep()) end,
                keep_menu_open = true,
            },
            {
                text = _("SSH follows Wi-Fi"),
                help_text = _("Start SSH when you turn Wi-Fi on, stop it whenever Wi-Fi goes off. Not started by the automatic reconnect after waking."),
                checked_func = sshStartOnConnect,
                callback = function() set("ssh_start_on_connect", not sshStartOnConnect()) end,
                keep_menu_open = true,
                separator = true,
            },
            {
                text = _("Wi-Fi, SSH & Calibre notifications:"),
                enabled = false,
            },
            styleItem("normal", _("Normal (KOReader popups)")),
            styleItem("silent", _("Minimal (small corner notes)")),
            styleItem("banner", _("Banner (top banner, SSH address)")),
            {
                text = _("Cancel Wi-Fi connection"),
                enabled_func = function() return quiet ~= nil end,
                callback = function() cancelQuiet() end,
            },
        },
    }
end

-- Tools → Add-ons (2-tweaks-menu.lua), via its shared registry.
local TM = package.loaded.tweaks_mods or {}
package.loaded.tweaks_mods = TM
TM.entries = TM.entries or {}
TM.entries[ADDON_ID] = {
    text = _("Network Tweaks"),
    build = function() return menuTable() end,
}

-- Checked at menu build time, so patch file order doesn't matter.
local function shownInAddons()
    return TM.active and (type(TM.shows) ~= "function" or TM.shows(ADDON_ID))
end

local orig_menu = NetworkMgr.getMenuTable
NetworkMgr.getMenuTable = function(self, common_settings)
    orig_menu(self, common_settings)
    if not shownInAddons() then
        common_settings.network_tweaks = menuTable()
    end
end

for _i, mod in ipairs({ "ui/elements/filemanager_menu_order", "ui/elements/reader_menu_order" }) do
    local ok, order = pcall(require, mod)
    if ok and type(order) == "table" and type(order.network) == "table" then
        local present = false
        for _j, v in ipairs(order.network) do
            if v == "network_tweaks" then present = true break end
        end
        if not present then
            -- No separator: it would dangle when the entry lives in Add-ons.
            table.insert(order.network, "network_tweaks")
        end
    end
end

---------------------------------------------------------------------------
-- Sleep / wake
---------------------------------------------------------------------------
-- KOReader broadcasts Suspend to every screen, but inside a screen it stops
-- at the first module or plugin whose handler returns true. Whether the SSH
-- plugin hears it depends on which plugins are installed and their order,
-- so sleep is handled here, where the event is sent.

local stopped_for_sleep = false

local function beforeSleep()
    user_connect_at = nil -- the reconnect on wake isn't the user's
    if quiet then cancelQuiet(true) end

    local running = sshRunning()
    logger.info("network-tweaks: going to sleep, SSH " .. (running and "running" or "not running")
        .. ", stop on sleep " .. (sshStopOnSleep() and "on" or "off"))
    if running and sshStopOnSleep() then
        stopSSHForSleep(sshInstance())
        stopped_for_sleep = not sshRunning()
        if not stopped_for_sleep then
            logger.warn("network-tweaks: SSH still running after stop")
        end
    end
end

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, event, ...)
    local handler = type(event) == "table" and event.handler
    if handler == "onSuspend" then
        local ok, err = pcall(beforeSleep)
        if not ok then logger.warn("network-tweaks: sleep handling failed:", err) end
        calibre.quiet_disconnect = true
        local ok_b, res = pcall(orig_broadcast, self, event, ...)
        calibre.quiet_disconnect = false
        if not ok_b then error(res, 0) end
        return res
    elseif handler == "onNetworkDisconnected" then
        local res = orig_broadcast(self, event, ...)
        -- Any other way Wi-Fi went off (Normal style, auto-disconnect...).
        -- Sleep is left to beforeSleep.
        if sshStartOnConnect() and sshRunning() and not Device.screen_saver_mode then
            UIManager:nextTick(function()
                if Device.screen_saver_mode then return end
                if stopSSHWithWifi() then
                    note(_("SSH off"), _("SSH off"))
                    stateChanged()
                end
            end)
        end
        return res
    elseif handler == "onResume" then
        local res = orig_broadcast(self, event, ...)
        if stopped_for_sleep then
            stopped_for_sleep = false
            stateChanged() -- toolbar indicators still show SSH on until told
        end
        return res
    end
    return orig_broadcast(self, event, ...)
end

logger.info("network-tweaks v" .. PATCH_VERSION)
