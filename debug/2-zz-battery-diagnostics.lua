--[[
2-zz-battery-diagnostics.lua - battery drain troubleshooting patch for KOReader
Version 1.0.7

Finds where the battery goes, mostly while the device is asleep, and names
the plugin or patch behind it when it can. Writes to its own log:
    koreader/battery.log   (Kobo: .adds/koreader/battery.log)

What it records
  • Every start: device, firmware, KOReader version, battery, the power
    settings that matter (auto suspend, auto standby, auto shutdown, sleep
    cover, Wi-Fi restore, Keep alive) and every plugin and patch that's on.
    If the device went to sleep last time and never woke up (battery ran
    out, crash, forced reboot), it says so.
  • Every sleep: battery and time going to sleep and waking, drain per hour,
    how much of that time the device was really suspended, every suspend
    try (refused by the kernel, woke up early by itself, KOReader giving up
    and staying awake on the sleep screen), front light, Wi-Fi and
    Bluetooth going to sleep, while suspended (flagged if either never
    turned off) and right after waking,
    timers left waiting and alarms set to wake the device (and who set
    them), buttons and sleep cover events while asleep, and anything that
    set timers or turned Wi-Fi on while asleep.
  • Every awake stretch: drain per hour, battery draw in mA, CPU busy % and
    the processes using it, CPU governor and speed, front light, how long
    Wi-Fi was on and who turned it on, Bluetooth, time in standby, things blocking standby, and the
    busiest timers by plugin/patch.

Menu: Tools → Battery diagnostics
  • Battery report: totals since KOReader started, problems found, hints.
  • Scan plugins and patches: reads their code for things known to cost
    battery (wake alarms, Wi-Fi on wake or sleep, standby blocks, keep
    awake) and adds what this run actually saw from each one.
  • View battery.log / Clear battery.log

How to use
  1. Put this file in koreader/patches/ and restart KOReader.
  2. Use the device normally for a day or two, sleeping it as usual.
  3. Tools → Battery diagnostics → Battery report. Send battery.log.
  4. Done: delete this file (and battery.log), restart KOReader.

It changes no settings and stops nothing: every hook passes straight
through, and an error in here can't break the original. No timers of its
own: it only writes when the device goes to sleep, tries to suspend, wakes,
starts, or when you use its menu. Log capped at 1 MB (older part kept as
battery.log.old).

Changes:
  1.0.7 2026-11-09  The awake stretch (with CPU use) is also logged when KOReader
                    closes or restarts and when the Battery report is opened;
                    before, only going to sleep logged it.
  1.0.6 2026-11-09  Awake stretches show CPU busy %, the processes that used it,
                    CPU governor and speed, and the battery draw in mA; flags a
                    CPU busy 50%+ or stuck on "performance". Plugin list skips
                    macOS "._" files (counted, harmless).
  1.0.5 2026-11-08  Auto shutdown's wake-up alarm is named even when it was set
                    a while before the suspend (it counts from the last use).
  1.0.4 2026-11-08  No drain rate (or "normal") from a short stretch where the
                    battery barely moved: needs 30 min, or 2%+ over 10 min+.
                    Flags any plugin/patch setting 5+ timers a second while
                    awake.
  1.0.3 2026-11-08  Radios: Wi-Fi and Bluetooth state going to sleep, while
                    suspended (flagged if either never turned off), right
                    after waking, and at the end of each awake stretch.
                    Bluetooth from the Kobo plugin, else the kernel's rfkill.
  1.0.2 2026-11-08  "Really suspended" share leaves out KOReader's normal ~15 s
                    wait before suspending (short sleeps looked bad). Timers
                    "while asleep" only count early wake-ups, not the normal
                    wake. Auto shutdown's wake-up alarm is named. Wi-Fi restore
                    names who asked for it.
  1.0.1 2026-11-08  Kobo firmware version shows (was "?"). A sleep woken before
                    KOReader's first suspend try (it waits about 15 s) says so
                    instead of "never suspended".
  1.0.0 2026-11-08  First version.
]]

local VERSION = "1.0.7"
local SELF = "2-zz-battery-diagnostics"
local ID = "battery_diagnostics"

local DataStorage = require("datastorage")
local Device = require("device")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local ok_time, time = pcall(require, "ui/time")
if not ok_time then time = nil end

local DATA = DataStorage:getDataDir()
local LOG = DATA .. "/battery.log"
local LOG_MAX = 1024 * 1024

local BUILTIN = {}
for name in ([[SSH archiveviewer autodim autostandby autosuspend autoturn autowarmth batterystat
    bookshortcuts calibre cloudstorage coverbrowser coverimage docsettingtweak exporter
    externalkeyboard gestures hello hotkeys httpinspector japanese keepalive kosync
    movetoarchive newsdownloader opds perceptionexpander profiles qrclipboard readtimer
    statistics systemstat terminal texteditor timesync vocabbuilder wallabag]]):gmatch("%S+") do
    BUILTIN[name] = true
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- Seconds on a clock that keeps running while suspended.
local function clock()
    if time and time.boottime_or_realtime_coarse then
        local ok, v = pcall(time.boottime_or_realtime_coarse)
        if ok and v then return time.to_s(v) end
    end
    return os.time()
end

local function stamp(t)
    return (os.date("%Y-%m-%d %I:%M:%S %p", t or os.time()):gsub(" 0(%d:)", " %1"))
end

local function hhmm(t)
    return (os.date("%I:%M %p", t or os.time()):gsub("^0", ""))
end

local function dur(s)
    s = math.max(0, math.floor((s or 0) + 0.5))
    if s < 90 then return s .. " s" end
    if s < 5400 then return math.floor(s / 60 + 0.5) .. " min" end
    return string.format("%.1f h", s / 3600)
end

local function pct(v)
    return v and (tostring(v) .. "%") or "?"
end

local pack = table.pack or function(...) return { n = select("#", ...), ... } end

local function call(obj, name, ...)
    if obj and type(obj[name]) == "function" then
        local ok, v = pcall(obj[name], obj, ...)
        if ok then return v end
    end
    return nil
end

local function bump(tbl, key, n)
    tbl[key] = (tbl[key] or 0) + (n or 1)
end

-- "a ×3, b ×2" from a count table, biggest first.
local function topList(counts, max_n, skip_core)
    local arr = {}
    for k, v in pairs(counts) do
        if not (skip_core and k:find("^KOReader")) then arr[#arr + 1] = { k = k, v = v } end
    end
    table.sort(arr, function(a, b) return a.v > b.v end)
    local out = {}
    for i = 1, math.min(max_n or 5, #arr) do
        out[i] = arr[i].k .. " ×" .. arr[i].v
    end
    return table.concat(out, ", "), #arr
end

---------------------------------------------------------------------------
-- battery.log
---------------------------------------------------------------------------

local log_size
local function writeLines(lines)
    local ok, err = pcall(function()
        if log_size == nil then log_size = lfs.attributes(LOG, "size") or 0 end
        if log_size > LOG_MAX then
            os.remove(LOG .. ".old")
            os.rename(LOG, LOG .. ".old")
            log_size = 0
        end
        local f = io.open(LOG, "a")
        if not f then return end
        local ts = stamp()
        local out = {}
        for i, l in ipairs(lines) do out[i] = ts .. "  " .. l end
        local s = table.concat(out, "\n") .. "\n"
        f:write(s)
        f:close()
        log_size = log_size + #s
    end)
    if not ok then logger.warn("battery diagnostics: can't write battery.log:", err) end
end

local function write(line) writeLines({ line }) end

---------------------------------------------------------------------------
-- Who is it? (plugin / patch / KOReader)
---------------------------------------------------------------------------

local function short(src)
    src = tostring(src or "?"):gsub("^@", "")
    src = src:gsub("^.-frontend/", ""):gsub("^%./", ""):gsub("%.lua$", "")
    return src
end

local function classify(source)
    if type(source) ~= "string" then return nil end
    if source:find(SELF, 1, true) then return "self" end
    local p = source:match("([^/\\]+)%.koplugin[/\\]")
    if p then return BUILTIN[p] and ("plugin " .. p .. " (built-in)") or ("plugin " .. p) end
    local q = source:match("patches[/\\]([^/\\]+%.lua)")
    if q then return "patch " .. q end
    return nil
end

local src_cache = setmetatable({}, { __mode = "k" })
local function srcOf(fn)
    if type(fn) ~= "function" then return "?" end
    local c = src_cache[fn]
    if c then return c end
    local info = debug.getinfo(fn, "S")
    if not info then
        c = "?"
    elseif info.what == "C" then
        c = "KOReader (C)"
    else
        c = classify(info.source) or ("KOReader " .. short(info.source) .. ":" .. tostring(info.linedefined or 0))
    end
    src_cache[fn] = c
    return c
end

-- First plugin/patch on the call stack, else the nearest KOReader caller.
local function caller()
    local first
    for lvl = 3, 40 do
        local info = debug.getinfo(lvl, "S")
        if not info then break end
        local c = classify(info.source)
        if c and c ~= "self" then return c end
        if not first and c == nil and info.what ~= "C" then
            first = "KOReader " .. short(info.source) .. ":" .. tostring(info.linedefined or 0)
        end
    end
    return first or "KOReader"
end

---------------------------------------------------------------------------
-- Device state
---------------------------------------------------------------------------

local powerd = Device.powerd

local function battery()
    local v = call(powerd, "getCapacityHW")
    if type(v) ~= "number" then v = call(powerd, "getCapacity") end
    return type(v) == "number" and v or nil
end

local function charging()
    return call(powerd, "isCharging") and true or false
end

local function sysfs(name)
    local dir = (powerd and powerd.battery_sysfs) or Device.battery_sysfs
    if not dir then return nil end
    local f = io.open(dir .. "/" .. name, "r")
    if not f then return nil end
    local s = f:read("*l")
    f:close()
    return s
end

local function lightState()
    if not call(Device, "hasFrontlight") then return "none" end
    if not call(powerd, "isFrontlightOn") then return "off" end
    return "on " .. tostring(call(powerd, "frontlightIntensity") or "?") .. "%"
end

local function netmgr()
    return package.loaded["ui/network/manager"]
end

local function wifiOn()
    local nm = netmgr()
    if type(nm) ~= "table" then return false end
    return call(nm, "isWifiOn") and true or false
end

-- Radios. Wi-Fi from KOReader's network manager, else the kernel's rfkill
-- switches. Bluetooth from the Kobo plugin (kobo.koplugin) when it's there,
-- else rfkill. nil = can't tell on this device.
local function readLine(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local v = f:read("*l")
    f:close()
    return v
end

local function rfkill()
    local out = {}
    local ok, iter, dir_obj = pcall(lfs.dir, "/sys/class/rfkill")
    if not ok then return out end
    for entry in iter, dir_obj do
        if entry:match("^rfkill%d+$") then
            local base = "/sys/class/rfkill/" .. entry
            local kind, state = readLine(base .. "/type"), readLine(base .. "/state")
            if kind and state then out[kind] = out[kind] == true or state == "1" end
        end
    end
    return out
end

local function koboBluetooth()
    for i, path in ipairs({ "apps/reader/readerui", "apps/filemanager/filemanager" }) do
        local mod = package.loaded[path]
        local ui = mod and mod.instance
        local k = type(ui) == "table" and ui.kobo
        local bt = type(k) == "table" and k.kobo_bluetooth
        if type(bt) == "table" and type(bt.isBluetoothEnabled) == "function" then
            local ok, v = pcall(bt.isBluetoothEnabled, bt)
            if ok then return v and true or false end
        end
    end
    return nil
end

local function radios()
    local rf = rfkill()
    local wifi
    if type(netmgr()) == "table" then wifi = wifiOn() else wifi = rf.wlan end
    local bt = koboBluetooth()
    if bt == nil then bt = rf.bluetooth end
    return wifi, bt
end

-- CPU: governor, speed, and which processes used it. /proc is read only at
-- sleep, wake and start, never in between.
local CPU = "/sys/devices/system/cpu/cpu0/cpufreq/"

local function cpuState()
    local gov = readLine(CPU .. "scaling_governor") or readLine("/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")
    local khz = tonumber(readLine(CPU .. "scaling_cur_freq") or "")
    local load = (readLine("/proc/loadavg") or ""):match("^(%S+)")
    return gov, khz and math.floor(khz / 1000 + 0.5) or nil, load
end

local function cpuText()
    local gov, mhz, load = cpuState()
    if not gov and not mhz and not load then return nil end
    return string.format("CPU %s%s%s", gov or "?", mhz and (" " .. mhz .. " MHz") or "", load and (" | load " .. load) or "")
end

-- Battery current. Most Kobos report µA, some (e.g. Sage) mA: big numbers
-- are taken as µA. Returns mA, or nil.
local function currentMA()
    local v = tonumber(sysfs("current_now") or "")
    if not v then return nil end
    v = math.abs(v)
    if v > 20000 then v = v / 1000 end
    return math.floor(v + 0.5)
end

local function procSnapshot()
    local snap = { procs = {} }
    local stat = readLine("/proc/stat")
    if stat then
        local nums, total = {}, 0
        for num in stat:gmatch("%d+") do nums[#nums + 1] = tonumber(num) end
        for i = 1, math.min(#nums, 8) do total = total + nums[i] end
        snap.total = total
        snap.idle = (nums[4] or 0) + (nums[5] or 0)
    end
    local ok, iter, dir_obj = pcall(lfs.dir, "/proc")
    if not ok then return snap end
    for entry in iter, dir_obj do
        if entry:match("^%d+$") then
            local line = readLine("/proc/" .. entry .. "/stat")
            local comm, rest
            if line then comm, rest = line:match("^%d+ %((.*)%) (.*)$") end
            if rest then
                local f = {}
                for field in rest:gmatch("%S+") do f[#f + 1] = field end
                local t = (tonumber(f[12]) or 0) + (tonumber(f[13]) or 0)
                snap.procs[entry] = { comm = comm, t = t }
            end
        end
    end
    return snap
end

-- CPU busy % over the stretch and the top processes (share of one core).
local function cpuUse(before, secs)
    if not before or secs < 30 then return nil end
    local after = procSnapshot()
    local busy
    if before.total and after.total and after.total > before.total then
        local dt = after.total - before.total
        local didle = (after.idle or 0) - (before.idle or 0)
        busy = math.floor(100 * (dt - didle) / dt + 0.5)
    end
    local by = {}
    for pid, p in pairs(after.procs) do
        local b = before.procs[pid]
        local d = p.t - ((b and b.comm == p.comm) and b.t or 0)
        if d > 0 then by[p.comm] = (by[p.comm] or 0) + d end
    end
    local arr = {}
    for comm, d in pairs(by) do arr[#arr + 1] = { comm = comm, pct = 100 * d / 100 / secs } end
    table.sort(arr, function(a, b) return a.pct > b.pct end)
    return busy, arr
end

local function onOff(v, on_text)
    if v == nil then return "n/a" end
    return v and (on_text or "ON") or "off"
end

-- Kobo's getter stores the version in firmware_rev instead of returning it.
local function firmware()
    local v = call(Device, "getFirmwareVersion")
    if type(v) ~= "string" or v == "" then v = Device.firmware_rev end
    if type(v) ~= "string" or v == "" or v == "none" then return "?" end
    return v
end

local function setting(key)
    return G_reader_settings and G_reader_settings:readSetting(key)
end

local function timeoutText(v, default, off_if)
    if v == nil then v = default end
    if type(v) ~= "number" then return tostring(v) end
    if v <= (off_if or 0) then return "off" end
    return dur(v)
end

---------------------------------------------------------------------------
-- Running state
---------------------------------------------------------------------------

local started = os.time()
local sleep             -- open sleep session, or nil
local awake             -- open awake stretch, or nil
local pre_wifi          -- Wi-Fi state just before the sleep screen
local run = {           -- totals since KOReader started
    sleep_s = 0, sleep_drop = 0, sleep_n = 0,
    awake_s = 0, awake_drop = 0,
    problems = {}, problem_order = {},
    sched_awake = {}, sched_asleep = {},
    wifi_by = {}, rtc_by = {}, prevent_by = {}, allow_by = {},
    worst_sleep_rate = nil,
}

local function problem(key, text)
    if not run.problems[key] then
        run.problem_order[#run.problem_order + 1] = key
        run.problems[key] = { text = text, n = 0 }
    end
    run.problems[key].n = run.problems[key].n + 1
    run.problems[key].text = text
end

local function newAwake()
    awake = {
        start = os.time(), c0 = clock(), batt = battery(), chg = charging(),
        sched = {}, wifi_s = 0, wifi_since = wifiOn() and clock() or nil, wifi_by = {},
        standby_n = 0, standby_s = 0, standby_refused = 0,
    }
    local ok, snap = pcall(procSnapshot)
    if ok then awake.procs = snap end
end

-- Battery reads in whole %, so a short stretch with 0-1% gone says nothing:
-- a rate needs 30 min, or 2%+ gone over 10 min+.
local function rate(drop, secs)
    if not drop or secs < 600 then return nil end
    if secs < 1800 and drop < 2 then return nil end
    return drop / (secs / 3600)
end

local function sleepGrade(r)
    if not r then return "" end
    if r > 1 then return "  [VERY HIGH]" end
    if r > 0.5 then return "  [HIGH]" end
    if r > 0.25 then return "  [a bit high]" end
    return "  [normal]"
end

local function awakeGrade(r)
    if not r then return "" end
    if r > 20 then return "  [VERY HIGH]" end
    if r > 12 then return "  [HIGH]" end
    return ""
end

---------------------------------------------------------------------------
-- Snapshots for the suspend moment
---------------------------------------------------------------------------

local function pendingTimers()
    local by = {}
    local q = UIManager._task_queue
    if type(q) ~= "table" then return "" end
    local now = time and time.now and time.now()
    for i = 1, #q do
        local t = q[i]
        local s = srcOf(t.action)
        local e = by[s]
        if not e then
            e = { n = 0 }
            by[s] = e
        end
        e.n = e.n + 1
        if now and t.time then
            local d = time.to_s(t.time - now)
            if not e.due or d < e.due then e.due = d end
        end
    end
    local arr = {}
    for s, e in pairs(by) do arr[#arr + 1] = { s = s, n = e.n, due = e.due } end
    table.sort(arr, function(a, b) return a.n > b.n end)
    local out = {}
    for i = 1, math.min(8, #arr) do
        local a = arr[i]
        out[i] = a.s .. (a.n > 1 and (" ×" .. a.n) or "") .. (a.due and (" (due in " .. dur(math.max(0, a.due)) .. ")") or "")
    end
    return table.concat(out, ", "), #q
end

local function rtcAlarms()
    local wm = Device.wakeup_mgr
    local q = wm and wm._task_queue
    if type(q) ~= "table" then return {} end
    local out = {}
    local now = os.time()
    local shutdown = setting("autoshutdown_timeout_seconds") or 3 * 24 * 3600
    for i = 1, #q do
        local t = q[i]
        local left = (t.epoch or now) - now
        local who = srcOf(t.callback)
        if who:find("^KOReader") and type(shutdown) == "number" and shutdown > 0 and left <= shutdown + 60 and left >= shutdown - 6 * 3600 then
            who = "KOReader auto shutdown"
        end
        out[#out + 1] = who .. " in " .. dur(left)
    end
    return out
end

---------------------------------------------------------------------------
-- Awake stretch → sleep session
---------------------------------------------------------------------------

local function closeAwake(why)
    local a = awake
    if not a then return end
    awake = nil
    local secs = clock() - a.c0
    if a.wifi_since then
        a.wifi_s = a.wifi_s + (clock() - a.wifi_since)
        a.wifi_since = nil
    end
    local b1 = battery()
    local drop = (a.batt and b1 and not a.chg and not charging()) and (a.batt - b1) or nil
    local r = rate(drop, secs)
    if drop and secs >= 600 then
        run.awake_s = run.awake_s + secs
        run.awake_drop = run.awake_drop + drop
    end
    local head = string.format("AWAKE %s%s: battery %s → %s", dur(secs), why and (" (" .. why .. ")") or "", pct(a.batt), pct(b1))
    if a.chg then
        head = head .. " (charging)"
    elseif r then
        head = head .. string.format(" = %.1f%%/h", r) .. awakeGrade(r)
    end
    local lines = { head }
    local parts = { "light " .. lightState(), "Wi-Fi on " .. dur(a.wifi_s), "Bluetooth " .. onOff(select(2, radios()), "on") }
    if a.standby_n > 0 then
        parts[#parts + 1] = string.format("standby %d%% of the time (%d times)", math.floor(100 * a.standby_s / math.max(secs, 1) + 0.5), a.standby_n)
    end
    if a.standby_refused > 0 then parts[#parts + 1] = "standby refused " .. a.standby_refused .. "×" end
    local ma = currentMA()
    if ma then parts[#parts + 1] = "draw now " .. ma .. " mA" end
    local ct = cpuText()
    if ct then parts[#parts + 1] = ct end
    lines[#lines + 1] = "  " .. table.concat(parts, " | ")
    local ok_cpu, busy, procs = pcall(cpuUse, a.procs, secs)
    if ok_cpu and (busy or procs) then
        local top = {}
        for i = 1, math.min(5, procs and #procs or 0) do
            if procs[i].pct >= 1 then top[#top + 1] = string.format("%s %d%%", procs[i].comm, math.floor(procs[i].pct + 0.5)) end
        end
        lines[#lines + 1] = string.format("  CPU busy %s (all cores)%s", busy and (busy .. "%") or "?",
            #top > 0 and (" | top processes (% of one core): " .. table.concat(top, ", ")) or "")
        local hog = procs and procs[1] and procs[1].pct >= 40
        if secs >= 600 and ((busy and busy >= 50) or hog) then
            problem("cpu_busy", string.format("The CPU stayed busy while awake (%s all cores; top: %s). An idle reader sits near 0–10%%; a process like that alone can drain 15%%+ an hour.",
                busy and (busy .. "%") or "?", #top > 0 and table.concat(top, ", ") or "?"))
        end
    end
    local gov = cpuState()
    if gov == "performance" then
        problem("governor", "The CPU governor is stuck on \"performance\" (full speed all the time). A reboot of the Kobo usually clears it; if it comes back, it was set that way before KOReader started.")
    end
    local wb = topList(a.wifi_by, 4)
    if wb ~= "" then lines[#lines + 1] = "  Wi-Fi turned on by: " .. wb end
    local busy = topList(a.sched, 6)
    if busy ~= "" then lines[#lines + 1] = "  busiest timers: " .. busy end
    -- A plugin/patch setting timers many times a second keeps the CPU busy
    -- (and out of standby) the whole time it's awake.
    if secs >= 30 then
        for who, n in pairs(a.sched) do
            local per_s = n / secs
            if per_s >= 5 and not who:find("^KOReader") then
                lines[#lines + 1] = string.format("  BUSY: %s set %.0f timers a second", who, per_s)
                problem("busy " .. who, string.format("%s sets timers %.0f times a second while awake, keeping the CPU busy. Try a day with it off and compare the awake drain.", who, per_s))
            end
        end
    end
    if r and r > 12 then
        problem("awake_high", "Drains fast while awake (worst seen this run: " .. string.format("%.1f%%/h", r) .. "). Check the front light level, Wi-Fi time and the busiest timers.")
    end
    if secs > 0 and a.wifi_s > 1800 and a.wifi_s / secs > 0.5 then
        problem("wifi_awake", "Wi-Fi stayed on for most of the awake time. Wi-Fi is one of the biggest drains on e-readers.")
    end
    writeLines(lines)
end

local function startSleep()
    if sleep then
        sleep.rerequests = sleep.rerequests + 1
        return
    end
    closeAwake()
    local b = battery()
    sleep = {
        start = os.time(), c0 = clock(), batt = b, chg = charging(),
        light = lightState(), wifi = pre_wifi, bt = select(2, radios()), cover = Device.is_cover_closed,
        tries = {}, events = {}, sched = {}, wifi_by = {}, rtc_by = {},
        rerequests = 0, event_n = 0, max_uwc = 0, pending = {},
    }
    pre_wifi = nil
    local lines = {
        string.format("SLEEP  battery %s%s | light was %s | Wi-Fi %s | Bluetooth %s | sleep cover %s",
            pct(b), sleep.chg and " (charging)" or "", sleep.light,
            sleep.wifi and "WAS ON (KOReader turns it off now)" or "off", onOff(sleep.bt),
            sleep.cover == true and "closed" or (sleep.cover == false and "open" or "n/a")),
    }
    if UIManager._prevent_standby_count and UIManager._prevent_standby_count > 0 then
        local held = {}
        for who, n in pairs(run.prevent_by) do
            local left = n - (run.allow_by[who] or 0)
            if left > 0 then held[#held + 1] = who .. " ×" .. left end
        end
        lines[#lines + 1] = "  standby blocked right now (" .. UIManager._prevent_standby_count .. "): " .. (#held > 0 and table.concat(held, ", ") or "?")
    end
    if sleep.wifi then
        problem("wifi_at_sleep", "Wi-Fi was still on when the device went to sleep. KOReader switches it off, but on Kobo that can fail or hang suspend. See \"Wi-Fi turned on by\" in battery.log.")
    end
    writeLines(lines)
end

local function noteTry(ok, secs, w0)
    local s = sleep
    local n = #s.tries + 1
    local t = { ok = ok, secs = secs, at = w0, ended = os.time() }
    s.tries[n] = t
    local uwc = Device.unexpected_wakeup_count
    if type(uwc) == "number" and uwc > s.max_uwc then s.max_uwc = uwc end
    -- Timers set since the last try ran during an early wake-up: really
    -- asleep. Ones set after the final try are the normal wake, never merged.
    if n > 1 then
        for who, c in pairs(s.pending) do
            bump(s.sched, who, c)
            bump(run.sched_asleep, who, c)
        end
    end
    s.pending = {}
    local lines = {}
    if n == 1 then
        local wifi, bt = radios()
        s.wifi_susp, s.bt_susp = wifi, bt
        lines[#lines + 1] = "  radios while suspended: Wi-Fi " .. onOff(wifi, "ON (never turned off)")
            .. " | Bluetooth " .. onOff(bt, "ON (never turned off)")
        if wifi then
            problem("wifi_suspended", "Wi-Fi was still ON while the device was suspended: it never got turned off. That keeps the radio powered all night.")
        end
        if bt then
            problem("bt_suspended", "Bluetooth was ON while the device was suspended. That keeps the radio powered all night; turn Bluetooth off before sleeping (or in the Kobo plugin) and compare.")
        end
        local timers, tn = pendingTimers()
        lines[#lines + 1] = string.format("  suspending %s after the sleep screen", dur(w0 - s.start))
        if tn and tn > 0 then lines[#lines + 1] = "  timers waiting (" .. tn .. "; they run on wake): " .. timers end
        local alarms = rtcAlarms()
        if #alarms > 0 then
            lines[#lines + 1] = "  wake-up alarms set: " .. table.concat(alarms, ", ")
            for i = 1, #alarms do
                local who = alarms[i]:match("^(.-) in ")
                if who and not who:find("^KOReader") then bump(s.rtc_by, who) end
            end
        end
    end
    if ok then
        lines[#lines + 1] = string.format("  suspend #%d: suspended %s, woke with battery %s%s", n, dur(secs), pct(battery()),
            (uwc and uwc > 0) and (" (early wake-ups so far: " .. uwc .. ")") or "")
    else
        lines[#lines + 1] = string.format("  suspend #%d: REFUSED by the kernel%s", n, wifiOn() and " (Wi-Fi is on)" or "")
    end
    writeLines(lines)
end

local function endSleep()
    local s = sleep
    if not s then return end
    sleep = nil
    local now = os.time()
    local wall = clock() - s.c0
    local b1 = battery()
    local chg = s.chg or charging()
    local suspended, ok_n, refused = 0, 0, 0
    local last_end
    for i = 1, #s.tries do
        local t = s.tries[i]
        if t.ok then
            ok_n = ok_n + 1
            suspended = suspended + t.secs
        else
            refused = refused + 1
        end
        last_end = t.ended
    end
    local early = math.max(0, ok_n - 1)
    -- KOReader waits ~15 s on the sleep screen before the first try: normal,
    -- so it's left out of the "really suspended" share.
    local wait = #s.tries > 0 and math.max(0, s.tries[1].at - s.start) or 0
    local span = math.max(0, wall - wait)
    local drop = (s.batt and b1 and not chg) and (s.batt - b1) or nil
    local r = rate(drop, wall)
    local head = string.format("WAKE  after %s on the sleep screen: battery %s → %s", dur(wall), pct(s.batt), pct(b1))
    if chg then
        head = head .. " (charging)"
    elseif r then
        head = head .. string.format(" = %.2f%%/h", r) .. sleepGrade(r)
    end
    local lines = { head }
    local w_wifi, w_bt = radios()
    lines[#lines + 1] = "  radios on wake: Wi-Fi " .. onOff(w_wifi) .. " | Bluetooth " .. onOff(w_bt)
    if #s.tries == 0 and wall < 30 then
        lines[#lines + 1] = "  woken before the first suspend try (KOReader waits about 15 s after the sleep screen): nothing to judge"
    elseif #s.tries == 0 then
        lines[#lines + 1] = "  never suspended: no suspend try at all while on the sleep screen"
    else
        lines[#lines + 1] = string.format("  really suspended %s (%d%% of the time after the usual %s wait) | suspend tries %d, refused %d, woke up early by itself %d",
            dur(suspended), math.floor(100 * suspended / math.max(span, 1) + 0.5), dur(wait), #s.tries, refused, early)
    end
    -- Awake on the sleep screen after the last try (Kobo resets its counter on
    -- wake, so the highest count seen during this sleep is used).
    local stuck = last_end and (now - last_end) > 120 and (now - last_end) or nil
    local gave_up = stuck and s.max_uwc >= 19
    if gave_up then
        lines[#lines + 1] = "  KOReader GAVE UP suspending after too many early wake-ups: awake on the sleep screen for the last " .. dur(stuck)
    elseif stuck then
        lines[#lines + 1] = "  awake on the sleep screen for the last " .. dur(stuck) .. " (no suspend try after that)"
    end
    -- The last event is the one that woke it up: not counted.
    if s.last_event and s.events[s.last_event] then
        s.events[s.last_event] = s.events[s.last_event] - 1
        s.event_n = s.event_n - 1
    end
    if s.event_n > 0 then
        local ev = {}
        for k, v in pairs(s.events) do
            if v > 0 then ev[#ev + 1] = k .. " ×" .. v end
        end
        lines[#lines + 1] = "  button/cover events while asleep: " .. table.concat(ev, ", ")
    end
    if s.rerequests > 0 then lines[#lines + 1] = "  extra sleep requests while asleep: " .. s.rerequests end
    local sl = topList(s.sched, 5, true)
    if sl ~= "" then lines[#lines + 1] = "  plugins/patches setting timers during early wake-ups: " .. sl end
    local wb = topList(s.wifi_by, 4)
    if wb ~= "" then lines[#lines + 1] = "  Wi-Fi turned on WHILE ASLEEP by: " .. wb end
    writeLines(lines)

    -- Totals and problems (only long enough sleeps count)
    if drop and wall >= 1800 then
        run.sleep_s = run.sleep_s + wall
        run.sleep_drop = run.sleep_drop + drop
        run.sleep_n = run.sleep_n + 1
        if r and (not run.worst_sleep_rate or r > run.worst_sleep_rate) then run.worst_sleep_rate = r end
    end
    if wall >= 120 then
        if #s.tries == 0 then
            problem("never", "Sat on the sleep screen without ever suspending. On Kobo that usually means the Keep alive plugin is on, or something cancelled the suspend.")
        elseif span >= 120 and suspended / span < 0.9 then
            problem("not_asleep", "Spent part of \"sleep\" awake: as low as " .. math.floor(100 * suspended / span + 0.5) .. "% of the time really suspended.")
        end
    end
    if refused > 0 then
        problem("refused", "The kernel refused to suspend (" .. refused .. "× in one sleep). Usually Wi-Fi, USB or a driver that's still busy.")
    end
    if early > 0 then
        problem("early", "Woke up by itself while asleep (" .. early .. "× in one sleep). With a magnetic sleep cover, try KOReader's \"Ignore all sleepcover events\" for a day and compare.")
    end
    if stuck and not gave_up then
        problem("stuck", "Sat awake on the sleep screen after a suspend try without trying again (up to " .. dur(stuck) .. ").")
    end
    if gave_up then
        problem("gave_up", "KOReader gave up suspending after 20 early wake-ups and stayed awake on the sleep screen. This alone can empty a battery overnight.")
    end
    if wb ~= "" then problem("wifi_asleep", "Wi-Fi was turned on while asleep by: " .. wb .. ".") end
    for who in pairs(s.rtc_by) do bump(run.rtc_by, who) end
    if next(s.rtc_by) then
        problem("rtc", "Plugins/patches set alarms that wake the device from sleep: " .. topList(run.rtc_by, 4) .. ".")
    end
    if r and r > 0.5 then
        problem("sleep_high", string.format("Drains fast while asleep (worst: %.2f%%/h; a healthy Kobo sleep is roughly 0.1–0.25%%/h).", run.worst_sleep_rate or r))
    end
    newAwake()
end

---------------------------------------------------------------------------
-- Hooks (each one passes straight through; our part is pcall'd)
---------------------------------------------------------------------------

-- Power events: Wi-Fi state before the sleep screen; events while asleep.
if type(Device.onPowerEvent) == "function" then
    local orig = Device.onPowerEvent
    Device.onPowerEvent = function(self, ev, ...)
        pcall(function()
            if not self.screen_saver_mode then
                if ev == "Power" or ev == "Suspend" then pre_wifi = wifiOn() end
            elseif sleep then
                local key = tostring(ev) .. (self.is_cover_closed and " (cover closed)" or "")
                bump(sleep.events, key)
                sleep.event_n = sleep.event_n + 1
                sleep.last_event = key
            end
        end)
        return orig(self, ev, ...)
    end
end

if type(Device._beforeSuspend) == "function" then
    local orig = Device._beforeSuspend
    Device._beforeSuspend = function(self, ...)
        local ok, err = pcall(startSleep)
        if not ok then logger.warn("battery diagnostics: sleep hook failed:", err) end
        return orig(self, ...)
    end
end

if type(Device._afterResume) == "function" then
    local orig = Device._afterResume
    Device._afterResume = function(self, ...)
        local ok, err = pcall(endSleep)
        if not ok then logger.warn("battery diagnostics: wake hook failed:", err) end
        return orig(self, ...)
    end
end

-- Every suspend/standby try (Kobo and other sysfs devices).
do
    local ok_ffi, ffiUtil = pcall(require, "ffi/util")
    if ok_ffi and type(ffiUtil) == "table" and type(ffiUtil.writeToSysfs) == "function" then
        local orig = ffiUtil.writeToSysfs
        ffiUtil.writeToSysfs = function(val, file, ...)
            if file ~= "/sys/power/state" then return orig(val, file, ...) end
            local c0, w0 = clock(), os.time()
            local r = pack(orig(val, file, ...))
            pcall(function()
                local secs = clock() - c0
                if val == "mem" and Device.screen_saver_mode then
                    if not sleep then startSleep() end
                    noteTry(r[1] and true or false, secs, w0)
                elseif awake then
                    if r[1] then
                        awake.standby_n = awake.standby_n + 1
                        awake.standby_s = awake.standby_s + secs
                    else
                        awake.standby_refused = awake.standby_refused + 1
                    end
                end
            end)
            return unpack(r, 1, r.n)
        end
    end
end

-- Timers: count who sets them, awake vs asleep. Also hooks Wi-Fi once
-- KOReader has loaded its network manager.
local net_hooked = false
local function hookNet()
    net_hooked = true
    local nm = netmgr()
    if type(nm) ~= "table" then return end
    local function onWifi(who)
        bump(run.wifi_by, who)
        if sleep then bump(sleep.wifi_by, who) end
        if awake then
            bump(awake.wifi_by, who)
            if not awake.wifi_since then awake.wifi_since = clock() end
        end
    end
    if type(nm.turnOnWifi) == "function" then
        local orig = nm.turnOnWifi
        nm.turnOnWifi = function(self, ...)
            pcall(function() onWifi(caller()) end)
            return orig(self, ...)
        end
    end
    if type(nm.restoreWifiAsync) == "function" then
        local orig = nm.restoreWifiAsync
        nm.restoreWifiAsync = function(self, ...)
            pcall(function() onWifi(caller() .. " (restore Wi-Fi)") end)
            return orig(self, ...)
        end
    end
    if type(nm.turnOffWifi) == "function" then
        local orig = nm.turnOffWifi
        nm.turnOffWifi = function(self, ...)
            pcall(function()
                if awake and awake.wifi_since then
                    awake.wifi_s = awake.wifi_s + (clock() - awake.wifi_since)
                    awake.wifi_since = nil
                end
            end)
            return orig(self, ...)
        end
    end
    if awake and not awake.wifi_since and wifiOn() then awake.wifi_since = clock() end
end

if type(UIManager.schedule) == "function" then
    local orig = UIManager.schedule
    UIManager.schedule = function(self, sched_time, action, ...)
        if not net_hooked and package.loaded["ui/network/manager"] then pcall(hookNet) end
        if action then
            local ok, s = pcall(srcOf, action)
            if ok and s ~= "self" then
                if sleep and #sleep.tries > 0 then
                    bump(sleep.pending, s)
                elseif sleep then
                    -- going to sleep: neither awake nor asleep
                else
                    if awake then bump(awake.sched, s) end
                    bump(run.sched_awake, s)
                end
            end
        end
        return orig(self, sched_time, action, ...)
    end
end

-- KOReader closing or restarting: log the awake stretch, or it's lost.
if type(UIManager.quit) == "function" then
    local orig = UIManager.quit
    UIManager.quit = function(self, ...)
        if awake and not sleep then
            local ok, err = pcall(closeAwake, "KOReader closing")
            if not ok then logger.warn("battery diagnostics: exit hook failed:", err) end
        end
        return orig(self, ...)
    end
end

-- Standby blocks: who holds them.
if type(UIManager.preventStandby) == "function" and type(UIManager.allowStandby) == "function" then
    local orig_p, orig_a = UIManager.preventStandby, UIManager.allowStandby
    UIManager.preventStandby = function(self, ...)
        pcall(function() bump(run.prevent_by, caller()) end)
        return orig_p(self, ...)
    end
    UIManager.allowStandby = function(self, ...)
        pcall(function() bump(run.allow_by, caller()) end)
        return orig_a(self, ...)
    end
end

-- Wake-up alarms: who sets them.
do
    local wm = Device.wakeup_mgr
    if type(wm) == "table" and type(wm.addTask) == "function" then
        local orig = wm.addTask
        wm.addTask = function(self, seconds, callback, ...)
            pcall(function()
                local who = callback and srcOf(callback)
                if not who or who:find("^KOReader") then who = caller() end
                if not who:find("^KOReader") then bump(run.rtc_by, who) end
            end)
            return orig(self, seconds, callback, ...)
        end
    end
end

---------------------------------------------------------------------------
-- Start-up report
---------------------------------------------------------------------------

local function listPlugins()
    local disabled = setting("plugins_disabled") or {}
    local paths = { "plugins" }
    local extra = setting("extra_plugin_paths")
    if type(extra) == "string" then extra = { extra } end
    if type(extra) == "table" then
        for i = 1, #extra do paths[#paths + 1] = extra[i] end
    elseif DATA ~= "." then
        paths[#paths + 1] = DATA .. "/plugins"
    end
    local on, seen = {}, {}
    local junk = 0
    for i = 1, #paths do
        local ok, iter, dir_obj = pcall(lfs.dir, paths[i])
        if ok then
            for entry in iter, dir_obj do
                local name = entry:match("^(.+)%.koplugin$")
                if name and name:sub(1, 2) == "._" then
                    junk = junk + 1
                    name = nil
                end
                if name and lfs.attributes(paths[i]:gsub("/$", "") .. "/" .. entry, "mode") ~= "directory" then name = nil end
                if name and not seen[name] then
                    seen[name] = true
                    if not disabled[name] then
                        on[#on + 1] = { name = name, path = paths[i]:gsub("/$", "") .. "/" .. entry, builtin = BUILTIN[name] }
                    end
                end
            end
        end
    end
    table.sort(on, function(a, b) return a.name < b.name end)
    return on, disabled, junk
end

local function listPatches()
    local out = {}
    local dir = DATA .. "/patches"
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if ok then
        for entry in iter, dir_obj do
            if entry:match("^%d.*%.lua$") then out[#out + 1] = entry end
        end
    end
    table.sort(out)
    return out, dir
end

local function settingsLine()
    local ok_ps, PluginShare = pcall(require, "pluginshare")
    local keep = ok_ps and type(PluginShare) == "table" and PluginShare.keepalive
    local cover = "used"
    if setting("ignore_power_sleepcover") then
        cover = "ignored"
    elseif setting("ignore_open_sleepcover") then
        cover = "close only"
    end
    return string.format("settings: auto suspend %s | auto standby %s | auto shutdown %s | sleep cover %s | restore Wi-Fi on wake %s | Wi-Fi when needed: %s | Keep alive %s",
        timeoutText(setting("auto_suspend_timeout_seconds"), 15 * 60),
        timeoutText(setting("auto_standby_timeout_seconds"), -1),
        timeoutText(setting("autoshutdown_timeout_seconds"), 3 * 24 * 3600),
        cover,
        setting("auto_restore_wifi") and "on" or "off",
        tostring(setting("wifi_enable_action") or "prompt"),
        keep and "ON" or "off"), keep
end

-- Did last run go to sleep and never wake?
local function lastRunCheck()
    local f = io.open(LOG, "r")
    if not f then return nil end
    local size = f:seek("end") or 0
    f:seek("set", math.max(0, size - 16384))
    local tail = f:read("*a") or ""
    f:close()
    local last_sleep, last_other
    for line in tail:gmatch("[^\n]+") do
        if line:find("  SLEEP  ", 1, true) then
            last_sleep = line
            last_other = nil
        elseif line:find("  WAKE  ", 1, true) or line:find("  === ", 1, true) then
            last_other = line
        end
    end
    if last_sleep and not last_other then return last_sleep end
    return nil
end

local function startupReport()
    local lines = { "=== Battery diagnostics " .. VERSION .. " started ===" }
    local prev = lastRunCheck()
    if prev then
        lines[#lines + 1] = "LAST RUN went to sleep and never woke up (battery ran out, crash or forced restart). Last sleep line:"
        lines[#lines + 1] = "  " .. prev
        problem("no_wake", "Last time the device went to sleep and KOReader never saw it wake (battery ran out, crash or forced restart).")
    end
    local ok_v, Version = pcall(require, "version")
    local rev = ok_v and call(Version, "getCurrentRevision") or "?"
    lines[#lines + 1] = string.format("device: %s | firmware %s | KOReader %s",
        tostring(Device.model or "?"), tostring(firmware()), tostring(rev))
    local cur, volt, status = sysfs("current_now"), sysfs("voltage_now"), sysfs("status")
    lines[#lines + 1] = string.format("battery %s%s%s%s%s", pct(battery()), charging() and " (charging)" or "",
        status and (" | status " .. status) or "",
        cur and (" | current_now " .. cur .. " (~" .. tostring(currentMA()) .. " mA)") or "", volt and (" | voltage " .. volt) or "")
    local ct = cpuText()
    if ct then lines[#lines + 1] = ct end
    local r_wifi, r_bt = radios()
    lines[#lines + 1] = "radios now: Wi-Fi " .. onOff(r_wifi, "on") .. " | Bluetooth " .. onOff(r_bt, "on")
    local sline, keep = settingsLine()
    lines[#lines + 1] = sline
    if keep then problem("keepalive", "Keep alive is ON: the device never sleeps by itself while it's on.") end
    local plugins, disabled, junk = listPlugins()
    if junk > 0 then
        lines[#lines + 1] = "macOS \"._\" files in plugins: " .. junk .. " (left by copying with a Mac; KOReader ignores them, harmless)"
    end
    local b, u = {}, {}
    for i = 1, #plugins do
        if plugins[i].builtin then b[#b + 1] = plugins[i].name else u[#u + 1] = plugins[i].name end
    end
    lines[#lines + 1] = "user plugins on: " .. (#u > 0 and table.concat(u, ", ") or "none")
    lines[#lines + 1] = "built-in plugins on: " .. (#b > 0 and table.concat(b, ", ") or "none")
    if disabled.autosuspend then
        problem("autosuspend_off", "The AutoSuspend plugin is disabled: the device won't go to sleep by itself.")
    end
    local as = setting("auto_suspend_timeout_seconds")
    if type(as) == "number" and as <= 0 then
        problem("autosuspend_never", "Auto suspend is off: if the device is put down without pressing power, it stays awake.")
    end
    local patches = listPatches()
    lines[#lines + 1] = "patches on: " .. (#patches > 0 and table.concat(patches, ", ") or "none")
    writeLines(lines)
end

---------------------------------------------------------------------------
-- Code scan of plugins and patches
---------------------------------------------------------------------------

local PATTERNS = {
    { key = "rtc", pat = { "wakeup_mgr", "WakeupMgr" } },
    { key = "prevent", pat = { "preventStandby" } },
    { key = "allow", pat = { "allowStandby" } },
    { key = "wifi", pat = { "turnOnWifi", "enableWifi", "runWhenOnline", "goOnlineToRun",
        "beforeWifiAction", "turnOnWifiAndWaitForConnection", "willRerunWhenOnline", "restoreWifiAsync" } },
    { key = "onresume", pat = { "onResume" } },
    { key = "onsuspend", pat = { "onSuspend" } },
    { key = "keepalive", pat = { "PluginShare.keepalive", "keepalive = true" } },
    { key = "timers", pat = { "scheduleIn", "nextTick", "tickAfterNext" } },
    { key = "shell", pat = { "io.popen", "os.execute" } },
}

local function countIn(text, needle)
    local n, pos = 0, 1
    while true do
        local s, e = text:find(needle, pos, true)
        if not s then return n end
        n = n + 1
        pos = e + 1
    end
end

local function readCode(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local s = f:read(1024 * 1024) or ""
    f:close()
    return s
end

local function scanText(text)
    local c = {}
    for i = 1, #PATTERNS do
        local p = PATTERNS[i]
        local n = 0
        for j = 1, #p.pat do n = n + countIn(text, p.pat[j]) end
        c[p.key] = n
    end
    return c
end

local function verdicts(c)
    local v = {}
    if c.rtc > 0 then v[#v + 1] = "sets wake-up alarms (can wake the device from sleep)" end
    if c.keepalive > 0 then v[#v + 1] = "can keep the device from sleeping" end
    if c.prevent > c.allow then v[#v + 1] = "blocks standby more often than it releases it" end
    if c.wifi > 0 and c.onresume > 0 then v[#v + 1] = "uses Wi-Fi and runs on wake (may turn Wi-Fi on at every wake)" end
    if c.wifi > 0 and c.onsuspend > 0 then v[#v + 1] = "uses Wi-Fi and runs on sleep" end
    if c.timers >= 15 and c.onsuspend == 0 then v[#v + 1] = c.timers .. " timer calls and no sleep handler" end
    if c.shell > 0 then v[#v + 1] = "runs shell commands" end
    return v
end

local function runtimeFor(name)
    local seen = {}
    local a = run.sched_awake[name]
    local s = run.sched_asleep[name]
    if a then seen[#seen + 1] = "timers awake ×" .. a end
    if s then seen[#seen + 1] = "timers ASLEEP ×" .. s end
    if run.wifi_by[name] then seen[#seen + 1] = "turned Wi-Fi on ×" .. run.wifi_by[name] end
    if run.rtc_by[name] then seen[#seen + 1] = "wake alarms ×" .. run.rtc_by[name] end
    local held = (run.prevent_by[name] or 0) - (run.allow_by[name] or 0)
    if held > 0 then seen[#seen + 1] = "standby blocks not released ×" .. held end
    return seen
end

local function scan()
    local out = { "SCAN of plugins and patches (code hints + what this run saw)" }
    local flagged = 0
    local plugins = listPlugins()
    for i = 1, #plugins do
        local p = plugins[i]
        local label = BUILTIN[p.name] and ("plugin " .. p.name .. " (built-in)") or ("plugin " .. p.name)
        local text = {}
        local ok, iter, dir_obj = pcall(lfs.dir, p.path)
        if ok then
            for entry in iter, dir_obj do
                if entry:match("%.lua$") then text[#text + 1] = readCode(p.path .. "/" .. entry) end
            end
        end
        local v = verdicts(scanText(table.concat(text, "\n")))
        local seen = runtimeFor(label)
        if (#v > 0 and (not p.builtin or p.name == "keepalive")) or #seen > 0 then
            flagged = flagged + 1
            out[#out + 1] = "• " .. label .. (#v > 0 and (": " .. table.concat(v, "; ")) or "")
            if #seen > 0 then out[#out + 1] = "    seen this run: " .. table.concat(seen, ", ") end
        end
    end
    local patches, dir = listPatches()
    for i = 1, #patches do
        local name = patches[i]
        if not name:find(SELF, 1, true) then
            local label = "patch " .. name
            local v = verdicts(scanText(readCode(dir .. "/" .. name)))
            local seen = runtimeFor(label)
            if #v > 0 or #seen > 0 then
                flagged = flagged + 1
                out[#out + 1] = "• " .. label .. (#v > 0 and (": " .. table.concat(v, "; ")) or "")
                if #seen > 0 then out[#out + 1] = "    seen this run: " .. table.concat(seen, ", ") end
            end
        end
    end
    if flagged == 0 then out[#out + 1] = "Nothing stands out." end
    out[#out + 1] = "Code hints only say what a plugin/patch CAN do. \"Seen this run\" is what it actually did."
    writeLines(out)
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------

local function report()
    local lines = {
        "Battery diagnostics " .. VERSION,
        "Since KOReader started at " .. hhmm(started) .. " (" .. dur(os.time() - started) .. " ago)",
        "",
    }
    if run.sleep_s > 0 then
        lines[#lines + 1] = string.format("ASLEEP: %s, -%d%% = %.2f%%/h%s  (%d sleeps of 30 min+)",
            dur(run.sleep_s), run.sleep_drop, run.sleep_drop / (run.sleep_s / 3600), sleepGrade(run.sleep_drop / (run.sleep_s / 3600)), run.sleep_n)
    else
        lines[#lines + 1] = "ASLEEP: no sleep of 30 min+ off the charger yet."
    end
    if run.awake_s > 0 then
        local r = run.awake_drop / (run.awake_s / 3600)
        lines[#lines + 1] = string.format("AWAKE: %s, -%d%% = %.1f%%/h%s", dur(run.awake_s), run.awake_drop, r, awakeGrade(r))
    else
        lines[#lines + 1] = "AWAKE: no awake stretch of 10 min+ off the charger finished yet."
    end
    if awake then
        local n_wifi, n_bt = radios()
        lines[#lines + 1] = string.format("Now: battery %s, awake %s, light %s, Wi-Fi %s, Bluetooth %s",
            pct(battery()), dur(clock() - awake.c0), lightState(), onOff(n_wifi, "on"), onOff(n_bt, "on"))
    end
    lines[#lines + 1] = ""
    if #run.problem_order > 0 then
        lines[#lines + 1] = "PROBLEMS FOUND"
        for i = 1, #run.problem_order do
            local p = run.problems[run.problem_order[i]]
            lines[#lines + 1] = "• " .. p.text .. (p.n > 1 and (" (" .. p.n .. "×)") or "")
        end
    else
        lines[#lines + 1] = "No problems found yet. Leave it a night or two, sleeping the device as usual."
    end
    local wb = topList(run.wifi_by, 5)
    if wb ~= "" then lines[#lines + 1] = "" lines[#lines + 1] = "Wi-Fi turned on by: " .. wb end
    local ta = topList(run.sched_awake, 6, true)
    if ta ~= "" then lines[#lines + 1] = "" lines[#lines + 1] = "Busiest plugins/patches (timers while awake): " .. ta end
    local ts = topList(run.sched_asleep, 6, true)
    if ts ~= "" then lines[#lines + 1] = "Plugins/patches setting timers during early wake-ups: " .. ts end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "HOW TO READ IT"
    lines[#lines + 1] = "• Asleep: a healthy Kobo loses about 0.1–0.25%/h (a few % a day). Much more means it isn't really suspending: look for refused tries, early wake-ups or \"gave up\" in battery.log."
    lines[#lines + 1] = "• Awake: reading usually costs a few %/h; front light and Wi-Fi push it up."
    lines[#lines + 1] = "• To find a culprit: disable the plugin/patch named above, sleep the device overnight, compare."
    lines[#lines + 1] = "• Full details in battery.log (" .. LOG .. ")."
    return table.concat(lines, "\n")
end

local function showText(title, text)
    local TextViewer = require("ui/widget/textviewer")
    UIManager:show(TextViewer:new{ title = title, text = text })
end

local function logTail()
    local f = io.open(LOG, "r")
    if not f then return "battery.log is empty." end
    local size = f:seek("end") or 0
    f:seek("set", math.max(0, size - 65536))
    local s = f:read("*a") or ""
    f:close()
    if size > 65536 then s = "(last 64 KB)\n" .. s:gsub("^[^\n]*\n", "") end
    return s
end

---------------------------------------------------------------------------
-- Menu: Tools → Battery diagnostics
---------------------------------------------------------------------------

local function menuItem()
    return {
        text = "Battery diagnostics",
        sub_item_table = {
            {
                text = "Battery report",
                keep_menu_open = true,
                callback = function()
                    -- Log the awake stretch so far (with its CPU use), then
                    -- carry on with a fresh one.
                    if awake and not sleep then
                        pcall(closeAwake, "so far, report opened")
                        newAwake()
                    end
                    local ok, res = pcall(report)
                    if ok then
                        write("REPORT opened")
                        showText("Battery report", res)
                    else
                        logger.warn("battery diagnostics: report failed:", res)
                        local InfoMessage = require("ui/widget/infomessage")
                        UIManager:show(InfoMessage:new{ text = "Battery report failed:\n" .. tostring(res) })
                    end
                end,
            },
            {
                text = "Scan plugins and patches",
                keep_menu_open = true,
                callback = function()
                    local ok, res = pcall(scan)
                    if ok then
                        showText("Plugins and patches", res)
                    else
                        logger.warn("battery diagnostics: scan failed:", res)
                        local InfoMessage = require("ui/widget/infomessage")
                        UIManager:show(InfoMessage:new{ text = "Scan failed:\n" .. tostring(res) })
                    end
                end,
            },
            {
                text = "View battery.log",
                keep_menu_open = true,
                callback = function() showText("battery.log", logTail()) end,
            },
            {
                text = "Clear battery.log",
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new{
                        text = "Delete battery.log and battery.log.old?\nThe numbers in the battery report since KOReader started stay.",
                        ok_text = "Delete",
                        ok_callback = function()
                            os.remove(LOG)
                            os.remove(LOG .. ".old")
                            log_size = 0
                            write("=== log cleared (Battery diagnostics " .. VERSION .. ") ===")
                        end,
                    })
                end,
            },
        },
    }
end

local function addToOrder(order_mod)
    local ok, order = pcall(require, order_mod)
    if not ok or type(order) ~= "table" or type(order.tools) ~= "table" then return end
    for i = 1, #order.tools do if order.tools[i] == ID then return end end
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
    if ok and type(M) == "table" and type(M.setUpdateItemTable) == "function" then
        local orig = M.setUpdateItemTable
        M.setUpdateItemTable = function(self, ...)
            pcall(function()
                if self.menu_items then
                    addToOrder(pair[2])
                    local m = menuItem()
                    m.sorting_hint = "tools"
                    self.menu_items[ID] = m
                end
            end)
            return orig(self, ...)
        end
    end
end

---------------------------------------------------------------------------
-- Go
---------------------------------------------------------------------------

do
    local ok, err = pcall(startupReport)
    if not ok then logger.warn("battery diagnostics: start-up report failed:", err) end
    newAwake()
    if package.loaded["ui/network/manager"] then pcall(hookNet) end
end

logger.info("battery diagnostics " .. VERSION .. " loaded, logging to " .. LOG)
