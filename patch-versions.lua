-- patch-versions.lua — version manifest for the on-device patch updater.
--
-- The updater ("Check for Patch Updates" in 2-backup-patches.lua) fetches
-- this file from
--   https://raw.githubusercontent.com/BrownTigerz/-KOReader.patches/main/patch-versions.lua
-- and compares each installed patch's declared version against it.
--
-- MAINTENANCE (hand-edit, one line per release): when your patch chat ships
-- a new version, bump that patch's line here and push this file alongside
-- the patch (same commit is fine). Keep the table sorted by repo path.
-- Main patches live in the repo root; diagnostics live under debug/.
--
-- Format: { ["<repo path>"] = "<version>", ... }
-- The updater compares versions numerically per dot-separated component
-- and skips entries it can't parse, so a typo here can't break updating.
-- On the device, a diagnostic is updated wherever its copy sits
-- (patches/ when active, patches/debug/ when switched off); a stale
-- duplicate is cleaned up.

return {
    ["2-ReadMastery-notify.lua"] = "1.0.6",
    ["2-ReadMastery-quests.lua"] = "1.0.6",
    ["2-backup-patches.lua"] = "2.4.8",
    ["2-bookorbit-tweaks.lua"] = "2.14.3",
    ["2-debugging-menu.lua"] = "1.3.6",
    ["2-kobo-style-sleepscreen-banner.lua"] = "1.2.2",
    ["2-list-rating-progress.lua"] = "1.0.0",
    ["2-network-tweaks.lua"] = "1.12.0",
    ["2-quickmenu-toggle-state.lua"] = "1.0.4",
    ["2-readinginsights-tweaks.lua"] = "2.1.1",
    ["2-shelfsync-tweaks.lua"] = "1.11.18",
    ["2-screenshot-timer.lua"] = "1.0.0",
    ["2-shortcutstoolbar-icon-tweaks.lua"] = "1.17.0",
    ["2-shortcutstoolbar-quick-shelf.lua"] = "1.2.2",
    ["2-simpleui-sidepanel.lua"] = "1.0.5",
    ["2-simpleui-tweaks.lua"] = "2.14.7",
    ["2-track-reading-location.lua"] = "1.9.5",
    ["2-tweaks-menu.lua"] = "1.0.7",
    ["debug/2-zz-backup-patches-diagnostics.lua"] = "1.3.2",
    ["debug/2-zz-bookorbit-diagnostics.lua"] = "1.3.1",
    ["debug/2-zz-debugging-diagnostics.lua"] = "1.2.1",
    ["debug/2-zz-network-tweaks-diagnostics.lua"] = "1.3.1",
    ["debug/2-zz-readinginsights-tweaks-diagnostics.lua"] = "2.1.2",
    ["debug/2-zz-readmastery-diagnostics.lua"] = "1.1.0",
    ["debug/2-zz-shelfsync-tweaks-diagnostics.lua"] = "1.1.0",
    ["debug/2-zz-shortcutstoolbar-diagnostics.lua"] = "1.1.0",
    ["debug/2-zz-shortcutstoolbar-quick-shelf-diagnostics.lua"] = "1.2.0",
    ["debug/2-zz-simpleui-diagnostics.lua"] = "2.12.1",
    ["debug/2-zz-sleepscreen-banner-diagnostics.lua"] = "1.1.0",
    ["debug/2-zz-track-reading-location-diagnostics.lua"] = "1.2.1",
    ["debug/2-zz-tweaks-menu-diagnostics.lua"] = "1.1.0",
}







