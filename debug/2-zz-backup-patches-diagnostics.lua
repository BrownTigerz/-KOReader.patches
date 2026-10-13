--[[
2-zz-backup-patches-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.1.6

Watches Patch Backup & Restore (2-backup-patches.lua) and its hooks into
Device Backup & Restore (backup.koplugin) from the outside, and writes
tagged lines to the shared log contract v1 file:
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)
so a full test run reads as a single chronological log alongside the other
diagnostics patches.

It changes nothing: no settings, no files except its tagged lines in the
shared log and a one-line state file. The "zz" makes it load after
2-backup-patches.lua.

Shuts itself off, in case it's forgotten:
  - Logs for 15 minutes after KOReader starts, then goes quiet. A backup or
    restore near the end extends that by 5 minutes so it finishes.
  - 3 days after its first run it doesn't hook anything at all any more
    (one line in the log per start says so). Delete
    backup-patches-diagnostics.state to start another 3 days.
  - Its lines share koreader/diagnostics.log with the other diagnostics
    patches; the shared log rotates at 2 MB (older part kept as
    diagnostics.log.old).
  - No heartbeat or repeating timer: it never wakes the device on its own.
  - Switched off with the Debugging menu (or this file moved or renamed
    out of patches/)? It notices within 5 seconds and stops logging right
    away, instead of carrying on until the next restart.

What it checks:
  Startup     Versions and paths. Per target: settings found, icon paths,
              missing icons, icons outside the target's folder, backups.
              Unused icons and how long that scan takes. Loose files in
              koreader/icons/. Logins toggle, and which secret files exist
              (names only, never their contents).
  Performance Every tap that holds the screen more than 300 ms, with the
              file work Patch Backup & Restore did during it. Memory before
              and after backups and restores.
  Sleep       Any file work or timer from Patch Backup & Restore while the
              device sleeps (should be none). Any timer it schedules at all
              (should be none).
  Device      After each Device Backup & Restore backup: the zip is opened
  backups     to check the icon map is there, every mapped icon is in it,
              and, with "Logins in device backups" off, that no logins
              went in. After each restore: per target, how many icon paths
              the remap repointed and which still miss; every login token
              the kept-logic should have re-inserted is verified present.
  Per-target  Each Back up now / safety backup zip: entries, size, time.
  zips        After a per-target restore: icon paths before → after, how
              many the remap repointed, and which are still missing.
  Notes       Every note or popup Patch Backup & Restore shows (to see the
              Network Tweaks style is used).
  Updater     The on-device updater end to end, via the trace hook the
              patch calls (2.2.2+): check start, manifest fetch (URL, HTTP
              status, bytes, entries), per-patch compare decisions, Wi-Fi
              on/off and the connection wait, each download (start, bytes,
              finish or error), install-location decisions, and the
              restart prompt. A run extends the logging window like a
              backup does.

How to use:
  1. Put this file in koreader/patches/ next to 2-backup-patches.lua and
     restart KOReader. A note says it's on.
  2. Within 15 minutes, use things: open Patch Backup & Restore, Back up
     now, Restore, Tidy icons, Unused icons, a Device Backup & Restore
     backup (and restore if you like), put the device to sleep and wake it.
  3. Send koreader/diagnostics.log.
  4. Delete this file (and the .state file) and restart.

Changelog
  1.1.6  Updater tracing: receives the _G.__backup_updater_trace events
         the patch emits (2.2.2+) and logs them as tagged lines —
         manifest fetch, per-patch compare decisions, Wi-Fi on/off,
         downloads, install locations, restart prompt. An updater run
         extends the logging window like a backup does.
  1.1.5  Shared-log rotation cap raised from 256 KB to 2 MB
         (SHARED_MAX_BYTES = 2 * 1024 * 1024), matching all 12 diagnostics.
  1.1.4  Restore coverage: after a per-target restore, logs icon paths
         before → after, how many the remap repointed, and which are still
         missing (remapTarget's return is discarded by the patch, so a
         no-op remap was invisible). After a device restore, same per
         target, plus every login token the kept-logic should have
         re-inserted is verified present.
  1.1.3  Shared log contract v1: tagged lines go to koreader/diagnostics.log
         (rotated at 2 MB to diagnostics.log.old) instead of the file's own
         log file. The "+N.Ns since start" offset on each line is unchanged.
  1.1.2  The startup note uses the shared notification contract v1
         (Network Tweaks' note, then ReadMastery's, then the plain
         KOReader note).
  1.1.1  Log lines carry the full date stamp ("%Y-%m-%d %I:%M:%S %p") and
         the startup banner reads "<name> diagnostics <version> started",
         per the diagnostics conventions. The device-backup check logs the
         reader's error reason when the backup can't be opened. The wake-up
         line is no longer written after the logging window ends.
  1.1.0  Stops logging as soon as it's switched off (file moved out of
         patches/), not at the next restart. File work, timers and notes
         are only credited to Patch Backup & Restore when its own code
         does them: work by other plugins while it's in the call chain
         (plugin loading, menu building) is no longer counted. That's
         where the "patch deleted plugins/bookends.koplugin/..." lines
         came from.
  1.0.0  First version.
]]

local DIAG_VERSION = "1.1.6"
local WINDOW_S     = 15 * 60       -- logging window after start
local EXTEND_S     = 5 * 60        -- extension when a backup/restore runs
local EXPIRE_S     = 3 * 24 * 3600 -- stops hooking anything after this
local SLOW_TAP_MS  = 300

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local ok_time, ktime = pcall(require, "ui/time")

local raw_attr, raw_remove = lfs.attributes, os.remove
local DATA = DataStorage:getDataDir()
local STATE = DATA .. "/backup-patches-diagnostics.state"
local orig_open = io.open -- the log never counts itself

-- --------------------------------------------------------------------------
-- Log
-- --------------------------------------------------------------------------

local t_start = ok_time and ktime.now() or nil

local function now() return ok_time and ktime.now() or nil end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 2 MB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "backup-patches"
local SHARED_LOG = DATA .. "/diagnostics.log"
local SHARED_MAX_BYTES = 2 * 1024 * 1024
local function shared_log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    pcall(function()
        if (raw_attr(SHARED_LOG, "size") or 0) > SHARED_MAX_BYTES then
            raw_remove(SHARED_LOG .. ".old")
            os.rename(SHARED_LOG, SHARED_LOG .. ".old")
        end
        -- orig_open, not the io.open this file wraps below: the shared log
        -- never counts as Patch Backup & Restore's file work.
        local f = orig_open(SHARED_LOG, "a")
        if not f then return end
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", line, "\n")
        f:close()
    end)
end

local function log(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = tostring(fmt) end
    -- The relative "+N.Ns" offset from startup is kept; shared_log adds
    -- the absolute date+time and the [backup-patches] tag itself.
    shared_log("+%7.1fs  %s", (t_start and ms(t_start) or 0) / 1000, line)
end

local function q(v) return v == nil and "(nil)" or tostring(v) end

local function kb(n) return string.format("%.1f KB", (n or 0) / 1024) end

local function short(p)
    p = tostring(p)
    local esc = (DATA:gsub("%p", "%%%0"))
    return (p:gsub("^" .. esc, "koreader"))
end

-- --------------------------------------------------------------------------
-- Expiry
-- --------------------------------------------------------------------------

local first_run
do
    local f = orig_open(STATE, "r")
    if f then
        first_run = tonumber(f:read("*l") or "")
        f:close()
    end
    if not first_run then
        first_run = os.time()
        local w = orig_open(STATE, "w")
        if w then
            w:write(first_run, "\n")
            w:close()
        end
    end
end

if os.difftime(os.time(), first_run) > EXPIRE_S then
    log("diagnostics %s expired (first run %s): not watching anything. Delete this patch.",
        DIAG_VERSION, os.date("%b %d %I:%M %p", first_run))
    return
end

local Backup = package.loaded.backup_patches
if type(Backup) ~= "table" or type(Backup.targets) ~= "table" then
    log("diagnostics %s: Patch Backup & Restore isn't loaded (is 2-backup-patches.lua installed?)", DIAG_VERSION)
    return
end

local UIManager = require("ui/uimanager")

local window_end = os.time() + WINDOW_S

-- This file's own path, to notice being switched off mid-session.
local SELF = (debug.getinfo(1, "S").source or ""):match("^@(.+)$")
if SELF and raw_attr(SELF, "mode") ~= "file" then SELF = nil end
local switched_off = false
local next_self_check = 0

local function active()
    if switched_off then return false end
    local t = os.time()
    if t > window_end then return false end
    if SELF and t >= next_self_check then
        next_self_check = t + 5
        if raw_attr(SELF, "mode") ~= "file" then
            switched_off = true
            log("switched off (this file was moved out of patches/): stopped logging")
            return false
        end
    end
    return true
end
local function extend() window_end = math.max(window_end, os.time() + EXTEND_S) end

-- --------------------------------------------------------------------------
-- Attribution: was this called from Patch Backup & Restore?
-- --------------------------------------------------------------------------

-- Looks at the nearest Lua code that made the call. C functions, this file
-- and pass-through helpers (KOReader's util, Network Tweaks' shared note)
-- are looked past; the first code after them decides. Code further up the
-- chain doesn't count: the patch wraps the plugin loader and menu building,
-- so other plugins' work runs "inside" it without being its work.
local PASS_THROUGH = { "/util.lua", "network-tweaks" }

local function fromPatch()
    for level = 3, 20 do
        local info = debug.getinfo(level, "S")
        if not info then return false end
        local src = info.source or ""
        if info.what ~= "C" and src:sub(1, 1) == "@" and not src:find("diagnostics", 1, true) then
            local through = false
            for _i, p in ipairs(PASS_THROUGH) do
                if src:find(p, 1, true) then through = true break end
            end
            if not through then
                return src:find("backup-patches", 1, true) ~= nil
            end
        end
    end
    return false
end

-- File work by the patch: totals, per tap, and while asleep.
local ops = { read = 0, write = 0, remove = 0, dir = 0, stat = 0 }
local tap_ops, sleep_ops
local asleep = false
local totals = { taps = 0, slow_taps = 0, slowest_ms = 0, slowest_what = "" }

local function count(kind)
    ops[kind] = ops[kind] + 1
    if tap_ops then tap_ops[kind] = tap_ops[kind] + 1 end
    if asleep and sleep_ops then sleep_ops[kind] = sleep_ops[kind] + 1 end
end

local function opsText(t)
    return string.format("%d reads, %d writes, %d deletes, %d folder scans, %d file checks",
        t.read, t.write, t.remove, t.dir, t.stat)
end

local function newOps() return { read = 0, write = 0, remove = 0, dir = 0, stat = 0 } end

local function memKB() return math.floor(collectgarbage("count")) end

-- --------------------------------------------------------------------------
-- File activity (only counted while the window is open)
-- --------------------------------------------------------------------------

io.open = function(path, mode, ...)
    if active() and fromPatch() then
        count((mode and mode:find("[wa]")) and "write" or "read")
    end
    return orig_open(path, mode, ...)
end

local orig_remove = os.remove
os.remove = function(path, ...)
    if active() and fromPatch() then
        count("remove")
        log("patch deleted %s", short(path))
    end
    return orig_remove(path, ...)
end

local orig_dir = lfs.dir
lfs.dir = function(path, ...)
    if active() and fromPatch() then count("dir") end
    return orig_dir(path, ...)
end

local orig_attr = lfs.attributes
lfs.attributes = function(path, ...)
    if active() and fromPatch() then count("stat") end
    return orig_attr(path, ...)
end

-- --------------------------------------------------------------------------
-- Timers: the patch shouldn't schedule any
-- --------------------------------------------------------------------------

local orig_sched = UIManager.scheduleIn
UIManager.scheduleIn = function(self, ...)
    if active() and fromPatch() then
        log("TIMER scheduled by Patch Backup & Restore (unexpected)\n%s", debug.traceback("", 2))
        if asleep and sleep_ops then sleep_ops.timers = (sleep_ops.timers or 0) + 1 end
    end
    return orig_sched(self, ...)
end

-- --------------------------------------------------------------------------
-- Notes and popups shown by the patch
-- --------------------------------------------------------------------------

local orig_show = UIManager.show
UIManager.show = function(self, w, ...)
    if active() and type(w) == "table" and (w.text or w.title) and fromPatch() then
        local text = tostring(w.text or w.title):gsub("\n", " "):sub(1, 90)
        local kind = w.toast and "note" or (w.ok_callback and "question" or "popup")
        log("shows %s: \"%s\"", kind, text)
    end
    return orig_show(self, w, ...)
end

-- --------------------------------------------------------------------------
-- On-device updater tracing (needs 2-backup-patches.lua 2.2.2+)
-- --------------------------------------------------------------------------

-- The updater calls _G.__backup_updater_trace at each step of a check run:
-- run start, manifest fetch (URL, HTTP status, bytes, entries), per-patch
-- compare decisions, Wi-Fi on/off and the connection wait, each download
-- (start, bytes, finish or error), install-location decisions, and the
-- restart prompt. Every event becomes a tagged line, so an on-device
-- updater run leaves full footprints. An updater run extends the logging
-- window, like a backup or restore does.
_G.__backup_updater_trace = function(event, msg)
    if switched_off then return end
    if os.difftime(os.time(), first_run) > EXPIRE_S then return end
    if event == "run" then extend() end
    if not active() then return end
    log("updater %s: %s", event, msg)
end

-- --------------------------------------------------------------------------
-- Taps: how long each one held the screen
-- --------------------------------------------------------------------------

local function topName(um)
    local top = um._window_stack and um._window_stack[#um._window_stack]
    local w = top and top.widget
    if type(w) ~= "table" then return "?" end
    local t = w.title or w.text or w.name
    if type(t) == "string" then return t:gsub("\n", " "):sub(1, 50) end
    return w.name or "?"
end

local orig_send = UIManager.sendEvent
UIManager.sendEvent = function(self, ev, ...)
    local g = active() and type(ev) == "table" and ev.handler == "onGesture" and ev.args and ev.args[1]
    if not (type(g) == "table" and (g.ges == "tap" or g.ges == "hold")) then
        return orig_send(self, ev, ...)
    end
    local before = topName(self)
    tap_ops = newOps()
    local t = now()
    local r = { orig_send(self, ev, ...) }
    local took = ms(t)
    local mine = tap_ops
    tap_ops = nil
    totals.taps = totals.taps + 1
    local patch_work = (mine.read + mine.write + mine.remove + mine.dir + mine.stat) > 0
    if took >= SLOW_TAP_MS then
        totals.slow_taps = totals.slow_taps + 1
        log("SLOW %s: screen held %d ms (on: %s)%s", g.ges, took, before,
            patch_work and ("  patch did " .. opsText(mine)) or "  (not Patch Backup & Restore)")
    elseif patch_work then
        log("%s: %d ms, patch did %s", g.ges, took, opsText(mine))
    end
    if took > totals.slowest_ms then
        totals.slowest_ms, totals.slowest_what = took, before
    end
    return unpack(r)
end

-- --------------------------------------------------------------------------
-- Sleep / wake
-- --------------------------------------------------------------------------

local orig_broadcast = UIManager.broadcastEvent
UIManager.broadcastEvent = function(self, event, ...)
    local handler = type(event) == "table" and event.handler
    if handler == "onSuspend" and active() then
        log("going to sleep (memory %d KB)", memKB())
        local r = { orig_broadcast(self, event, ...) }
        asleep, sleep_ops = true, newOps()
        return unpack(r)
    elseif handler == "onResume" and asleep then
        asleep = false
        local s = sleep_ops or newOps()
        sleep_ops = nil
        if active() then
            local any = s.read + s.write + s.remove + s.dir + s.stat + (s.timers or 0)
            log("woke up: while asleep Patch Backup & Restore did %s%s",
                any == 0 and "nothing (good)" or opsText(s),
                (s.timers or 0) > 0 and (", scheduled " .. s.timers .. " timers") or "")
        end
    end
    return orig_broadcast(self, event, ...)
end

-- --------------------------------------------------------------------------
-- Per-target zips (Back up now, before restore, before tidy)
-- --------------------------------------------------------------------------

-- Forward declaration: defined after the shared checks below (it needs
-- iconCheck). Called from the zip hook when a before-restore safety backup
-- starts, so the restore gets a post-check.
local watchRestore

local ok_a, Archiver = pcall(require, "ffi/archiver")
if ok_a and type(Archiver) == "table" and type(Archiver.Writer) == "table" then
    local W = Archiver.Writer
    local w_open, w_mem, w_close = W.open, W.addFileFromMemory, W.close
    if w_open and w_mem and w_close then
        W.open = function(self, path, ...)
            local ok = w_open(self, path, ...)
            if active() and fromPatch() then
                rawset(self, "__diag", { path = path, t = now(), n = 0, bytes = 0, mem = memKB() })
                if not ok then log("zip: could NOT create %s: %s", short(path), q(self.err)) end
                watchRestore(path)
            end
            return ok
        end
        W.addFileFromMemory = function(self, name, data, ...)
            local d = rawget(self, "__diag")
            if d then
                d.n = d.n + 1
                d.bytes = d.bytes + #(data or "")
            end
            return w_mem(self, name, data, ...)
        end
        W.close = function(self, ...)
            local r = { w_close(self, ...) }
            local d = rawget(self, "__diag")
            if d then
                rawset(self, "__diag", nil)
                log("zip: %s  %d entries, %s, %d ms, memory %+d KB", short(d.path), d.n, kb(d.bytes),
                    ms(d.t), memKB() - d.mem)
                extend()
            end
            return unpack(r)
        end
    end
end

-- --------------------------------------------------------------------------
-- Checks shared by the startup report and restores
-- --------------------------------------------------------------------------

local ICON_EXT = { svg = true, png = true, jpg = true, jpeg = true }
local CWD = lfs.currentdir() or "."

local function absPath(p)
    if p:sub(1, 1) == "/" then return p end
    return CWD .. "/" .. (p:gsub("^%./", ""))
end

local function isIconPath(v)
    if type(v) ~= "string" or not v:find("/", 1, true) then return false end
    local ext = v:match("%.(%w+)$")
    if not (ext and ICON_EXT[ext:lower()]) then return false end
    return absPath(v):sub(1, #CWD + 11) ~= CWD .. "/resources/"
end

local function walk(v, fn, depth)
    depth = depth or 0
    if depth > 16 or type(v) ~= "table" then return end
    for _k, x in pairs(v) do
        if type(x) == "string" then fn(x) else walk(x, fn, depth + 1) end
    end
end

-- A target's settings, read-only. from_disk for store targets after a
-- device restore (the running plugin still holds the old ones).
local function targetSettings(t, from_disk)
    local data
    if type(t.store) == "function" then
        local ok, d = pcall(t.store, from_disk)
        if not ok then return {}, false end           -- store threw: unreadable
        if type(d) ~= "table" then return {}, true end -- not installed / no file yet
        data = d
    else
        data = G_reader_settings and G_reader_settings.data or {}
    end
    local prefix = t.setting_prefix
    local out = {}
    if (type(prefix) ~= "string" or prefix == "") and not t.store then return out, true end
    for k, v in pairs(data) do
        if type(k) == "string" and (type(prefix) ~= "string" or prefix == "" or k:sub(1, #prefix) == prefix) then
            out[k] = v
        end
    end
    return out, true
end

-- { paths, missing = {..}, outside }
local function iconCheck(t, from_disk)
    local settings, ok = targetSettings(t, from_disk)
    local seen, res = {}, { paths = 0, missing = {}, outside = 0, ok = ok }
    local own = t.icon_dir and absPath(t.icon_dir)
    walk(settings, function(v)
        if isIconPath(v) and not seen[v] then
            seen[v] = true
            res.paths = res.paths + 1
            if orig_attr(v, "mode") ~= "file" then
                res.missing[#res.missing + 1] = v
            elseif own and absPath(v:match("^(.*)/[^/]+$") or "") ~= own then
                res.outside = res.outside + 1
            end
        end
    end)
    local keys = 0
    for _k in pairs(settings) do keys = keys + 1 end
    res.keys = keys
    return res
end

local function logins_on()
    return G_reader_settings and G_reader_settings:isTrue("backup_patches_include_logins")
end

-- Set of icon paths currently in a target's settings (for restore
-- post-checks).
local function iconPathSet(t, from_disk)
    local settings = targetSettings(t, from_disk)
    local set = {}
    walk(settings, function(v)
        if isIconPath(v) then set[v] = true end
    end)
    return set
end

-- Post-check after a per-target restore: did the remap repoint anything,
-- and do the resulting icon paths exist? remapTarget's return value is
-- discarded by the patch, so a remap that changes nothing would otherwise
-- be invisible.
local function restorePostCheck(target, before)
    if not active() then return end
    local after = iconPathSet(target, false)
    local nB, nA, repointed = 0, 0, 0
    for _p in pairs(before) do nB = nB + 1 end
    for p in pairs(after) do
        nA = nA + 1
        if not before[p] then repointed = repointed + 1 end
    end
    local c = iconCheck(target, false)
    log("restore post-check %s: %d icon paths before → %d after, %d repointed, %d missing afterwards%s",
        q(target.text), nB, nA, repointed, #c.missing,
        #c.missing > 0 and (" (" .. table.concat(c.missing, ", "):sub(1, 200) .. ")") or "")
    if repointed == 0 and nA > 0 then
        log("  remap changed nothing: settings still point at the pre-restore paths")
    end
end

-- A before-restore safety backup means restoreBackup is about to run for
-- that target: snapshot its icon paths now, post-check on the next tick
-- (the restore is synchronous inside the current tap).
watchRestore = function(path)
    local tid = path:match("/backups/([^/]+)/[^/]*_before%-restore%.zip$")
    if not tid then return end
    for _i, tg in ipairs(Backup.targets) do
        if tg.id == tid then
            local before = iconPathSet(tg, false)
            UIManager:nextTick(function() pcall(restorePostCheck, tg, before) end)
            return
        end
    end
end

-- --------------------------------------------------------------------------
-- Device Backup & Restore (backup.koplugin)
-- --------------------------------------------------------------------------

local function pluginVersion()
    for _i, base in ipairs({ DATA .. "/plugins", "./plugins" }) do
        local f = orig_open(base .. "/backup.koplugin/_meta.lua", "r")
        if f then
            local s = f:read("*a") or ""
            f:close()
            return s:match("version%s*=%s*[\"']([^\"']+)") or "installed, version unknown"
        end
    end
    return "not installed"
end

local function loadTable(src)
    local chunk = src and loadstring(src)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, t = pcall(chunk)
    return ok and type(t) == "table" and t or nil
end

-- Reads a settings file from disk, bypassing the wrapped io.open (so the
-- read isn't counted as Patch Backup & Restore's file work).
local function readSettingsFile(rel)
    local f = orig_open(DataStorage:getSettingsDir() .. "/" .. rel, "r")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    return loadTable(src)
end

-- Opens a finished device backup and checks the icon map and logins.
local function inspectDeviceBackup(Arch, path)
    local r, rerr = Arch.createReader and Arch.createReader(path)
    if not r then log("  could not open the backup to check it: %s", q(rerr)) return end
    local entries, n = {}, 0
    for e in r:iterate() do
        local p = (e.path or ""):gsub("^%./", "")
        entries[p] = true
        n = n + 1
    end
    if n == 0 then
        r:close()
        log("  could not read any entries from the backup to check it")
        return
    end

    local map_src = entries["backup_patches/icons.lua"] and r:extractToMemory("backup_patches/icons.lua")
    local plan = loadTable(map_src)
    if plan and type(plan.map) == "table" then
        local mapped, missing = 0, {}
        for _old, rel in pairs(plan.map) do
            mapped = mapped + 1
            if not entries[rel] then missing[#missing + 1] = rel end
        end
        log("  icon map: %d icons mapped, %d missing from the zip%s", mapped, #missing,
            #missing > 0 and (": " .. table.concat(missing, ", ")) or "")
    else
        log("  icon map: none (needs Settings + Icons ticked, and icons in use)")
    end

    local S = Backup.secrets or {}
    local leaks = {}
    for p in pairs(entries) do
        local rel = p:match("^settings/(.+)$")
        if rel then
            local top = rel:match("^([^/]+)/")
            if (S.files or {})[rel] or (top and (S.folders or {})[top]) then
                leaks[#leaks + 1] = rel
            elseif (S.keys or {})[rel] then
                local t = loadTable(r:extractToMemory(p))
                if t then
                    for k in pairs(S.keys[rel]) do
                        if t[k] ~= nil then leaks[#leaks + 1] = rel .. " [" .. k .. "]" end
                    end
                end
            end
        end
    end
    r:close()
    if logins_on() then
        log("  logins: included on purpose (toggle on), %d login items in the zip", #leaks)
    elseif #leaks > 0 then
        log("  LOGINS LEAKED with the toggle off: %s", table.concat(leaks, ", "))
    else
        log("  logins: none in the zip (good)")
    end
    log("  %d entries in total", n)
end

local function hookDevice()
    local Arch = package.loaded["backup_archiver"]
    local Rest = package.loaded["backup_restore"]
    if type(Arch) == "table" and type(Arch.createBackup) == "function" and not Arch.__bp_diag then
        Arch.__bp_diag = true
        local orig = Arch.createBackup
        Arch.createBackup = function(options, ...)
            if not active() then return orig(options, ...) end
            extend()
            local comps = {}
            for k, v in pairs(type(options) == "table" and options.components or {}) do
                if v then comps[#comps + 1] = k end
            end
            table.sort(comps)
            log("device backup started: %s | logins toggle %s | memory %d KB",
                table.concat(comps, ", "), logins_on() and "ON" or "off", memKB())
            local t = now()
            local r = { pcall(orig, options, ...) }
            local ok, res = r[2], r[3]
            log("device backup %s in %d ms, memory %d KB", (r[1] and ok) and "done" or "FAILED", ms(t), memKB())
            if r[1] and ok then
                local path = type(res) == "table" and res.archive_path
                    or (type(options) == "table" and options.archive_path)
                local ok_i, err = pcall(inspectDeviceBackup, Arch, path)
                if not ok_i then log("  check failed: %s", q(err)) end
            elseif not r[1] then
                log("  error: %s", q(r[2]))
            else
                log("  reason: %s", q(res))
            end
            extend()
            if not r[1] then error(r[2], 0) end
            return unpack(r, 2, table.maxn(r))
        end
        log("watching Device Backup & Restore backups")
    end
    if type(Rest) == "table" and type(Rest.executeRestore) == "function" and not Rest.__bp_diag then
        Rest.__bp_diag = true
        local orig = Rest.executeRestore
        Rest.executeRestore = function(archive_path, options, ...)
            if not active() then return orig(archive_path, options, ...) end
            extend()
            local undo = type(options) == "table" and options.is_undo
            log("device %s started: %s | memory %d KB", undo and "undo" or "restore", short(archive_path), memKB())
            -- Baselines for the post-restore checks: per-target icon paths
            -- (HIGH 1: did the remap repoint anything?) and login tokens
            -- (HIGH 2: does the kept-logic put them back?).
            local paths_before, tokens_before = {}, {}
            if not undo then
                for _i, tg in ipairs(Backup.targets) do
                    paths_before[tg] = iconPathSet(tg, true)
                end
                for rel, keys in pairs((Backup.secrets or {}).keys or {}) do
                    local data = readSettingsFile(rel)
                    if data then
                        for k in pairs(keys) do
                            if data[k] ~= nil then
                                tokens_before[rel] = tokens_before[rel] or {}
                                tokens_before[rel][k] = true
                            end
                        end
                    end
                end
            end
            local t = now()
            local r = { pcall(orig, archive_path, options, ...) }
            log("device %s %s in %d ms, memory %d KB", undo and "undo" or "restore",
                (r[1] and r[2]) and "done" or "FAILED", ms(t), memKB())
            if r[1] and r[2] and not undo then
                for _i, tg in ipairs(Backup.targets) do
                    local c = iconCheck(tg, true)
                    if c.paths > 0 then
                        local repointed, pb = 0, paths_before[tg] or {}
                        for p in pairs(iconPathSet(tg, true)) do
                            if not pb[p] then repointed = repointed + 1 end
                        end
                        log("  %s: %d icon paths, %d repointed by remap, %d missing%s", q(tg.text), c.paths,
                            repointed, #c.missing,
                            #c.missing > 0 and (" (" .. table.concat(c.missing, ", "):sub(1, 200) .. ")") or "")
                    end
                end
                if next(tokens_before) then
                    local lost = {}
                    for rel, keys in pairs(tokens_before) do
                        local data = readSettingsFile(rel)
                        for k in pairs(keys) do
                            if not data or data[k] == nil then
                                lost[#lost + 1] = rel .. "[" .. k .. "]"
                            end
                        end
                    end
                    if #lost > 0 then
                        log("  TOKENS LOST by device restore (kept-logic failed): %s",
                            table.concat(lost, ", "))
                    else
                        log("  login tokens: all present after restore")
                    end
                end
            elseif not r[1] then
                log("  error: %s", q(r[2]))
            end
            extend()
            if not r[1] then error(r[2], 0) end
            return unpack(r, 2, table.maxn(r))
        end
        log("watching Device Backup & Restore restores")
    end
end

do
    local ok, PluginLoader = pcall(require, "pluginloader")
    if ok and type(PluginLoader) == "table" and type(PluginLoader.loadPlugins) == "function" then
        local orig = PluginLoader.loadPlugins
        PluginLoader.loadPlugins = function(self, ...)
            local r = { orig(self, ...) }
            pcall(hookDevice)
            return unpack(r, 1, table.maxn(r))
        end
    end
    pcall(hookDevice)
end

-- --------------------------------------------------------------------------
-- Startup report (once, a few seconds after start)
-- --------------------------------------------------------------------------

local function startupReport()
    log("==================== backup-patches diagnostics %s started ====================", DIAG_VERSION)
    log("Patch Backup & Restore %s | Device Backup & Restore %s", q(Backup.version), pluginVersion())
    local ok_v, ver = pcall(function() return require("version"):getCurrentRevision() end)
    log("KOReader %s | data folder %s | working folder %s", ok_v and q(ver) or "?", DATA, CWD)
    local NM = package.loaded["ui/network/manager"]
    local nt = G_reader_settings and G_reader_settings:readSetting("network_tweaks") or {}
    log("Network Tweaks %s, note style %s | SimpleUI store %s",
        (type(NM) == "table" and NM.__network_tweaks) and "on" or "not installed",
        q(nt.connect_style or "banner (default)"),
        package.loaded["infra/sui_store"] and "loaded" or "not loaded")
    log("logging until %s, diagnostics expire %s",
        os.date("%I:%M %p", window_end), os.date("%b %d %I:%M %p", first_run + EXPIRE_S))
    log("memory at start: %d KB", memKB())

    log("---- targets ----")
    for _i, t in ipairs(Backup.targets) do
        local c = iconCheck(t, false)
        local backups, bytes = 0, 0
        local dir = DATA .. "/backups/" .. tostring(t.id)
        if orig_attr(dir, "mode") == "directory" then
            for f in orig_dir(dir) do
                if f:match("%.zip$") then
                    backups = backups + 1
                    bytes = bytes + (orig_attr(dir .. "/" .. f, "size") or 0)
                end
            end
        end
        if c.keys > 0 or backups > 0 or not c.ok then
            log("%s: %s%d settings, %d icon paths (%d missing, %d outside %s), %d backups (%s)",
                q(t.text), c.ok and "" or "SETTINGS UNREADABLE, ", c.keys, c.paths, #c.missing, c.outside,
                short(t.icon_dir or "?"), backups, kb(bytes))
            for _j, m in ipairs(c.missing) do log("  missing icon: %s", m) end
        end
    end

    log("---- icons ----")
    local loose = 0
    if orig_attr(DATA .. "/icons", "mode") == "directory" then
        for f in orig_dir(DATA .. "/icons") do
            if orig_attr(DATA .. "/icons/" .. f, "mode") == "file" then loose = loose + 1 end
        end
    end
    log("loose files in koreader/icons/ (overrides, never touched): %d", loose)
    if type(Backup.findUnusedIcons) == "function" then
        local t = now()
        local ok, list = pcall(Backup.findUnusedIcons)
        if ok and type(list) == "table" then
            log("unused icons: %d (scan took %d ms)", #list, ms(t))
            for i, e in ipairs(list) do
                if i > 20 then log("  … and %d more", #list - 20) break end
                log("  %s", q(e.label or e.path))
            end
        else
            log("unused icon scan FAILED: %s", q(list))
        end
    end

    log("---- logins ----")
    log("Logins in device backups: %s", logins_on() and "ON (logins go into device backups)" or "off")
    local S = Backup.secrets or {}
    local present = {}
    local sdir = DataStorage:getSettingsDir()
    for name in pairs(S.files or {}) do
        if orig_attr(sdir .. "/" .. name, "mode") == "file" then present[#present + 1] = name end
    end
    for name in pairs(S.folders or {}) do
        if orig_attr(sdir .. "/" .. name, "mode") == "directory" then present[#present + 1] = name .. "/" end
    end
    for name in pairs(S.keys or {}) do
        if orig_attr(sdir .. "/" .. name, "mode") == "file" then present[#present + 1] = name .. " (tokens)" end
    end
    table.sort(present)
    log("login files on this device (kept out of device backups while off): %s",
        #present > 0 and table.concat(present, ", ") or "none")
    log("---- watching for %d minutes ----", math.floor((window_end - os.time()) / 60 + 0.5))
end

local function endOfWindow()
    if switched_off then return end
    if os.time() < window_end then
        orig_sched(UIManager, window_end - os.time() + 1, endOfWindow)
        return
    end
    log("---- logging stopped ----")
    log("taps: %d, slow (>%d ms): %d, slowest %d ms (on: %s)", totals.taps, SLOW_TAP_MS,
        totals.slow_taps, totals.slowest_ms, totals.slowest_what)
    log("Patch Backup & Restore file work while watching: %s", opsText(ops))
    log("memory now: %d KB", memKB())
end

orig_sched(UIManager, 5, function()
    local ok, err = pcall(startupReport)
    if not ok then log("startup report failed: %s", q(err)) end
end)
orig_sched(UIManager, WINDOW_S + 1, endOfWindow)

-- Shared notification contract v1: the "logging" note goes through Network
-- Tweaks' note first, then ReadMastery's, then the plain KOReader note.
-- Checks run at call time, so patch load order doesn't matter.
local function shared_note(banner_text, minimal_text, timeout)
    local Device = require("device")
    if Device.screen_saver_mode then return true end -- never over the sleep screen
    local NetworkMgr = require("ui/network/manager")
    if type(NetworkMgr.__network_tweaks_note) == "function" then
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

UIManager:nextTick(function()
    pcall(function()
        if shared_note("Backup diagnostics: logging for 15 min", "Backup diagnostics on", 3) then return end
        orig_show(UIManager, require("ui/widget/notification"):new{
            text = "Backup diagnostics: logging for 15 min",
            timeout = 3,
        })
    end)
end)
