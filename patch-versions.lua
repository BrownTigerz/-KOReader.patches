-- patch-versions.lua — version manifest for the on-device patch updater.
--
-- The updater ("Check for Patch Updates" in 2-backup-patches.lua) fetches
-- this file from
--   https://raw.githubusercontent.com/BrownTigerz/-KOReader.patches/main/patch-versions.lua
-- and compares each installed patch's declared version against it.
--
-- MAINTENANCE (hand-edit, one line per release): when your patch chat ships
-- a new version, bump that patch's line here and push this file alongside
-- the patch (same commit is fine). Keep the table sorted by filename.
-- Only the 13 main patches are listed — diagnostics are temporary and are
-- updated by hand, never by the updater.
--
-- Format: { ["<repo-root filename>"] = "<version>", ... }
-- The updater compares versions numerically per dot-separated component
-- and skips entries it can't parse, so a typo here can't break updating.

return {
    ["2-ReadMastery-notify.lua"] = "1.0.4",
    ["2-ReadMastery-quests.lua"] = "1.0.3",
    ["2-backup-patches.lua"] = "2.2.0",
    ["2-debugging-menu.lua"] = "1.3.3",
    ["2-kobo-style-sleepscreen-banner.lua"] = "1.1.3",
    ["2-network-tweaks.lua"] = "1.8.2",
    ["2-readinginsights-tweaks.lua"] = "1.1.5",
    ["2-shelfsync-tweaks.lua"] = "1.11.11",
    ["2-shortcutstoolbar-icon-tweaks.lua"] = "1.12.2",
    ["2-simpleui-tweaks.lua"] = "2.8.5",
    ["2-track-reading-location.lua"] = "1.9.4",
    ["2-tweaks-menu.lua"] = "1.0.4",
    ["2-xray-direct-lookup.lua"] = "1.1.10",
}
