--[[
Network Tweaks (userpatch)
==========================
Version: 1.8.4

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

  Choose network…
    Scans (tap the scanning message to cancel) and lists networks:
    Connected, Saved, Saved · away (saved, not in range) or Open. Tap one
    for Reconnect / Edit password / Forget, or Disconnect when connected.
    Forget all saved, Rescan and Close at the bottom. Never connects by
    itself: with Wi-Fi off (Kobo) the radio comes up just for the scan, and
    closing the list without picking puts Wi-Fi back off. "Saved" here is
    KOReader's list; background connect uses the device's own saved
    networks (on Kobo, the ones joined in Kobo's Wi-Fi settings).
    Devices without wpa_supplicant use KOReader's own list.

  Notifications                                 (default: Banner)
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

  Cancel Wi-Fi connection (only shown while connecting)
    Stops a background connect in progress. You can also tap the banner,
    or tap the Wi-Fi toggle (toolbar/gesture) again. A connect in progress
    is also cancelled when the device goes to sleep.

Changelog (condensed; full history in the patches repo)
  1.8.4  reconnectOrShowNetworkMenu hooked too: in Banner/Minimal the
         stock "Scanning for networks…" / "Connected to network X"
         popups (requestToTurnOnWifi path, e.g. the Backup updater)
         are swapped for contract notes; Normal unchanged.
  1.8.3  turnOnWifiAndWaitForConnection: in Banner/Minimal the stock
         "Connecting to Wi-Fi…" popup is swapped for one contract
         notification (no more duplicates next to the caller's own
         note); Normal unchanged.
  1.8.2  Title case for all menu item texts (TK's cross-patch convention).
  1.8.1  Shared notification contract v1: note() returns whether it handled
         the note — true for banner/corner/sleep-suppressed, false for Normal
         so the caller shows its own default popup.
  1.8.0  Tidy-up: changelog condensed. "No known network · tap to choose
         one" opens Network Tweaks' own network list.
  1.7.x  Own network list: scans without freezing and can be cancelled;
         Connected / Saved / Join / Open, per-network Reconnect, Edit
         password, Forget, Disconnect; Forget all, Rescan, Close. Never
         connects by itself. Fixes from on-device diagnostics: empty
         list after power-up, hidden networks shown blank, wake reconnect
         run twice, SSH address shown before Wi-Fi had one, tapping Wi-Fi
         after Disconnect turning it off, dropped "then do X" requests.
  1.6.x  Menu reorganised (SSH toggles, Choose network, Notifications
         submenu). Shared NetworkMgr.__network_tweaks_choose_network.
  1.5.x  Cancel really stops a background connect (KOReader's pkill
         never matched). SSH follows Wi-Fi. Shared note style for other
         patches (NetworkMgr.__network_tweaks_note).
  1.4.x  Sleep caught where it's sent; SSH stop that actually waits
         (KOReader's rounded 0.1s down to 0). Calibre notes.
  1.0-1.3  SSH stop on sleep, background connect with Normal / Minimal /
         Banner styles, failure note, SSH address banner.
--]]

local PATCH_VERSION = "1.8.4"

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
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
local util = require("util")
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
    on_tap = nil, -- optional: tap on the note (e.g. cancel a scan)
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

function CornerNote:onGesture(ev)
    if not self.on_tap then return false end
    if ev and ev.pos and self.dimen and ev.pos:intersectWith(self.dimen) then
        local is_tap = ev.ges == "tap"
        -- Toasts can't stop propagation: neuter it so the page underneath
        -- doesn't also get the tap.
        ev.ges = "network_tweaks_note"
        if is_tap then self.on_tap() end
    end
    return false
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
-- Shared notification contract v1: returns true when the note was handled
-- (banner or corner note shown, or suppressed over the sleep screen), false
-- when the style is "normal" so the caller shows its own default popup.
-- Existing callers ignore the return value.
local function note(banner_text, minimal_text, timeout)
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local style = connectStyle()
    if style == "banner" then
        flash(banner_text, timeout)
        return true
    elseif style == "silent" then
        corner(minimal_text or banner_text, timeout)
        return true
    end
    return false
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
-- Stand-in for an InfoMessage that's never built: just its own arguments,
-- plus enough to survive the caller closing it.
local STUB_MT = { __index = { __nt_stub = true, handleEvent = function() return false end } }

local function withoutPopups(fn, ...)
    local warned = false
    local own_new = rawget(InfoMessage, "new") -- normally nil (inherited)
    InfoMessage.new = function(_cls, o) return setmetatable(o or {}, STUB_MT) end
    local orig_show, orig_close = UIManager.show, UIManager.close
    -- Only the InfoMessages stubbed above are swallowed. Anything else
    -- (a ConfirmBox, another patch's dialog) shows as normal.
    UIManager.show = function(um, widget, ...)
        if type(widget) == "table" and widget.__nt_stub then
            if widget.icon == "notice-warning" then warned = true end
            return
        end
        return orig_show(um, widget, ...)
    end
    UIManager.close = function(um, widget, ...)
        if type(widget) == "table" and widget.__nt_stub then return end
        return orig_close(um, widget, ...)
    end
    local ok, err = pcall(fn, ...)
    UIManager.show, UIManager.close = orig_show, orig_close
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
local ssh_ip_pending = false -- SSH on, its address not shown yet

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

-- Show "SSH on · address:port" once Wi-Fi has an IPv4 address. KOReader
-- counts Wi-Fi as connected as soon as the interface has any address, which
-- can come a moment before the IPv4 one (DHCP still finishing), so check
-- once a second for up to 10s. One check at a time; stops early if SSH
-- stops or the address shows up.
local ADDR_TRIES = 10
local addr_tick
local function noteSSHAddress(port)
    if addr_tick then UIManager:unschedule(addr_tick) end
    local tries = 0
    addr_tick = function()
        tries = tries + 1
        if not sshRunning() or Device.screen_saver_mode then addr_tick = nil return end
        local ip = localIPv4()
        if ip then
            addr_tick = nil
            if connectStyle() == "banner" then
                note(_("SSH on · ") .. ip .. ":" .. port, nil, 4)
            end
        elseif tries < ADDR_TRIES then
            UIManager:scheduleIn(1, addr_tick)
        else
            addr_tick = nil
        end
    end
    UIManager:scheduleIn(1, addr_tick)
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
        -- children: also signal dropbear's children (the open sessions) first.
        local function send(sig, children)
            local cmd = string.format("kill -%s %d 2>/dev/null", sig, pid)
            if children then
                cmd = string.format("pkill -%s -P %d 2>/dev/null; ", sig, pid) .. cmd
            end
            os.execute(cmd)
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
                -- No address yet (Wi-Fi off or still connecting): the note
                -- with it is shown when Wi-Fi connects.
                ssh_ip_pending = ip == nil
                if ip == nil and NetworkMgr:isConnected() then
                    -- Connected, IPv4 address still on its way.
                    ssh_ip_pending = false
                    noteSSHAddress(port)
                end
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
            ssh_ip_pending = false
            if addr_tick then UIManager:unschedule(addr_tick); addr_tick = nil end
            if connectStyle() == "normal" then return orig_stop(self, ...) end
            local ok, err, warned = withoutPopups(orig_stop, self, ...)
            if not ok or sshRunning() then
                -- Threw, or dropbear is still there: it didn't stop.
                logger.warn("network-tweaks: SSH stop failed:", err)
                note(_("SSH server failed to stop"), _("SSH stop failed"), 3)
            elseif warned then
                -- Server stopped, but the plugin says sessions are still open.
                note(_("SSH off · open sessions stay until closed"), _("SSH off (sessions open)"), 3)
            else
                note(_("SSH off"), _("SSH off"))
            end
            stateChanged()
        end
    end

    -- Wi-Fi connected (SSH address, SSH follows Wi-Fi) is handled where
    -- the event is sent: see onWifiConnected at the end of this file.
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
                -- Network Tweaks' own list (defined further down).
                NetworkMgr.__network_tweaks_choose_network()
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

-- Returns true if it took the request: started a background connect, or
-- joined the one already running (the callback then runs when that one
-- succeeds). Returns false when a stock connect is in progress, so the
-- caller falls back to KOReader's own flow, which knows how to wait for it.
-- Callbacks only run on success: a cancel or failure drops them, like stock.
local function quietConnect(callback)
    if quiet then
        logger.info("network-tweaks: joining the connect already in progress")
        if callback then table.insert(quiet.callbacks, callback) end
        return true
    end
    if NetworkMgr.pending_connection then
        logger.info("network-tweaks: stock connect in progress, leaving it to KOReader")
        return false
    end

    local attempt = { started = os.time(), style = connectStyle(), callbacks = {} }
    if callback then attempt.callbacks[1] = callback end
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

    -- A reconnect already running (the automatic one after waking): take it
    -- over instead of starting a second restore script next to it. Two at
    -- once both load the driver and fight over wpa_supplicant.
    if NetworkMgr.pending_connectivity_check then
        logger.info("network-tweaks: taking over the reconnect already running")
    else
        NetworkMgr:restoreWifiAsync()
    end

    if NetworkMgr.pending_connectivity_check then
        NetworkMgr:unscheduleConnectivityCheck()
    end
    -- Upstream check handles NetworkConnected, wifi_was_on and pending_connection.
    NetworkMgr:scheduleConnectivityCheck(function()
        -- Cancelled or failed meanwhile: nothing runs.
        if quiet ~= attempt then return end
        endQuiet()
        local ssid = currentSSID()
        note(ssid and (_("Connected to ") .. ssid) or _("Wi-Fi connected"), _("Wi-Fi connected"))
        for _i, cb in ipairs(attempt.callbacks) do
            local ok, err = pcall(cb)
            if not ok then logger.warn("network-tweaks: callback after connect failed:", err) end
        end
    end)

    UIManager:scheduleIn(WATCH_S, watch, attempt)
    return true
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
    local ok_c, was_connected = pcall(self.isConnected, self)
    was_connected = ok_c and was_connected
    endQuiet()
    orig_abort(self, ...)
    if attempt then failureNote() end
    -- KOReader's abort assumes Wi-Fi never connected, so it sends no
    -- "disconnected" event. If it just tore down a working connection,
    -- send it, so the toolbar, SSH follows Wi-Fi, Calibre etc. hear about it,
    -- and log who called it (this shouldn't happen).
    if was_connected and not self:isWifiOn() then
        logger.warn("network-tweaks: a connection abort turned off working Wi-Fi",
            debug.traceback("", 2))
        UIManager:broadcastEvent(Event:new("NetworkDisconnected"))
    end
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
    markUserConnect()
    if quiet or (not long_press and not self:isWifiOn() and canQuiet()) then
        if quietConnect(complete_callback) then return end
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
    markUserConnect()
    if quiet or (not self:isWifiOn() and canQuiet()) then
        if quietConnect(callback) then return end
    end
    if connectStyle() == "normal" then return orig_wait(self, callback) end
    -- Styled mode: swap the stock "Connecting to Wi-Fi…" popup for one
    -- contract notification. Otherwise the caller's own contract note
    -- (e.g. the Backup updater's) appears next to the bare stock popup.
    -- (No note when core started no connect: already connected, or the
    -- attempt was refused — core shows nothing there either.)
    local ok, res = withoutPopups(orig_wait, self, callback)
    if not ok then error(res, 0) end
    if res then note(_("Connecting to Wi-Fi…"), _("Connecting…")) end
    return res
end

-- Kobo/Kindle turnOnWifi (requestToTurnOnWifi, enableWifi & co.): the stock
-- "Scanning for networks…" / "Connected to network X" popups live here and
-- bypass the turnOnWifiAndWaitForConnection hook above, so they need their
-- own swap. (This is the path the Backup updater takes.)
local orig_reconnect = NetworkMgr.reconnectOrShowNetworkMenu
if orig_reconnect then
    NetworkMgr.reconnectOrShowNetworkMenu = function(self, complete_callback, interactive)
        if connectStyle() == "normal" then
            return orig_reconnect(self, complete_callback, interactive)
        end
        -- Styled mode: the caller's "Connecting…" contract note is already
        -- up; swap the stock scan/connected popups for contract notes.
        -- Failure UX stays with the caller (e.g. the Backup updater's own
        -- "Couldn't Connect" popup).
        local ok, success = withoutPopups(orig_reconnect, self, complete_callback, interactive)
        if not ok then error(success, 0) end
        if success then
            local ssid = currentSSID()
            note(ssid and (_("Connected to ") .. ssid) or _("Wi-Fi connected"), _("Wi-Fi connected"))
        end
        return success
    end
end

-- Toolbar / gesture actions. Toggle again while connecting = cancel.
-- Radio on, nothing connected and nothing connecting (e.g. after Disconnect
-- in the network list). Tapping Wi-Fi then means "connect", not "turn off".
local function halfOn()
    return NetworkMgr:isWifiOn() and not NetworkMgr:isConnected()
        and not NetworkMgr.pending_connection and not NetworkMgr.pending_connectivity_check
end

-- Power down first so the reconnect starts clean: the radio may have had
-- its networks switched off (network list) or the network removed
-- (Disconnect), which a reconnect alone wouldn't undo.
local function reconnectFromHalfOn()
    logger.info("network-tweaks: Wi-Fi on but not connected, reconnecting")
    markUserConnect()
    NetworkMgr:disableWifi(nil, true)
    UIManager:nextTick(function()
        if not quietConnect() then NetworkMgr:toggleWifiOn(nil, false, true) end
    end)
end

local ok_nl, NetworkListener = pcall(require, "ui/network/networklistener")
if ok_nl and type(NetworkListener) == "table" then
    local orig_toggle = NetworkListener.onToggleWifi
    if orig_toggle then
        NetworkListener.onToggleWifi = function(self, ...)
            if quiet then cancelQuiet() return end
            if not NetworkMgr:isWifiOn() then
                markUserConnect()
                if canQuiet() and quietConnect() then return end
            elseif halfOn() and canQuiet() then
                reconnectFromHalfOn()
                return
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
            if not NetworkMgr:isWifiOn() and canQuiet() and quietConnect() then return end
            if halfOn() and canQuiet() then reconnectFromHalfOn() return end
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
-- Choose network
---------------------------------------------------------------------------
-- Own network list instead of KOReader's: scans without freezing the screen
-- (cancellable), marks Connected / Saved networks, offers Reconnect / Forget
-- / Disconnect per network, Forget all saved, Rescan and Close. Built from a
-- plain button dialog, so it's one light widget; the scan result is reused
-- after each action, no rescan unless you ask.

-- KOReader's saved networks (settings/network.lua), keyed by SSID.
local function savedNetworks()
    local ok, nw = pcall(NetworkMgr.getAllSavedNetworks, NetworkMgr)
    return ok and nw and type(nw.data) == "table" and nw.data or {}
end

-- Same SSID decoding as KOReader's wpa_supplicant backend.
local function decodeSSID(ssid)
    local decoded = ssid:gsub("%f[\\]\\x(%x%x)", function(b)
        local c = string.char(tonumber(b, 16))
        return c == "\\" and "\\\\" or c
    end)
    return (decoded:gsub("\\\\", "\\"))
end

local function wpaCtrl()
    return Device:hasWifiManager() and type(NetworkMgr.wpa_supplicant) == "table"
        and NetworkMgr.wpa_supplicant.ctrl_interface or nil
end

local function wpaIface()
    local ok, name = pcall(NetworkMgr.getNetworkInterfaceName, NetworkMgr)
    return (ok and type(name) == "string" and name ~= "") and name or "wlan0"
end

local function execOK(r) return r == 0 or r == true end

-- Kobo: power the radio up for a scan without joining anything, without
-- freezing the screen. enable-wifi.sh (the same script KOReader uses) runs
-- in the background; we check every 0.25s for wpa_supplicant's control
-- socket, then disable all networks it would join on its own (in memory
-- only: they're back next time Wi-Fi is turned on). Returns a cancel
-- function; on_ready(ok) runs when it's up (or gave up after 15s).
local RADIO_TICK_S = 0.25
local RADIO_MAX_TICKS = 60

local function radioOnlyAsync(on_ready)
    logger.info("network-tweaks: Wi-Fi radio on for the network list (no auto-join)")
    os.execute("./enable-wifi.sh &")
    local ctrl = wpaCtrl()
    local ticks, cancelled = 0, false
    local tick
    tick = function()
        if cancelled then return end
        ticks = ticks + 1
        if ctrl and lfs.attributes(ctrl, "mode") == "socket" then
            local r = os.execute(string.format(
                "wpa_cli -i %s disable_network all >/dev/null 2>&1", wpaIface()))
            if execOK(r) then return on_ready(true) end
        end
        if ticks >= RADIO_MAX_TICKS then
            logger.warn("network-tweaks: Wi-Fi radio didn't come up")
            return on_ready(false)
        end
        UIManager:scheduleIn(RADIO_TICK_S, tick)
    end
    UIManager:scheduleIn(RADIO_TICK_S, tick)
    return function() cancelled = true; UIManager:unschedule(tick) end
end

-- Progress message in the notification style. With on_cancel, tapping it
-- cancels (banner / corner note: tap it; Normal: tap to dismiss).
local function progress(text, on_cancel)
    local style = connectStyle()
    local w
    if style == "banner" then
        w = Banner:new{ text = on_cancel and (text .. _(" · tap to cancel")) or text, on_tap = on_cancel }
    elseif style == "silent" then
        w = CornerNote:new{ text = on_cancel and (text .. _(" · tap to cancel")) or text,
                            timeout = 120, on_tap = on_cancel }
    else
        w = InfoMessage:new{ text = text, dismiss_callback = on_cancel }
    end
    UIManager:show(w)
    UIManager:forceRePaint()
    return w
end

-- Scan without blocking: start it, then check for results every 250ms
-- (non-blocking reads) until wpa_supplicant reports them. Returns a cancel
-- function. Backends other than wpa_supplicant fall back to the stock
-- (blocking, not cancellable) scan.
local SCAN_TICK_S = 0.25
local SCAN_MAX_TICKS = 48 -- ~12s, stock waits up to 20s

local function scanAsync(on_done)
    local ctrl = wpaCtrl()
    local ok_w, WpaClient = pcall(require, "lj-wpaclient/wpaclient")
    if not (ctrl and ok_w) then
        -- Stock list: SSIDs already decoded.
        UIManager:nextTick(function()
            local list, e = NetworkMgr:getNetworkList()
            on_done(list, e, { decoded = true })
        end)
        return function() end
    end
    local wcli, err = WpaClient.new(ctrl)
    if not wcli then
        UIManager:nextTick(function() on_done(nil, err) end)
        return function() end
    end

    local cancelled, finished = false, false
    local tick
    local function finish(results, e, how)
        if finished then return end
        finished = true
        UIManager:unschedule(tick)
        pcall(wcli.close, wcli)
        if not cancelled then on_done(results, e, how) end
    end
    -- Read the list the way KOReader does: drain pending events and stop
    -- listening first. Asking while still attached, with a burst of
    -- "access point found" events arriving, can hand the list to the wrong
    -- reply: it came back empty ("No networks found").
    local function results()
        pcall(wcli.readAllEvents, wcli, {})
        pcall(wcli.detach, wcli)
        local ok, res, e = pcall(wcli.getScanResults, wcli)
        if ok and type(res) == "table" and #res == 0 then
            ok, res, e = pcall(wcli.getScanResults, wcli) -- once more
        end
        if ok then return res, e end
        return nil, res
    end

    pcall(wcli.attach, wcli)
    local ok_s, reply, serr = pcall(wcli.doScan, wcli)
    if not ok_s or reply == nil then
        UIManager:nextTick(function() finish(nil, ok_s and serr or reply) end)
        return function() cancelled = true; finish() end
    end

    local ticks = 0
    tick = function()
        if finished then return end
        ticks = ticks + 1
        local evs = {}
        local ok_e, incoming = pcall(wcli.waitForEvent, wcli, 0)
        if ok_e and incoming then pcall(wcli.readAllEvents, wcli, evs) end
        -- Results are ready the moment wpa_supplicant says so.
        for _i, ev in ipairs(evs) do
            if ev.msg == "CTRL-EVENT-SCAN-RESULTS" then return finish(results()) end
        end
        if ticks >= SCAN_MAX_TICKS then
            -- No results event: what's there may be from an older scan.
            local res, e = results()
            return finish(res, e, { stale = true })
        end
        UIManager:scheduleIn(SCAN_TICK_S, tick)
    end
    UIManager:scheduleIn(SCAN_TICK_S, tick)
    return function() cancelled = true; finish() end
end

-- One entry per SSID (strongest access point), with saved/connected state.
-- Connected first, then saved, then by signal; saved networks that aren't
-- in range go last so they can still be forgotten.
local function buildList(results, decoded)
    local saved = savedNetworks()
    local cur
    local ok_c, c = pcall(NetworkMgr.getCurrentNetwork, NetworkMgr)
    if ok_c and type(c) == "table" and c.ssid then cur = c end
    -- NetworkMgr:getCurrentNetwork already decodes the SSID; raw scan
    -- results (straight from wpa_supplicant) don't.
    local cur_ssid = cur and cur.ssid

    local best, list = {}, {}
    for _i, r in ipairs(results or {}) do
        local ssid = r.ssid and (decoded and r.ssid or decodeSSID(r.ssid)) or ""
        -- Hidden networks broadcast no name, or one made of zero bytes the
        -- length of the real name: those showed as blank rows. They can't be
        -- joined by tapping anyway, so they're left out.
        local shown = ssid:gsub("%z", "")
        if shown:find("%S") then
            local q = (r.getSignalQuality and r:getSignalQuality()) or r.signal_quality or 0
            local e = best[ssid]
            if not e or q > e.signal_quality then
                r.ssid, r.signal_quality, r.flags = ssid, q, r.flags or ""
                -- Names that aren't valid UTF-8 get a replacement mark
                -- instead of drawing as nothing. Display only: the real
                -- name is kept for connecting.
                r.display = util.fixUtf8(shown, "?")
                best[ssid] = r
            end
        end
    end
    for ssid, nw in pairs(best) do
        local s = saved[ssid]
        if s then nw.password, nw.psk = s.password, s.psk end
        if cur_ssid == ssid then
            nw.connected = true
            nw.wpa_supplicant_id = cur.id
        end
        list[#list + 1] = nw
    end
    local function rank(nw) return nw.connected and 0 or (saved[nw.ssid] and 1 or 2) end
    table.sort(list, function(a, b)
        if rank(a) ~= rank(b) then return rank(a) < rank(b) end
        return a.signal_quality > b.signal_quality
    end)
    local away = {}
    for ssid, s in pairs(saved) do
        if not best[ssid] then
            away[#away + 1] = { ssid = ssid, password = s.password, psk = s.psk, flags = "", away = true }
        end
    end
    table.sort(away, function(a, b) return a.ssid:lower() < b.ssid:lower() end)
    for _i, nw in ipairs(away) do list[#list + 1] = nw end
    return list
end

local startScan, showPicker -- forward declarations

-- Done with the list. If the radio was only brought up for it and nothing
-- got connected, Wi-Fi goes back off.
local function finishPicker(state)
    if state.finished then return end
    state.finished = true
    if state.radio_only and not state.picked then
        logger.info("network-tweaks: network list closed without a pick, Wi-Fi back off")
        os.execute("pkill -TERM -f '[e]nable-wifi.sh' 2>/dev/null")
        UIManager:nextTick(function() NetworkMgr:disableWifi(nil, true) end)
    elseif state.disconnected and not state.picked and not NetworkMgr:isConnected() then
        -- Disconnected here and didn't pick another: don't leave the radio
        -- on with nothing connected (the toolbar would show Wi-Fi as on).
        logger.info("network-tweaks: list closed after a disconnect, Wi-Fi off")
        UIManager:nextTick(function() quietOff() end)
    end
end

local function closePicker(state)
    local d = state.dlg
    state.dlg = nil
    if d then UIManager:close(d) end
end

local function connectTo(state, nw)
    if nw.flags:find("WEP") then
        note(_("WEP networks aren't supported"), _("WEP not supported"), 3)
        return
    end
    closePicker(state)
    -- Only one network at a time.
    for _i, other in ipairs(state.list) do
        if other.connected and other ~= nw then
            pcall(NetworkMgr.disconnectNetwork, NetworkMgr, other)
            pcall(NetworkMgr.releaseIP, NetworkMgr)
            other.connected = nil
        end
    end

    local ok, err
    local function auth() ok, err = NetworkMgr:authenticateNetwork(nw) end
    if connectStyle() == "normal" then
        local pok, perr = pcall(auth)
        if not pok then ok, err = false, perr end
    else
        -- Stock "Authenticating…" popups replaced by one styled message.
        local info = progress(_("Connecting to ") .. nw.ssid .. "…")
        local pok, perr = withoutPopups(auth)
        UIManager:close(info)
        if not pok then ok, err = false, perr end
    end
    if not ok then
        logger.warn("network-tweaks: couldn't connect to", nw.ssid, err)
        note(err or _("Couldn't connect"), _("Couldn't connect"), 3)
        return showPicker(state)
    end

    local info = progress(_("Obtaining IP address…"))
    local ok_ip, ip_err = pcall(NetworkMgr.obtainIP, NetworkMgr)
    UIManager:close(info)
    if not ok_ip then
        logger.warn("network-tweaks: couldn't get an IP address:", ip_err)
        note(_("Couldn't get an IP address"), _("No IP address"), 3)
        return showPicker(state)
    end
    nw.connected = true
    state.picked = true
    logger.info("network-tweaks: connected to", nw.ssid, "from the network list")
    -- Announce it like any other connect, so the toolbar, "SSH follows
    -- Wi-Fi" and auto-restore on wake see it.
    markUserConnect()
    if not NetworkMgr.pending_connectivity_check then
        NetworkMgr:scheduleConnectivityCheck()
    end
    if connectStyle() == "normal" then
        UIManager:show(InfoMessage:new{ text = _("Connected to ") .. nw.ssid, timeout = 3 })
    else
        note(_("Connected to ") .. nw.ssid, _("Wi-Fi connected"))
    end
    finishPicker(state)
end

local function askPassword(state, nw, saved)
    local dlg
    local function go()
        local pw = dlg:getInputText() or ""
        if #pw == 0 and nw.flags:find("WPA") then
            UIManager:show(InfoMessage:new{ text = _("Password cannot be empty."), timeout = 2 })
            return
        end
        UIManager:close(dlg)
        if pw ~= nw.password then
            nw.password, nw.psk = pw, nil
            NetworkMgr:saveNetwork(nw)
        end
        connectTo(state, nw)
    end
    dlg = InputDialog:new{
        title = nw.display or nw.ssid,
        input = saved and nw.password or "",
        input_hint = _("password (leave empty for open networks)"),
        input_type = "text",
        text_type = "password",
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function()
                UIManager:close(dlg) -- the list is still underneath
            end },
            { text = _("Connect"), is_enter_default = true, callback = go },
        }},
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

local function forget(nw)
    NetworkMgr:deleteNetwork(nw)
    nw.password, nw.psk = nil, nil
end

-- Per-network actions.
local function networkActions(state, nw)
    local saved = savedNetworks()[nw.ssid] ~= nil
    local dlg
    -- The list stays open underneath: Back just closes this, no rebuild.
    local function back() UIManager:close(dlg) end
    local function row(text, fn)
        return {{ text = text, callback = function() UIManager:close(dlg); fn() end }}
    end

    local buttons = {}
    if nw.connected then
        table.insert(buttons, row(_("Disconnect"), function()
            local ok, _r, err = pcall(NetworkMgr.disconnectNetwork, NetworkMgr, nw)
            if not ok then err = _r end
            -- Check rather than trust: upstream does nothing without an id.
            local okc, cur = pcall(NetworkMgr.getCurrentNetwork, NetworkMgr)
            if okc and type(cur) == "table" and cur.ssid == nw.ssid then
                logger.warn("network-tweaks: disconnect from", nw.ssid, "didn't take:", err)
                note(_("Couldn't disconnect"), _("Disconnect failed"), 3)
                return showPicker(state)
            end
            pcall(NetworkMgr.releaseIP, NetworkMgr)
            nw.connected = nil
            state.disconnected = true
            stateChanged()
            showPicker(state)
        end))
    elseif not nw.away then
        if saved then
            table.insert(buttons, row(_("Reconnect"), function() connectTo(state, nw) end))
            table.insert(buttons, row(_("Edit password"), function() askPassword(state, nw, true) end))
        elseif not nw.flags:find("WPA") then
            -- Open network: nothing to ask.
            nw.password = ""
            return connectTo(state, nw)
        else
            return askPassword(state, nw, false)
        end
    end
    if saved then
        table.insert(buttons, row(_("Forget"), function()
            forget(nw)
            if nw.away then
                for i, other in ipairs(state.list) do
                    if other == nw then table.remove(state.list, i) break end
                end
            end
            showPicker(state)
        end))
    end
    table.insert(buttons, {{ text = _("Back"), callback = back }})
    dlg = ButtonDialog:new{
        title = nw.display or nw.ssid,
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(dlg)
end

-- Rows shown before "More networks…": building the dialog is the slow part
-- on e-ink devices (every row is laid out), and busy areas list dozens.
local PICKER_ROWS = 12

showPicker = function(state)
    if state.finished then return end
    closePicker(state)
    local saved = savedNetworks()
    local dlg
    local buttons = {}
    local status_w = Screen:scaleBySize(130)
    local shown = state.show_all and #state.list or math.min(#state.list, PICKER_ROWS)
    for i = 1, shown do
        local nw = state.list[i]
        local status
        if nw.connected then status = _("Connected")
        elseif nw.away then status = _("Saved · away")
        elseif saved[nw.ssid] then status = _("Saved")
        elseif not nw.flags:find("WPA") then status = _("Open")
        else status = _("Join") end
        local function tap() networkActions(state, nw) end
        table.insert(buttons, {
            { text = nw.display or nw.ssid, align = "left", callback = tap },
            { text = status, width = status_w, callback = tap },
        })
    end
    if shown < #state.list then
        table.insert(buttons, {{ text = string.format(_("More networks (%d)…"), #state.list - shown),
            callback = function()
                state.show_all = true
                showPicker(state)
            end }})
    end
    if #buttons == 0 then
        table.insert(buttons, {{ text = _("No networks found"), enabled = false }})
    end
    if next(saved) then
        table.insert(buttons, {{ text = _("Forget all saved networks"), callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Forget all saved networks?"),
                ok_text = _("Forget all"),
                ok_callback = function()
                    local ok, nws = pcall(NetworkMgr.getAllSavedNetworks, NetworkMgr)
                    if ok and nws then
                        for ssid in pairs(savedNetworks()) do nws:delSetting(ssid) end
                        nws:flush()
                    end
                    for i = #state.list, 1, -1 do
                        local nw = state.list[i]
                        nw.password, nw.psk = nil, nil
                        if nw.away then table.remove(state.list, i) end
                    end
                    showPicker(state)
                end,
            })
        end }})
    end
    table.insert(buttons, {
        { text = _("Rescan"), callback = function()
            closePicker(state)
            startScan(state)
        end },
        { text = _("Close"), callback = function()
            closePicker(state)
            finishPicker(state)
        end },
    })
    dlg = ButtonDialog:new{
        title = state.stale and _("Wi-Fi networks (last scan, may be out of date)") or _("Wi-Fi networks"),
        title_align = "center",
        buttons = buttons,
        rows_per_page = 14,
        tap_close_callback = function()
            state.dlg = nil
            finishPicker(state)
        end,
    }
    state.dlg = dlg
    UIManager:show(dlg)
end

startScan = function(state)
    local cancel_step
    local done = false
    local info
    info = progress(_("Scanning for networks…"), function()
        if done then return end
        done = true
        if cancel_step then cancel_step() end
        -- Banner / corner note stay until closed (a Normal popup closes
        -- itself when tapped).
        if info and info.toast then UIManager:close(info) end
        finishPicker(state)
    end)

    local function scan()
        if done then return end
        cancel_step = scanAsync(function(results, err, how)
            how = how or {}
            if done then return end
            done = true
            UIManager:close(info)
            if not results or (how.stale and #results == 0) then
                if connectStyle() == "normal" then
                    UIManager:show(InfoMessage:new{ text = err or _("Couldn't scan for networks"), timeout = 3 })
                else
                    note(err or _("Couldn't scan for networks"), _("Scan failed"), 3)
                end
                return finishPicker(state)
            end
            state.list = buildList(results, how.decoded)
            state.stale = how.stale
            showPicker(state)
        end)
    end

    if state.radio_only and not state.radio_up then
        state.radio_up = true
        cancel_step = radioOnlyAsync(function(ok)
            if done then return end
            if not ok then
                done = true
                UIManager:close(info)
                note(_("Wi-Fi didn't come up"), _("Wi-Fi failed"), 3)
                return finishPicker(state)
            end
            scan()
        end)
    else
        scan()
    end
end

-- Opens the network list, never connecting on its own.
-- Wi-Fi on: scan and list. Wi-Fi off (Kobo): radio up without joining
-- anything, then the list; closed without a pick, Wi-Fi goes back off.
-- Other devices (no wpa_supplicant): KOReader's own long-press flow.
-- Shared as NetworkMgr.__network_tweaks_choose_network (toolbar hold).
local function chooseNetwork()
    if not Device:hasWifiToggle() then return end
    if quiet then cancelQuiet(true) end -- you asked for the list instead
    local wifi_on = NetworkMgr:isWifiOn()

    if not wpaCtrl() or (not wifi_on and not Device:isKobo()) then
        markUserConnect()
        if wifi_on and NetworkMgr.reconnectOrShowNetworkMenu then
            NetworkMgr.wifi_toggle_long_press = true
            NetworkMgr:reconnectOrShowNetworkMenu(nil, true)
        else
            NetworkMgr:toggleWifiOn(nil, true, true)
        end
        return
    end
    startScan({ radio_only = not wifi_on })
end
NetworkMgr.__network_tweaks_choose_network = chooseNetwork

---------------------------------------------------------------------------
-- Menu: Settings → Network → Network Tweaks (or Tools → Add-ons)
---------------------------------------------------------------------------

local STYLE_LABELS = {
    normal = _("Normal"),
    silent = _("Minimal"),
    banner = _("Banner"),
}

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
        -- Built each time it's opened, so "Cancel" only shows while connecting.
        sub_item_table_func = function()
            local items = {
                {
                    text = _("Stop SSH Server On Sleep"),
                    help_text = _("Stop the SSH server when the device sleeps. It is not restarted on wake."),
                    checked_func = sshStopOnSleep,
                    callback = function() set("ssh_stop_on_sleep", not sshStopOnSleep()) end,
                    keep_menu_open = true,
                },
                {
                    text = _("SSH Follows Wi-Fi"),
                    help_text = _("Start SSH when you turn Wi-Fi on, stop it whenever Wi-Fi goes off. Not started by the automatic reconnect after waking."),
                    checked_func = sshStartOnConnect,
                    callback = function() set("ssh_start_on_connect", not sshStartOnConnect()) end,
                    keep_menu_open = true,
                    separator = true,
                },
                {
                    text = _("Choose Network…"),
                    enabled_func = function() return Device:hasWifiToggle() end,
                    callback = function() chooseNetwork() end,
                },
                {
                    text_func = function()
                        return _("Notifications: ") .. STYLE_LABELS[connectStyle()]
                    end,
                    help_text = _("One style for Wi-Fi, SSH and Calibre notes."),
                    sub_item_table = {
                        styleItem("normal", _("Normal (KOReader Popups)")),
                        styleItem("silent", _("Minimal (Small Corner Notes)")),
                        styleItem("banner", _("Banner (Top Banner, SSH Address)")),
                    },
                },
            }
            if quiet then
                items[#items].separator = true
                items[#items + 1] = {
                    text = _("Cancel Wi-Fi Connection"),
                    enabled_func = function() return quiet ~= nil end,
                    callback = function() cancelQuiet() end,
                }
            end
            return items
        end,
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

-- Wi-Fi connected. Done here rather than in the SSH plugin's own handler:
-- KOReader stops passing an event along inside a screen once a module or
-- plugin says it handled it, so whether the SSH plugin heard about the
-- connect depended on what else was installed (same as sleep, 1.4.1).
local function onWifiConnected()
    local ssh = sshInstance()
    local port = tostring(ssh and ssh.SSH_port or SSH_DEFAULT_PORT)
    if ssh_ip_pending and sshRunning() then
        -- SSH was started before Wi-Fi had an address: show it once it does.
        ssh_ip_pending = false
        noteSSHAddress(port)
    elseif sshStartOnConnect() and recentUserConnect() and not sshRunning()
            and ssh and type(ssh.start) == "function" then
        local ok, err = pcall(ssh.start, ssh)
        if not ok then logger.warn("network-tweaks: SSH start on connect failed:", err) end
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
    elseif handler == "onNetworkConnected" then
        local res = orig_broadcast(self, event, ...)
        UIManager:nextTick(onWifiConnected)
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
