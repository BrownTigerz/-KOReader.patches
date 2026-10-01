--[[
2-backup-patches.lua
KOReader user patch: per-patch backups, icon cleanup, and better device
backups with Device Backup & Restore (backup.koplugin).

Menu:  Tools → Patch Backup & Restore
       With the Add-ons patch it's under Tools → Add-ons → Patches instead,
       as long as "backup_patches" is in its PATCH_MENUS list.

  Patch Backup & Restore
  ├─ Shortcuts toolbar, SimpleUI, …   one entry per target you use
  │  ├─ Back up now
  │  ├─ Restore latest
  │  └─ History                      every backup: restore or delete,
  │                                   or delete all of this target's
  ├─ Delete all backups              every target's, safety backups too
  ├─ Icons
  │  ├─ Tidy icons
  │  └─ Unused icons
  └─ Logins in device backups        off by default

Back up now       The target's settings, any settings files it keeps in
                  koreader/settings/, and every icon its settings point to,
                  in one zip: koreader/backups/<target>/<target>_<date>.zip
Restore           Puts settings and files back, unpacks the icons into the
                  target's icon folder and points the settings there. Takes
                  a "before restore" backup first, then asks to restart.
                  "Restore latest" skips the automatic safety backups.

Tidy icons        Copies every icon a target uses into its own folder, flat
                  (koreader/icons/<target>/; SimpleUI: its sui_icons/), and
                  points the settings there. Originals stay put. Takes a
                  "before tidy" backup of the target first.
Unused icons      Icons nothing points to, in koreader/icons/ subfolders and
                  SimpleUI's sui_icons/ (packs included). Delete one by one
                  or all at once; emptied folders (and packs) go too.
                  Never touched: loose files directly in koreader/icons/
                  (KOReader's icon overrides) and KOReader's built-in icons.

Device Backup & Restore (backup.koplugin, 26.9.29 or newer for icons)
  Backup          With Settings and Icons ticked, every icon a target uses is
                  included, wherever it lives, plus a map of its old paths.
  Restore         Points the target settings at the restored icons, so they
                  work on another device too (Kobo, Kindle, Android).
  Logins          Off: saved logins, session tokens and the keys that decrypt
                  them (ShelfSync, ShelfSync tweaks) are left out, including
                  from Beam. Files that mix tokens with normal settings go in
                  with just the tokens removed, and a restore keeps the
                  device's own logins. On: everything goes in, so the new
                  device is signed in straight away - keep that file private.

Built-in targets: Shortcuts toolbar, Track Reading Location, Add-ons menu,
Reading Insights tweaks, ReadMastery Notify/Quests, ShelfSync tweaks
(settings only, never logins) and SimpleUI. Targets you don't use stay
hidden.

For patch authors - add a target:
  local BK = package.loaded.backup_patches or { targets = {} }
  package.loaded.backup_patches = BK
  BK.register{            -- or table.insert(BK.targets, {...}) if not loaded yet
      id = "mything", text = "My thing",
      setting_prefix = "mything",     -- optional: G_reader_settings keys
      files = { "mything.lua" },      -- optional: files in koreader/settings/
      store = function(from_disk)     -- optional: settings kept in your own
          return data_table, flush_fn --   file (every key, or those
      end,                            --   matching setting_prefix)
      icon_dir = "/abs/folder",       -- optional: where Tidy puts icons
      library_dirs = { "/abs/dir" },  -- optional: icon folders Unused cleans fully
  }
and declare secrets kept out of device backups (names relative to
koreader/settings/):
  BK.addSecrets{ files = { "x_login.lua" }, folders = { "x_session" },
                 keys = { ["x_settings.lua"] = { "api_token" } } }

Needs a KOReader build with zip support (ffi/archiver, 2024+).

Install: koreader/patches/2-backup-patches.lua (Kobo: .adds/koreader/patches/),
then restart.
--]]

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local DATA = DataStorage:getDataDir()
local SETTINGS_DIR = DataStorage:getSettingsDir()
local BACKUP_ROOT = DATA .. "/backups"
local ICON_ROOT = DATA .. "/icons"
local MANIFEST = "backup.lua"
local ICON_EXT = { svg = true, png = true, jpg = true, jpeg = true }

-- --------------------------------------------------------------------------
-- Registry
-- --------------------------------------------------------------------------

local Backup = package.loaded.backup_patches or { targets = {} }
package.loaded.backup_patches = Backup
Backup.targets = Backup.targets or {}

function Backup.register(target)
    target.icon_dir = target.icon_dir or (ICON_ROOT .. "/" .. target.id)
    for i, t in ipairs(Backup.targets) do
        if t.id == target.id then Backup.targets[i] = target; return end
    end
    table.insert(Backup.targets, target)
end

-- Secrets: never in a device backup unless "Logins in device backups" is on.
-- Names are relative to koreader/settings/.
local LOGINS_SETTING = "backup_patches_include_logins"
Backup.secrets = Backup.secrets or { files = {}, folders = {}, keys = {} }

function Backup.addSecrets(def)
    local S = Backup.secrets
    for _i, f in ipairs(def.files or {}) do S.files[f] = true end
    for _i, d in ipairs(def.folders or {}) do S.folders[d] = true end
    for file, keys in pairs(def.keys or {}) do
        S.keys[file] = S.keys[file] or {}
        for _i, k in ipairs(keys) do S.keys[file][k] = true end
    end
end

-- targets queued by patches that loaded before this one
for _i, t in ipairs(Backup.targets) do
    t.icon_dir = t.icon_dir or (ICON_ROOT .. "/" .. t.id)
end

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------

-- KOReader keeps paths relative to its own folder on some devices (Kobo:
-- "./icons/x.svg", with KOReader's folder as the working directory) and
-- absolute on others. Everything is compared in absolute form.
local CWD = lfs.currentdir() or "."

local function absPath(p)
    if p:sub(1, 1) == "/" then return p end
    if p == "." then return CWD end
    return CWD .. "/" .. (p:gsub("^%./", ""))
end

local ABS_DATA = absPath(DATA)
local BUILTIN = CWD .. "/resources/" -- KOReader's own icons: never touched

-- Path relative to koreader/ ("icons/x.svg"), or nil if it's outside.
local function dataRel(p)
    local a = absPath(p)
    if a:sub(1, #ABS_DATA + 1) == ABS_DATA .. "/" then return a:sub(#ABS_DATA + 2) end
end

local function dirOf(p) return p:match("^(.*)/[^/]+$") end

-- An icon file path (absolute or relative), not a bare name, not built in.
local function isIconPath(v)
    if type(v) ~= "string" or not v:find("/", 1, true) then return false end
    local ext = v:match("%.(%w+)$")
    if not (ext and ICON_EXT[ext:lower()]) then return false end
    return absPath(v):sub(1, #BUILTIN) ~= BUILTIN
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeFile(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    return true
end

-- settings file names only (no folders, no "..") - they live in SETTINGS_DIR
local function safeName(name)
    return type(name) == "string" and name:match("^[%w%._%-]+$") and not name:find("%.%.")
end

local function walkStrings(v, fn, depth)
    depth = depth or 0
    if depth > 16 or type(v) ~= "table" then return end
    for k, x in pairs(v) do
        if type(x) == "string" then
            local nx = fn(x)
            if nx ~= nil then v[k] = nx end
        else
            walkStrings(x, fn, depth + 1)
        end
    end
end

-- Where a target's settings live: KOReader's main settings, or the target's
-- own store. from_disk asks a store for what's on disk rather than what the
-- running plugin holds in memory (they differ right after a device restore).
local function targetStore(target, from_disk)
    if type(target.store) == "function" then
        local ok, data, flush = pcall(target.store, from_disk)
        if ok and type(data) == "table" then return data, flush or function() end end
        if not ok then logger.warn("backup_patches: settings store failed for", target.id, data) end
        return nil
    end
    if not G_reader_settings then return nil end
    return G_reader_settings.data, function() G_reader_settings:flush() end
end

-- The target's keys and values (values are the live tables, not copies).
local function collectSettings(target, data)
    local out = {}
    data = data or targetStore(target)
    if type(data) ~= "table" then return out end
    local prefix = target.setting_prefix
    if type(prefix) ~= "string" or prefix == "" then
        if not target.store then return out end
        prefix = nil -- own store: every key belongs to it
    end
    for k, v in pairs(data) do
        if type(k) == "string" and (not prefix or k:sub(1, #prefix) == prefix) then out[k] = v end
    end
    return out
end

-- Swaps icon paths in a target's settings. Returns how many changed.
local function remapTarget(target, remap, from_disk)
    local data, flush = targetStore(target, from_disk)
    if not data then return 0 end
    local changed = 0
    for k, v in pairs(collectSettings(target, data)) do
        local box = { v }
        walkStrings(box, function(x)
            local nx = remap[x]
            if nx then changed = changed + 1 end
            return nx
        end)
        data[k] = box[1] -- tables were edited in place; strings need this
    end
    if changed > 0 then flush() end
    return changed
end

local function existingFiles(target)
    local out = {}
    for _i, name in ipairs(target.files or {}) do
        if safeName(name) and lfs.attributes(SETTINGS_DIR .. "/" .. name, "mode") == "file" then
            out[#out + 1] = name
        end
    end
    return out
end

local function targetDir(target) return BACKUP_ROOT .. "/" .. target.id end

-- Newest first. Each entry: { path, name, time, pre_restore, size }
local function listBackups(target)
    local dir = targetDir(target)
    local list = {}
    if lfs.attributes(dir, "mode") ~= "directory" then return list end
    for f in lfs.dir(dir) do
        local y, mo, d, h, mi, s = f:match("_(%d%d%d%d)%-(%d%d)%-(%d%d)_(%d%d)(%d%d)(%d%d)")
        if y and f:match("%.zip$") then
            local path = dir .. "/" .. f
            local tag = f:match("_before%-(%w+)%.zip$") -- "restore" or "tidy"
            table.insert(list, {
                path = path,
                name = f,
                time = os.time{ year = y, month = mo, day = d, hour = h, min = mi, sec = s },
                pre_restore = tag ~= nil, -- any automatic safety backup
                tag = tag,
                size = lfs.attributes(path, "size") or 0,
            })
        end
    end
    table.sort(list, function(a, b) return a.name > b.name end)
    return list
end

-- A target is worth listing if there's something to back up or restore.
local function inUse(target)
    return next(collectSettings(target)) ~= nil
        or #existingFiles(target) > 0
        or #listBackups(target) > 0
end

local function prettyTime(t)
    local s = os.date("%b %d, %Y  %I:%M %p", t)
    return (s:gsub("  0", "  "))
end

local function prettySize(n)
    if n >= 1024 * 1024 then return string.format("%.1f MB", n / 1048576) end
    return string.format("%d KB", math.max(1, math.floor(n / 1024 + 0.5)))
end

-- Deletes every backup of the given targets (safety backups included).
-- Returns how many files went.
local function deleteAllBackups(targets)
    local n = 0
    for _i, t in ipairs(targets) do
        for _j, e in ipairs(listBackups(t)) do
            if os.remove(e.path) then n = n + 1 end
        end
        lfs.rmdir(targetDir(t)) -- only goes if it's empty now
    end
    return n
end

local function backupTotals(targets)
    local n, bytes = 0, 0
    for _i, t in ipairs(targets) do
        for _j, e in ipairs(listBackups(t)) do
            n = n + 1
            bytes = bytes + e.size
        end
    end
    return n, bytes
end

-- A book being open matters for targets with files: their patch may write
-- its file again when the book closes, undoing the restore.
local function bookOpen()
    local R = package.loaded["apps/reader/readerui"]
    return type(R) == "table" and R.instance ~= nil
end

-- --------------------------------------------------------------------------
-- Backup / restore
-- --------------------------------------------------------------------------

local function makeBackup(target, tag)
    local ok_a, Archiver = pcall(require, "ffi/archiver")
    if not ok_a then return nil, _("This KOReader version has no zip support.") end
    local dump = require("dump")

    local settings = collectSettings(target)
    local files = existingFiles(target)
    if next(settings) == nil and #files == 0 then
        return nil, _("Nothing to back up yet: no settings saved."), "empty"
    end

    -- Every icon file the settings point to, flattened into icons/ with
    -- unique names.
    local icons, used, seen = {}, {}, {}
    walkStrings({ settings }, function(v)
        if isIconPath(v) and not seen[v] and util.fileExists(v) then
            seen[v] = true
            local base, ext = v:match("([^/]+)%.(%w+)$")
            local name, n = base .. "." .. ext, 1
            while used[name] do
                n = n + 1
                name = string.format("%s_%d.%s", base, n, ext)
            end
            used[name] = true
            icons[name] = v
        end
    end)

    local manifest = {
        target = target.id,
        created = os.time(),
        koreader = require("version"):getCurrentRevision(),
        settings = settings,
        icons = icons, -- archive name -> original path
        files = files, -- settings files, stored under files/
    }

    local ok_d, manifest_src = pcall(dump, manifest)
    if not ok_d then
        logger.warn("backup_patches: could not serialise settings for", target.id, manifest_src)
        return nil, _("Could not read these settings.")
    end

    util.makePath(targetDir(target))
    local path = string.format("%s/%s_%s%s.zip", targetDir(target), target.id,
        os.date("%Y-%m-%d_%H%M%S"), tag and ("_" .. tag) or "")

    local w = Archiver.Writer:new()
    if not w:open(path, "zip") then return nil, w.err or _("Could not create zip.") end
    local count = 0
    local ok = w:addFileFromMemory(MANIFEST, "return " .. manifest_src)
    for name, orig in pairs(icons) do
        local data = readFile(orig)
        if data and w:addFileFromMemory("icons/" .. name, data) then count = count + 1 end
    end
    for _i, name in ipairs(files) do
        local data = readFile(SETTINGS_DIR .. "/" .. name)
        if not (data and w:addFileFromMemory("files/" .. name, data)) then ok = false end
    end
    w:close()
    if not ok then
        os.remove(path)
        return nil, w.err or _("Could not write backup.")
    end
    return path, count
end

local function restoreBackup(target, zip_path)
    local ok_a, Archiver = pcall(require, "ffi/archiver")
    if not ok_a then return nil, _("This KOReader version has no zip support.") end

    local r = Archiver.Reader:new()
    if not r:open(zip_path) then return nil, r.err or _("Could not open zip.") end
    for _e in r:iterate() do end -- index entries

    local src = r:extractToMemory(MANIFEST)
    local chunk = src and loadstring(src)
    if not chunk then r:close(); return nil, _("Not a valid backup (no manifest).") end
    setfenv(chunk, {})
    local ok_m, manifest = pcall(chunk)
    if not ok_m or type(manifest) ~= "table" or manifest.target ~= target.id then
        r:close()
        return nil, _("This backup belongs to something else.")
    end

    -- Safety net: snapshot the current setup first. Nothing to save is fine;
    -- any other failure stops the restore before anything is changed.
    local safe, safe_err, safe_why = makeBackup(target, "before-restore")
    if not safe and safe_why ~= "empty" then
        r:close()
        return nil, T(_("Couldn't make the safety backup, so nothing was changed.\n\n%1"), tostring(safe_err))
    end

    -- All icons go into one folder; remember old path -> new path.
    local remap, count = {}, 0
    if next(manifest.icons or {}) then util.makePath(target.icon_dir) end
    for name, orig in pairs(manifest.icons or {}) do
        local data = r:extractToMemory("icons/" .. name)
        local dest = target.icon_dir .. "/" .. name
        if data and writeFile(dest, data) then
            remap[orig] = dest
            count = count + 1
        end
    end

    -- Settings files go back into koreader/settings/.
    for _i, name in ipairs(manifest.files or {}) do
        if safeName(name) then
            local data = r:extractToMemory("files/" .. name)
            if data then writeFile(SETTINGS_DIR .. "/" .. name, data) end
        end
    end
    r:close()

    local data, flush = targetStore(target)
    if data and (target.store or target.setting_prefix) then
        local settings = manifest.settings or {}
        walkStrings({ settings }, function(v) return remap[v] end)
        for k in pairs(collectSettings(target, data)) do data[k] = nil end
        for k, v in pairs(settings) do data[k] = v end
        flush()
    end
    return true, count
end

-- --------------------------------------------------------------------------
-- Icon cleanup
-- --------------------------------------------------------------------------

-- Icons a target's settings point to that aren't directly in its own
-- folder (subfolders like SimpleUI's packs count as stray: tidy is flat).
local function strayIcons(target)
    local out, seen = {}, {}
    walkStrings({ collectSettings(target) }, function(v)
        if isIconPath(v) and not seen[v] and absPath(dirOf(v) or "") ~= absPath(target.icon_dir)
                and util.fileExists(v) then
            seen[v] = true
            out[#out + 1] = v
        end
    end)
    table.sort(out)
    return out
end

-- Copies a target's stray icons into its folder and repoints its settings.
-- Returns the number of icons moved.
local function tidyIcons(target)
    local stray = strayIcons(target)
    if #stray == 0 then return 0 end
    local safe, safe_err, safe_why = makeBackup(target, "before-tidy")
    if not safe and safe_why ~= "empty" then return nil, safe_err end
    util.makePath(target.icon_dir)

    local remap, moved = {}, 0
    for _i, src in ipairs(stray) do
        local data = readFile(src)
        if data then
            local base, ext = src:match("([^/]+)%.(%w+)$")
            local name, n, dest = base .. "." .. ext, 1, nil
            while true do
                local try = target.icon_dir .. "/" .. name
                local cur = readFile(try)
                if cur == nil then
                    if writeFile(try, data) then dest = try end
                    break
                elseif cur == data then
                    dest = try -- identical copy already there, reuse it
                    break
                end
                n = n + 1
                name = string.format("%s_%d.%s", base, n, ext)
            end
            if dest then
                remap[src] = dest
                moved = moved + 1
            end
        end
    end

    -- Rewritten in place, so a plugin holding the same tables sees the new
    -- paths straight away.
    remapTarget(target, remap)
    return moved
end

-- Icons in koreader/icons/ subfolders that no setting points to.
-- Loose files in koreader/icons/ are skipped: KOReader uses those as
-- overrides by file name, so no setting would ever mention them.
local function findUnusedIcons()
    local out = {}

    local refs = {}
    local function note(v) if isIconPath(v) then refs[absPath(v)] = true end end
    walkStrings({ G_reader_settings.data or {} }, note)
    for _i, t in ipairs(Backup.targets) do
        if t.store then
            local data = targetStore(t)
            if data then walkStrings({ data }, note) end
        end
    end
    -- Anything else that keeps a settings file in koreader/settings/ or a
    -- folder under it (SimpleUI: settings/simpleui/sui_settings.lua).
    local texts = {}
    local function readTexts(dir, depth)
        for f in lfs.dir(dir) do
            if f ~= "." and f ~= ".." then
                local p = dir .. "/" .. f
                local mode = lfs.attributes(p, "mode")
                if mode == "directory" and depth < 3 then
                    readTexts(p, depth + 1)
                elseif mode == "file" and f:match("%.lua$")
                        and (lfs.attributes(p, "size") or 0) < 4 * 1024 * 1024 then
                    texts[#texts + 1] = readFile(p) or ""
                end
            end
        end
    end
    if lfs.attributes(SETTINGS_DIR, "mode") == "directory" then readTexts(SETTINGS_DIR, 0) end
    local function mentioned(p)
        if refs[absPath(p)] then return true end
        -- "icons/x.svg" matches "./icons/x.svg" and ".../koreader/icons/x.svg"
        local needle = dataRel(p) or p
        for _i, t in ipairs(texts) do
            if t:find(needle, 1, true) then return true end
        end
        return false
    end

    -- root: folder being cleaned. min_depth 1 skips its loose files (the
    -- override spot in koreader/icons/); library folders are cleaned fully.
    local function scan(root, label, min_depth, library)
        local function walk(dir, depth)
            for f in lfs.dir(dir) do
                if f ~= "." and f ~= ".." then
                    local p = dir .. "/" .. f
                    local mode = lfs.attributes(p, "mode")
                    if mode == "directory" then
                        if depth < 8 then walk(p, depth + 1) end
                    elseif mode == "file" and depth >= min_depth and isIconPath(p)
                            and not mentioned(p) then
                        out[#out + 1] = {
                            path = p,
                            root = root,
                            library = library,
                            label = label .. p:sub(#root + 1),
                            size = lfs.attributes(p, "size") or 0,
                        }
                    end
                end
            end
        end
        if lfs.attributes(root, "mode") == "directory" then walk(root, 0) end
    end
    scan(ICON_ROOT, "icons", 1, false)
    for _i, t in ipairs(Backup.targets) do
        for _j, dir in ipairs(t.library_dirs or {}) do
            scan(dir, dir:match("([^/]+)$") or dir, 0, true)
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function hasIcons(dir, depth)
    depth = depth or 0
    for f in lfs.dir(dir) do
        if f ~= "." and f ~= ".." then
            local p = dir .. "/" .. f
            local mode = lfs.attributes(p, "mode")
            if mode == "file" and isIconPath(p) then return true end
            if mode == "directory" and depth < 8 and hasIcons(p, depth + 1) then return true end
        end
    end
    return false
end

local function removeTree(dir, depth)
    depth = depth or 0
    if depth > 8 then return end
    for f in lfs.dir(dir) do
        if f ~= "." and f ~= ".." then
            local p = dir .. "/" .. f
            if lfs.attributes(p, "mode") == "directory" then removeTree(p, depth + 1) else os.remove(p) end
        end
    end
    lfs.rmdir(dir)
end

-- Deletes an icon, then folders it leaves empty, up to (never including)
-- the root being cleaned. In a library folder (SimpleUI's sui_icons/), a
-- folder with no icons left goes too, with whatever else was in it (a
-- pack's manifest or readme).
local function removeIcon(entry)
    local ok = os.remove(entry.path)
    local root = entry.root or ICON_ROOT
    local dir = entry.path:match("^(.*)/[^/]+$")
    while dir and dir:sub(1, #root + 1) == root .. "/" do
        if entry.library and lfs.attributes(dir, "mode") == "directory" and not hasIcons(dir) then
            removeTree(dir)
            if lfs.attributes(dir, "mode") then break end
        elseif not lfs.rmdir(dir) then
            break -- only succeeds when empty
        end
        dir = dir:match("^(.*)/[^/]+$")
    end
    return ok ~= nil
end

Backup.tidyIcons = tidyIcons
Backup.findUnusedIcons = findUnusedIcons


-- --------------------------------------------------------------------------
-- Menu
-- --------------------------------------------------------------------------

local function short(p)
    local esc = (DATA:gsub("%p", "%%%0"))
    return (p:gsub("^" .. esc, "koreader"))
end

local function confirmRestore(target, entry)
    local UIManager = require("ui/uimanager")
    local ConfirmBox = require("ui/widget/confirmbox")
    local InfoMessage = require("ui/widget/infomessage")
    if target.files and #target.files > 0 and bookOpen() then
        UIManager:show(InfoMessage:new{
            text = T(_("Close the book first, then restore %1 from the file browser."), target.text),
        })
        return
    end
    UIManager:show(ConfirmBox:new{
        text = T(_("Restore %1 from %2?\n\nYour current setup is backed up first."),
            target.text, prettyTime(entry.time)),
        ok_text = _("Restore"),
        ok_callback = function()
            local ok, res = restoreBackup(target, entry.path)
            if ok then
                local msg = res > 0
                    and T(_("Restored, with %1 icons in:\n%2\n\nKOReader needs to restart."), res, short(target.icon_dir))
                    or _("Restored.\n\nKOReader needs to restart.")
                UIManager:askForRestart(msg)
            else
                UIManager:show(InfoMessage:new{ text = T(_("Restore failed:\n%1"), tostring(res)) })
            end
        end,
    })
end

local function targetMenu(target)
    local UIManager = require("ui/uimanager")
    local InfoMessage = require("ui/widget/infomessage")
    local ConfirmBox = require("ui/widget/confirmbox")

    return {
        {
            text = _("Back up now"),
            keep_menu_open = true,
            callback = function()
                local path, res = makeBackup(target)
                local text
                if not path then
                    text = T(_("Backup failed:\n%1"), tostring(res))
                elseif res > 0 then
                    text = T(_("Backed up settings and %1 icons to:\n%2"), res, short(path))
                else
                    text = T(_("Backed up to:\n%1"), short(path))
                end
                UIManager:show(InfoMessage:new{ text = text })
            end,
        },
        {
            text_func = function()
                for _i, e in ipairs(listBackups(target)) do
                    if not e.pre_restore then
                        return T(_("Restore latest (%1)"), prettyTime(e.time))
                    end
                end
                return _("Restore latest")
            end,
            enabled_func = function()
                for _i, e in ipairs(listBackups(target)) do
                    if not e.pre_restore then return true end
                end
                return false
            end,
            callback = function()
                for _i, e in ipairs(listBackups(target)) do
                    if not e.pre_restore then confirmRestore(target, e); return end
                end
            end,
        },
        {
            text = _("History"),
            enabled_func = function() return #listBackups(target) > 0 end,
            sub_item_table_func = function()
                local items = {}
                local n, bytes = backupTotals({ target })
                if n > 1 then
                    table.insert(items, {
                        text = T(_("Delete all (%1 · %2)"), n, prettySize(bytes)),
                        separator = true,
                        callback = function(touchmenu)
                            UIManager:show(ConfirmBox:new{
                                text = T(_("Delete all %1 backups of %2, safety backups included?\n\nThis can't be undone."), n, target.text),
                                ok_text = _("Delete all"),
                                ok_callback = function()
                                    deleteAllBackups({ target })
                                    -- Back out past the (now empty) history list.
                                    if touchmenu then touchmenu:backToUpperMenu() end
                                end,
                            })
                        end,
                    })
                end
                for _i, e in ipairs(listBackups(target)) do
                    table.insert(items, {
                        text = prettyTime(e.time)
                            .. (e.pre_restore and ("  · " .. (e.tag == "tidy"
                                and _("before tidy") or _("before restore"))) or "")
                            .. "  · " .. prettySize(e.size),
                        sub_item_table = {
                            {
                                text = _("Restore this backup"),
                                callback = function() confirmRestore(target, e) end,
                            },
                            {
                                text = _("Delete"),
                                callback = function(touchmenu)
                                    UIManager:show(ConfirmBox:new{
                                        text = T(_("Delete the backup from %1?"), prettyTime(e.time)),
                                        ok_text = _("Delete"),
                                        ok_callback = function()
                                            os.remove(e.path)
                                            -- Back out past the (now stale) history list.
                                            if touchmenu then
                                                touchmenu:backToUpperMenu()
                                                touchmenu:backToUpperMenu()
                                            end
                                        end,
                                    })
                                end,
                            },
                        },
                    })
                end
                return items
            end,
        },
    }
end

local function iconsMenu()
    local UIManager = require("ui/uimanager")
    local InfoMessage = require("ui/widget/infomessage")
    local ConfirmBox = require("ui/widget/confirmbox")


    local function runTidy(list)
        local total, skipped = 0, {}
        for _i, t in ipairs(list) do
            local n, err = tidyIcons(t)
            if n then
                total = total + n
            else
                skipped[#skipped + 1] = T(_("%1: %2"), t.text, tostring(err))
            end
        end
        if #skipped > 0 then
            -- Left untouched: their safety backup couldn't be made.
            UIManager:show(InfoMessage:new{
                text = T(_("Skipped, couldn't make the safety backup:\n%1"), table.concat(skipped, "\n")),
            })
        end
        if total > 0 then
            UIManager:askForRestart(T(_("Tidied %1 icons.\n\nKOReader needs to restart."), total))
        end
    end

    return {
        {
            text = _("Tidy icons"),
            sub_item_table_func = function()
                local list, total = {}, 0
                for _i, t in ipairs(Backup.targets) do
                    local n = #strayIcons(t)
                    if n > 0 then
                        list[#list + 1] = { target = t, n = n }
                        total = total + n
                    end
                end
                if #list == 0 then
                    return { { text = _("All icons are already tidy"), enabled = false } }
                end
                table.sort(list, function(a, b) return tostring(a.target.text) < tostring(b.target.text) end)

                local items = {
                    {
                        text = T(_("All targets (%1 icons)"), total),
                        separator = true,
                        callback = function()
                            UIManager:show(ConfirmBox:new{
                                text = T(_("Copy %1 icons into each target's own folder and point the settings there?\n\nOriginals stay where they are. Each target is backed up first."), total),
                                ok_text = _("Tidy"),
                                ok_callback = function()
                                    local targets = {}
                                    for _i, x in ipairs(list) do targets[#targets + 1] = x.target end
                                    runTidy(targets)
                                end,
                            })
                        end,
                    },
                }
                for _i, x in ipairs(list) do
                    table.insert(items, {
                        text = T(_("%1 (%2 icons)"), x.target.text, x.n),
                        callback = function()
                            UIManager:show(ConfirmBox:new{
                                text = T(_("Copy %1 icons into:\n%2\n\nand point %3 there?\n\nOriginals stay where they are. It's backed up first."),
                                    x.n, short(x.target.icon_dir), x.target.text),
                                ok_text = _("Tidy"),
                                ok_callback = function() runTidy({ x.target }) end,
                            })
                        end,
                    })
                end
                return items
            end,
        },
        {
            text = _("Unused icons"),
            sub_item_table_func = function()
                local unused = findUnusedIcons()
                if #unused == 0 then
                    return { { text = _("No unused icons"), enabled = false } }
                end
                local bytes = 0
                for _i, e in ipairs(unused) do bytes = bytes + e.size end

                local items = {
                    {
                        text = T(_("Delete all (%1 · %2)"), #unused, prettySize(bytes)),
                        separator = true,
                        callback = function(touchmenu)
                            UIManager:show(ConfirmBox:new{
                                text = T(_("Delete %1 icons that nothing points to?\n\nThis can't be undone."), #unused),
                                ok_text = _("Delete"),
                                ok_callback = function()
                                    local n = 0
                                    for _i, e in ipairs(unused) do
                                        if removeIcon(e) then n = n + 1 end
                                    end
                                    if touchmenu then touchmenu:backToUpperMenu() end
                                    UIManager:show(InfoMessage:new{ text = T(_("Deleted %1 icons."), n) })
                                end,
                            })
                        end,
                    },
                }
                for _i, e in ipairs(unused) do
                    table.insert(items, {
                        text = e.label .. "  · " .. prettySize(e.size),
                        callback = function(touchmenu)
                            UIManager:show(ConfirmBox:new{
                                text = T(_("Delete %1?\n\nNothing in your settings points to it."), e.label),
                                ok_text = _("Delete"),
                                ok_callback = function()
                                    removeIcon(e)
                                    -- Back out past the (now stale) list.
                                    if touchmenu then touchmenu:backToUpperMenu() end
                                end,
                            })
                        end,
                    })
                end
                return items
            end,
        },
    }
end

local MENU_TEXT = _("Patch Backup & Restore")
local mainItems

local MenuWidget = {}

-- The Add-ons patch (2-tweaks-menu.lua) moves this into Add-ons → Patches
-- when "backup_patches" is in its PATCH_MENUS list.
function MenuWidget:addToMainMenu(menu_items)
    menu_items.backup_patches = {
        text = MENU_TEXT,
        sorting_hint = "tools",
        sub_item_table_func = function() return mainItems() end,
    }
end

mainItems = function()
    local list = {}
    for _i, target in ipairs(Backup.targets) do
        if inUse(target) then list[#list + 1] = target end
    end
    table.sort(list, function(a, b) return tostring(a.text) < tostring(b.text) end)
    local items = {}
    for _i, target in ipairs(list) do
        table.insert(items, {
            text = target.text,
            sub_item_table_func = function() return targetMenu(target) end,
        })
    end
    if #items == 0 then
        items[1] = { text = _("Nothing to back up yet"), enabled = false }
    end
    items[#items].separator = true
    table.insert(items, {
        text_func = function()
            local n, bytes = backupTotals(Backup.targets)
            if n == 0 then return _("Delete all backups") end
            return T(_("Delete all backups (%1 · %2)"), n, prettySize(bytes))
        end,
        enabled_func = function() return (backupTotals(Backup.targets)) > 0 end,
        callback = function(touchmenu)
            local UIManager = require("ui/uimanager")
            local ConfirmBox = require("ui/widget/confirmbox")
            local InfoMessage = require("ui/widget/infomessage")
            local n = backupTotals(Backup.targets)
            UIManager:show(ConfirmBox:new{
                text = T(_("Delete all %1 patch backups, for every target, safety backups included?\n\nDevice Backup & Restore backups aren't affected. This can't be undone."), n),
                ok_text = _("Delete all"),
                ok_callback = function()
                    local gone = deleteAllBackups(Backup.targets)
                    -- Targets with nothing left drop off this menu: go up so
                    -- it's rebuilt next time.
                    if touchmenu then touchmenu:backToUpperMenu() end
                    UIManager:show(InfoMessage:new{ text = T(_("Deleted %1 backups."), gone) })
                end,
            })
        end,
    })
    table.insert(items, {
        text = _("Icons"),
        sub_item_table_func = iconsMenu,
    })
    table.insert(items, {
        text = _("Logins in device backups"),
        help_text = _("Off: Device Backup & Restore leaves out saved logins, session tokens and their keys. A device you restore to keeps its own logins.\n\nOn: they're included, so the new device is signed in straight away."),
        checked_func = function() return G_reader_settings:isTrue(LOGINS_SETTING) end,
        callback = function(touchmenu)
            if G_reader_settings:isTrue(LOGINS_SETTING) then
                G_reader_settings:saveSetting(LOGINS_SETTING, false)
                return
            end
            local UIManager = require("ui/uimanager")
            local ConfirmBox = require("ui/widget/confirmbox")
            UIManager:show(ConfirmBox:new{
                text = _("Include saved logins, session tokens and the keys that decrypt them in device backups?\n\nAnyone with the backup file can sign in to your accounts. Keep it private, and think twice before sending it with Beam."),
                ok_text = _("Include"),
                ok_callback = function()
                    G_reader_settings:saveSetting(LOGINS_SETTING, true)
                    if touchmenu then touchmenu:updateItems() end
                end,
            })
        end,
    })
    return items
end

-- Place it in the Tools tab, just above the "More tools" separator.
local function addToOrder(order_module)
    local ok, order = pcall(require, order_module)
    if not ok or type(order.tools) ~= "table" then return end
    for _i, v in ipairs(order.tools) do
        if v == "backup_patches" then return end
    end
    local pos = #order.tools + 1
    for i, v in ipairs(order.tools) do
        if type(v) == "string" and v:match("^%-%-%-") then pos = i; break end
    end
    table.insert(order.tools, pos, "backup_patches")
end

local function hookMenu(module_path)
    local ok, Menu = pcall(require, module_path)
    if not ok or Menu.__backup_patches_hooked then return end
    Menu.__backup_patches_hooked = true
    local orig = Menu.setUpdateItemTable
    Menu.setUpdateItemTable = function(self, ...)
        -- Menus can be rebuilt; register once per menu, not once per rebuild.
        local list = self.registered_widgets
        if list and self.registerToMainMenu then
            local found = false
            for _i, w in ipairs(list) do
                if w == MenuWidget then found = true; break end
            end
            if not found then self:registerToMainMenu(MenuWidget) end
        end
        return orig(self, ...)
    end
end

addToOrder("ui/elements/filemanager_menu_order")
addToOrder("ui/elements/reader_menu_order")
hookMenu("apps/filemanager/filemanagermenu")
hookMenu("apps/reader/modules/readermenu")

-- --------------------------------------------------------------------------
-- Device Backup & Restore (backup.koplugin) integration
--
-- The plugin archives koreader/icons/ as a folder but never looks at icon
-- paths in settings. So icons stored elsewhere get left out, and after a
-- restore on another device every path still points at the old device's
-- data folder. This fills both gaps for registered targets:
--   backup  – adds icons from outside koreader/icons/ as
--             icons/<target>/<name>, plus a map of old path -> new
--             (relative) path in backup_patches/icons.lua
--   restore – once the plugin is done, rewrites the target settings to
--             the unpacked icons in this device's koreader/icons/
-- --------------------------------------------------------------------------

local BKP_ENTRY = "backup_patches/icons.lua"

local function pack(...) return { n = select("#", ...), ... } end

-- Folders the plugin archives anyway (icons/ with Icons, settings/ with
-- Settings - both required for this to run).
-- Path relative to koreader/ if the plugin archives it anyway, else nil.
local function archivedRel(path)
    local rel = dataRel(path)
    if rel and (rel:match("^icons/") or rel:match("^settings/")) then return rel end
end

local function relIconDir(target)
    return archivedRel((target.icon_dir or (ICON_ROOT .. "/" .. target.id)) .. "/x")
        and dataRel(target.icon_dir or (ICON_ROOT .. "/" .. target.id))
        or ("icons/" .. target.id)
end

-- What to add for the backup being written:
--   map   = { [absolute icon path] = "icons/..." (relative to koreader/) }
--   extra = { { entry = "icons/<target>/<name>", disk = absolute path }, ... }
local function planIcons()
    local plan = { map = {}, extra = {} }
    local used = {}
    for _i, target in ipairs(Backup.targets) do
        walkStrings({ collectSettings(target) }, function(v)
            if not isIconPath(v) or plan.map[v] or not util.fileExists(v) then return end
            local rel = archivedRel(v)
            if rel then
                -- The plugin archives it already; only the path needs
                -- fixing on restore.
                plan.map[v] = rel
                return
            end
            local base, ext = v:match("([^/]+)%.(%w+)$")
            local dir = relIconDir(target)
            local name, n = base .. "." .. ext, 1
            -- Don't collide with this backup's other icons or with files the
            -- plugin is already archiving from koreader/icons/.
            while used[dir .. "/" .. name] or util.fileExists(DATA .. "/" .. dir .. "/" .. name) do
                n = n + 1
                name = string.format("%s_%d.%s", base, n, ext)
            end
            local entry = dir .. "/" .. name
            used[entry] = true
            plan.map[v] = entry
            table.insert(plan.extra, { entry = entry, disk = v })
        end)
    end
    return plan
end

local pending -- { plan, strip }: handed from createBackup to its writer

-- A settings file as a plain table, or nil.
local function loadLuaFile(path)
    local chunk = loadfile(path)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, t = pcall(chunk)
    return ok and type(t) == "table" and t or nil
end

local function isSecretFile(rel)
    local S = Backup.secrets
    if S.files[rel] then return true end
    local top = rel:match("^([^/]+)/")
    return top ~= nil and S.folders[top] == true
end

local function hookArchiver(Arch)
    if Arch.__backup_patches_hooked then return end
    Arch.__backup_patches_hooked = true
    local orig_create, orig_writer = Arch.createBackup, Arch.createWriter

    Arch.createBackup = function(options, ...)
        local C = package.loaded["backup_constants"]
        local comps = (options and options.components)
            or (C and C.DEFAULT_COMPONENT_SELECTION) or {}
        local plan
        if comps.settings and comps.icons then
            local ok, p = pcall(planIcons)
            if ok and next(p.map) then
                plan = p
            elseif not ok then
                logger.warn("backup_patches: icon scan failed:", p)
            end
        end
        pending = {
            plan = plan,
            strip = not (G_reader_settings and G_reader_settings:isTrue(LOGINS_SETTING)),
        }
        local res = pack(pcall(orig_create, options, ...))
        pending = nil
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, res.n)
    end

    -- createBackup opens exactly one writer. The rollback snapshot opens its
    -- own outside createBackup, so it stays complete (it never leaves the
    -- device, and Undo has to put the logins back too).
    Arch.createWriter = function(...)
        local w, err = orig_writer(...)
        local job = pending
        pending = nil
        if not w or not job then return w, err end
        local dump = require("dump")

        if job.strip then
            local orig_add = w.addDisk
            local left_out = 0
            w.addDisk = function(self, entry, disk, ...)
                local rel = type(entry) == "string" and entry:match("^settings/(.+)$")
                if rel then
                    if isSecretFile(rel) then
                        left_out = left_out + 1
                        return false -- not added, not counted
                    end
                    local keys = Backup.secrets.keys[rel]
                    local data = keys and loadLuaFile(disk)
                    if data then
                        for k in pairs(keys) do data[k] = nil end
                        return self:addMemory(entry, "-- backup_patches: logins removed\nreturn " .. dump(data))
                    end
                end
                return orig_add(self, entry, disk, ...)
            end
            local close0 = w.close
            w.close = function(self, ...)
                if left_out > 0 then logger.info("backup_patches: left", left_out, "login files out of device backup") end
                return close0(self, ...)
            end
        end

        local plan = job.plan
        if not plan then return w, err end
        local orig_close = w.close
        w.close = function(self, ...)
            local ok, e = pcall(function()
                local added = 0
                for _i, x in ipairs(plan.extra) do
                    if self:addDisk(x.entry, x.disk) then
                        added = added + 1
                    else
                        plan.map[x.disk] = nil -- not in the archive, don't remap it
                    end
                end
                self:addMemory(BKP_ENTRY, "return " .. dump{
                    data_dir = DATA,
                    created = os.time(),
                    map = plan.map,
                })
                logger.info("backup_patches: added", added, "icons to device backup")
            end)
            if not ok then logger.warn("backup_patches: could not add icons:", e) end
            return orig_close(self, ...)
        end
        return w, err
    end
end

local function readPlan(Arch, archive_path)
    local r = Arch.createReader(archive_path)
    if not r then return nil end
    local src
    for e in r:iterate() do
        local p = e.path or ""
        if p == BKP_ENTRY or p == "./" .. BKP_ENTRY then
            src = r:extractToMemory(p)
            break
        end
    end
    r:close()
    local chunk = src and loadstring(src)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, plan = pcall(chunk)
    if ok and type(plan) == "table" and type(plan.map) == "table" then return plan end
end

local function applyIconPaths(archive_path, options)
    local Arch = package.loaded["backup_archiver"]
    if type(Arch) ~= "table" or type(Arch.createReader) ~= "function" then return end

    -- Only when the backup's settings were actually put back.
    local comps = options and options.selected_components
    if not comps and type(Arch.readManifest) == "function" then
        local m = Arch.readManifest(archive_path)
        comps = m and m.components
    end
    -- If it can't be told whether settings came back, leave them alone.
    if type(comps) ~= "table" or not comps.settings then return end

    local plan = readPlan(Arch, archive_path)
    if not plan then return end

    local remap = {}
    for old, rel in pairs(plan.map) do
        if type(old) == "string" and type(rel) == "string"
                and (rel:match("^icons/") or rel:match("^settings/"))
                and not rel:find("%.%.") then
            local new = DATA .. "/" .. rel
            -- Skip if the icons component wasn't restored.
            if new ~= old and lfs.attributes(new, "mode") == "file" then remap[old] = new end
        end
    end
    if not next(remap) then return end

    -- Own stores are read from disk: the plugin just wrote the restored file,
    -- while the running plugin still holds the old settings in memory.
    local changed = 0
    for _i, target in ipairs(Backup.targets) do
        changed = changed + remapTarget(target, remap, true)
    end
    if changed > 0 then
        logger.info("backup_patches: repointed", changed, "icon settings")
    end
end

local function hookRestore(Rest)
    if Rest.__backup_patches_hooked then return end
    Rest.__backup_patches_hooked = true
    local orig = Rest.executeRestore
    Rest.executeRestore = function(archive_path, options, ...)
        -- This device's logins in files that mix tokens with settings. A
        -- backup made without logins would otherwise sign this device out.
        local kept = {}
        if not (options and options.is_undo) then
            for rel, keys in pairs(Backup.secrets.keys) do
                local data = loadLuaFile(SETTINGS_DIR .. "/" .. rel)
                if data then
                    for k in pairs(keys) do
                        if data[k] ~= nil then
                            kept[rel] = kept[rel] or {}
                            kept[rel][k] = data[k]
                        end
                    end
                end
            end
        end

        local res = pack(orig(archive_path, options, ...))

        if res[1] and next(kept) then
            local ok, e = pcall(function()
                local dump = require("dump")
                for rel, vals in pairs(kept) do
                    local path = SETTINGS_DIR .. "/" .. rel
                    local data = loadLuaFile(path)
                    if data then
                        local changed = false
                        for k, v in pairs(vals) do
                            if data[k] == nil then data[k] = v; changed = true end
                        end
                        if changed then writeFile(path, "-- we can read Lua syntax here!\nreturn " .. dump(data) .. "\n") end
                    end
                end
            end)
            if not ok then logger.warn("backup_patches: could not keep logins:", e) end
        end

        -- Undo restores the plugin's rollback snapshot, which has no map.
        if res[1] and not (options and options.is_undo) then
            local ok, e = pcall(applyIconPaths, archive_path, options)
            if not ok then logger.warn("backup_patches: icon path fix failed:", e) end
        end
        return unpack(res, 1, res.n)
    end
end

local function hookDeviceBackup()
    local Arch = package.loaded["backup_archiver"]
    local Rest = package.loaded["backup_restore"]
    if type(Arch) == "table" and type(Arch.createBackup) == "function"
            and type(Arch.createWriter) == "function" then
        hookArchiver(Arch)
    end
    if type(Rest) == "table" and type(Rest.executeRestore) == "function" then
        hookRestore(Rest)
    end
end

-- The plugin's modules only exist after plugins load, which happens after
-- userpatches run. Hook once they're there (and right now, in case they are).
pcall(hookDeviceBackup)
do
    local ok, PluginLoader = pcall(require, "pluginloader")
    if ok and type(PluginLoader) == "table" and not PluginLoader.__backup_patches_hooked then
        PluginLoader.__backup_patches_hooked = true
        local orig = PluginLoader.loadPlugins
        PluginLoader.loadPlugins = function(self, ...)
            local res = pack(orig(self, ...))
            pcall(hookDeviceBackup)
            return unpack(res, 1, res.n)
        end
    end
end

-- --------------------------------------------------------------------------
-- Built-in targets (patches that don't register themselves).
-- SimpleUI Mod registers itself. Targets you don't use stay hidden.
-- --------------------------------------------------------------------------

Backup.register{
    id = "shortcutstoolbar",
    text = _("Shortcuts toolbar"),
    setting_prefix = "shortcutstoolbar", -- plugin settings + icon tweaks patch
}

Backup.register{
    id = "readingloc",
    text = _("Track Reading Location"),
    setting_prefix = "readingloc_",       -- button look and behaviour
}

Backup.register{
    id = "addons_menu",
    text = _("Add-ons menu"),
    setting_prefix = "addons_menu_",      -- what's in / out of Add-ons
}

Backup.register{
    id = "readinginsights_tweaks",
    text = _("Reading Insights tweaks"),
    setting_prefix = "ri_cover_calendar",
}

Backup.register{
    id = "readmastery_notify",
    text = _("ReadMastery Notify"),
    files = { "ReadMastery_notify.lua" },
}

Backup.register{
    id = "readmastery_quests",
    text = _("ReadMastery Quests"),
    files = { "ReadMastery_quests.lua" }, -- settings + quest progress
}

Backup.register{
    id = "shelfsync_tweaks",
    text = _("ShelfSync tweaks"),
    -- Settings only. Saved logins and the key that encrypts them are left
    -- out on purpose: a backup with both would expose your passwords.
    files = { "shelfsync_tweaks.lua" },
}

-- ShelfSync (Lyfts/ShelfSync) and the ShelfSync tweaks patch.
Backup.addSecrets{
    files = {
        "shelfsync_goodreads_login.lua",   -- tweaks: saved logins
        "shelfsync_storygraph_login.lua",
        "goodreadskosync_keyring.lua",     -- tweaks: key for the above
        "shelfsync_keyring.lua",           -- ShelfSync: key for its passwords
    },
    folders = { "goodreadskosync" },       -- tweaks: Goodreads session
    keys = {
        ["goodreadssync_settings.lua"]  = { "session_cookie", "cookie_refresh_url", "cookie_refresh_token" },
        ["storygraphsync_settings.lua"] = { "session_cookie", "remember_token" },
        ["hardcoversync_settings.lua"]  = { "api_token" },
        ["fablesync_settings.lua"]      = { "email", "id_token", "refresh_token", "token_expires_at",
                                            "password_enc", "password_plain" },
        ["pageboundsync_settings.lua"]  = { "email", "firebase_id_token", "refresh_token", "token_expires_at",
                                            "api_token", "password_enc", "password_plain" },
    },
}

-- SimpleUI (doctorhetfield-cmd/simpleui.koplugin) keeps its settings in
-- its own file. Its icons are tidied into its own sui_icons/ folder, which
-- SimpleUI's own backup carries too.
local SUI_FILE = SETTINGS_DIR .. "/simpleui/sui_settings.lua"
Backup.register{
    id = "simpleui_plugin",
    text = _("SimpleUI"),
    icon_dir = SETTINGS_DIR .. "/simpleui/sui_icons",
    -- Unused icons cleans all of sui_icons/, packs included: after a tidy,
    -- everything in use sits loose in sui_icons/ and the packs are spare.
    library_dirs = { SETTINGS_DIR .. "/simpleui/sui_icons" },
    store = function(from_disk)
        local S = package.loaded["infra/sui_store"]
        if not from_disk and type(S) == "table" and type(S.iterateKeys) == "function" then
            local _f, data = S:iterateKeys() -- the running plugin's live table
            if type(data) == "table" then
                return data, function() S:flush() end
            end
        end
        if lfs.attributes(SUI_FILE, "mode") ~= "file" then return nil end
        local s = require("luasettings"):open(SUI_FILE)
        return s.data, function() s:flush() end
    end,
}

logger.dbg("backup_patches: loaded", #Backup.targets, "targets")
