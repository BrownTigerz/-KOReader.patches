-- ShelfSync tweaks (one patch, put in koreader/patches/ and restart)
--
-- 1) Goodreads "Log in" (email + password) in ShelfSync > Providers >
--    Goodreads > Account, same as StoryGraph's. Login code is bundled from
--    goodreadskosync (MIT) at the bottom -- that plugin is NOT needed.
-- 2) "Remember my login" for both Goodreads and StoryGraph. Tap "Log in as..."
--    to sign in with the saved login, long-press it to edit, or use
--    "Forget saved login". Saved encrypted with a device-local key when possible.
-- 3) Goodreads search / CSRF fetch routed around the AWS WAF bot check
--    (/book/auto_complete and /review/list instead of /search and /).
-- 4) ShelfSync > Settings, above "Verbose logging":
--      * Exclude WikiReader articles  (no autolink for koreader/cache/wikireader/)
--      * Hide providers > Fable / Hardcover / Goodreads / StoryGraph
--    Only "Exclude WikiReader articles" is ON by default; the Hide toggles
--    start OFF. Hiding a provider also stops it doing anything.
--    Menu changes show after reopening the book / file browser.

local userpatch = require("userpatch")

-- In-memory caches, shared across ShelfSync re-inits (the hook below runs
-- every time a book / the file browser opens). Avoids hitting the Kobo's
-- storage on every page turn and menu redraw.
local CACHE = {
    creds = {},    -- [file] = { email, pw } or false (= none saved)
    tweaks = nil,  -- table of toggle values, loaded once
    csrf = nil,    -- Goodreads CSRF token
    csrf_at = 0,
    uid = nil,     -- Goodreads user id
}
-- Login: single attempt (no hidden 2s/4s sleep-and-retry that freezes the
-- screen), 10s socket timeout instead of 15. Saved login = one tap to retry.
local LOGIN_OPTS = { attempts = 1, timeout = 10 }
local CSRF_TTL = 120 -- seconds; Goodreads rotates tokens, same TTL goodreadskosync uses

userpatch.registerPatchPluginFunc("shelfsync", function()
    local _ = require("gettext")
    local UIManager = require("ui/uimanager")
    local Trapper = require("ui/trapper")
    local InfoMessage = require("ui/widget/infomessage")
    local GoodreadsMenu = require("shelfsync/lib/goodreads/menu")
    local SETTING = require("shelfsync/lib/common/constants/settings")

    local function notify(text, warn)
        UIManager:show(InfoMessage:new{
            text = text,
            icon = warn and "notice-warning" or nil,
        })
    end

    -- Saved login ---------------------------------------------------------
    local LuaSettings = require("luasettings")
    local DataStorage = require("datastorage")
    local CRED_FILE = DataStorage:getSettingsDir() .. "/shelfsync_goodreads_login.lua"

    local SG_CRED_FILE = DataStorage:getSettingsDir() .. "/shelfsync_storygraph_login.lua"

    local function credStore(file) return LuaSettings:open(file or CRED_FILE) end

    local function loadCreds(file)
        file = file or CRED_FILE
        local c = CACHE.creds[file]
        if c ~= nil then
            if c == false then return nil end
            return c[1], c[2]
        end
        CACHE.creds[file] = false
        local s = credStore(file)
        local email, pw = s:readSetting("email"), s:readSetting("password")
        if not email or not pw or email == "" or pw == "" then return nil end
        if s:readSetting("encrypted") then
            local ok, Crypto = pcall(require, "shelfsync_grlogin.crypto_util")
            if not ok then return nil end
            pw = Crypto.unprotect(pw, true)
            if not pw or pw == "" then return nil end
        end
        CACHE.creds[file] = { email, pw }
        return email, pw
    end

    local function saveCreds(email, pw, file)
        local blob, encrypted = pw, false
        local ok, Crypto = pcall(require, "shelfsync_grlogin.crypto_util")
        if ok then blob, encrypted = Crypto.protect(pw) end
        local s = credStore(file)
        s:saveSetting("email", email)
        s:saveSetting("password", blob)
        s:saveSetting("encrypted", encrypted and true or false)
        s:flush()
        CACHE.creds[file or CRED_FILE] = { email, pw }
        return encrypted
    end

    local function clearCreds(file)
        os.remove(file or CRED_FILE)
        CACHE.creds[file or CRED_FILE] = false
    end

    local function failureText(result)
        local err = result and result.error
        if err == "SIGNIN_BLOCKED" then
            return _("Goodreads login blocked by a sign-in check. Try again later or on another network, or paste a browser cookie instead.")
        elseif err == "INVALID_CREDENTIALS" then
            return _("Goodreads login failed: check your email and password.")
        elseif err == "NETWORK_ERROR" then
            return _("Goodreads login failed: no network connection.")
        end
        return _("Goodreads login failed (") .. tostring(result and result.stage or "?")
            .. ": " .. tostring(err or "?") .. ")"
    end

    -- Runs a blocking login step with a "working" message, then routes the result.
    local function runStep(self, message, step, creds)
        Trapper:wrap(function()
            local info = InfoMessage:new{ text = message }
            UIManager:show(info)
            UIManager:forceRePaint()
            local ok, result = pcall(step)
            UIManager:close(info)
            if not ok then
                notify(_("Goodreads login error: ") .. tostring(result), true)
                return
            end
            self:_grkHandleResult(result, creds)
        end)
    end

    local function prompt(title, on_submit)
        local InputDialog = require("ui/widget/inputdialog")
        local dialog
        dialog = InputDialog:new{
            title = title,
            input = "",
            buttons = { {
                { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
                {
                    text = _("Submit"),
                    callback = function()
                        local value = dialog:getInputText()
                        UIManager:close(dialog)
                        on_submit(value)
                    end,
                },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function GoodreadsMenu:_grkHandleResult(result, creds)
        local Login = require("shelfsync_grlogin.auth.login")

        if result and result.ok and result.session and result.session.cookies
                and result.session.cookies ~= "" then
            self.settings:updateSetting(SETTING.GOODREADS.SESSION_COOKIE, result.session.cookies)
            CACHE.csrf, CACHE.csrf_at, CACHE.uid = nil, 0, nil
            local saved_email, saved_pw = loadCreds()
            if creds and not (saved_email == creds.email and saved_pw == creds.password) then
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = _("Logged in to Goodreads.\n\nSave your email and password on this device so you don't have to type them again?"),
                    ok_text = _("Save"),
                    cancel_text = _("Not now"),
                    ok_callback = function()
                        local encrypted = saveCreds(creds.email, creds.password)
                        notify(encrypted and _("Login saved (encrypted).")
                            or _("Login saved (plain text -- encryption unavailable on this device)."))
                    end,
                })
            else
                notify(_("Logged in to Goodreads"))
            end
            return
        end

        if result and result.needs_otp then
            local ctx = result.ctx
            prompt(_("Enter the verification code"), function(otp)
                runStep(self, _("Verifying code..."), function()
                    return Login.submit_otp(ctx, otp, LOGIN_OPTS)
                end, creds)
            end)
            return
        end

        if result and result.needs_challenge then
            self:_grkShowChallenge(result, creds)
            return
        end

        notify(failureText(result), true)
    end

    function GoodreadsMenu:_grkShowChallenge(result, creds)
        local Login = require("shelfsync_grlogin.auth.login")
        local Http = require("shelfsync_grlogin.goodreads.http")
        local ctx, challenge = result.ctx, result.challenge
        if not ctx or not ctx.http or not challenge or not challenge.image_url then
            notify(failureText({ error = "SIGNIN_BLOCKED" }), true)
            return
        end

        local url = Http.absolute(ctx.challenge_url or ctx.http.base_url, challenge.image_url)
        local resp = ctx.http:get(url, { follow = true, detect_auth = false })
        if resp.error or not resp.body or resp.body == "" then
            notify(_("Could not load the Goodreads verification image."), true)
            return
        end

        local DataStorage = require("datastorage")
        local path = DataStorage:getDataDir() .. "/cache/shelfsync-gr-challenge."
            .. (url:match("%.png") and "png" or "jpg")
        local f = io.open(path, "wb")
        if not f then
            notify(_("Could not save the Goodreads verification image."), true)
            return
        end
        f:write(resp.body)
        f:close()

        local ImageViewer = require("ui/widget/imageviewer")
        local viewer = ImageViewer:new{
            image = path,
            caption = _("Type these characters, then close this to continue"),
        }
        local orig_onClose = viewer.onClose
        local chained = false
        viewer.onClose = function(this)
            if orig_onClose then orig_onClose(this) end
            if chained then return end
            chained = true
            prompt(_("Enter the characters shown"), function(answer)
                runStep(self, _("Submitting..."), function()
                    return Login.submit_challenge(ctx, answer, LOGIN_OPTS)
                end, creds)
            end)
        end
        UIManager:show(viewer)
    end

    function GoodreadsMenu:_grkDoLogin(email, password)
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:runWhenOnline(function()
            runStep(self, _("Logging in to Goodreads..."), function()
                return require("shelfsync_grlogin.auth.login").perform(email, password, LOGIN_OPTS)
            end, { email = email, password = password })
        end)
    end

    function GoodreadsMenu:_grkLoginDialog(force_dialog)
        local saved_email, saved_pw = loadCreds()
        if saved_email and not force_dialog then
            self:_grkDoLogin(saved_email, saved_pw)
            return
        end
        local MultiInputDialog = require("ui/widget/multiinputdialog")
        local dialog
        dialog = MultiInputDialog:new{
            title = _("Goodreads Login"),
            fields = {
                { text = saved_email or "", hint = _("Email") },
                { text = saved_pw or "", hint = _("Password"), text_type = "password" },
            },
            buttons = { {
                { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
                {
                    text = _("Log in"),
                    callback = function()
                        local fields = dialog:getFields()
                        local email, password = fields[1], fields[2]
                        UIManager:close(dialog)
                        self:_grkDoLogin(email, password)
                    end,
                },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    -- The plugin is re-initialised every time a book or the file browser
    -- opens, and this hook runs each time -- only wrap once.
    if not GoodreadsMenu.__ss_login_patched then
    GoodreadsMenu.__ss_login_patched = true
    local orig_getAuthSubMenuItems = GoodreadsMenu.getAuthSubMenuItems
    GoodreadsMenu.getAuthSubMenuItems = function(self)
        local items = orig_getAuthSubMenuItems(self)
        table.insert(items, 1, {
            text_func = function()
                local email = loadCreds()
                return email and (_("Log in as ") .. email) or _("Log in")
            end,
            keep_menu_open = true,
            callback = function() self:_grkLoginDialog(false) end,
            hold_callback = function() self:_grkLoginDialog(true) end,
        })
        table.insert(items, 2, {
            text = _("Forget saved login"),
            keep_menu_open = true,
            enabled_func = function()
                return loadCreds() ~= nil
            end,
            callback = function()
                clearCreds()
                notify(_("Saved Goodreads login removed."))
            end,
        })
        return items
    end
    end -- __ss_login_patched

    -- StoryGraph: same saved-login behaviour on ShelfSync's own login ------
    local ok_sg, StoryGraphMenu = pcall(require, "shelfsync/lib/storygraph/menu")
    if ok_sg and StoryGraphMenu and StoryGraphMenu.getAuthSubMenuItems
            and not StoryGraphMenu.__ss_login_patched then
        StoryGraphMenu.__ss_login_patched = true

        function StoryGraphMenu:_sgDoLogin(email, password)
            local NetworkMgr = require("ui/network/manager")
            NetworkMgr:runWhenOnline(function()
                Trapper:wrap(function()
                    local info = InfoMessage:new{ text = _("Logging in to StoryGraph...") }
                    UIManager:show(info)
                    UIManager:forceRePaint()
                    local ok, res, err = pcall(function() return self.api:login(email, password) end)
                    UIManager:close(info)
                    if not ok then
                        notify(_("StoryGraph login error: ") .. tostring(res), true)
                        return
                    end
                    if not res then
                        notify(_("StoryGraph login failed: ") .. tostring(err or "unknown error"), true)
                        return
                    end
                    local se, sp = loadCreds(SG_CRED_FILE)
                    if se == email and sp == password then
                        notify(_("Logged in to StoryGraph"))
                        return
                    end
                    local ConfirmBox = require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new{
                        text = _("Logged in to StoryGraph.\n\nSave your email and password on this device so you don't have to type them again?"),
                        ok_text = _("Save"),
                        cancel_text = _("Not now"),
                        ok_callback = function()
                            local encrypted = saveCreds(email, password, SG_CRED_FILE)
                            notify(encrypted and _("Login saved (encrypted).")
                                or _("Login saved (plain text -- encryption unavailable on this device)."))
                        end,
                    })
                end)
            end)
        end

        function StoryGraphMenu:_sgLoginDialog(force_dialog)
            local saved_email, saved_pw = loadCreds(SG_CRED_FILE)
            if saved_email and not force_dialog then
                self:_sgDoLogin(saved_email, saved_pw)
                return
            end
            local MultiInputDialog = require("ui/widget/multiinputdialog")
            local dialog
            dialog = MultiInputDialog:new{
                title = _("StoryGraph Login"),
                fields = {
                    { text = saved_email or "", hint = _("Email") },
                    { text = saved_pw or "", hint = _("Password"), text_type = "password" },
                },
                buttons = { {
                    { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
                    {
                        text = _("Log in"),
                        callback = function()
                            local fields = dialog:getFields()
                            UIManager:close(dialog)
                            self:_sgDoLogin(fields[1], fields[2])
                        end,
                    },
                } },
            }
            UIManager:show(dialog)
            dialog:onShowKeyboard()
        end

        local orig_sg_auth = StoryGraphMenu.getAuthSubMenuItems
        StoryGraphMenu.getAuthSubMenuItems = function(self)
            local items = orig_sg_auth(self)
            -- Swap ShelfSync's own "Log in" item for ours (same login, plus saving)
            local idx
            for i, item in ipairs(items) do
                local t = type(item.text) == "string" and item.text or ""
                if t == _("Log in") or t == "Log in" or t:lower():match("^%s*log%s*in%s*$") then
                    idx = i; break
                end
            end
            local login_item = {
                text_func = function()
                    local email = loadCreds(SG_CRED_FILE)
                    return email and (_("Log in as ") .. email) or _("Log in")
                end,
                keep_menu_open = true,
                callback = function() self:_sgLoginDialog(false) end,
                hold_callback = function() self:_sgLoginDialog(true) end,
            }
            local forget_item = {
                text = _("Forget saved login"),
                keep_menu_open = true,
                enabled_func = function() return loadCreds(SG_CRED_FILE) ~= nil end,
                callback = function()
                    clearCreds(SG_CRED_FILE)
                    notify(_("Saved StoryGraph login removed."))
                end,
            }
            if idx then
                items[idx] = login_item
                table.insert(items, idx + 1, forget_item)
            else
                table.insert(items, 1, login_item)
                table.insert(items, 2, forget_item)
            end
            return items
        end
    end

    -- Goodreads: dodge the WAF-challenged endpoints -----------------------
    local ok_api, GoodreadsApi = pcall(require, "shelfsync/lib/goodreads/api")
    if ok_api and GoodreadsApi and not GoodreadsApi.__ss_waf_patched then
        GoodreadsApi.__ss_waf_patched = true
        local logger = require("logger")

        local function decodeJson(body)
            if type(body) ~= "string" or body == "" then return nil end
            local ok, rj = pcall(require, "rapidjson")
            if ok and rj and rj.decode then
                local ok2, v = pcall(rj.decode, body)
                if ok2 then return v end
            end
            local ok3, json = pcall(require, "json")
            if ok3 and json and json.decode then
                local ok4, v = pcall(json.decode, body)
                if ok4 then return v end
            end
        end

        local function urlencode(str)
            return (tostring(str):gsub("\n", " "):gsub("([^%w%-%.%_%~ ])", function(c)
                return string.format("%%%02X", string.byte(c))
            end):gsub(" ", "+"))
        end

        local orig_findBooks = GoodreadsApi.findBooks
        GoodreadsApi.findBooks = function(self, title, author, userId)
            local query = tostring(title or "")
            if author and author ~= "" then query = query .. " " .. author end
            local url = "https://www.goodreads.com/book/auto_complete?format=json&q=" .. urlencode(query)
            local code, body = self:request(url, "GET")
            local items = (code == 200) and decodeJson(body) or nil
            if type(items) == "table" and #items > 0 then
                local results = {}
                for _, item in ipairs(items) do
                    local id = item.bookId and tostring(item.bookId)
                    if id then
                        local author_name = type(item.author) == "table" and item.author.name or "Unknown Author"
                        results[#results + 1] = {
                            book_id = id,
                            title = item.bookTitleBare or item.title or "",
                            contributions = { { author = { name = author_name } } },
                            cached_image = { url = item.imageUrl },
                            book_series = {},
                            description = "",
                        }
                    end
                end
                logger.info("Goodreads: auto_complete found " .. #results .. " result(s) for '" .. query .. "'")
                if #results > 0 then return results end
            else
                logger.info("Goodreads: auto_complete gave nothing (code=" .. tostring(code) .. "), falling back to /search")
            end
            return orig_findBooks(self, title, author, userId)
        end

        local orig_refreshSession = GoodreadsApi.refreshSession
        GoodreadsApi.refreshSession = function(self)
            -- Reuse a fresh token instead of fetching a page before every write
            if CACHE.csrf and (os.time() - CACHE.csrf_at) < CSRF_TTL then
                self.last_csrf = CACHE.csrf
                self.last_user_id = self.last_user_id or CACHE.uid
                return self.last_csrf, self.last_user_id
            end
            local code, html, headers = self:request("https://www.goodreads.com/review/list", "GET")
            if code == 200 and html then
                -- extract_csrf() returns the PREVIOUS token when the page has
                -- none, which would get cached as fresh. Clear it first so a
                -- missing token is actually detected.
                local prev = self.last_csrf
                self.last_csrf = nil
                local csrf = self:extract_csrf(html)
                if not csrf then self.last_csrf = prev end
                local final_url = headers and headers["x-final-url"] or ""
                local uid = final_url:match("/review/list/(%d+)") or html:match("/user/show/(%d+)")
                if uid then self.last_user_id = uid; CACHE.uid = uid end
                if csrf then
                    CACHE.csrf, CACHE.csrf_at = csrf, os.time()
                    return csrf, self.last_user_id
                end
            end
            logger.info("Goodreads: /review/list CSRF fetch failed (code=" .. tostring(code) .. "), falling back to /")
            return orig_refreshSession(self)
        end
    end

    -- Tweaks settings + menu toggles ------------------------------------------
    local TWEAKS_FILE = DataStorage:getSettingsDir() .. "/shelfsync_tweaks.lua"
    local DEFAULTS = { exclude_wikireader = true } -- everything else defaults OFF
    local function tweak(key)
        if not CACHE.tweaks then
            CACHE.tweaks = LuaSettings:open(TWEAKS_FILE).data or {}
        end
        local v = CACHE.tweaks[key]
        if v == nil then return DEFAULTS[key] == true end
        return v == true
    end
    local function setTweak(key, value)
        local t = LuaSettings:open(TWEAKS_FILE)
        t:saveSetting(key, value)
        t:flush()
        CACHE.tweaks = CACHE.tweaks or {}
        CACHE.tweaks[key] = value
    end

    local HIDDEN = {
        StoryGraph = "hide_storygraph",
        Goodreads = "hide_goodreads",
        Hardcover = "hide_hardcover",
        Fable = "hide_fable",
    }

    local function isWikiReaderFile(file)
        return tweak("exclude_wikireader")
            and type(file) == "string" and file:find("/cache/wikireader/", 1, true) ~= nil
    end

    -- WikiReader exclusion
    local ok_bs, BaseSettings = pcall(require, "shelfsync/lib/common/base_settings")
    if ok_bs and BaseSettings and not BaseSettings.__ss_wiki_patched then
        BaseSettings.__ss_wiki_patched = true
        local orig_autolinkEnabled = BaseSettings.autolinkEnabled
        BaseSettings.autolinkEnabled = function(self)
            if isWikiReaderFile(self:getFilePath()) then return false end
            return orig_autolinkEnabled(self)
        end
    end
    local ok_bp, BaseProvider = pcall(require, "shelfsync/lib/common/base_provider")
    if ok_bp and BaseProvider and not BaseProvider.__ss_wiki_patched then
        BaseProvider.__ss_wiki_patched = true
        local orig_tryAutolink = BaseProvider.tryAutolink
        BaseProvider.tryAutolink = function(self, done)
            local file = self.ui and self.ui.document and self.ui.document.file
            if isWikiReaderFile(file) then
                if done then done() end
                return
            end
            return orig_tryAutolink(self, done)
        end
    end

    -- Hidden providers: never active, and left out of the Providers menu
    local ok_se, SyncEngine = pcall(require, "shelfsync/lib/common/sync_engine")
    if ok_se and SyncEngine and not SyncEngine.__ss_hide_patched then
        SyncEngine.__ss_hide_patched = true
        local orig_isActive = SyncEngine.isActive
        SyncEngine.isActive = function(self)
            local key = HIDDEN[self.label]
            if key and tweak(key) then return false end
            return orig_isActive(self)
        end
    end
    for label, key in pairs(HIDDEN) do
        local ok_m, Menu = pcall(require, "shelfsync/lib/" .. label:lower() .. "/menu")
        if ok_m and Menu and Menu.mainMenu and not Menu.__ss_hide_patched then
            Menu.__ss_hide_patched = true
            local orig_mainMenu = Menu.mainMenu
            Menu.mainMenu = function(self)
                if tweak(key) then return nil end -- table.insert(t, nil) is a no-op
                return orig_mainMenu(self)
            end
        end
    end

    -- Toggles in ShelfSync > Settings, just above "Verbose logging"
    local ok_cm, CommonMenu = pcall(require, "shelfsync/lib/common/menu")
    if ok_cm and CommonMenu and not CommonMenu.__ss_tweaks_patched then
        CommonMenu.__ss_tweaks_patched = true
        local function toggle(text, key, help)
            return {
                text = text,
                checked_func = function() return tweak(key) end,
                callback = function() setTweak(key, not tweak(key)) end,
                hold_callback = function() notify(help) end,
            }
        end
        local orig_getSubMenuItems = CommonMenu.getSubMenuItems
        CommonMenu.getSubMenuItems = function(self)
            local items = orig_getSubMenuItems(self)
            local idx = #items + 1
            for i, item in ipairs(items) do
                if item.text == _("Verbose logging") then idx = i; break end
            end
            local new = {
                toggle(_("Exclude WikiReader articles"), "exclude_wikireader",
                    _("Don't auto-link Wikipedia articles opened with WikiReader (koreader/cache/wikireader/) to books on any provider.")),
                {
                    text = _("Hide providers"),
                    sub_item_table = {
                        toggle(_("Fable"), "hide_fable",
                            _("Remove Fable from the Providers menu and stop it from doing anything. Reopen the book or file browser to update the menu.")),
                        toggle(_("Hardcover"), "hide_hardcover",
                            _("Remove Hardcover from the Providers menu and stop it from doing anything. Reopen the book or file browser to update the menu.")),
                        toggle(_("Goodreads"), "hide_goodreads",
                            _("Remove Goodreads from the Providers menu and stop it from doing anything. Reopen the book or file browser to update the menu.")),
                        toggle(_("StoryGraph"), "hide_storygraph",
                            _("Remove StoryGraph from the Providers menu and stop it from doing anything. Reopen the book or file browser to update the menu.")),
                    },
                },
            }
            new[#new].separator = true
            for i = #new, 1, -1 do table.insert(items, idx, new[i]) end
            return items
        end
    end
end)

-- ===================================================================
--[[ Bundled login code from goodreadskosync
    https://github.com/gkgangavarapu/goodreadskosync
    Module names renamed to shelfsync_grlogin.* so they never clash with the real plugin.

MIT License

Copyright (c) 2026 G Geetha Krishna Manikanteswar

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

package.preload["shelfsync_grlogin.constants"] = function(...)
--[[--
Shared constants for the Goodreads KO Sync plugin.

No module here may require an authentication provider or a UI widget, so that
the resolver and sync engine remain usable from unit tests without KOReader.

@module koplugin.goodreads.constants
--]]

local Constants = {
    VERSION = "1.15.0",

    -- Storage schema version. Bump only alongside a migration function.
    SCHEMA_VERSION = 1,

    -- How long a fetched CSRF token is reused (seconds). Goodreads rotates it;
    -- refreshing within a sync run keeps writes fast without going stale.
    CSRF_TTL = 120,

    -- Provider identifiers. The value is also the module basename under
    -- goodreadskosync.koplugin/providers/.
    PROVIDER = {
        MOCK = "mock",
        NATIVE_KINDLE = "native_kindle",
        GOODREADS_WEB = "goodreads_web",
        OFFICIAL_API = "official_api",
    },

    -- Canonical shelf states. Providers must translate these to their own
    -- representation; the rest of the plugin only ever sees these.
    SHELF = {
        WANT_TO_READ = "want_to_read",
        CURRENTLY_READING = "currently_reading",
        READ = "read",
        DID_NOT_FINISH = "did_not_finish",
    },

    -- Normalized error codes returned by every provider and by network.lua.
    ERROR = {
        NETWORK_ERROR = "NETWORK_ERROR",
        AUTH_REQUIRED = "AUTH_REQUIRED",
        INVALID_CREDENTIALS = "INVALID_CREDENTIALS",
        SIGNIN_BLOCKED = "SIGNIN_BLOCKED",
        RATE_LIMITED = "RATE_LIMITED",
        NOT_FOUND = "NOT_FOUND",
        SERVER_ERROR = "SERVER_ERROR",
        INVALID_RESPONSE = "INVALID_RESPONSE",
        PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE",
        CONFLICT = "CONFLICT",
        INVALID_REQUEST = "INVALID_REQUEST",
        UNSUPPORTED = "UNSUPPORTED",
    },

    -- How a book identity was derived, in decreasing order of authority.
    IDENTIFIER_SOURCE = {
        GOODREADS_ID = "goodreads_id",
        ISBN13 = "isbn13",
        ISBN10 = "isbn10",
        ASIN = "asin",
        FILENAME_ISBN = "filename_isbn",
        FILENAME_ASIN = "filename_asin",
        METADATA = "metadata",
        TITLE_AUTHOR = "title_author",
        TITLE = "title",
        MANUAL = "manual",
        MAPPING = "mapping",
    },

    -- Confidence thresholds for the matcher.
    CONFIDENCE = {
        AUTO = 90,     -- >= this, and an identifier matched: select silently
        CONFIRM = 70,  -- >= this: ask the user to confirm
    },

    -- Exponential retry schedule for the offline queue, in seconds.
    BACKOFF = { 30, 120, 300, 900, 1800 },

    -- Conflict policies for cloud-vs-local progress.
    CONFLICT_POLICY = {
        PREFER_LOCAL = "prefer_local",
        PREFER_CLOUD = "prefer_cloud",
        ASK = "ask",
    },

    -- Completion behavior.
    COMPLETION_BEHAVIOR = {
        EXPLICIT_ONLY = "explicit_only",
        PERCENT_99 = "percent_99",
    },

    -- Default provider discovery order (highest priority first).
    PROVIDER_ORDER = {
        "goodreads_web",
        "native_kindle",
        "official_api",
        "mock",
    },

    -- Storage file names (relative to the plugin settings directory).
    STORAGE = {
        ACCOUNT = "account",
        SESSION = "session",
        CREDENTIALS = "credentials",
        MAPPINGS = "mappings",
        BOOK_SETTINGS = "book_settings",
        SYNC_STATE = "sync_state",
        QUEUE = "queue",
        SEARCH_CACHE = "search_cache",
        SETTINGS = "settings",
    },

    -- How long a remote shelf read is reused before it is fetched again, in
    -- seconds. A fresh read is always taken on document open and manual sync.
    REMOTE_SHELF_TTL = 60 * 60,

    -- Background update check interval, in seconds (about once a day).
    UPDATE_CHECK_INTERVAL = 24 * 60 * 60,

    -- Minimum gap between the low-key "support the project" toasts shown after
    -- a successful sync, in seconds (about once every two weeks).
    SUPPORT_TOAST_INTERVAL = 14 * 24 * 60 * 60,

    -- Search cache lifetime, in seconds (7 days).
    SEARCH_CACHE_TTL = 7 * 24 * 60 * 60,

    -- Maximum entries retained in the search cache.
    SEARCH_CACHE_MAX = 200,
}

return Constants

end

package.preload["shelfsync_grlogin.logging"] = function(...)
--[[--
Redacting logging facade.

All plugin logging goes through this module so that credentials can never be
written to the KOReader log, even accidentally. It also degrades gracefully
when `logger` is not available (e.g. under the unit test runner).

@module koplugin.goodreads.logging
--]]

local Constants = require("shelfsync_grlogin.constants")

local Logging = {}

local LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

local current_level = LEVELS.INFO
-- File/system logging is opt-in: off by default so nothing is written unless the
-- user enables "Diagnostic logging" in Settings.
local logging_enabled = false
local prefix = "[goodreads]"

local ok, klogger = pcall(require, "logger")
if not ok then klogger = nil end

local fallback = {
    dbg = function(...) io.write("[goodreads] ", table.concat({ ... }, " "), "\n") end,
    info = function(...) io.write("[goodreads] ", table.concat({ ... }, " "), "\n") end,
    warn = function(...) io.write("[goodreads] ", table.concat({ ... }, " "), "\n") end,
    err = function(...) io.write("[goodreads] ", table.concat({ ... }, " "), "\n") end,
}

-- Patterns whose values must never reach the log. The replacement keeps the
-- key (useful for diagnostics) but drops the secret.
local REDACTIONS = {
    { "([Tt]oken[%s=:]+)[%w%._%-]+", "%1<redacted>" },
    { "([Cc]ookie[%s=:]+)[^\r\n]+", "%1<redacted>" },
    { "([Aa]uthorization[%s=:]+)[^\r\n]+", "%1<redacted>" },
    { "([Ss]ession[%s_]?[Ii][Dd][%s=:]+)[%w%._%-]+", "%1<redacted>" },
    { "([Pp]assword[%s=:]+)[^\r\n]+", "%1<redacted>" },
    { "([Aa]ccess[%s_]?[Tt]oken[%s=:]+)[%w%._%-]+", "%1<redacted>" },
    { "([Rr]efresh[%s_]?[Tt]oken[%s=:]+)[%w%._%-]+", "%1<redacted>" },
    { "([Cc]srf[%s=:]+)[%w%._%-]+", "%1<redacted>" },
}

function Logging.redact(value)
    if value == nil then return "" end
    local s = tostring(value)
    for _, rule in ipairs(REDACTIONS) do
        s = s:gsub(rule[1], rule[2])
    end
    return s
end

local LEVEL_METHOD = {
    DEBUG = "dbg",
    INFO = "info",
    WARN = "warn",
    ERROR = "err",
}

local function emit(level, ...)
    if LEVELS[level] < current_level then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = Logging.redact((select(i, ...)))
    end
    local line = table.concat(parts, " ")
    if klogger then
        klogger[LEVEL_METHOD[level]](line)
    else
        fallback[LEVEL_METHOD[level]](prefix, level, line)
    end
end

function Logging.setLevel(level)
    if LEVELS[level] then current_level = LEVELS[level] end
end

function Logging.getLevel()
    for name, value in pairs(LEVELS) do
        if value == current_level then return name end
    end
    return "INFO"
end

function Logging.debug(...) emit("DEBUG", ...) end
function Logging.info(...) emit("INFO", ...) end
function Logging.warn(...) emit("WARN", ...) end
function Logging.error(...) emit("ERROR", ...) end

-- Redacted trace that is also appended to a small file next to the plugin
-- settings, so a failed on-device login can always be diagnosed over USB
-- regardless of how KOReader persists its own log.
local function trace_path()
    local has_ds, DataStorage = pcall(require, "datastorage")
    if has_ds and DataStorage and type(DataStorage.getSettingsDir) == "function" then
        local got, dir = pcall(function() return DataStorage:getSettingsDir() end)
        if got and dir and dir ~= "" then
            return dir .. "/goodreadskosync/login.log"
        end
    end
    return "./login.log"
end

local function append_trace(line)
    local path = trace_path()
    local file = io.open(path, "a")
    if not file then
        local dir = path:match("^(.*)[/\\][^/\\]*$")
        if dir then
            if os.getenv("OS") ~= nil then
                os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
            else
                os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
            end
        end
        file = io.open(path, "a")
    end
    if file then
        file:write(line)
        file:close()
    end
end

function Logging.trace(...)
    if not logging_enabled then return end
    emit("INFO", ...)
    if current_level <= LEVELS.INFO then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = Logging.redact((select(i, ...)))
        end
        append_trace(os.date("%Y-%m-%d %H:%M:%S ")
            .. table.concat(parts, " ") .. "\n")
    end
end

-- Diagnostics that go ONLY to the local login.log (never the shared KOReader
-- system log), so troubleshooting can be verbose without flooding anything.
function Logging.diag(...)
    if not logging_enabled then return end
    if current_level > LEVELS.INFO then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = Logging.redact((select(i, ...)))
    end
    append_trace(os.date("%Y-%m-%d %H:%M:%S ") .. "diag: "
        .. table.concat(parts, " ") .. "\n")
end

-- Enable/disable file logging (wired to the user's "Diagnostic logging" setting).
function Logging.setEnabled(value)
    logging_enabled = value and true or false
end

function Logging.isEnabled()
    return logging_enabled
end

-- Build a support-safe diagnostic summary. Only allowlisted scalar fields are
-- included; book titles, authors, credentials, and response bodies never are.
function Logging.diagnosticSummary(fields)
    fields = fields or {}
    local order = {
        "koreader_version", "plugin_version", "device_family", "provider",
        "provider_available", "last_stage", "http_status", "queue_size",
        "mappings_count", "last_sync_at",
    }
    local lines = {}
    for _, key in ipairs(order) do
        local value = fields[key]
        if value ~= nil then
            lines[#lines + 1] = string.format("%s=%s", key, Logging.redact(value))
        end
    end
    return table.concat(lines, "\n")
end

Logging.LEVELS = LEVELS
Logging.VERSION = Constants.VERSION

return Logging

end

package.preload["shelfsync_grlogin.storage"] = function(...)
--[[--
Persistent storage for the plugin.

Each concern lives in its own file (mappings, sync state, queue, ...) so that
a corrupt queue can never take the book mappings down with it. When KOReader's
`LuaSettings` is available it is used directly; otherwise a self-contained
serializer keeps the module usable from the unit test suite.

@module koplugin.goodreads.storage
--]]

local Constants = require("shelfsync_grlogin.constants")
local Logging = require("shelfsync_grlogin.logging")

local Storage = {}

local base_dir_override = nil
local ok_ls, LuaSettings = pcall(require, "luasettings")
if not ok_ls then LuaSettings = nil end

-- Windows is only used for the offline test suite; KOReader devices are Linux.
local IS_WINDOWS = os.getenv("OS") ~= nil

--------------------------------------------------------------------------------
-- Fallback serializer
--------------------------------------------------------------------------------

local function serialize(value)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "table" then
        local parts = { "{" }
        -- Emit array part first for readability, then remaining keys.
        local array_len = #value
        for i = 1, array_len do
            parts[#parts + 1] = serialize(value[i]) .. ","
        end
        for k, v in pairs(value) do
            local is_array_index = type(k) == "number" and k >= 1
                and k <= array_len and k == math.floor(k)
            if not is_array_index then
                local key_repr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key_repr = k
                else
                    key_repr = "[" .. serialize(k) .. "]"
                end
                parts[#parts + 1] = key_repr .. "=" .. serialize(v) .. ","
            end
        end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    end
    return "nil"
end

--------------------------------------------------------------------------------
-- Backends
--------------------------------------------------------------------------------

local Store = {}
Store.__index = Store

function Store:get(key, default)
    local value = self.data[key]
    if value == nil then return default end
    return value
end

function Store:set(key, value)
    self.data[key] = value
    self.dirty = true
end

function Store:delete(key)
    self.data[key] = nil
    self.dirty = true
end

function Store:has(key)
    return self.data[key] ~= nil
end

function Store:keys()
    local keys = {}
    for k in pairs(self.data) do keys[#keys + 1] = k end
    return keys
end

function Store:flush()
    if not self.dirty then return true end
    local ok
    if self.ls then
        for k, v in pairs(self.data) do
            self.ls:saveSetting(k, v)
        end
        ok = pcall(function() self.ls:flush() end)
    else
        ok = self:_writeFile()
    end
    if ok then self.dirty = false end
    return ok
end

function Store:_writeFile()
    local dir = self.dir
    if IS_WINDOWS then
        os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
    local tmp = self.path .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then
        Logging.warn("storage: cannot write", self.path)
        return false
    end
    file:write("return ", serialize(self.data), "\n")
    file:close()
    os.remove(self.path)
    local ok = os.rename(tmp, self.path)
    if not ok then
        -- Windows cannot rename over an existing file; remove first.
        os.remove(self.path)
        ok = os.rename(tmp, self.path)
    end
    return ok and true or false
end

local function fallback_store(path)
    local data = {}
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local chunk = loadstring(content)
        if chunk then
            local ok, loaded = pcall(chunk)
            if ok and type(loaded) == "table" then data = loaded end
        end
    end
    local dir = path:match("^(.*)[/\\][^/\\]*$") or "."
    return setmetatable({
        data = data,
        path = path,
        dir = dir,
        dirty = false,
    }, Store)
end

local function luasettings_store(path)
    local ls = LuaSettings:open(path)
    local data = {}
    -- LuaSettings stores a flat table; materialize it for a uniform interface.
    if ls.data then
        for k, v in pairs(ls.data) do data[k] = v end
    end
    local store = setmetatable({
        data = data,
        path = path,
        dir = path:match("^(.*)[/\\][^/\\]*$") or ".",
        ls = ls,
        dirty = false,
    }, Store)
    return store
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Storage.getBaseDir()
    if base_dir_override then return base_dir_override end
    local ok, DataStorage = pcall(require, "datastorage")
    if ok and DataStorage then
        return DataStorage:getSettingsDir() .. "/goodreadskosync"
    end
    return "./.goodreads-test"
end

function Storage.setBaseDir(dir)
    base_dir_override = dir
end

function Storage.open(name)
    local path = Storage.getBaseDir() .. "/" .. name .. ".lua"
    if LuaSettings and not base_dir_override then
        return luasettings_store(path)
    end
    return fallback_store(path)
end

-- Test helper: remove every storage file and reset the override.
function Storage.reset()
    local dir = Storage.getBaseDir()
    local names = {
        Constants.STORAGE.ACCOUNT,
        Constants.STORAGE.SESSION,
        Constants.STORAGE.CREDENTIALS,
        Constants.STORAGE.MAPPINGS,
        Constants.STORAGE.BOOK_SETTINGS,
        Constants.STORAGE.SYNC_STATE,
        Constants.STORAGE.QUEUE,
        Constants.STORAGE.SEARCH_CACHE,
        Constants.STORAGE.SETTINGS,
        "mock_state",
        "mock_account",
    }
    for _, name in ipairs(names) do
        os.remove(dir .. "/" .. name .. ".lua")
        os.remove(dir .. "/" .. name .. ".lua.tmp")
    end
end

Storage.serialize = serialize
Storage._fallback_store = fallback_store

return Storage

end

package.preload["shelfsync_grlogin.crypto_util"] = function(...)
--[[--
Secret-at-rest helper (inspired by ShelfSync).

Uses AES-256-CBC through the libcrypto that KOReader already links, with the
key kept in a separate settings file. This stops secrets from sitting in
cleartext in a settings file that might be shared for support, but it is NOT
protection against someone with full filesystem access (KOReader has no OS
keystore). Every function degrades to nil when libcrypto is unavailable, so
callers can fall back to plaintext.

@module koplugin.goodreads.crypto_util
--]]

local CryptoUtil = {}

local ok_ffi, ffi = pcall(require, "ffi")
if not ok_ffi then ffi = nil end

local KEYRING_FILENAME = "goodreadskosync_keyring.lua"
local KEY_SETTING = "session_aes_key"

local libcrypto -- nil = unresolved, false = failed
local cdef_done = false

local function ensure_cdef()
    if cdef_done then return end
    cdef_done = true
    ffi.cdef([[
        typedef struct engine_st ENGINE;
        typedef struct evp_cipher_st EVP_CIPHER;
        typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
        EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
        void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *);
        int EVP_EncryptInit_ex(EVP_CIPHER_CTX *, const EVP_CIPHER *, ENGINE *, const unsigned char *, const unsigned char *);
        int EVP_EncryptUpdate(EVP_CIPHER_CTX *, unsigned char *, int *, const unsigned char *, int);
        int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *, unsigned char *, int *);
        int EVP_DecryptInit_ex(EVP_CIPHER_CTX *, const EVP_CIPHER *, ENGINE *, const unsigned char *, const unsigned char *);
        int EVP_DecryptUpdate(EVP_CIPHER_CTX *, unsigned char *, int *, const unsigned char *, int);
        int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *, unsigned char *, int *);
        const EVP_CIPHER *EVP_aes_256_cbc(void);
        int RAND_bytes(unsigned char *, int);
    ]])
end

local function get_libcrypto()
    if libcrypto ~= nil then return libcrypto or nil end
    if not ffi then
        libcrypto = false
        return nil
    end
    local ok, result = pcall(function()
        ensure_cdef()
        -- ffi.loadlib is KOReader's own FFI extension (ffi/loadlib.lua), the
        -- same call ShelfSync uses. Fall back to plain ffi.load just in case.
        if ffi.loadlib then return ffi.loadlib("crypto", "57") end
        local ok_l, lib = pcall(ffi.load, "libs/libcrypto.so.57")
        if ok_l and lib then return lib end
        return ffi.load("crypto")
    end)
    libcrypto = (ok and result) and result or false
    return libcrypto or nil
end

local function random_bytes(lib, n)
    local buf = ffi.new("unsigned char[?]", n)
    if lib.RAND_bytes(buf, n) ~= 1 then return nil end
    return ffi.string(buf, n)
end

local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function from_hex(s)
    if type(s) ~= "string" or not s:match("^%x*$") or #s % 2 ~= 0 then return nil end
    return (s:gsub("%x%x", function(cc) return string.char(tonumber(cc, 16)) end))
end

function CryptoUtil.aesEncrypt(plaintext, key)
    local lib = get_libcrypto()
    if not lib or not plaintext or plaintext == "" or not key or #key ~= 32 then
        return nil
    end
    local iv = random_bytes(lib, 16)
    if not iv then return nil end

    local ctx = lib.EVP_CIPHER_CTX_new()
    if ctx == nil then return nil end

    local ok = lib.EVP_EncryptInit_ex(ctx, lib.EVP_aes_256_cbc(), nil, key, iv) == 1
    local output, output_len
    if ok then
        output = ffi.new("unsigned char[?]", #plaintext + 16)
        local len1 = ffi.new("int[1]")
        ok = lib.EVP_EncryptUpdate(ctx, output, len1, plaintext, #plaintext) == 1
        if ok then
            local len2 = ffi.new("int[1]")
            ok = lib.EVP_EncryptFinal_ex(ctx, output + len1[0], len2) == 1
            if ok then output_len = len1[0] + len2[0] end
        end
    end
    lib.EVP_CIPHER_CTX_free(ctx)
    if not ok then return nil end
    return to_hex(iv .. ffi.string(output, output_len))
end

function CryptoUtil.aesDecrypt(blob_hex, key)
    local lib = get_libcrypto()
    if not lib or not blob_hex or blob_hex == "" or not key or #key ~= 32 then
        return nil
    end
    local raw = from_hex(blob_hex)
    if not raw or #raw <= 16 then return nil end
    local iv = raw:sub(1, 16)
    local ciphertext = raw:sub(17)

    local ctx = lib.EVP_CIPHER_CTX_new()
    if ctx == nil then return nil end

    local ok = lib.EVP_DecryptInit_ex(ctx, lib.EVP_aes_256_cbc(), nil, key, iv) == 1
    local output, output_len
    if ok then
        output = ffi.new("unsigned char[?]", #ciphertext + 16)
        local len1 = ffi.new("int[1]")
        ok = lib.EVP_DecryptUpdate(ctx, output, len1, ciphertext, #ciphertext) == 1
        if ok then
            local len2 = ffi.new("int[1]")
            ok = lib.EVP_DecryptFinal_ex(ctx, output + len1[0], len2) == 1
            if ok then output_len = len1[0] + len2[0] end
        end
    end
    lib.EVP_CIPHER_CTX_free(ctx)
    if not ok then return nil end
    return ffi.string(output, output_len)
end

local keyring

local function get_keyring()
    if keyring then return keyring end
    local ok_ds, DataStorage = pcall(require, "datastorage")
    local ok_ls, LuaSettings = pcall(require, "luasettings")
    if not (ok_ds and ok_ls) then return nil end
    local ok, result = pcall(function()
        return LuaSettings:open(DataStorage:getSettingsDir() .. "/" .. KEYRING_FILENAME)
    end)
    if not ok then return nil end
    keyring = result
    return keyring
end

function CryptoUtil.getOrCreateKey()
    local lib = get_libcrypto()
    if not lib then return nil end
    local kr = get_keyring()
    if not kr then return nil end

    local hex_key = kr:readSetting(KEY_SETTING)
    if hex_key and #hex_key == 64 then
        local key = from_hex(hex_key)
        if key then return key end
    end

    local key = random_bytes(lib, 32)
    if not key then return nil end
    kr:saveSetting(KEY_SETTING, to_hex(key))
    kr:flush()
    return key
end

function CryptoUtil.encryptSecret(plaintext)
    local key = CryptoUtil.getOrCreateKey()
    if not key then return nil end
    return CryptoUtil.aesEncrypt(plaintext, key)
end

function CryptoUtil.decryptSecret(blob_hex)
    local key = CryptoUtil.getOrCreateKey()
    if not key then return nil end
    return CryptoUtil.aesDecrypt(blob_hex, key)
end

-- "Encrypt if possible, otherwise plaintext" convenience: returns a value and
-- whether it is encrypted.
function CryptoUtil.protect(plaintext)
    local blob = CryptoUtil.encryptSecret(plaintext)
    if blob then return blob, true end
    return plaintext, false
end

function CryptoUtil.unprotect(value, encrypted)
    if not encrypted then return value end
    return CryptoUtil.decryptSecret(value) or ""
end

return CryptoUtil

end

package.preload["shelfsync_grlogin.auth.session"] = function(...)
--[[--
Session state for the Goodreads web provider.

The session is the cookie bundle Goodreads issued at login, plus the
derived CSRF token and the legacy numeric user id. No password is stored here.

@module koplugin.goodreads.auth.session
--]]

local Constants = require("shelfsync_grlogin.constants")
local CryptoUtil = require("shelfsync_grlogin.crypto_util")
local Storage = require("shelfsync_grlogin.storage")

local Session = {}

local function store()
    return Storage.open(Constants.STORAGE.SESSION)
end

function Session.new()
    return {
        cookies = "",
        csrf_token = nil,
        csrf_at = nil,
        user_id = nil,
        username = nil,
        state = "unknown", -- unknown | valid | expired | blocked
        updated_at = nil,
        last_error = nil,
    }
end

function Session.load()
    local data = store():get("current", {})
    local session = Session.new()
    for key, value in pairs(data or {}) do session[key] = value end
    if session.cookies_encrypted then
        session.cookies = CryptoUtil.unprotect(session.cookies, true)
        session.cookies_encrypted = nil
    end
    return session
end

function Session.save(session)
    session = session or Session.new()
    session.updated_at = os.time()
    local stored = {}
    for key, value in pairs(session) do stored[key] = value end
    if type(session.cookies) == "string" and session.cookies ~= "" then
        local blob, encrypted = CryptoUtil.protect(session.cookies)
        stored.cookies = blob
        stored.cookies_encrypted = encrypted and true or false
    end
    local s = store()
    s:set("current", stored)
    return s:flush()
end

function Session.clear()
    local s = store()
    s:set("current", Session.new())
    return s:flush()
end

function Session.is_valid(session)
    return type(session) == "table"
        and (session.state == "valid" or session.state == "unknown")
        and type(session.cookies) == "string"
        and session.cookies ~= ""
end

function Session.mark_valid(session, fields)
    session.state = "valid"
    session.last_error = nil
    for key, value in pairs(fields or {}) do session[key] = value end
    return session
end

function Session.mark_expired(session, reason)
    session.state = "expired"
    session.last_error = reason or Constants.ERROR.AUTH_REQUIRED
    return session
end

function Session.mark_blocked(session, reason)
    session.state = "blocked"
    session.last_error = reason or Constants.ERROR.SIGNIN_BLOCKED
    return session
end

-- Copy cookie/CSRF/user state from an http.lua object back into the session.
function Session.absorb(session, http)
    session.cookies = http:get_cookie_header()
    if http.csrf_token then session.csrf_token = http.csrf_token end
    if http.csrf_at then session.csrf_at = http.csrf_at end
    if http.user_id then session.user_id = http.user_id end
    return session
end

-- Build an http.lua object preloaded with this session.
function Session.to_http(session, opts)
    local Http = require("shelfsync_grlogin.goodreads.http")
    opts = opts or {}
    local http = Http:new{
        cookies = session and session.cookies or "",
        csrf_token = session and session.csrf_token or nil,
        user_id = session and session.user_id or nil,
        base_url = opts.base_url,
        timeout = opts.timeout,
        transport = opts.transport,
    }
    http.csrf_at = session and session.csrf_at or nil
    return http
end

return Session

end

package.preload["shelfsync_grlogin.goodreads.http"] = function(...)
--[[--
Session-aware HTTP transport for Goodreads.

Responsibilities:
  * maintain a raw Cookie header (Goodreads auth is a cookie bundle, not a
    single token);
  * merge and rotate cookies from Set-Cookie on every hop;
  * follow redirects manually so cookies survive the hop;
  * classify responses into the plugin's normalized error codes.

The transport itself is injectable so the whole layer can be unit tested
without network access. HTTPS only; certificate validation is never disabled.

@module koplugin.goodreads.goodreads.http
--]]

local Constants = require("shelfsync_grlogin.constants")

local Http = {}
Http.__index = Http

local USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0"

local COOKIE_ATTR = {
    path = true, domain = true, expires = true, ["max-age"] = true,
    samesite = true, secure = true, httponly = true, version = true,
    partitioned = true, ["same-site"] = true,
}

-- A stale short-lived GraphQL JWT in the Cookie header makes Goodreads reject
-- the whole request, so it is always dropped.
local COOKIE_DROP = { jwt_token = true }

local SIGN_IN_MARKERS = {
    "/user/sign_in",
    "/ap/signin",
    'name="email"',
    "something wrong with your Goodreads cookie",
}

--------------------------------------------------------------------------------
-- Cookie helpers
--------------------------------------------------------------------------------

function Http.sanitizeCookie(header)
    if type(header) ~= "string" or header == "" then return "" end
    local jar, order = {}, {}
    for name, value in header:gmatch("([%w_%-%.]+)=([^;]*)") do
        local lname = name:lower()
        if not COOKIE_ATTR[lname] and not COOKIE_DROP[name] and not COOKIE_DROP[lname] then
            value = value:match("^%s*(.-)%s*$") or value
            if value ~= "" then
                if not jar[name] then order[#order + 1] = name end
                jar[name] = value
            end
        end
    end
    local parts = {}
    for _, name in ipairs(order) do
        parts[#parts + 1] = name .. "=" .. jar[name]
    end
    return table.concat(parts, "; ")
end

-- LuaSocket comma-folds repeated Set-Cookie headers and Expires values also
-- contain commas, so walk name=value pairs and skip attribute keys.
function Http.mergeSetCookie(jar, set_cookie)
    if type(set_cookie) ~= "string" or set_cookie == "" then
        return Http.sanitizeCookie(jar)
    end
    local jar_map, order = {}, {}
    local function put(name, value)
        if not jar_map[name] then order[#order + 1] = name end
        jar_map[name] = value
    end
    for name, value in (jar or ""):gmatch("([%w_%-%.]+)=([^;]*)") do
        if not COOKIE_ATTR[name:lower()] and not COOKIE_DROP[name] then
            put(name, value)
        end
    end
    -- [ShelfSync tweaks] Split the header into individual cookies (a comma
    -- followed by "name=" starts a new one; Expires dates don't match) so a
    -- deletion (empty value, "deleted", or Max-Age<=0) removes the old cookie
    -- instead of leaving it stale in the jar.
    local marked = set_cookie:gsub(",%s*([%w_%-%.]+=)", "\1%1")
    for segment in (marked .. "\1"):gmatch("([^\1]*)\1") do
        local name, value = segment:match("^%s*([%w_%-%.]+)=([^;]*)")
        if name and not COOKIE_ATTR[name:lower()] and not COOKIE_DROP[name]
                and not COOKIE_DROP[name:lower()] then
            value = value:match("^%s*(.-)%s*$") or value
            local max_age = tonumber(segment:lower():match("max%-age=%s*(%-?%d+)"))
            if value == "" or value == "deleted" or (max_age and max_age <= 0) then
                if jar_map[name] then jar_map[name] = false end
            else
                put(name, value)
            end
        end
    end
    local parts = {}
    for _, name in ipairs(order) do
        if jar_map[name] then parts[#parts + 1] = name .. "=" .. jar_map[name] end
    end
    return table.concat(parts, "; ")
end

--------------------------------------------------------------------------------
-- Encoding
--------------------------------------------------------------------------------

local function urlencode(value)
    if value == nil then return "" end
    value = tostring(value)
    value = value:gsub("\n", "\r\n")
    value = value:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return value
end

function Http.urlencode(value)
    return urlencode(value)
end

function Http.encodeForm(data)
    local parts = {}
    for key, value in pairs(data or {}) do
        parts[#parts + 1] = urlencode(key) .. "=" .. urlencode(value)
    end
    table.sort(parts)
    return table.concat(parts, "&")
end

function Http.absolute(base, location)
    if not location or location == "" then return location end
    if location:match("^https?://") then return location end
    if location:sub(1, 2) == "//" then return "https:" .. location end
    local scheme_host = base:match("^(https?://[^/]+)")
    if location:sub(1, 1) == "/" then
        return (scheme_host or base) .. location
    end
    return (scheme_host or base) .. "/" .. location
end

--------------------------------------------------------------------------------
-- Default transport
--------------------------------------------------------------------------------

local function default_transport(req)
    local ok_http, http = pcall(require, "socket.http")
    local ok_ltn12, ltn12 = pcall(require, "ltn12")
    local ok_sutil, socketutil = pcall(require, "socketutil")
    if not ok_http or not ok_ltn12 then
        return false, nil, nil, nil
    end

    local sink = {}
    local request = {
        url = req.url,
        method = req.method or "GET",
        headers = req.headers or {},
        sink = ltn12.sink.table(sink),
        redirect = false,
    }
    if req.body then request.source = ltn12.source.string(req.body) end

    if ok_sutil and socketutil then
        socketutil:set_timeout(req.timeout or 15, (req.timeout or 15) * 2)
    end
    -- LuaSocket's http.request returns (1, code, headers, statusline) on
    -- success or (nil, error). The first value is the success indicator, not
    -- the HTTP status code.
    local call_ok, ok, code, headers = pcall(http.request, request)
    if ok_sutil and socketutil then socketutil:reset_timeout() end

    if not call_ok or not ok then
        return false, nil, nil, nil
    end
    return true, code, headers, table.concat(sink)
end

local function normalize_headers(headers)
    local normalized = {}
    if type(headers) ~= "table" then return normalized end
    for key, value in pairs(headers) do
        normalized[tostring(key):lower()] = value
    end
    return normalized
end

--------------------------------------------------------------------------------
-- Http object
--------------------------------------------------------------------------------

function Http:new(opts)
    opts = opts or {}
    return setmetatable({
        cookies = Http.sanitizeCookie(opts.cookies or ""),
        csrf_token = opts.csrf_token,
        user_id = opts.user_id,
        base_url = opts.base_url or "https://www.goodreads.com",
        timeout = opts.timeout or 15,
        max_hops = opts.max_hops or 6,
        transport = opts.transport or default_transport,
    }, self)
end

function Http:get_cookie_header()
    return self.cookies
end

function Http:set_cookie_header(cookie)
    self.cookies = Http.sanitizeCookie(cookie or "")
end

function Http:has_cookies()
    return self.cookies ~= nil and self.cookies ~= ""
end

local function base_headers(self, method)
    local headers = {
        ["User-Agent"] = USER_AGENT,
        ["Accept-Language"] = "en-US,en;q=0.9",
        ["Referer"] = self.base_url .. "/",
    }
    if self.cookies and self.cookies ~= "" then
        headers["Cookie"] = self.cookies
    end
    if method == "POST" then
        headers["Accept"] = "*/*"
        headers["Origin"] = self.base_url
        headers["X-Requested-With"] = "XMLHttpRequest"
        headers["Sec-Fetch-Site"] = "same-origin"
        headers["Sec-Fetch-Mode"] = "cors"
        headers["Sec-Fetch-Dest"] = "empty"
    else
        headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        headers["Sec-Fetch-Site"] = "same-origin"
        headers["Sec-Fetch-Mode"] = "navigate"
        headers["Sec-Fetch-Dest"] = "document"
        headers["Sec-Fetch-User"] = "?1"
        headers["Upgrade-Insecure-Requests"] = "1"
    end
    return headers
end

-- Some sign-in requests are intercepted before they reach the app page. We
-- detect this generically (an accepted-but-empty status, or a response header
-- carrying a challenge marker) without hard-coding any provider specifics.
local function is_intercepted(status, headers)
    if status == 202 then return true end
    if headers then
        for _, value in pairs(headers) do
            if type(value) == "string" and value:lower():find("challenge", 1, true) then
                return true
            end
        end
    end
    return false
end

local function classify(status, headers)
    if is_intercepted(status, headers) then
        return Constants.ERROR.SIGNIN_BLOCKED
    end
    if status == nil then return Constants.ERROR.NETWORK_ERROR end
    if status >= 200 and status < 300 then return nil end
    if status == 401 or status == 403 then return Constants.ERROR.AUTH_REQUIRED end
    if status == 404 then return Constants.ERROR.NOT_FOUND end
    if status == 409 then return Constants.ERROR.CONFLICT end
    if status == 422 then return Constants.ERROR.INVALID_REQUEST end
    if status == 429 then return Constants.ERROR.RATE_LIMITED end
    if status >= 500 then return Constants.ERROR.SERVER_ERROR end
    return Constants.ERROR.INVALID_RESPONSE
end

local function looks_like_sign_in(url, body)
    if url then
        for _, marker in ipairs(SIGN_IN_MARKERS) do
            if url:find(marker, 1, true) then return true end
        end
    end
    if body then
        if body:find('name="email"', 1, true) and body:find("/ap/signin", 1, true) then
            return true
        end
        if body:find("something wrong with your Goodreads cookie", 1, true) then
            return true
        end
    end
    return false
end

-- Perform a request. opts:
--   body, headers, follow (default true), detect_auth (default true),
--   csrf (bool: attach X-CSRF-Token)
-- Returns a response table:
--   { status, body, headers, url, error, blocked }
function Http:request(method, url, opts)
    opts = opts or {}
    method = method or "GET"
    local current_url = url
    local current_method = method
    local current_body = opts.body
    local hops = 0
    local last = { status = nil, body = nil, headers = {}, url = url }

    while true do
        local headers = base_headers(self, current_method)
        if opts.headers then
            for k, v in pairs(opts.headers) do headers[k] = v end
        end
        if current_body and not headers["Content-Type"] then
            headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
        end
        if current_body then
            headers["Content-Length"] = tostring(#current_body)
        end
        if opts.csrf and self.csrf_token then
            headers["X-CSRF-Token"] = self.csrf_token
        end
        if self.cookies and self.cookies ~= "" then
            headers["Cookie"] = self.cookies
        end

        local transport_ok, status, raw_headers, body = self.transport({
            url = current_url,
            method = current_method,
            headers = headers,
            body = current_body,
            timeout = self.timeout,
        })
        if not transport_ok then status = nil end
        local resp_headers = normalize_headers(raw_headers)

        -- Rotate cookies before any redirect decision.
        local set_cookie = resp_headers["set-cookie"]
        if set_cookie then
            self.cookies = Http.mergeSetCookie(self.cookies, set_cookie)
        end

        last = {
            status = status,
            body = body,
            headers = resp_headers,
            url = current_url,
        }

        local location = resp_headers["location"]
        local is_redirect = status == 301 or status == 302 or status == 303
            or status == 307 or status == 308

        if opts.follow ~= false and is_redirect and location and hops < self.max_hops then
            current_url = Http.absolute(current_url, location)
            if status == 301 or status == 302 or status == 303 then
                current_method = "GET"
                current_body = nil
            end
            hops = hops + 1
        else
            break
        end
    end

    local error_code = classify(last.status, last.headers)
    local blocked = is_intercepted(last.status, last.headers)

    if opts.detect_auth ~= false and not error_code then
        if looks_like_sign_in(last.url, last.body) then
            error_code = Constants.ERROR.AUTH_REQUIRED
        end
    end

    last.error = error_code
    last.blocked = blocked
    return last
end

function Http:get(url, opts)
    return self:request("GET", url, opts)
end

function Http:post_form(url, form, opts)
    opts = opts or {}
    local body = type(form) == "string" and form or Http.encodeForm(form)
    local request_opts = {
        body = body,
        headers = opts.headers,
        follow = opts.follow,
        detect_auth = opts.detect_auth,
        csrf = opts.csrf,
    }
    return self:request("POST", url, request_opts)
end

Http.default_transport = default_transport
Http._classify = classify
Http._looks_like_sign_in = looks_like_sign_in

return Http

end

package.preload["shelfsync_grlogin.auth.providers.amazon_web"] = function(...)
--[[--
On-device email/password login mechanism.

Concrete "AuthProvider" for the web provider. It follows the email sign-in
flow the site serves: a form with hidden anti-CSRF fields and email/password
inputs. Credentials are supplied by the caller and are never persisted here.

When the site answers with an image challenge, it is parsed and surfaced to
the caller (and on to the UI) so the user can solve it on-device. A challenge
that needs a browser cannot be solved here; it is reported and stops the flow.

@module koplugin.goodreads.auth.providers.amazon_web
--]]

local Constants = require("shelfsync_grlogin.constants")
local Logging = require("shelfsync_grlogin.logging")
local Session = require("shelfsync_grlogin.auth.session")

local AmazonWeb = {}
AmazonWeb.__index = AmazonWeb

local function parse_hidden_inputs(html)
    local fields = {}
    if type(html) ~= "string" then return fields end
    for tag in html:gmatch("<input[^>]*>") do
        local is_hidden = tag:find('type="hidden"', 1, true) or tag:find("type='hidden'", 1, true)
        if is_hidden then
            local name = tag:match('name="([^"]*)"') or tag:match("name='([^']*)'")
            local value = tag:match('value="([^"]*)"') or tag:match("value='([^']*)'")
            if name then fields[name] = value or "" end
        end
    end
    return fields
end

local function parse_form_with_password(html)
    if type(html) ~= "string" then return nil end
    for attrs, inner in html:gmatch("<form([^>]*)>(.-)</form>") do
        if inner:find('type="password"', 1, true) or inner:find("type='password'", 1, true) then
            local action = attrs:match('action="([^"]*)"') or attrs:match("action='([^']*)'")
            -- Goodreads historically used user[email]/user[password]; the
            -- Amazon AP form uses email/password (and sometimes ap_email).
            local email_name, password_name = "email", "password"
            for _, n in ipairs({ "user[email]", "ap_email", "email" }) do
                if inner:find('name="' .. n .. '"', 1, true) then
                    email_name = n
                    break
                end
            end
            for _, n in ipairs({ "user[password]", "ap_password", "password" }) do
                if inner:find('name="' .. n .. '"', 1, true) then
                    password_name = n
                    break
                end
            end
            local remember_name
            for tag in inner:gmatch("<input[^>]*>") do
                local name = tag:match('name="([^"]*)"') or tag:match("name='([^']*)'")
                if name and name:lower():find("remember", 1, true) then
                    remember_name = name
                    break
                end
            end
            return {
                action = action,
                hidden = parse_hidden_inputs(inner),
                email_field = email_name,
                password_field = password_name,
                remember_field = remember_name,
            }
        end
    end
    return nil
end

local function parse_otp_form(html)
    if type(html) ~= "string" then return nil end
    for attrs, inner in html:gmatch("<form([^>]*)>(.-)</form>") do
        local otp_name = inner:match('name="(otpCode)"')
            or inner:match('name="(code)"')
            or inner:match('name="([^"]*otp[^"]*)"')
        if otp_name then
            local action = attrs:match('action="([^"]*)"') or attrs:match("action='([^']*)'")
            return {
                action = action,
                hidden = parse_hidden_inputs(inner),
                otp_field = otp_name,
            }
        end
    end
    return nil
end

-- Find the challenge image. Only accept sources that look like a challenge so
-- we never mistake an ordinary page image for one.
local function find_challenge_image(html)
    if type(html) ~= "string" then return nil end
    for tag in html:gmatch("<img[^>]*>") do
        local src = tag:match('src="([^"]*)"') or tag:match("src='([^']*)'")
        if src then
            local l = src:lower()
            if l:find("captcha", 1, true) or l:find("validate", 1, true)
                or l:find("/errors/", 1, true) then
                return src
            end
        end
    end
    return nil
end

local function challenge_input_in(inner)
    if type(inner) ~= "string" then return nil end
    for tag in inner:gmatch("<input[^>]*>") do
        local typ = (tag:match('type="([^"]*)"') or tag:match("type='([^']*)'") or "text"):lower()
        local name = tag:match('name="([^"]*)"') or tag:match("name='([^']*)'")
        if name and (typ == "text" or typ == "search") then
            local l = name:lower()
            if l:find("captcha", 1, true) or l:find("keyword", 1, true) then
                return name
            end
        end
    end
    return nil
end

local function first_text_input_in(inner)
    if type(inner) ~= "string" then return nil end
    for tag in inner:gmatch("<input[^>]*>") do
        local typ = (tag:match('type="([^"]*)"') or tag:match("type='([^']*)'") or "text"):lower()
        local name = tag:match('name="([^"]*)"') or tag:match("name='([^']*)'")
        if name and (typ == "text" or typ == "search") then
            return name
        end
    end
    return nil
end

-- Parse an image challenge. The image is often outside the form, and the
-- answer field may be named in a few different ways, so the image and the
-- input are located independently.
local function parse_challenge(html)
    if type(html) ~= "string" then return nil end
    local image_url = find_challenge_image(html)
    if not image_url then return nil end

    local fallback
    for attrs, inner in html:gmatch("<form([^>]*)>(.-)</form>") do
        local action = attrs:match('action="([^"]*)"') or attrs:match("action='([^']*)'")
        local hidden = parse_hidden_inputs(inner)
        local input = challenge_input_in(inner)
        if input then
            return {
                action = action,
                hidden = hidden,
                image_url = image_url,
                input_name = input,
            }
        end
        if not fallback then
            local any_input = first_text_input_in(inner)
            if any_input then
                fallback = {
                    action = action,
                    hidden = hidden,
                    image_url = image_url,
                    input_name = any_input,
                }
            end
        end
    end
    return fallback
end

local function collect_sign_in_links(html)
    local links = {}
    if type(html) ~= "string" then return links end
    for href in html:gmatch('href="(https?://[^"]*/ap/signin%?[^"]*)"') do
        links[#links + 1] = (href:gsub("&amp;", "&"))
    end
    for href in html:gmatch("href='(https?://[^']*/ap/signin%?[^']*)'") do
        links[#links + 1] = (href:gsub("&amp;", "&"))
    end
    return links
end

local function sign_in_link(html)
    local links = collect_sign_in_links(html)
    -- Prefer the straightforward sign-in flow over the third-party buttons.
    for _, link in ipairs(links) do
        if not link:find("identityProvider", 1, true) then return link end
    end
    return links[1]
end

local function lower(s)
    return type(s) == "string" and s:lower() or ""
end

local function contains_any(haystack, needles)
    local h = lower(haystack)
    for _, needle in ipairs(needles) do
        if h:find(needle, 1, true) then return true end
    end
    return false
end

-- Only strong, challenge-specific phrases. Bare generic words also appear on
-- ordinary pages, so they must NOT be used to detect a challenge.
local CHALLENGE_MARKERS = {
    "enter the characters you see",
    "type the characters you see",
    "characters you see",
}
local OTP_MARKERS = { "auth-mfa", "otpcode", "verification code", "two-step verification", "enter otp" }
local BAD_CREDENTIALS_MARKERS = {
    "password is incorrect",
    "problem with your password",
    "cannot find an account",
    "your password is incorrect",
    "there was a problem with your request",
}

-- A compact, non-secret fingerprint of a page, for diagnostics only.
local function page_markers(body)
    local l = lower(body)
    local markers = {
        "form=" .. tostring(l:find("<form", 1, true) ~= nil),
        "password=" .. tostring(l:find('type="password"', 1, true) ~= nil),
        "email=" .. tostring(l:find('name="email"', 1, true) ~= nil),
        "signin=" .. tostring(l:find("sign_in", 1, true) ~= nil or l:find("signin", 1, true) ~= nil),
        "check=" .. tostring(contains_any(body, CHALLENGE_MARKERS)),
        "consent=" .. tostring(l:find("consent", 1, true) ~= nil),
        "intercept=" .. tostring(l:find("challenge", 1, true) ~= nil),
    }
    return table.concat(markers, " ")
end

function AmazonWeb:new(opts)
    opts = opts or {}
    return setmetatable({
        base_url = opts.base_url or "https://www.goodreads.com",
        transport = opts.transport,
        -- Login round-trips can be slow; allow more than the
        -- generic 15s used for routine calls.
        timeout = opts.timeout or 30,
    }, self)
end

function AmazonWeb:_new_http()
    local Http = require("shelfsync_grlogin.goodreads.http")
    return Http:new{
        base_url = self.base_url,
        transport = self.transport,
        timeout = self.timeout,
    }
end

-- Fetch the sign-in page and locate the credential form.
-- Returns ctx or nil, error.
local function host_of(url)
    if type(url) ~= "string" then return "?" end
    return url:match("^https?://([^/]+)") or url
end

function AmazonWeb:start()
    local http = self:_new_http()
    local resp = http:get(self.base_url .. "/user/sign_in", {
        follow = true,
        detect_auth = false,
    })
    Logging.trace("login/start: sign_in status=", tostring(resp.status),
        "url=", tostring(resp.url), "bytes=", tostring(resp.body and #resp.body),
        "error=", tostring(resp.error))
    if resp.body then
        Logging.trace("login/start: sign_in page ", page_markers(resp.body))
    end

    if resp.error == Constants.ERROR.SIGNIN_BLOCKED then
        return nil, Constants.ERROR.SIGNIN_BLOCKED
    end
    if resp.error then return nil, resp.error end

    local form = parse_form_with_password(resp.body)
    if form and form.action then
        form.action = require("shelfsync_grlogin.goodreads.http").absolute(self.base_url, form.action)
        Logging.trace("login/start: direct form host=", host_of(form.action))
        return { http = http, form = form }
    end

    local link = sign_in_link(resp.body)
    if not link then
        Logging.trace("login/start: no sign-in link found")
        return nil, Constants.ERROR.INVALID_RESPONSE
    end
    Logging.trace("login/start: following sign-in link host=", host_of(link))
    local form_resp = http:get(link, { follow = true, detect_auth = false })
    Logging.trace("login/start: form page status=", tostring(form_resp.status),
        "url=", tostring(form_resp.url),
        "bytes=", tostring(form_resp.body and #form_resp.body),
        "error=", tostring(form_resp.error))
    if form_resp.body then
        Logging.trace("login/start: form page ", page_markers(form_resp.body))
    end

    if form_resp.error == Constants.ERROR.SIGNIN_BLOCKED then
        return nil, Constants.ERROR.SIGNIN_BLOCKED
    end
    if form_resp.error then return nil, form_resp.error end

    form = parse_form_with_password(form_resp.body)
    if not form or not form.action then
        local challenge = parse_challenge(form_resp.body)
        if challenge then
            Logging.trace("login/start: challenge on the form page")
            return {
                http = http,
                challenge = challenge,
                challenge_url = form_resp.url,
            }
        end
        if contains_any(form_resp.body, CHALLENGE_MARKERS) then
            return nil, Constants.ERROR.SIGNIN_BLOCKED
        end
        Logging.trace("login/start: no credential form on form page")
        return nil, Constants.ERROR.INVALID_RESPONSE
    end
    form.action = require("shelfsync_grlogin.goodreads.http").absolute(form_resp.url, form.action)
    Logging.trace("login/start: form action host=", host_of(form.action))
    return { http = http, form = form }
end

function AmazonWeb:_interpret(ctx, resp)
    Logging.trace("login/interpret: status=", tostring(resp.status),
        "url=", tostring(resp.url), "bytes=", tostring(resp.body and #resp.body),
        "error=", tostring(resp.error))

    local body = resp.body or ""
    ctx.last_body = body
    ctx.challenge_url = resp.url or ctx.challenge_url

    -- A real image challenge is treated as solvable and takes priority, so the
    -- user can complete it on-device.
    local challenge = parse_challenge(body)
    if challenge then
        ctx.challenge = challenge
        Logging.trace("login/interpret: challenge image host=",
            host_of(challenge.image_url), " input=", tostring(challenge.input_name))
        return {
            ok = false,
            needs_challenge = true,
            ctx = ctx,
            challenge = challenge,
            stage = "challenge",
        }
    end

    if resp.error == Constants.ERROR.SIGNIN_BLOCKED then
        -- The landing page is frequently intercepted even when the credential
        -- POST already established a session. Validate against a normally
        -- served page before failing.
        local verified = self:_finalize(ctx)
        if verified.ok then return verified end
        return { ok = false, error = Constants.ERROR.SIGNIN_BLOCKED, stage = "blocked" }
    end
    if resp.error == Constants.ERROR.NETWORK_ERROR
        or resp.error == Constants.ERROR.SERVER_ERROR then
        return { ok = false, error = resp.error, stage = "network" }
    end

    -- Strong challenge text without a parseable image: an unsolvable challenge.
    -- Ordinary pages that merely mention it must NOT land here, or a successful
    -- login would be reported as blocked.
    if contains_any(body, CHALLENGE_MARKERS) then
        Logging.trace("login/interpret: challenge page without a parseable image ",
            page_markers(body))
        return { ok = false, error = Constants.ERROR.SIGNIN_BLOCKED, stage = "challenge" }
    end
    if contains_any(body, OTP_MARKERS) then
        Logging.trace("login/interpret: OTP/MFA required")
        return { ok = false, needs_otp = true, ctx = ctx, stage = "otp" }
    end
    if contains_any(body, BAD_CREDENTIALS_MARKERS) then
        Logging.trace("login/interpret: bad credentials marker present")
        return { ok = false, error = Constants.ERROR.INVALID_CREDENTIALS, stage = "credentials" }
    end
    -- If the response is still a credential form, the attempt did not progress.
    if parse_form_with_password(body) then
        Logging.trace("login/interpret: still on credential form")
        return { ok = false, error = Constants.ERROR.INVALID_CREDENTIALS, stage = "credentials" }
    end

    return self:_finalize(ctx)
end

function AmazonWeb:_finalize(ctx)
    local http = ctx.http
    -- Validate against a normally-served page that, when signed in, contains
    -- the user id and a CSRF token.
    local resp = http:get(http.base_url .. "/review/list", { follow = true, detect_auth = false })
    local looks_signin = require("shelfsync_grlogin.goodreads.http")._looks_like_sign_in(resp.url, resp.body)
    local body = resp.body or ""
    local user_id = body:match("/user/show/(%d+)")
    local csrf = body:match(
        '<meta%s+[^>]-name=["\']csrf%-token["\']%s+[^>]-content=["\']([^"\']+)["\']')
    Logging.trace("login/finalize: status=", tostring(resp.status),
        "url=", tostring(resp.url), "bytes=", tostring(resp.body and #resp.body),
        "error=", tostring(resp.error),
        "user_id=", tostring(user_id),
        "csrf=", tostring(csrf ~= nil),
        "looks_like_signin=", tostring(looks_signin))

    if resp.error == Constants.ERROR.SIGNIN_BLOCKED then
        return { ok = false, error = Constants.ERROR.SIGNIN_BLOCKED, stage = "blocked" }
    end
    if resp.error then
        return { ok = false, error = resp.error, stage = "finalize" }
    end

    -- Only trust a page that clearly belongs to a signed-in account.
    if not user_id or looks_signin then
        return { ok = false, error = Constants.ERROR.INVALID_CREDENTIALS, stage = "finalize" }
    end

    http.csrf_token = csrf
    http.user_id = user_id

    local session = Session.new()
    Session.absorb(session, http)
    Session.mark_valid(session)
    return {
        ok = true,
        session = session,
        account = { id = http.user_id, username = http.user_id },
    }
end

-- Submit credentials. `email`/`password` come from the UI and are not stored.
function AmazonWeb:submit(ctx, email, password)
    if not ctx or not ctx.form then
        return { ok = false, error = Constants.ERROR.AUTH_REQUIRED, stage = "submit" }
    end
    local fields = {}
    for key, value in pairs(ctx.form.hidden or {}) do fields[key] = value end
    fields[ctx.form.email_field or "email"] = email
    fields[ctx.form.password_field or "password"] = password
    -- "Keep me signed in" — request a long-lived session.
    local remember_field = ctx.form.remember_field or "rememberMe"
    if not fields[remember_field] then fields[remember_field] = "true" end

    Logging.trace("login/submit: posting to host=", host_of(ctx.form.action),
        "email_field=", tostring(ctx.form.email_field))

    local resp = ctx.http:post_form(ctx.form.action, fields, {
        follow = true,
        detect_auth = false,
    })
    return self:_interpret(ctx, resp)
end

function AmazonWeb:submit_otp(ctx, otp)
    if not ctx then
        return { ok = false, error = Constants.ERROR.AUTH_REQUIRED, stage = "otp" }
    end
    local otp_form = parse_otp_form(ctx.last_body)
    if not otp_form or not otp_form.action then
        return { ok = false, error = Constants.ERROR.INVALID_RESPONSE, stage = "otp" }
    end
    local fields = {}
    for key, value in pairs(otp_form.hidden or {}) do fields[key] = value end
    fields[otp_form.otp_field] = otp

    local action = require("shelfsync_grlogin.goodreads.http").absolute(ctx.http.base_url, otp_form.action)
    local resp = ctx.http:post_form(action, fields, {
        follow = true,
        detect_auth = false,
    })
    return self:_interpret(ctx, resp)
end

function AmazonWeb:submit_challenge(ctx, answer)
    if not ctx or not ctx.challenge then
        return { ok = false, error = Constants.ERROR.INVALID_RESPONSE, stage = "challenge" }
    end
    local fields = {}
    for key, value in pairs(ctx.challenge.hidden or {}) do fields[key] = value end
    fields[ctx.challenge.input_name] = answer

    local base_action = ctx.challenge.action or (ctx.form and ctx.form.action)
    local action = base_action
        and require("shelfsync_grlogin.goodreads.http").absolute(ctx.http.base_url, base_action)
    if not action then
        return { ok = false, error = Constants.ERROR.INVALID_RESPONSE, stage = "challenge" }
    end

    Logging.trace("login/challenge: submitting answer to host=", host_of(action))
    local resp = ctx.http:post_form(action, fields, {
        follow = true,
        detect_auth = false,
    })
    return self:_interpret(ctx, resp)
end

AmazonWeb._parse_hidden_inputs = parse_hidden_inputs
AmazonWeb._parse_form_with_password = parse_form_with_password
AmazonWeb._parse_otp_form = parse_otp_form
AmazonWeb._parse_challenge = parse_challenge
AmazonWeb._sign_in_link = sign_in_link

return AmazonWeb

end

package.preload["shelfsync_grlogin.auth.login"] = function(...)
--[[--
Interactive login orchestration.

Keeps the UI independent of the concrete authentication mechanism: the UI
calls `Login.perform(email, password)` and, if the result asks for an OTP,
`Login.submit_otp(ctx, otp)`.

Transient failures (network/timeout, server error, unparseable response) are
retried a few times with a small backoff. Authentication outcomes (bad
credentials, OTP, challenge) are never retried.

@module koplugin.goodreads.auth.login
--]]

local Constants = require("shelfsync_grlogin.constants")

local Login = {}

local TRANSIENT = {
    [Constants.ERROR.NETWORK_ERROR] = true,
    [Constants.ERROR.SERVER_ERROR] = true,
    [Constants.ERROR.INVALID_RESPONSE] = true,
}

local DEFAULT_ATTEMPTS = 3
local DEFAULT_RETRY_DELAY = 2

local function default_sleep(seconds)
    local ok, socket = pcall(require, "socket")
    if ok and socket and type(socket.sleep) == "function" then
        socket.sleep(seconds)
    end
end

local function mechanism(opts)
    opts = opts or {}
    local AmazonWeb = require("shelfsync_grlogin.auth.providers.amazon_web")
    return AmazonWeb:new{
        base_url = opts.base_url,
        transport = opts.transport,
        timeout = opts.timeout,
    }
end

-- A result is worth retrying only when it is a transient failure.
local function should_retry(result)
    return type(result) == "table"
        and not result.ok
        and not result.needs_otp
        and not result.needs_challenge
        and TRANSIENT[result.error] == true
end

local function with_retries(fn, opts)
    opts = opts or {}
    local attempts = tonumber(opts.attempts) or DEFAULT_ATTEMPTS
    if attempts < 1 then attempts = 1 end
    local delay = tonumber(opts.retry_delay) or DEFAULT_RETRY_DELAY
    local sleep = opts.sleep or default_sleep

    local result
    for attempt = 1, attempts do
        result = fn()
        if not should_retry(result) or attempt == attempts then
            return result
        end
        sleep(delay * attempt)
    end
    return result
end

-- Returns:
--   { ok = true, session = ..., account = ... }
--   { ok = false, error = <code>, stage = ... }
--   { ok = false, needs_otp = true, ctx = ... }
--   { ok = false, needs_challenge = true, ctx = ..., challenge = ... }
--   (the challenge fields are internal; the UI only needs `needs_challenge`)
function Login.perform(email, password, opts)
    if type(email) ~= "string" or email == ""
        or type(password) ~= "string" or password == "" then
        return { ok = false, error = Constants.ERROR.INVALID_REQUEST, stage = "input" }
    end

    return with_retries(function()
        local mech = mechanism(opts)
        local ctx, err = mech:start()
        if not ctx then
            return { ok = false, error = err or Constants.ERROR.PROVIDER_UNAVAILABLE, stage = "start" }
        end
        -- The sign-in page itself can present a challenge.
        if ctx.challenge then
            return { ok = false, needs_challenge = true, ctx = ctx, challenge = ctx.challenge, stage = "challenge" }
        end
        return mech:submit(ctx, email, password)
    end, opts)
end

function Login.submit_otp(ctx, otp, opts)
    if not ctx then
        return { ok = false, error = Constants.ERROR.AUTH_REQUIRED, stage = "otp" }
    end
    if type(otp) ~= "string" or otp == "" then
        return { ok = false, error = Constants.ERROR.INVALID_REQUEST, stage = "otp" }
    end
    return with_retries(function()
        local mech = mechanism(opts)
        return mech:submit_otp(ctx, otp)
    end, opts)
end

function Login.submit_challenge(ctx, answer, opts)
    if not ctx then
        return { ok = false, error = Constants.ERROR.AUTH_REQUIRED, stage = "challenge" }
    end
    if type(answer) ~= "string" or answer == "" then
        return { ok = false, error = Constants.ERROR.INVALID_REQUEST, stage = "challenge" }
    end
    return with_retries(function()
        local mech = mechanism(opts)
        return mech:submit_challenge(ctx, answer)
    end, opts)
end

return Login

end
