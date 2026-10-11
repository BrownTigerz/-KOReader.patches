--[[
2-zz-readmastery-diagnostics.lua - TEMPORARY troubleshooting patch
Version 1.0.4

Changelog:
  1.0.4 (2026-10-11) - Shared log contract v1: all diagnostic lines are
    now appended as [readmastery]-tagged lines to the shared
    koreader/diagnostics.log (rotation at 256 KB, older part kept as
    diagnostics.log.old) instead of this patch's own
    readmastery-diagnostics.log; only the log-writing mechanics changed,
    all gating and call sites are untouched.
  1.0.3 (2026-10-11) - Review nits fixed: wrap() in the Full-style
    notifications hook now logs when a method is missing instead of
    skipping silently; the "hooked ReadMasteryNotify bridge" line only
    prints when at least one bridge function was actually wrapped;
    ReaderUI.onSuspend/onResume absence now logs a line instead of
    staying quiet (symmetric with the require-failure line).
  1.0.2 (2026-10-10) - Brought in line with the house diagnostics-patch
    standard: added the missing 30-minute active-logging window after
    each start (every hook now goes idle - still called, just stops
    writing - once the window closes, instead of logging for the whole
    multi-day expiry period); shrank the hard calendar expiry from 7
    days to 3 (the standard's 1-3 day range); timestamps now include
    the date, not just the time; the start-of-log line now reads
    "readmastery diagnostics <version> started (...)"; the one-time
    notification now states how long it'll log for; log() itself is
    now pcall-wrapped end to end, not just the string.format call.
  1.0.1 (2026-10-09) - Your own log caught this: addXP and ui/notifications
    failed to hook ("module not found"), and AchievementsView failed
    silently with no log line at all. Cause: those three did
    pcall(require, "readmasterycore" / "ui/notifications" /
    "ui/achievements_view") at file-load time, before ReadMastery's own
    main.lua has required them - same class of mistake as the "main" vs
    registerPatchPluginFunc fix already applied to the page-update timing
    hook, just not carried over to these three. All three now deferred
    into registerPatchPluginFunc callbacks like the timing hook, and the
    AchievementsView one now logs a failure line instead of going quiet.
  1.0.0 (2026-10-02) - First release.

Watches the ReadMastery quest + notification patches from OUTSIDE and
writes what it sees as tagged [readmastery] lines to the SHARED
diagnostics log:
    koreader/diagnostics.log
(Kobo: .adds/koreader/diagnostics.log)

It does NOT touch 2-ReadMastery-quests.lua or 2-ReadMastery-notify.lua at
all - everything here is read-only observation of things those two files
already expose (the shared notification bridge, ReadMastery's own XP
ledger, the settings files on disk) or of KOReader's own generic APIs
(UIManager, suspend/resume). Most of what those two patches actually do
lives in Lua `local` variables private to their own files - genuinely
unreachable from here, by design - so this can only ever show what's
externally visible, not everything.

How to use:
  1. Put this file in koreader/patches/ alongside the other two and
     restart KOReader.
  2. Within the next WINDOW_MIN minutes of that start, read normally -
     finish a book, let quests complete, whatever you're trying to
     catch. After the window closes every hook goes idle (still called,
     just stops writing) until the next restart.
  3. Send diagnostics.log (the [readmastery] lines are this patch's).
  4. Delete this file. It changes nothing, it only writes the log (plus
     the tiny settings/readmastery-diagnostics-meta.lua state file) -
     deleting both removes 100% of its footprint immediately.

Shuts itself off two ways:
  - Per start: logs for WINDOW_MIN minutes, then every hook stays
    installed but stops writing - "passes straight through" - until the
    next restart resets the window.
  - Calendar expiry: the first time this ever loads, it remembers that
    date in its own tiny settings file (never touches either main
    patch's settings). Once EXPIRE_AFTER_DAYS has passed, it stops
    installing any hooks at all, on every subsequent load - in case you
    forget to delete it.
The shared log file itself is size-capped (rotation at 256 KB, older
part kept as diagnostics.log.old) as a third, independent safety net.

The "zz" makes it load after both 2-ReadMastery-*.lua files, so the
notification bridge and the plugin's own classes already exist by the
time this wraps them.
]]

local userpatch = require("userpatch")
local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local LuaSettings = require("luasettings")
local lfs = require("libs/libkoreader-lfs")
local ok_time, ktime = pcall(require, "ui/time")

local PATCH_VERSION = "1.0.4"
local EXPIRE_AFTER_DAYS = 3
local WINDOW_MIN = 30 -- active-logging window per start, in minutes
local WINDOW_S = WINDOW_MIN * 60
local SLOW_PAGE_UPDATE_MS = 50 -- log a warning if a single page-turn's full handling chain takes longer than this

-- --------------------------------------------------------------------------
-- Expiry check - own tiny settings file, separate from both main patches'.
-- --------------------------------------------------------------------------

local meta = LuaSettings:open(DataStorage:getSettingsDir() .. "/readmastery-diagnostics-meta.lua")
local first_loaded = meta:readSetting("first_loaded")
if not first_loaded then
    first_loaded = os.time()
    meta:saveSetting("first_loaded", first_loaded)
    meta:flush()
end
local days_active = (os.time() - first_loaded) / 86400
local expired = days_active > EXPIRE_AFTER_DAYS

-- --------------------------------------------------------------------------
-- Log helper
-- --------------------------------------------------------------------------

local function now()
    return ok_time and ktime.now() or nil
end

local function ms(since)
    if not (ok_time and since) then return -1 end
    local ok, v = pcall(function() return ktime.to_ms(ktime.since(since)) end)
    return ok and v or -1
end

-- Shared log contract v1: all diagnostics append timestamped, tagged lines
-- to ONE file (koreader/diagnostics.log) so a full test run reads as a
-- single chronological log. Rotation at 256 KB, older part kept as
-- diagnostics.log.old.
local DIAG_TAG = "readmastery"
local SHARED_LOG = DataStorage:getDataDir() .. "/diagnostics.log"
local SHARED_MAX_BYTES = 256 * 1024
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
        f:write(os.date("%Y-%m-%d %I:%M:%S %p  "), "[", DIAG_TAG, "] ", line, "\n")
        f:close()
    end)
end

local function log(fmt, ...)
    shared_log(fmt, ...)
end

local function q(v)
    if v == nil then return "(nil)" end
    if type(v) == "table" then return "(table)" end
    local s = tostring(v)
    return s:gsub("\n", " | "):sub(1, 90)
end

if expired then
    log("EXPIRED (%.1f days since first load, limit %d) - not installing any hooks. Delete this file.",
        days_active, EXPIRE_AFTER_DAYS)
    return
end

-- Active-logging window for THIS start - separate from the multi-day
-- calendar expiry above. Once it closes, every hook below stays
-- installed (cheap, harmless) but stops writing until the next restart.
local started = os.time()
local active = true
local function on()
    if not active then return false end
    if os.time() - started > WINDOW_S then
        active = false
        log("==== %d minutes up: logging stopped, every hook is idle now ====", WINDOW_MIN)
        return false
    end
    return true
end

log("==================== readmastery diagnostics %s started (logging for %d min, day %.1f of %d) ====================",
    PATCH_VERSION, WINDOW_MIN, days_active, EXPIRE_AFTER_DAYS)

-- --------------------------------------------------------------------------
-- XP ledger - the single funnel every XP grant passes through (quest
-- completions, discovery bonuses, and ReadMastery's own organic reading
-- XP all call this), distinguishable by the `source` string the quest
-- patch passes. Catches a quest double-awarding, or awarding the wrong
-- amount, without needing any access to the quest patch's own internals.
-- --------------------------------------------------------------------------

-- NOTE: require("readmasterycore") only resolves once ReadMastery's own
-- main.lua has already required it during plugin instantiation - same
-- reasoning as hookPageUpdateTiming below ("main" being too generic to
-- require blind). Doing this at file-load time (top level) is too early:
-- this patch file loading after the other two, alphabetically, says
-- nothing about whether ReadMastery's plugin class has been instantiated
-- yet. Deferred via registerPatchPluginFunc instead, same as the timing
-- hook, so it only runs once ReadMastery itself is actually loading.
local function hookAddXP(plugin)
    if plugin._readmastery_diag_addxp_installed then return end
    plugin._readmastery_diag_addxp_installed = true

    local ok_core, Core = pcall(require, "readmasterycore")
    if not (ok_core and type(Core) == "table" and type(Core.addXP) == "function") then
        log("could not hook ReadMasteryCore.addXP (module not found - ReadMastery not installed/different version?)")
        return
    end
    local orig_addXP = Core.addXP
    Core.addXP = function(self, amount, source, ...)
        local level_before = (type(self.getLevel) == "function") and self:getLevel() or nil
        local t = now()
        local r = { orig_addXP(self, amount, source, ...) }
        local level_after = (type(self.getLevel) == "function") and self:getLevel() or nil
        if on() then
            log("addXP +%s  source=%s  level %s->%s  (%dms)",
                q(amount), q(source), q(level_before), q(level_after), ms(t))

            -- Ground truth: if this came from the quest patch, read what
            -- it actually persisted to disk (separate from whatever's
            -- still only in memory on its side) rather than trust our
            -- own log line.
            if type(source) == "string" and source:find("^quest:") then
                local ok_s, qsettings = pcall(function()
                    return LuaSettings:open(DataStorage:getSettingsDir() .. "/ReadMastery_quests.lua")
                end)
                if ok_s and qsettings then
                    local lifetime = qsettings:readSetting("lifetime") or {}
                    log("  quest settings on disk: total_completed=%s  total_xp=%s",
                        q(lifetime.total_completed), q(lifetime.total_xp))
                end
            end
        end
        return unpack(r)
    end
    log("hooked ReadMasteryCore.addXP")
end
userpatch.registerPatchPluginFunc("ReadMastery", hookAddXP)
userpatch.registerPatchPluginFunc("readmastery", hookAddXP)

-- --------------------------------------------------------------------------
-- Notification bridge - the shared pipeline both the quest patch and
-- Compact/Banner-style achievements/level-ups route through.
-- --------------------------------------------------------------------------

do
    local bridge = _G.ReadMasteryNotify
    if type(bridge) == "table" then
        local hooked_any = false
        if type(bridge.render) == "function" then
            local orig_render = bridge.render
            bridge.render = function(title, text, ascii_art, ...)
                if on() then log("bridge.render  title=%s  text=%s", q(title), q(text)) end
                return orig_render(title, text, ascii_art, ...)
            end
            hooked_any = true
        end
        if type(bridge.clearQueue) == "function" then
            local orig_clear = bridge.clearQueue
            bridge.clearQueue = function(...)
                if on() then log("bridge.clearQueue() called") end
                return orig_clear(...)
            end
            hooked_any = true
        end
        if hooked_any then
            log("hooked ReadMasteryNotify bridge")
        else
            log("ReadMasteryNotify bridge found but render/clearQueue are not functions - nothing wrapped")
        end
    else
        log("ReadMasteryNotify bridge not found (notify patch not installed, or didn't load first)")
    end
end

-- --------------------------------------------------------------------------
-- Full-style notifications bypass the bridge above entirely (by design -
-- see the notify patch's own comments), so they're wrapped separately
-- here for the same visibility when that style is selected.
-- --------------------------------------------------------------------------

-- Same early-require problem as addXP above: "ui/notifications" here is
-- ReadMastery's OWN submodule (not KOReader core's "ui/notification"),
-- only resolvable once ReadMastery's main.lua has required it. Deferred
-- the same way.
local function hookNotificationsFullPath(plugin)
    if plugin._readmastery_diag_notif_installed then return end
    plugin._readmastery_diag_notif_installed = true

    local ok_n, Notifications = pcall(require, "ui/notifications")
    if not (ok_n and type(Notifications) == "table") then
        log("could not hook ui/notifications module")
        return
    end
    local function wrap(name, describe_args)
        local orig = Notifications[name]
        if type(orig) ~= "function" then
            log("Notifications:%s not found - skipping wrap", name)
            return
        end
        Notifications[name] = function(self, ...)
            if on() then log("Notifications:%s  %s", name, describe_args(...)) end
            return orig(self, ...)
        end
    end
    wrap("showLevelUp", function(level) return "level=" .. q(level) end)
    wrap("showAchievement", function(achievement)
        return "id=" .. q(type(achievement) == "table" and achievement.id or achievement)
    end)
    wrap("showTierUp", function(achievement_id) return "achievement_id=" .. q(achievement_id) end)
    wrap("showStreakMilestone", function(days) return "days=" .. q(days) end)
    log("hooked ui/notifications (Full-style path)")
end
userpatch.registerPatchPluginFunc("ReadMastery", hookNotificationsFullPath)
userpatch.registerPatchPluginFunc("readmastery", hookNotificationsFullPath)

-- --------------------------------------------------------------------------
-- Achievement detail popup - marks when it opens, so the generic
-- UIManager show/close log below can be read against it to confirm the
-- "reopen the list after closing a detail" behavior actually fires once,
-- not zero or twice.
-- --------------------------------------------------------------------------

-- Same early-require problem as addXP/notifications above, plus this one
-- had no failure log line at all - it just silently did nothing. Deferred
-- now, with a failure line added so a miss is visible instead of quiet.
local function hookAchievementsView(plugin)
    if plugin._readmastery_diag_av_installed then return end
    plugin._readmastery_diag_av_installed = true

    local ok_av, AchievementsView = pcall(require, "ui/achievements_view")
    if not (ok_av and type(AchievementsView) == "table" and type(AchievementsView.showAchievementDetail) == "function") then
        log("could not hook AchievementsView.showAchievementDetail")
        return
    end
    local orig_detail = AchievementsView.showAchievementDetail
    AchievementsView.showAchievementDetail = function(self, achievement, ...)
        if on() then
            log("AchievementsView:showAchievementDetail  id=%s",
                q(type(achievement) == "table" and achievement.id or achievement))
        end
        return orig_detail(self, achievement, ...)
    end
    log("hooked AchievementsView.showAchievementDetail")
end
userpatch.registerPatchPluginFunc("ReadMastery", hookAchievementsView)
userpatch.registerPatchPluginFunc("readmastery", hookAchievementsView)

-- --------------------------------------------------------------------------
-- Generic popup show/close - catches timing/overlap across the whole
-- session (not filtered to ReadMastery's own text), same technique as
-- the network-tweaks diagnostics patch. Unfiltered on purpose: the
-- achievement detail popup above, for one, doesn't carry any of our own
-- recognizable wording, so filtering by content would miss it.
-- --------------------------------------------------------------------------

do
    local function describe(w)
        if type(w) ~= "table" then return q(w) end
        return q(w.text or w.title)
    end
    local orig_show = UIManager.show
    UIManager.show = function(self, w, ...)
        if on() and type(w) == "table" and (w.text or w.title) then log("show  %s", describe(w)) end
        return orig_show(self, w, ...)
    end
    local orig_close = UIManager.close
    UIManager.close = function(self, w, ...)
        if on() and type(w) == "table" and (w.text or w.title) then log("close  %s", describe(w)) end
        return orig_close(self, w, ...)
    end
    log("hooked UIManager.show/close")
end

-- --------------------------------------------------------------------------
-- Performance check: times the FULL page-update chain (ReadMastery's own
-- processing plus the quest patch's, since wrapping from outside can't
-- isolate just one layer) and flags it only if it's actually slow -
-- confirms the hot-path work holds up on real hardware, not just on
-- paper. Silent when fast, so this costs nothing to read through later.
-- --------------------------------------------------------------------------

-- Same mechanism both main patches use to get the REAL ReadMastery
-- class (handed to the callback directly by KOReader's userpatch
-- system) rather than a bare require() - "main" is too generic a
-- module name to require by itself and trust it resolved to the right
-- plugin's file instead of some other plugin's own main.lua.
local function hookPageUpdateTiming(plugin)
    if plugin._readmastery_diag_timing_installed then return end
    plugin._readmastery_diag_timing_installed = true
    if type(plugin.onPageUpdate) ~= "function" then
        log("plugin.onPageUpdate not found - cannot time it")
        return
    end
    local orig_opu = plugin.onPageUpdate
    plugin.onPageUpdate = function(self, page, ...)
        local t = now()
        local r = { orig_opu(self, page, ...) }
        local elapsed = ms(t)
        if on() and elapsed >= 0 and elapsed > SLOW_PAGE_UPDATE_MS then
            log("SLOW page update: %dms (page %s) - full chain including ReadMastery's own processing", elapsed, q(page))
        end
        return unpack(r)
    end
    log("hooked plugin.onPageUpdate for slow-update timing (threshold %dms)", SLOW_PAGE_UPDATE_MS)
end
userpatch.registerPatchPluginFunc("ReadMastery", hookPageUpdateTiming)
userpatch.registerPatchPluginFunc("readmastery", hookPageUpdateTiming)

-- --------------------------------------------------------------------------
-- Sleep-state check: neither main patch installs a timer or does any
-- background work (confirmed by code review), so nothing here SHOULD
-- fire during suspend/resume. This just confirms that empirically -
-- logs the gap and flags if anything unexpected ran in between.
-- --------------------------------------------------------------------------

do
    local ok_rui, ReaderUI = pcall(require, "apps/reader/readerui")
    if ok_rui and type(ReaderUI) == "table" then
        local suspend_t = nil
        if type(ReaderUI.onSuspend) == "function" then
            local orig_suspend = ReaderUI.onSuspend
            ReaderUI.onSuspend = function(self, ...)
                suspend_t = now()
                if on() then log("device suspending") end
                return orig_suspend(self, ...)
            end
        else
            log("ReaderUI.onSuspend not found - suspend timing not hooked")
        end
        if type(ReaderUI.onResume) == "function" then
            local orig_resume = ReaderUI.onResume
            ReaderUI.onResume = function(self, ...)
                if on() then log("device resumed (asleep for %dms)", suspend_t and ms(suspend_t) or -1) end
                suspend_t = nil
                return orig_resume(self, ...)
            end
        else
            log("ReaderUI.onResume not found - resume timing not hooked")
        end
        log("hooked ReaderUI.onSuspend/onResume")
    else
        log("could not hook ReaderUI for suspend/resume timing")
    end
end

-- One notice so you know it's on.
UIManager:nextTick(function()
    pcall(function()
        require("ui/widget/notification"):notify(
            "ReadMastery diagnostics: logging for " .. WINDOW_MIN .. " min")
    end)
end)
