-- Lake drawings for Reading Log, by BrownTigerz: a lake in a round window for the rings.
-- The water rises with your pages, the sun climbs over the pines with
-- your minutes, and a paddleboarder heads out once both are done (a loon
-- swims by while you keep a streak). Lily pads that flower for the days,
-- pines for the bar charts, a canoe rack for the year goal, a paddleboard
-- crossing to an island for the Monthly challenge, a paddleboard riding
-- the progress bars, a fish jumping for each reading session, and water
-- along the foot of the covers.
local floor, max, min, sqrt, sin, cos, pi = math.floor, math.max, math.min, math.sqrt, math.sin, math.cos, math.pi

local SKY      = { 187, 221, 255 }
local SKY_D    = { 119, 187, 238 }
local WATER    = { 34, 119, 204 }
local WATER_L  = { 102, 170, 238 }
local WATER_D  = { 17, 68, 136 }
local SAND     = { 238, 221, 187 }
local SAND_D   = { 204, 170, 119 }
local PINE     = { 34, 119, 68 }
local PINE_D   = { 17, 68, 51 }
local PINE_L   = { 85, 170, 102 }
local WOOD     = { 136, 85, 51 }
local WOOD_L   = { 187, 136, 85 }
local SUN      = { 255, 187, 34 }
local SUN_L    = { 255, 238, 153 }
local BOARD    = { 238, 102, 34 }
local LILY     = { 68, 153, 68 }
local PINK     = { 238, 119, 170 }
local LOON     = { 34, 34, 34 }
local FISH     = { 238, 136, 51 }
local WHITE    = { 255, 255, 255 }
local RED      = { 204, 51, 51 }
local CANOES   = { { 204, 51, 51 }, { 238, 136, 34 }, { 34, 136, 85 }, { 238, 187, 34 }, { 34, 119, 187 } }

local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function clamp01(v) return max(0, min(1, v or 0)) end
local function step(size) return max(1, floor(size / 22)) end

-- shapes from thin rows (the canvas has rectangles, discs, rings and lines)

-- the part of a circle between two heights
local function band(c, cx, cy, r, ya, yb, col)
    local s = step(r)
    local y0 = floor(max(ya, cy - r))
    local y1 = min(yb, cy + r)
    local yy = y0
    while yy < y1 do
        local h = min(s, y1 - yy)
        local dy = yy + h / 2 - cy
        local half = sqrt(max(0, r * r - dy * dy))
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- a triangle pointing up: apex at (cx, top), base half-width hw at bottom
local function tri(c, cx, top, bottom, hw, col)
    local hgt = bottom - top
    if hgt < 1 then return end
    local s = step(hgt)
    local yy = top
    while yy < bottom do
        local h = min(s, bottom - yy)
        local half = hw * ((yy + h - top) / hgt)
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- an ellipse
local function oval(c, cx, cy, rx, ry, col)
    if ry < 1 or rx < 1 then return end
    local s = step(ry * 2)
    local yy = cy - ry
    while yy < cy + ry do
        local h = min(s, cy + ry - yy)
        local dy = (yy + h / 2 - cy) / ry
        local half = rx * sqrt(max(0, 1 - dy * dy))
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- a wavy line
local function wave(c, x0, x1, y, amp, col, lw, n)
    n = n or max(2, floor((x1 - x0) / max(6, amp * 10)))
    local pts = {}
    local k = max(8, n * 6)
    for i = 0, k do
        local f = i / k
        pts[#pts + 1] = x0 + (x1 - x0) * f
        pts[#pts + 1] = y + amp * sin(f * pi * 2 * n)
    end
    c:polyline(pts, lw, col)
end

-- a pine: a trunk and three tiers
local function pine(c, x, base, h, col, dark)
    local w = h * 0.36
    c:rect(floor(x - max(1, h * 0.035)), floor(base - h * 0.14), max(2, floor(h * 0.07)), max(1, floor(h * 0.14)), WOOD)
    tri(c, x, base - h * 0.62, base - h * 0.12, w, dark or col)
    tri(c, x, base - h * 0.84, base - h * 0.4, w * 0.78, col)
    tri(c, x, base - h, base - h * 0.64, w * 0.56, col)
end

-- a paddleboarder: board, person, paddle (x, y: the middle of the board)
local function paddler(c, x, y, s)
    local lw = max(1, s * 0.09)
    c:rrect(floor(x - s * 0.75), floor(y - s * 0.08), max(4, floor(s * 1.5)), max(2, floor(s * 0.18)), s * 0.09, BOARD)
    c:polyline({ x - s * 0.15, y - s * 0.08, x, y - s * 0.45, x + s * 0.15, y - s * 0.08 }, lw, PINE_D)
    c:polyline({ x, y - s * 0.45, x, y - s * 0.9 }, max(1, s * 0.13), RED)
    c:disc(x, y - s * 1.02, max(1.5, s * 0.13), WOOD_L)
    c:polyline({ x + s * 0.35, y - s * 1.0, x - s * 0.1, y + s * 0.15 }, lw, WOOD)
    c:polyline({ x - s * 0.95, y + s * 0.05, x - s * 0.6, y + s * 0.05 }, lw, WHITE)
end

-- a loon: a dark body, a white-dotted back, a head
local function loon(c, x, y, s)
    oval(c, x, y, s * 0.55, s * 0.22, LOON)
    c:disc(x + s * 0.45, y - s * 0.28, max(1.5, s * 0.16), LOON)
    c:polyline({ x + s * 0.55, y - s * 0.28, x + s * 0.78, y - s * 0.24 }, max(1, s * 0.07), LOON)
    c:disc(x - s * 0.1, y - s * 0.06, max(1, s * 0.05), WHITE)
    c:disc(x + s * 0.12, y - s * 0.07, max(1, s * 0.05), WHITE)
end

-- a fish leaping, head up
local function fish(c, x, y, s)
    oval(c, x, y, s * 0.22, s * 0.42, FISH)
    c:polyline({ x - s * 0.2, y + s * 0.62, x, y + s * 0.38, x + s * 0.2, y + s * 0.62 }, max(1, s * 0.12), FISH)
    c:disc(x + s * 0.05, y - s * 0.2, max(1, s * 0.06), WHITE)
end

-- a lily pad: a disc with a notch; flowering pink when full
local function lilypad(c, cx, cy, r, col, bg)
    c:disc(cx, cy, r, col)
    c:polyline({ cx, cy, cx + r * 0.9, cy - r * 0.45 }, max(1, r * 0.22), bg)
    c:polyline({ cx, cy, cx + r * 0.6, cy + r * 0.5 }, max(1, r * 0.08), mix(col, WHITE, 0.25))
end

local function lily(c, cx, cy, r)
    for k = 0, 5 do
        local a = k * pi / 3
        c:disc(cx + r * 0.55 * cos(a), cy + r * 0.55 * sin(a), r * 0.42, PINK)
    end
    c:disc(cx, cy, r * 0.32, SUN)
end

-- a square box with its bottom-right corner clipped off (the Cyber finish)
local function cutbox(c, x, y, w, h, k, col)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    k = floor(min(k, w / 2, h / 2))
    if w < 2 or h < 2 then return end
    if k < 2 then c:rect(x, y, w, h, col) return end
    c:rect(x, y, w, h - k, col)
    local s = max(1, floor(k / 8))
    local yy = 0
    while yy < k do
        local hh = min(s, k - yy)
        c:rect(x, y + h - k + yy, max(1, w - floor(yy + hh / 2)), hh, col)
        yy = yy + s
    end
end

-- a clipped box with an edge in another colour
local function cutframe(c, x, y, w, h, k, lw, edge, fill)
    cutbox(c, x, y, w, h, k, edge)
    cutbox(c, x + lw, y + lw, w - 2 * lw, h - 2 * lw, max(0, k - lw * 0.6), fill)
end

local D = {}

-- ─── rings: a lake in a round window ───────────────────────────────────────
-- Reading Log draws a set of rings outer first at one centre: the pages
-- call draws the window, the sky and the water (it rises with the pages);
-- the minutes call puts the sun up over the pines; the last call (the
-- streak) sends a loon across. A ring on its own is drawn as usual.

local tri_state

local function lakeWindow(c, cx, cy, R, f1, tone)
    local horizon = cy + R * 0.12
    band(c, cx, cy, R, cy - R, horizon, SKY)
    band(c, cx, cy, R, cy - R, cy - R * 0.55, mix(SKY, SKY_D, 0.45))
    -- the lake bed, then the water up to the pages level
    band(c, cx, cy, R, horizon, cy + R, SAND)
    local level = (cy + R) - (cy + R - horizon) * f1
    if f1 > 0 then
        band(c, cx, cy, R, level, cy + R, WATER)
        band(c, cx, cy, R, level, level + R * 0.06, WATER_L)
        local hw = sqrt(max(0, R * R - (level - cy) ^ 2))
        if hw > R * 0.2 then wave(c, cx - hw * 0.8, cx + hw * 0.8, level + R * 0.14, R * 0.015, WATER_L, max(1, R * 0.015), 4) end
    end
    return horizon, level
end

local function shore(c, cx, cy, R, horizon)
    -- far shore: a band of pines, tall in the middle
    local hw = sqrt(max(0, R * R - (horizon - cy) ^ 2))
    c:rect(floor(cx - hw), floor(horizon - R * 0.04), floor(2 * hw), max(2, floor(R * 0.06)), PINE_D)
    local n = 9
    for k = 0, n - 1 do
        local f = (k + 0.5) / n
        local px = cx - hw * 0.92 + 2 * hw * 0.92 * f
        local h = R * (0.22 + 0.16 * sin(f * pi) + 0.05 * ((k % 2 == 0) and 1 or -1))
        pine(c, px, horizon, h, (k % 2 == 0) and PINE or PINE_L, PINE_D)
    end
end

function D.ring(c, cx, cy, R, t, frac, track, fill, tone, which)
    frac = clamp01(frac)
    if which == 1 then
        if R < 22 then
            -- small: a pond filling up
            c:disc(cx, cy, R, SAND)
            if frac > 0 then band(c, cx, cy, R, cy + R - 2 * R * frac, cy + R, WATER) end
            c:ring(cx, cy, R, max(1, R * 0.12), 1, PINE, PINE)
            return true
        end
        tri_state = { c = c, cx = cx, cy = cy, R = R, f1 = frac }
        local horizon = lakeWindow(c, cx, cy, R, frac, tone)
        tri_state.horizon = horizon
        shore(c, cx, cy, R, horizon)
        c:ring(cx, cy, R, max(2, R * 0.05), 1, WOOD, WOOD)
        c:ring(cx, cy, R * 0.95, max(1, R * 0.015), 1, WOOD_L, WOOD_L)
        return true
    end
    local st = tri_state
    if not (st and st.c == c and st.cx == cx and st.cy == cy) then return false end
    if which == 2 then
        st.f2 = frac
        local Rr, horizon = st.R, st.horizon
        if frac > 0 then
            -- the sun climbs from the left of the treeline to the top
            local a = pi - pi * 0.5 * frac
            local sx = cx + Rr * 0.55 * cos(a)
            local sy = horizon - Rr * 0.12 - (Rr * 0.6) * sin(pi * 0.5 * frac) - Rr * 0.05
            local sr = Rr * 0.13
            c:disc(sx, sy, sr * 1.6, mix(SUN_L, SKY, 0.4))
            c:disc(sx, sy, sr * 1.3, SUN_L)
            c:disc(sx, sy, sr, SUN)
            shore(c, cx, cy, Rr, horizon)
        end
        if (st.f1 or 0) >= 1 and frac >= 1 then
            paddler(c, cx + Rr * 0.12, horizon + Rr * 0.32, Rr * 0.3)
        end
        return true
    end
    -- the streak: a loon swims by while the streak lasts
    if frac > 0 and (st.f1 or 0) > 0.3 then
        local level = (cy + st.R) - (cy + st.R - st.horizon) * (st.f1 or 0)
        loon(c, cx - st.R * 0.45, max(level, st.horizon) + st.R * 0.2, st.R * 0.22)
    end
    tri_state = nil
    return true
end

-- ─── a day: a lily pad that flowers ────────────────────────────────────────
-- The pad greens with the day's pages; the lily opens on the page goal and
-- a dragonfly stops by on the minutes goal. Days to come: a faint ripple.

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local r = d * 0.34
    if o.future then
        c:ring(cx, cy, r * 0.9, max(1, d * 0.03), 1, mix(WATER_L, tone.bg, 0.6), mix(WATER_L, tone.bg, 0.6))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    wave(c, cx - r * 1.2, cx + r * 1.2, cy + r * 0.95, d * 0.02, mix(WATER, tone.bg, 0.35), max(1, d * 0.03), 2)
    local pad = (fp > 0) and mix(mix(LILY, tone.bg, 0.55), LILY, fp) or mix(LILY, tone.bg, 0.65)
    lilypad(c, cx, cy, r, pad, tone.bg)
    if fp >= 1 then
        lily(c, cx - r * 0.2, cy - r * 0.15, r * 0.62)
    elseif fp > 0.05 then
        c:disc(cx - r * 0.2, cy - r * 0.15, r * 0.18 + r * 0.2 * fp, PINK)
    end
    if fm >= 1 then
        local dx, dy = cx + r * 0.95, cy - r * 0.95
        c:polyline({ dx - r * 0.4, dy, dx + r * 0.4, dy }, max(1, d * 0.05), WATER)
        c:disc(dx - r * 0.05, dy - r * 0.12, max(1, d * 0.05), mix(WATER_L, WHITE, 0.4))
        c:disc(dx + r * 0.12, dy - r * 0.12, max(1, d * 0.05), mix(WATER_L, WHITE, 0.4))
    end
    if o.today then c:ring(cx, cy, d * 0.47, max(1.5, d * 0.045), 1, WATER, WATER) end
    return true
end

-- ─── the year goal: a canoe rack ────────────────────────────────────────────
-- A canoe for every book on the rack (past 24, each stands for a few); the
-- ones still to read are empty slots.

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cols = max(1, floor((n + 3) / 4))
    local rows = max(1, floor((n + cols - 1) / cols))
    local px0, px1 = x + w * 0.04, x + w * 0.96
    local cw = (px1 - px0) / cols
    local top, bot = y + h * 0.08, y + h * 0.94
    local rh = (bot - top) / rows
    local post = max(2, floor(w * 0.018))
    -- posts and rails
    for k = 0, cols do
        c:rect(floor(px0 + cw * k - post / 2), floor(top), post, floor(bot - top), WOOD)
    end
    local i = 0
    for r = 0, rows - 1 do
        local ry = top + rh * (r + 0.72)
        c:rect(floor(px0), floor(ry), floor(px1 - px0), max(2, floor(rh * 0.08)), WOOD_L)
        for k = 0, cols - 1 do
            i = i + 1
            if i <= n then
                local ccx = px0 + cw * (k + 0.5)
                local hw, hh = cw * 0.4, max(2, rh * 0.22)
                if i <= lit then
                    local col = CANOES[(i - 1) % #CANOES + 1]
                    oval(c, ccx, ry - hh * 0.95, hw, hh, col)
                    c:rect(floor(ccx - hw * 0.8), floor(ry - hh * 1.05), floor(hw * 1.6), max(1, floor(hh * 0.25)), mix(col, LOON, 0.35))
                else
                    c:polyline({ ccx - hw * 0.8, ry - hh * 0.4, ccx + hw * 0.8, ry - hh * 0.4 }, max(1, hh * 0.18), mix(tone.track, tone.bg, 0.2))
                end
            end
        end
    end
    return true
end

-- ─── the challenge: a paddleboard crossing to an island ─────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local wy = cy + R * 0.12
    -- a round window: sky, sun, water
    band(c, cx, cy, R, cy - R, wy, SKY)
    band(c, cx, cy, R, cy - R, cy - R * 0.5, mix(SKY, SKY_D, 0.45))
    c:disc(cx - R * 0.45, cy - R * 0.45, R * 0.2, SUN_L)
    c:disc(cx - R * 0.45, cy - R * 0.45, R * 0.14, SUN)
    band(c, cx, cy, R, wy, cy + R, WATER)
    band(c, cx, cy, R, wy, wy + R * 0.06, WATER_L)
    wave(c, cx - R * 0.6, cx + R * 0.1, wy + R * 0.42, R * 0.025, WATER_L, max(1, R * 0.03), 3)
    -- the island: sand, pines and a dock
    local ix = cx + R * 0.48
    band(c, ix, wy + R * 0.14, R * 0.4, wy - R * 0.22, wy + R * 0.02, SAND_D)
    pine(c, ix - R * 0.06, wy - R * 0.06, R * 0.62, PINE, PINE_D)
    pine(c, ix + R * 0.2, wy - R * 0.04, R * 0.42, PINE_L, PINE_D)
    c:rect(floor(ix - R * 0.6), floor(wy - R * 0.02), floor(R * 0.3), max(2, floor(R * 0.05)), WOOD)
    c:rect(floor(ix - R * 0.58), floor(wy), max(1, floor(R * 0.03)), floor(R * 0.12), WOOD)
    -- the board, from the left shore to the dock
    local bx = cx - R * 0.62 + (R * 0.82) * frac
    local by = wy + R * 0.2 - R * 0.12 * frac
    if frac > 0.02 then
        wave(c, max(cx - R * 0.85, bx - R * 0.55), bx - R * 0.28, by + R * 0.05, R * 0.02, WHITE, max(1, R * 0.025), 2)
    end
    paddler(c, bx, by, R * 0.34)
    if frac >= 1 then
        c:polyline({ ix + R * 0.36, wy - R * 0.06, ix + R * 0.36, wy - R * 0.5 }, max(1, R * 0.03), WOOD)
        tri(c, ix + R * 0.46, wy - R * 0.5, wy - R * 0.34, R * 0.07, RED)
    end
    c:ring(cx, cy, R, max(2, R * 0.05), 1, WOOD, WOOD)
    return true
end

-- ─── progress bars: a paddleboard riding the water ──────────────────────────

function D.bar(c, x, y, w, h, frac, tone, fill)
    frac = clamp01(frac)
    c:rect(floor(x), floor(y), floor(w), floor(h), mix(WATER_L, tone.bg, 0.6))
    if frac > 0 then
        cutbox(c, x, y, max(h, floor(w * frac + 0.5)), h, h * 0.45, fill or WATER)
        if w * frac > h * 3 then
            wave(c, x + h * 0.5, x + w * frac - h * 1.2, y + h * 0.5, h * 0.12, mix(fill or WATER, WHITE, 0.45), max(1, h * 0.14), max(2, floor(w * frac / (h * 3))))
        end
    end
    if h >= 6 then
        local bx = x + max(h * 0.8, min(w - h * 0.8, w * frac))
        c:rrect(floor(bx - h * 0.8), floor(y - h * 0.3), max(4, floor(h * 1.6)), max(2, floor(h * 0.35)), h * 0.17, BOARD)
        c:disc(bx, y - h * 0.7, max(1.5, h * 0.22), RED)
    end
    return true
end

-- ─── bar charts: pines ──────────────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 4 then return false end
    local cx = x + w / 2
    local base = y + h
    local tw = w * 0.5
    c:rect(floor(cx - max(1, w * 0.07)), floor(base - h * 0.12), max(2, floor(w * 0.14)), max(1, floor(h * 0.12)), WOOD)
    local col = o.current and PINE_L or PINE
    -- tiers stacked up the whole height
    local tiers = max(2, min(5, floor(h / (w * 0.7))))
    local th = (h * 0.9) / tiers
    for k = 0, tiers - 1 do
        local tb = base - h * 0.1 - th * k
        local hw = tw * (1 - 0.45 * k / tiers)
        tri(c, cx, tb - th * 1.35, tb, hw, (k % 2 == 0) and col or mix(col, PINE_D, 0.35))
    end
    if o.current then
        c:disc(cx, y - w * 0.35, max(2, w * 0.24), SUN_L)
        c:disc(cx, y - w * 0.35, max(1.5, w * 0.17), SUN)
    end
    return true
end

-- ─── lines: a shoreline with a ripple at every point ────────────────────────

function D.line(c, pts, xs, ys, n, lw, fill, tone, o)
    c:polyline(pts, max(1.5, lw), fill or WATER)
    for i = 1, n do
        c:disc(xs[i], ys[i], max(2, lw * 1.4), fill or WATER)
        c:disc(xs[i], ys[i], max(1, lw * 0.6), WHITE)
    end
    return true
end

-- ─── Today's timeline: a fish jumps for every reading session ───────────────

function D.timeline(c, x, y, w, h, spans, now, tone)
    local my = y + h * 0.62
    c:rect(floor(x), floor(my - h * 0.12), floor(w), max(2, floor(h * 0.24)), mix(WATER_L, tone.bg, 0.55))
    for si = 1, #spans do
        local s = spans[si]
        local a, b = x + w * clamp01(s[1]), x + w * clamp01(s[2])
        c:rect(floor(a), floor(my - h * 0.12), max(2, floor(b - a)), max(2, floor(h * 0.24)), s[3] or WATER)
        local fx = (a + b) / 2
        local fs = max(5, h * 1.1)
        fish(c, fx, my - fs * 0.55, fs * 0.6)
        c:disc(fx - fs * 0.3, my - fs * 0.15, max(1, fs * 0.06), WATER_L)
        c:disc(fx + fs * 0.32, my - fs * 0.25, max(1, fs * 0.05), WATER_L)
    end
    if now then
        local nx = x + w * now
        c:disc(nx, y + h * 0.15, max(2, h * 0.16), SUN)
        c:polyline({ nx, y + h * 0.32, nx, my - h * 0.14 }, max(1, h * 0.04), mix(SUN, tone.bg, 0.3))
    end
    return true
end

-- ─── Reading trends: a tile with water at the foot, a round badge ───────────

function D.trendTile(c, x, y, w, h, tone, i)
    cutbox(c, x, y, w, h, min(h * 0.18, 14), mix(tone.bg, SKY, 0.35))
    c:rect(floor(x + h * 0.1), floor(y + h * 0.82), floor(w - h * 0.2), max(2, floor(h * 0.1)), mix(WATER_L, tone.bg, 0.45))
    return true
end

function D.trendBadge(c, cx, cy, r, dir, tone, fill)
    local col = (dir == "up") and PINE or ((dir == "down") and RED or WATER)
    c:disc(cx, cy, r, col)
    local a = r * 0.42
    local lw = max(1.5, r * 0.18)
    if dir == "up" then
        c:polyline({ cx - a, cy + a * 0.45, cx, cy - a * 0.5, cx + a, cy + a * 0.45 }, lw, WHITE)
    elseif dir == "down" then
        c:polyline({ cx - a, cy - a * 0.45, cx, cy + a * 0.5, cx + a, cy - a * 0.45 }, lw, WHITE)
    else
        wave(c, cx - a, cx + a, cy, a * 0.18, WHITE, lw, 1)
    end
    return true
end

-- ─── the calendar: a tile with a ripple; a lily pad for today ───────────────

function D.calendarEmpty(c, x, y, w, h, n, tone, o)
    local m = max(2, floor(min(w, h) * 0.07))
    local dw, dh = w - 2 * m, h - 2 * m
    if dw < 6 or dh < 6 then return false end
    local fillcol = o.future and mix(tone.bg, tone.track, 0.15) or mix(tone.bg, SKY, 0.35)
    cutframe(c, x + m, y + m, dw, dh, max(2, floor(min(dw, dh) * 0.18)), max(1, floor(min(dw, dh) * 0.04)), o.future and mix(WATER_L, tone.bg, 0.5) or WATER_L, fillcol)
    if not o.future and dw > 14 then
        wave(c, x + m + dw * 0.15, x + m + dw * 0.85, y + m + dh * 0.84, dh * 0.03, mix(WATER, tone.bg, 0.4), max(1, dh * 0.03), 2)
    end
    local size = o.num_px or max(10, floor(dh * 0.4))
    c:label(tostring(n), size, x + w / 2, y + h * 0.46, { bold = true, anchor = "c", valign = "mid", color = o.future and tone.muted or tone.fg })
    if o.today then lilypad(c, x + w - m - dw * 0.18, y + m + dh * 0.18, max(2, dw * 0.12), LILY, fillcol) end
    return true
end

-- ─── covers: water along the foot, a paddleboard as far as you've read ──────

local function coverWater(c, x, y, w, h, pct)
    local wh = max(3, h * 0.12)
    local wy = y + h - wh
    c:rect(floor(x), floor(wy), floor(w), floor(wh), mix(WATER, LOON, 0.1))
    wave(c, x, x + w, wy, max(1, wh * 0.12), WATER_L, max(1, wh * 0.16), max(2, floor(w / (wh * 2.5))))
    if pct and pct > 0 and w >= 20 then
        local bx = x + w * 0.12 + w * 0.76 * clamp01(pct)
        c:rrect(floor(bx - w * 0.1), floor(wy - wh * 0.15), max(3, floor(w * 0.2)), max(2, floor(wh * 0.25)), wh * 0.12, BOARD)
    end
end

function D.bookCover(c, x, y, w, h, tone, o)
    coverWater(c, x, y, w, h, o and o.pct)
    return true
end

function D.calendarCover(c, x, y, w, h, tone, o)
    coverWater(c, x, y, w, h, nil)
    if o and o.today and w >= 12 then
        c:disc(x + w * 0.8, y + h * 0.14, max(2, w * 0.1), SUN)
    end
    return true
end

-- ─── the Dashboard's tab bar: a canoe for the open tab, pines and water ─────

-- Night mode: Reading Log paints the cards pre-inverted, but the tab row
-- sits on the page canvas, where only Reading Log's own colours are
-- pre-inverted. A style can't ask whether it's night, but it can tell: the
-- page colour it's given is the inverted one while `dark` still describes
-- the real page. Then everything here is pre-inverted too, so the open tab
-- and its name come out in their real colours.
local function nightRow(tone)
    local bg = tone and tone.bg
    if type(bg) ~= "table" then return false end
    local l = 0.299 * bg[1] + 0.587 * bg[2] + 0.114 * bg[3]
    return (tone.dark and l >= 128) or ((not tone.dark) and l < 128)
end
local function flip(col) return { 255 - col[1], 255 - col[2], 255 - col[3] } end
local function nightCanvas(c)
    local n = {}
    function n:rect(x, y, w, h, col) return c:rect(x, y, w, h, flip(col)) end
    function n:rrect(x, y, w, h, r, col) return c:rrect(x, y, w, h, r, flip(col)) end
    function n:frame(x, y, w, h, r, bw, border, fill) return c:frame(x, y, w, h, r, bw, flip(border), fill and flip(fill) or nil) end
    function n:disc(x, y, r, col) return c:disc(x, y, r, flip(col)) end
    function n:ring(x, y, R, t, frac, track, fill) return c:ring(x, y, R, t, frac, flip(track), flip(fill)) end
    function n:polyline(pts, lw, col) return c:polyline(pts, lw, flip(col)) end
    return n
end

function D.tabBar(c, x, y, w, h, cells, tone)
    local night = nightRow(tone)
    if night then
        c = nightCanvas(c)
        local real = {}
        for k, v in pairs(tone) do real[k] = v end
        real.bg = flip(tone.bg)
        tone = real
    end
    local wy = y + h * 0.9
    wave(c, x, x + w, wy, h * 0.04, tone.dark and WATER_L or WATER, max(2, floor(h * 0.05 + 0.5)), max(4, floor(w / (h * 1.2))))
    pine(c, x + h * 0.25, wy - h * 0.05, h * 0.62, PINE, PINE_D)
    for ci = 1, #cells do
        local cell = cells[ci]
        if cell.active then
            local cx = cell.x + cell.w / 2
            local pw = min(cell.w - 6, cell.label_w + h * 0.7)
            local ph = h * 0.58
            cutframe(c, cx - pw / 2, y + h * 0.47 - ph / 2, pw, ph, ph * 0.32, max(2, floor(ph * 0.08)), WHITE, CANOES[1])
            cell.color = night and flip(WHITE) or WHITE
            cell.dy = h * 0.02
        end
    end
    return true
end

return D
