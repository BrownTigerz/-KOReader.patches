--[[ 2-kobo-style-sleepscreen-banner.lua ]]
--redesigns the inbuilt 'banner' type sleep screen message to
--make it look like the kobo lockscreen tag.

--Version: 1.1.3

--VERSIONING
--1.0.x = fixes (e.g. adapting to a ShelfSync token rename)
--1.x.0 = new features
--2.0.0 = changes that affect how existing backups work

--CHANGELOG
--1.1.3 - expose HL_SETT.allowed_hl_styles + QUOTE_SETT.file_path as
--         _G.__sleepscreen_banner_settings for the diagnostics patch
--         (it was duplicating them and drifting)
--1.1.2 - banner re-reads screen size on every sleep (was sized for the
--         orientation at load time after rotating); no book ever opened now
--         returns straight to the stock banner instead of relying on a
--         caught error from the title lookup; restored the left-edge comment
--1.1.1 -fix possible infinite loop in random pick when the highlight pool
--         or quotes file shrinks; footer now reads metadata from the highlight
--         actually shown (was indexing the unfiltered annotations list);
--         '%' in chapter/title/author no longer crashes the footer; no longer
--         pins ReaderUI onto UIManager (leak); sidecar is now per-sleep local
--         and prefers the open book's live annotations; whole rebuild wrapped
--         in pcall with fallback to the stock banner; nil lastfile guarded;
--         text heights clamped so they can't go negative; no-repeat history
--         keyed by content instead of index (survives edits/deletes); short
--         multi-line highlights render line breaks; UTF-8 BOM stripped from
--         quotes file; max_height nil guard
--1.1.0 - fallback random quote from a txt file (its own no-repeat window)
--         when the current book has no highlights; quotes file hot-reloads
--         if it changes on disk; RNG now seeded; highlight no-repeat window
--         fixed to scope per book instead of leaking across books; dropped
--         a redundant Sidecar:flush() on every sleep; sleep-screen date
--         format corrected to "Mon D 'YY"
--1.0.0 - baseline: Kobo-style banner with book title/stats and a random
--         highlight on sleep

--CREDITS
--this version was written in collab with discord user @sandcastles.
--i've also borrowed some design cues from a similar patch written by reddit user u/juancoquet.

local B_SETT = {	--BANNER SETTINGS
					title_text = "%T", 	--configure title_text like you'd configure the inbuilt 
										--sleep screen message. for eg, "%T" shows book title,
										--"page %c of %t" shows 'page 1 of 400' etc.
					title_fontFace = "AtkinsonHyperlegibleNext-Regular.otf",
					title_fontSize = 22,
					stats_fontFace = "AtkinsonHyperlegibleNext-Regular.otf",
					stats_fontSize = 16,
					border_size = 1,
					border_color = 1,	-- 0 = white, 1 = black						
					background = 0,		-- 0 = white, 1 = black
					margin = 10,
					padding = 15,	
					max_height = 40,		-- percentage of screen height, min: 20
					max_width_hl_off = 50,	-- width when highlight off, min: 20
					max_width_hl_on = 60,  	-- width when highlight on, min: 20
}
local HL_SETT = {	--HIGHLIGHT SETTINGS
					showRandomHighlight = true, 
					highlight_fontFace = "NotoSerif-Italic.ttf",
					highlight_fontSize = 16,
					justify = true,
					add_quotations = true,
					show_accent_line = true,					
					showHighlightFooter = true,
					hl_footer_fontFace = "NotoSerif-Regular.ttf",
					hl_footer_fontSize = 15,
					hl_footer_text = "saved on %DT at %HM", 	
										-- %DT = date, 
										-- %HM = time,
										-- %PG = page, 
										-- %C = chapter,
										-- %A = author, 
										-- %T = title, 
										-- \n = line break
												
					allowed_hl_styles = { 	-- only 'true' styles will be shown
									lighten = true,
									underscore = true,
									strikethrough = false,
									invert = false,
					},
					no_repeat_window = 5,	-- won't repeat a highlight until this many
											-- other highlights FROM THE SAME BOOK
											-- have shown first
}
local QUOTE_SETT = {	--FALLBACK QUOTE SETTINGS
						--used only when the current book has no eligible highlights.
						--quotes.txt should have one quote per line, already formatted
						--the way you want it shown, e.g.:
						--“Blah blah blah” - Quoter
					enabled = true,
					file_path = "/mnt/onboard/Famous Quotes.txt",  -- adjust path to your device
					no_repeat_window = 8,	-- won't repeat a quote until this many
											-- other quotes have shown first
}

--exposed for 2-zz-sleepscreen-banner-diagnostics.lua: it reads these live
--instead of keeping its own copies, so editing HL_SETT/QUOTE_SETT above
--can't silently desync its counts
_G.__sleepscreen_banner_settings = {
	allowed_hl_styles = HL_SETT.allowed_hl_styles,
	quotes_file_path = QUOTE_SETT.file_path,
}

local Bb = require("ffi/blitbuffer")
local BookInfo = require("apps/filemanager/filemanagerbookinfo")
local BookList = require("ui/widget/booklist")
local datetime = require("datetime")  
local Device = require("device")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local Screen = Device.screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local PATCH_VERSION = "1.1.3"	--bump this on every change; it's the only
								--number that needs to change -- the header's
								--Version line and changelog are kept in sync
								--by hand, this constant is what actually
								--reaches crash.log.
local TAG = "[kobo-style-sleepscreen-banner]"
logger.info(TAG .. " loaded, version " .. PATCH_VERSION)

math.randomseed(os.time())	--without this, "random" picks can repeat the same
							--sequence across restarts

local MIN_TEXT_H = Screen:scaleBySize(30)	-- floor for any text box height, so
											-- a long title can't push later
											-- fields to zero/negative height
local recent_highlight_keys = {}	-- rolling history of highlight keys, oldest first
local recent_highlight_book			-- which book recent_highlight_keys applies to
local recent_quote_keys = {}		-- rolling history of quote text, oldest first
local cached_quotes_list			-- kept in memory, reloaded if file mtime changes
local cached_quotes_mtime

local function highlightKey(item)
	return tostring(item.datetime) .. "|" .. tostring(item.text)
end

local function quoteKey(text)
	return text
end

--picks a random index into items, skipping anything whose key is in the
--recent window. History is keyed by content, not position, so editing the
--quotes file or deleting a highlight can't make it guard the wrong items.
--Never loops: if every candidate is excluded (e.g. duplicate lines), it
--just picks from the whole pool.
local function pickRandom(items, keyOf, recent_list, window)
	local count = #items
	if count == 0 then return nil end
	if count == 1 then return 1 end
	local eff_window = math.min(window or 0, count - 1)
	while #recent_list > eff_window do table.remove(recent_list, 1) end

	local recent_set = {}
	for _, k in ipairs(recent_list) do recent_set[k] = true end
	local candidates = {}
	for i = 1, count do
		if not recent_set[keyOf(items[i])] then
			candidates[#candidates + 1] = i
		end
	end

	local idx = #candidates > 0 and candidates[math.random(#candidates)] or math.random(count)
	table.insert(recent_list, keyOf(items[idx]))
	while #recent_list > eff_window do table.remove(recent_list, 1) end
	return idx
end

local function buildTextField(
								text, 
								font_face, 
								max_height, 
								max_wid, 
								ignoreLineBreaks, 
								isHighlight, 
								text_color
							)
	local wgt_grp = VerticalGroup:new{align = "left"}
	max_height = math.max(max_height, MIN_TEXT_H)
	text = text:gsub("\\n", "\n")
	local segments = ignoreLineBreaks and {text} or util.splitToArray(text, "\n")
	local fg = text_color or 
				(B_SETT.background == 1 and Bb.COLOR_WHITE or Bb.COLOR_BLACK)
	local bg = B_SETT.background == 0 and Bb.COLOR_WHITE or Bb.COLOR_BLACK
	for _, item in ipairs(segments) do 
		--TextWidget can't render real line breaks, so anything that still
		--contains one has to go straight to a TextBoxWidget
		local has_break = item:find("\n", 1, true) ~= nil
		local wgt
		if not has_break then
			wgt = TextWidget:new{
						padding = 0,
						text = item,
						face = font_face,
						alignment = "left",
						fgcolor = fg,
						bgcolor = bg,
			}
		end
		if has_break or wgt:getSize().w > max_wid then 
			if wgt then wgt:free() end
			wgt = TextBoxWidget:new{
						text = item,
						face = font_face,
						width = max_wid,
						alignment = "left",
						height = max_height,
						height_adjust = true,
						height_overflow_show_ellipsis = true,
						justified = isHighlight and HL_SETT.justify,
						fgcolor = fg,
						bgcolor = bg,
			}			
		end		
		table.insert(wgt_grp, wgt)
	end
	return wgt_grp
end

local function addQuotesIfReq(text)
	if not text or text == "" then
		return text
	end
	local chars = util.splitToChars(text)  
	local first_char = chars[1]   
	local last_char = chars[#chars]
	local control = { {"'", "'"}, {"\"", "\""}, {"“", "”"}, 
						{"‘", "’"}, {"«", "»"}, {"„", "“"} }
	for _, quotes in ipairs(control) do 
		if first_char == quotes[1] and last_char == quotes[2] then 
			return text
		end
	end
	return "“" .. text .. "”"
end

--item is the highlight actually being shown (not an index into the raw
--annotations list, which also contains bookmarks/notes/disallowed styles).
local function parseFooterText(text, item, doc_settings)
	if not text or text == "" or not item then 
		return text 
	end

	local hl_chapter = item.chapter or "N/A"
	local use_labels = doc_settings and doc_settings:isTrue("pagemap_use_page_labels")
	local hl_pageno = (use_labels and item.pageref) or item.pageno or "N/A"

	local doc_props = doc_settings and doc_settings:readSetting("doc_props") or {}
	local bk_author = doc_props.authors or "N/A"
	local bk_title = doc_props.title or "N/A"

	--date and time
	local date_and_time = item.datetime and 
							util.splitToArray(item.datetime, "%s+", false) or {}

	local hl_date = "N/A"
	local yr, mth, dy = (date_and_time[1] or ""):match("(%d+)-(%d+)-(%d+)")
	if yr and mth and dy then
		local month_abbr = os.date("%b", os.time{
								year = tonumber(yr), month = tonumber(mth), day = tonumber(dy)})
		local short_month = datetime.shortMonthTranslation[month_abbr] or month_abbr
		if short_month and short_month ~= "" then
			hl_date = string.format("%s %d '%02d", short_month, tonumber(dy), tonumber(yr) % 100)
		end
	end

	local timesplit = date_and_time[2] and util.splitToArray(date_and_time[2], ":") or {}
	local hl_time = timesplit[1] and timesplit[2] and 
					timesplit[1] .. ":" .. timesplit[2] or "N/A"

	local tokens = {
		HM = hl_time,
		DT = hl_date,
		PG = hl_pageno,
		C  = hl_chapter,
		A  = bk_author,
		T  = bk_title,
	}
	--single pass with a function replacement: values are inserted literally
	--(a '%' in a chapter name can't break gsub) and never re-expanded.
	--two-letter tokens are tried first, then one-letter.
	text = text:gsub("%%(%u%u?)", function(tok)
		if tokens[tok] ~= nil then
			return tostring(tokens[tok])
		end
		local one = tok:sub(1, 1)
		if tokens[one] ~= nil then
			return tostring(tokens[one]) .. tok:sub(2)
		end
	end)
	return text	
end

local function loadQuotesFromFile(path)
	local mtime = lfs.attributes(path, "modification")

	--already cached and file hasn't changed since (or mtime is unreadable
	--but we have a cache from before) -- reuse it.
	if cached_quotes_list and (not mtime or mtime == cached_quotes_mtime) then
		return cached_quotes_list
	end

	local new_list = {}
	local f = io.open(path, "r")
	if not f then
		return cached_quotes_list or new_list
	end
	local first = true
	for line in f:lines() do
		if first then
			line = line:gsub("^\239\187\191", "")	-- strip UTF-8 BOM (Windows editors)
			first = false
		end
		local trimmed = util.trim(line)
		if trimmed ~= "" then
			table.insert(new_list, trimmed)
		end
	end
	f:close()

	cached_quotes_list = new_list
	cached_quotes_mtime = mtime
	return cached_quotes_list
end

local function pctOf(val, total, default_pct)
	if type(val) == "number" and val >= 20 and val <= 100 then
		return val / 100 * total
	end
	return default_pct * total
end

local function shouldIntercept(widget)
	if not widget or widget.name ~= "ScreenSaver" then return false end

	if not G_reader_settings:isTrue("screensaver_show_message") or 
			G_reader_settings:readSetting("screensaver_message_container") ~= "banner" then 
		return false
	end
	local screensaver_type = G_reader_settings:readSetting("screensaver_type")
	if screensaver_type ~= "cover" and 
			screensaver_type ~= "random_image" and 
			screensaver_type ~= "document_cover" then			
		return false
	end		

	return widget[1] and						--screensaver wgt
			widget[1][1] and					--overlap group
			widget[1][1][2] and					--custom pos. container
			widget[1][1][2].widget and			--textbox widget
			widget[1][1][2].widget.text and true or false
end

--builds the replacement banner. Does NOT touch the original widget, so if
--anything here throws, the caller can still show the stock banner.
local function buildBanner(widget)
	local last_file = G_reader_settings:readSetting("lastfile")
	if not last_file then
		return nil	-- no book ever opened: nothing to show, caller keeps stock banner
	end

	--read per sleep, not at load, so rotation is picked up
	local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()

	local ReaderUI = require("apps/reader/readerui")
	local FileManager = require("apps/filemanager/filemanager")
	local reader = ReaderUI.instance
	local ui = reader or FileManager.instance

	--prefer the open book's live settings/annotations: highlights made this
	--session may not be flushed to the sidecar yet.
	local live = reader and reader.document and last_file and 
					reader.document.file == last_file
	local doc_settings = live and reader.doc_settings or 
						(last_file and BookList.getDocSettings(last_file)) or nil

	--the highlight no-repeat window is meant to be PER BOOK
	if recent_highlight_book ~= last_file then
		recent_highlight_keys = {}
		recent_highlight_book = last_file
	end

	--dimen roundup	
	local dimen_ = {
			padding = Screen:scaleBySize(B_SETT.padding or 15),
			margin = Screen:scaleBySize(B_SETT.margin or 10),
			border_size = Screen:scaleBySize(B_SETT.border_size or 1),
			line_width = Screen:scaleBySize(1),
			line_clearance = Size.padding.large,
			hl_wgt_clearance = Screen:scaleBySize(15),
			footer_clearance = Screen:scaleBySize(5),			
	}

	local overflow_h = (dimen_.padding + dimen_.margin + dimen_.border_size) * 2 + 
							dimen_.hl_wgt_clearance
	local overflow_w = (dimen_.padding + dimen_.margin + dimen_.border_size) * 2	
	local overflow_w_hl = HL_SETT.show_accent_line and 
							(overflow_w + dimen_.line_clearance + dimen_.line_width) or 
							overflow_w

	--font roundup
	local font_ = {
		title_font = Font:getFace(B_SETT.title_fontFace, B_SETT.title_fontSize) or 
						Font:getFace("cfont", 30),
		stats_font = Font:getFace(B_SETT.stats_fontFace, B_SETT.stats_fontSize) or 
						Font:getFace("cfont", 17),
		footer_font = Font:getFace(HL_SETT.hl_footer_fontFace, HL_SETT.hl_footer_fontSize) or 
						Font:getFace("NotoSerif-Regular.ttf", 15),
		highlight_font = Font:getFace(HL_SETT.highlight_fontFace, HL_SETT.highlight_fontSize) or 
						Font:getFace("NotoSerif-Italic.ttf", 16)					
	}	

	local orig_sleep_text = widget[1][1][2].widget.text

	--eligible highlights
	local highlightEnabled, highlights_list = false, {}
	if HL_SETT.showRandomHighlight then
		local all_annotations = (live and reader.annotation and reader.annotation.annotations) or 
								(doc_settings and doc_settings:readSetting("annotations")) or {}
		local allowed = HL_SETT.allowed_hl_styles
		for _, item in ipairs(all_annotations) do
			if type(item.text) == "string" and item.drawer and allowed[item.drawer] 
					and util.trim(item.text) ~= "" then
				table.insert(highlights_list, item)
			end
		end
		highlightEnabled = #highlights_list > 0
	end

	--fallback: no eligible highlight in this book, try a random quote from file
	local quoteEnabled, quotes_list = false, nil
	if not highlightEnabled and QUOTE_SETT.enabled then
		quotes_list = loadQuotesFromFile(QUOTE_SETT.file_path)
		quoteEnabled = #quotes_list > 0
	end

	local hl_footer_enabled = highlightEnabled and 
								HL_SETT.showHighlightFooter and 
								HL_SETT.hl_footer_text and 
								util.trim(HL_SETT.hl_footer_text) ~= ""

	local max_wid
	if not highlightEnabled and not quoteEnabled then
		max_wid = pctOf(B_SETT.max_width_hl_off, screen_w, 0.4) - overflow_w
	else
		max_wid = pctOf(B_SETT.max_width_hl_on, screen_w, 0.6) - overflow_w_hl
	end			
	local max_height = pctOf(B_SETT.max_height, screen_h, 0.5) - overflow_h

	--TITLE WIDGET
	local title_text
	if ui and ui.document and ui.toc and ui.bookinfo then
		title_text = ui.bookinfo:expandString(B_SETT.title_text, last_file)
	else
		title_text = BookInfo:expandString(B_SETT.title_text, last_file)
	end
	title_text = title_text or "N/A"

	local title_widget = buildTextField(title_text, font_.title_font, max_height, max_wid, true)
	local title_dimen = title_widget:getSize()					

	--STATS WIDGET
	local stats_widget = buildTextField(
							orig_sleep_text, 
							font_.stats_font, 
							max_height - title_dimen.h, 
							max_wid
	)
	local stats_dimen = stats_widget:getSize()

	local footer_color = B_SETT.background == 0 and Bb.COLOR_GRAY_4 or Bb.COLOR_GRAY_9

	local function withAccent(wgt)
		if not HL_SETT.show_accent_line then return wgt end
		local accent = LineWidget:new{  
						background = footer_color,   
						dimen = Geom:new{  
							w = dimen_.line_width,   
							h = wgt:getSize().h, 
						},  
		}
		return HorizontalGroup:new{
			align = "top",
			accent,
			HorizontalSpan:new{width = dimen_.line_clearance},
			wgt,
		}
	end

	--HIGHLIGHT / FALLBACK QUOTE WIDGET
	local highlight_widget
	local remaining_h = max_height - title_dimen.h - stats_dimen.h

	if highlightEnabled then 
		local idx = pickRandom(
						highlights_list, 
						highlightKey, 
						recent_highlight_keys, 
						HL_SETT.no_repeat_window
		)
		local chosen = highlights_list[idx]
		local random_highlight = util.trim(chosen.text or "")
		if HL_SETT.add_quotations then
			random_highlight = addQuotesIfReq(random_highlight)
		end

		local hl_footer_widget
		if hl_footer_enabled then
			local hyphen_wid = buildTextField(
									"— ", 
									font_.footer_font,
									max_height, 
									max_wid, 
									true, 
									false, 
									footer_color
			)						
			local footer_text = buildTextField(
									parseFooterText(HL_SETT.hl_footer_text, chosen, doc_settings), 
									font_.footer_font, 
									remaining_h, 
									max_wid - hyphen_wid:getSize().w, 
									false, 
									false, 
									footer_color
			)						
			hl_footer_widget = VerticalGroup:new{
								VerticalSpan:new{width = dimen_.footer_clearance},
								HorizontalGroup:new{
									align = "top",
									hyphen_wid,
									footer_text,
								},
			}
		end

		local hl_wgt_max_h = hl_footer_widget and 
						(remaining_h - hl_footer_widget:getSize().h) or remaining_h
		highlight_widget = withAccent(buildTextField(
								random_highlight, 
								font_.highlight_font, 
								hl_wgt_max_h, 
								max_wid,
								true, 
								true
		))

		if hl_footer_widget then
			highlight_widget = VerticalGroup:new{
					align = "left",
					highlight_widget,
					hl_footer_widget,
			}
		end
	elseif quoteEnabled then
		--fallback: random quote from txt file. no footer, no re-wrapping in
		--quote marks since lines in the file are expected to already be
		--formatted the way you want them shown (e.g. “Blah blah blah” - Quoter)
		local idx = pickRandom(
						quotes_list, 
						quoteKey, 
						recent_quote_keys, 
						QUOTE_SETT.no_repeat_window
		)
		highlight_widget = withAccent(buildTextField(
								quotes_list[idx], 
								font_.highlight_font, 
								remaining_h, 
								max_wid,
								true, 
								true
		))
	end

	local content_widget = VerticalGroup:new{
		align = "left",
		title_widget,
		stats_widget,			
	}

	if highlight_widget then
		table.insert(content_widget, VerticalSpan:new{width = dimen_.hl_wgt_clearance})
		table.insert(content_widget, highlight_widget)
	end

	return FrameContainer:new{                
		background = B_SETT.background == 0 and Bb.COLOR_WHITE or Bb.COLOR_BLACK,
		color = B_SETT.border_color == 0 and Bb.COLOR_WHITE or Bb.COLOR_BLACK,
		margin = dimen_.margin,
		bordersize = dimen_.border_size,
		padding = dimen_.padding,
		content_widget,
	}
end

local og_uiMan_show = UIManager.show

function UIManager:show(widget, ...)
	-- if widget isn't 'screensaver' or if wallpaper type
	-- isn't 'book cover' or 'custom image' or if sleep screen message type
	-- isn't 'banner', we do not intercept. 
	if not shouldIntercept(widget) then
		return og_uiMan_show(self, widget, ...)
	end

	local ok, banner = pcall(buildBanner, widget)
	if ok and banner then
		-- only now is it safe to drop the stock banner and swap ours in
		local cus_pos_container = widget[1][1][2]
		cus_pos_container.widget:free()
		cus_pos_container.horizontal_position = 0	-- pin to the left edge (Kobo look);
													-- 0 is left in both 0-1 and 0-100 scales
		cus_pos_container.widget = banner
	elseif not ok then
		logger.warn(TAG, "banner build failed, showing stock banner:", banner)
	end	-- ok but nil = nothing to show (no book yet), stock banner silently

	return og_uiMan_show(self, widget, ...)
end
