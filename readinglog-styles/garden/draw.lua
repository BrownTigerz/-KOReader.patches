-- Garden drawings for Reading Log, by BrownTigerz. A raised garden bed for
-- the rings: tomatoes, carrots and lettuce grow with your pages, the
-- watering can pours with your minutes and a butterfly visits when both are
-- done. Seeds that sprout for the days, carrots for the bar charts, a
-- harvest crate for the year goal and a wheelbarrow full of vegetables for
-- the challenge.
local floor, max, min, sqrt, sin, cos, pi, abs = math.floor, math.max, math.min, math.sqrt, math.sin, math.cos, math.pi, math.abs

local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function clamp01(v) return max(0, min(1, v or 0)) end
local function step(size) return max(1, floor(size / 22)) end

-- ─── shapes from thin rows (the canvas has rects, discs, rings and lines) ──

-- the part of a circle between two heights
local function band(c, cx, cy, r, ya, yb, col)
    local s = step(r)
    local y1 = min(yb, cy + r)
    local yy = floor(max(ya, cy - r))
    while yy < y1 do
        local h = min(s, y1 - yy)
        local dy = yy + h / 2 - cy
        local half = sqrt(max(0, r * r - dy * dy))
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- a rectangle kept inside a circle (for scenes in a round window)
local function crect(c, cx, cy, r, x0, y0, x1, y1, col)
    local s = step(r)
    local yy = floor(max(y0, cy - r))
    local ye = min(y1, cy + r)
    while yy < ye do
        local h = min(s, ye - yy)
        local dy = yy + h / 2 - cy
        local half = sqrt(max(0, r * r - dy * dy))
        local a, b = max(x0, cx - half), min(x1, cx + half)
        if b - a > 0.4 then c:rect(floor(a + 0.5), floor(yy), max(1, floor(b - a + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- a triangle, apex at top (or at the bottom with flip): base half-width hw
local function tri(c, cx, top, bottom, hw, col, flip)
    local hgt = bottom - top
    if hgt < 1 then return end
    local s = step(hgt)
    local yy = top
    while yy < bottom do
        local h = min(s, bottom - yy)
        local f = (yy + h / 2 - top) / hgt
        if flip then f = 1 - f end
        local half = hw * f
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- a trapezoid: half-widths at top and bottom
local function trap(c, cx, top, bottom, hwt, hwb, col)
    local hgt = bottom - top
    if hgt < 1 then return end
    local s = step(hgt)
    local yy = top
    while yy < bottom do
        local h = min(s, bottom - yy)
        local f = (yy + h / 2 - top) / hgt
        local half = hwt + (hwb - hwt) * f
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(h + 0.5)), col) end
        yy = yy + s
    end
end

-- an ellipse (or the part of it between two heights)
local function oval(c, cx, cy, rx, ry, col, ya, yb)
    if ry < 0.5 or rx < 0.5 then return end
    local s = step(ry * 2)
    local yy = max(cy - ry, ya or (cy - ry))
    local y1 = min(cy + ry, yb or (cy + ry))
    while yy < y1 do
        local h = min(s, y1 - yy)
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
    c:polyline(pts, max(1, lw), col)
end

-- a star with n points (thick spokes and a middle)
local function star(c, cx, cy, r, col, n, turn)
    n = n or 5
    turn = turn or -pi / 2
    for k = 0, n - 1 do
        local a = turn + k * 2 * pi / n
        c:polyline({ cx, cy, cx + r * cos(a), cy + r * sin(a) }, max(1, r * 0.34), col)
    end
    c:disc(cx, cy, max(1, r * 0.42), col)
end

-- a heart (two lobes and a point)
local function heart(c, cx, cy, s, col)
    local r = s * 0.27
    c:disc(cx - r * 0.95, cy - s * 0.12, r, col)
    c:disc(cx + r * 0.95, cy - s * 0.12, r, col)
    tri(c, cx, cy - s * 0.12, cy + s * 0.5, r * 1.95, col, true)
end

-- a burst of lines (fireworks, sun rays, sparkles)
local function burst(c, cx, cy, r0, r1, n, col, lw, turn)
    turn = turn or 0
    for k = 0, n - 1 do
        local a = turn + k * 2 * pi / n
        c:polyline({ cx + r0 * cos(a), cy + r0 * sin(a), cx + r1 * cos(a), cy + r1 * sin(a) }, max(1, lw), col)
    end
end

-- an arc as a line (from angle a0 to a1, 0 = right, clockwise on screen)
local function arc(c, cx, cy, r, a0, a1, col, lw)
    local n = max(6, floor(abs(a1 - a0) * r / 6))
    local pts = {}
    for i = 0, n do
        local a = a0 + (a1 - a0) * i / n
        pts[#pts + 1] = cx + r * cos(a)
        pts[#pts + 1] = cy + r * sin(a)
    end
    c:polyline(pts, max(1, lw), col)
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

local SKY    = { 204, 238, 255 }
local SOIL   = { 119, 85, 51 }
local SOIL_D = { 85, 51, 34 }
local WOOD   = { 187, 136, 85 }
local WOOD_D = { 136, 85, 51 }
local LEAF   = { 68, 153, 51 }
local LEAF_L = { 136, 204, 85 }
local TOMATO = { 221, 51, 34 }
local CARROT = { 255, 136, 34 }
local PEA    = { 119, 187, 68 }
local EGG    = { 119, 51, 136 }
local CAN    = { 85, 153, 187 }
local WATER  = { 102, 187, 255 }
local BUTTER = { 255, 204, 51 }
local PICKET = { 255, 255, 238 }
local VEG    = { TOMATO, CARROT, PEA, EGG, BUTTER }

local P = { a = LEAF, b = TOMATO, light = { 221, 255, 204 }, dark = SOIL_D,
    frame = WOOD_D, pill = { 34, 119, 34 }, pill_fg = WHITE, pill_edge = PICKET, good = LEAF, bad = TOMATO }

local function tomato(c, x, y, r)
    c:disc(x, y, r, TOMATO)
    star(c, x, y - r * 0.85, r * 0.45, LEAF, 5, -pi / 2)
    c:disc(x - r * 0.35, y - r * 0.3, r * 0.2, mix(TOMATO, WHITE, 0.4))
end

local function carrot(c, x, top, bottom, w)
    tri(c, x, top, bottom, w, CARROT, true)
    for k = 1, 3 do c:polyline({ x - w * 0.5, top + (bottom - top) * k / 4, x - w * 0.1, top + (bottom - top) * k / 4 }, max(1, w * 0.1), mix(CARROT, SOIL, 0.3)) end
    for k = -1, 1 do c:polyline({ x, top, x + k * w * 0.45, top - w * 1.1 }, max(1, w * 0.22), LEAF) end
end

local function lettuce(c, x, y, r)
    c:disc(x, y, r, LEAF)
    c:disc(x - r * 0.4, y - r * 0.15, r * 0.6, LEAF_L)
    c:disc(x + r * 0.4, y - r * 0.15, r * 0.6, LEAF_L)
    c:disc(x, y - r * 0.4, r * 0.55, mix(LEAF_L, WHITE, 0.3))
end

local function sprout(c, x, base, s)
    c:polyline({ x, base, x, base - s }, max(1, s * 0.12), LEAF)
    oval(c, x - s * 0.25, base - s * 0.9, s * 0.25, s * 0.12, LEAF_L)
    oval(c, x + s * 0.25, base - s * 0.95, s * 0.25, s * 0.12, LEAF)
end

local function ladybug(c, x, y, s)
    c:disc(x, y, s * 0.5, TOMATO)
    c:disc(x + s * 0.45, y, s * 0.22, BLACK)
    c:polyline({ x - s * 0.5, y, x + s * 0.35, y }, max(1, s * 0.06), BLACK)
    c:disc(x - s * 0.15, y - s * 0.22, s * 0.1, BLACK)
    c:disc(x - s * 0.15, y + s * 0.22, s * 0.1, BLACK)
    c:disc(x + s * 0.15, y - s * 0.2, s * 0.08, BLACK)
end

local function butterfly(c, x, y, s)
    c:disc(x - s * 0.3, y - s * 0.15, s * 0.3, CARROT)
    c:disc(x + s * 0.3, y - s * 0.15, s * 0.3, CARROT)
    c:disc(x - s * 0.22, y + s * 0.2, s * 0.2, BUTTER)
    c:disc(x + s * 0.22, y + s * 0.2, s * 0.2, BUTTER)
    c:polyline({ x, y - s * 0.35, x, y + s * 0.35 }, max(1, s * 0.1), SOIL_D)
end

local ICON = function(c, x, y, s, tone) tomato(c, x, y + s * 0.08, s * 0.32) end
local RIDER = function(c, x, y, h, tone) ladybug(c, x, y, h * 1.1) end
local DECOR = function(c, x, y, w, h, tone)
    local n = max(8, floor(w / (h * 0.32)))
    local pw = w / n * 0.55
    c:rect(floor(x), floor(y + h * 0.82), floor(w), max(2, floor(h * 0.06)), PICKET)
    for k = 0, n - 1 do
        local px = x + w * (k + 0.5) / n
        c:rect(floor(px - pw / 2), floor(y + h * 0.72), max(2, floor(pw)), floor(h * 0.28), PICKET)
        tri(c, px, y + h * 0.66, y + h * 0.72, pw / 2, PICKET)
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local sh = max(3, h * 0.09)
    c:rect(floor(x), floor(y + h - sh), floor(w), floor(sh), SOIL)
    sprout(c, x + w * 0.78, y + h - sh, max(4, h * 0.12))
end

-- the scene: a raised bed under the sky, in the round window
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, SKY)
    local soil = cy + R * 0.35
    band(c, cx, cy, R, soil, cy + R, SOIL)
    band(c, cx, cy, R, soil - R * 0.08, soil + R * 0.06, WOOD)
    band(c, cx, cy, R, soil + R * 0.06, soil + R * 0.1, WOOD_D)
    -- tomato stakes and vines rise with the pages, carrots and lettuce fill in
    local g = f1
    for k = -1, 1 do
        local sx = cx + k * R * 0.42
        c:rect(floor(sx - R * 0.015), floor(soil - R * 0.85), max(2, floor(R * 0.03)), floor(R * 0.78), WOOD_D)
        if g > 0 then
            local vh = R * 0.75 * g
            local pts = {}
            for i = 0, 8 do pts[#pts + 1] = sx + R * 0.04 * sin(i * 1.4); pts[#pts + 1] = soil - R * 0.08 - vh * i / 8 end
            c:polyline(pts, max(1.5, R * 0.03), LEAF)
            for i = 1, 3 do
                if i / 3 <= g + 0.01 then oval(c, sx + R * 0.07 * ((i % 2 == 0) and 1 or -1), soil - R * 0.08 - vh * i / 3.4, R * 0.07, R * 0.035, LEAF_L) end
            end
            if g >= 0.6 then tomato(c, sx + R * 0.06, soil - R * 0.08 - vh * 0.55, R * 0.06) end
            if g >= 0.9 then tomato(c, sx - R * 0.07, soil - R * 0.08 - vh * 0.8, R * 0.055) end
        end
    end
    for k = 0, 4 do
        local lx = cx + R * (-0.62 + 0.31 * k)
        if g > 0.2 then
            if k % 2 == 0 then lettuce(c, lx, soil + R * 0.25, R * 0.07 * min(1, g * 1.5))
            else for j = -1, 1 do c:polyline({ lx, soil + R * 0.22, lx + j * R * 0.04, soil + R * (0.22 - 0.12 * min(1, g * 1.5)) }, max(1, R * 0.02), LEAF) end end
        else
            c:disc(lx, soil + R * 0.24, max(1, R * 0.015), SOIL_D)
        end
    end
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    if f2 > 0 then
        -- the watering can, pouring
        local wx, wy = cx + R * 0.52, cy - R * 0.55
        c:rect(floor(wx - R * 0.14), floor(wy - R * 0.1), floor(R * 0.28), floor(R * 0.2), CAN)
        c:polyline({ wx - R * 0.14, wy + R * 0.05, wx - R * 0.32, wy - R * 0.08 }, max(2, R * 0.04), CAN)
        arc(c, wx, wy - R * 0.1, R * 0.1, pi, 2 * pi, CAN, max(1, R * 0.03))
        local n = floor(6 * f2 + 0.5)
        for k = 1, n do
            local dx = wx - R * 0.34 - R * 0.03 * (k % 3)
            local dy = wy - R * 0.02 + R * 0.08 * k
            c:polyline({ dx, dy, dx - R * 0.02, dy + R * 0.05 }, max(1, R * 0.018), WATER)
        end
    end
    if f1 >= 1 and f2 >= 1 then butterfly(c, cx - R * 0.15, cy - R * 0.5, R * 0.2) end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then
        local pts = {}
        for i = 0, 8 do pts[#pts + 1] = cx - R * 0.3 + R * 0.04 * i; pts[#pts + 1] = cy + R * 0.7 + R * 0.025 * sin(i * 1.5) end
        c:polyline(pts, max(2, R * 0.035), { 221, 136, 136 })
    end
end

-- ─── a day: a seed that sprouts with the pages ───────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local base = cy + d * 0.3
    if o.future then
        oval(c, cx, base + d * 0.02, d * 0.3, d * 0.08, mix(SOIL, tone.bg, 0.7))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    oval(c, cx, base + d * 0.04, d * 0.36, d * 0.11, SOIL)
    if fp <= 0.05 then c:disc(cx, base - d * 0.02, max(1.5, d * 0.05), mix(SOIL_D, WOOD, 0.4))
    else sprout(c, cx, base, d * (0.25 + 0.4 * fp)) end
    if fp >= 1 then tomato(c, cx + d * 0.14, base - d * 0.3, d * 0.1) end
    if fm >= 1 then c:disc(cx - d * 0.28, base - d * 0.38, max(1, d * 0.05), WATER) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, LEAF, LEAF) end
    return true
end

-- ─── bar charts: carrots pulled up ───────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 5 or h < 8 then return false end
    local cx = x + w / 2
    carrot(c, cx, y + w * 0.6, y + h, w * 0.48)
    if o.current then butterfly(c, cx + w * 0.3, y - w * 0.15, w * 0.4) end
    return true
end

-- ─── the year goal: a harvest crate, one vegetable per book ──────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cw, ch = min(w * 0.9, h * 2.2), h * 0.5
    local cx0, cy0 = x + (w - cw) / 2, y + h - ch
    local cols = (n <= 8) and 4 or ((n <= 16) and 6 or 8)
    local rows = max(1, floor((n + cols - 1) / cols))
    local slot = cw * 0.92 / cols
    local r = min(slot * 0.42, (h * 0.75) / (rows + 1) * 0.5)
    -- the produce, heaped from the back row down to the crate
    for i = 1, n do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local vx = cx0 + cw * 0.04 + slot * (col + 0.5) + ((row % 2 == 1) and slot * 0.25 or 0)
        local vy = cy0 + r * 0.3 - r * 1.7 * row
        if i <= lit then
            local kind = (i - 1) % #VEG + 1
            if kind == 1 then tomato(c, vx, vy, r)
            elseif kind == 2 then carrot(c, vx, vy - r * 0.6, vy + r * 1.1, r * 0.45)
            elseif kind == 3 then for k = -1, 1 do c:disc(vx + k * r * 0.45, vy, r * 0.32, PEA) end
            elseif kind == 4 then oval(c, vx, vy, r * 0.55, r * 0.9, EGG)
            else c:disc(vx, vy, r * 0.8, BUTTER) end
        else
            c:disc(vx, vy, max(1, r * 0.2), mix(SOIL, tone.bg, 0.65))
        end
    end
    c:rect(floor(cx0), floor(cy0), floor(cw), floor(ch), WOOD)
    for k = 1, 2 do c:rect(floor(cx0), floor(cy0 + ch * k / 3), floor(cw), max(1, floor(ch * 0.06)), WOOD_D) end
    c:rect(floor(cx0), floor(cy0), max(2, floor(cw * 0.04)), floor(ch), WOOD_D)
    c:rect(floor(cx0 + cw * 0.96), floor(cy0), max(2, floor(cw * 0.04)), floor(ch), WOOD_D)
    return true
end

-- ─── the challenge: a wheelbarrow of vegetables heading for the gate ─────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local gy = cy + R * 0.55
    c:rect(floor(cx - R), floor(gy), floor(2 * R), floor(R * 0.28), mix(SOIL, WOOD, 0.4))
    -- the gate at the end
    local gx = cx + R * 0.82
    for k = -1, 1 do
        c:rect(floor(gx + k * R * 0.1 - R * 0.03), floor(gy - R * 0.55), max(2, floor(R * 0.06)), floor(R * 0.55), PICKET)
        tri(c, gx + k * R * 0.1, gy - R * 0.63, gy - R * 0.55, R * 0.03, PICKET)
    end
    c:rect(floor(gx - R * 0.15), floor(gy - R * 0.4), floor(R * 0.3), max(2, floor(R * 0.04)), PICKET)
    -- the barrow
    local bx = cx - R * 0.6 + R * 1.15 * frac
    trap(c, bx, gy - R * 0.45, gy - R * 0.15, R * 0.36, R * 0.22, TOMATO)
    tomato(c, bx - R * 0.15, gy - R * 0.5, R * 0.1)
    lettuce(c, bx + R * 0.1, gy - R * 0.52, R * 0.11)
    carrot(c, bx + R * 0.26, gy - R * 0.55, gy - R * 0.35, R * 0.06)
    c:disc(bx + R * 0.18, gy - R * 0.06, R * 0.1, SOIL_D)
    c:disc(bx + R * 0.18, gy - R * 0.06, R * 0.04, WOOD)
    c:polyline({ bx - R * 0.3, gy - R * 0.25, bx - R * 0.55, gy - R * 0.38 }, max(2, R * 0.04), WOOD_D)
    c:polyline({ bx - R * 0.2, gy - R * 0.15, bx - R * 0.22, gy }, max(2, R * 0.04), WOOD_D)
    if frac >= 1 then butterfly(c, gx - R * 0.2, gy - R * 0.85, R * 0.2) end
    return true
end

-- ─── rings: one scene for a whole set of rings ─────────────────────────────
-- Reading Log draws a set of rings outer first at one centre: pages (1),
-- then minutes (2), then the streak (0) when the card has three. The pages
-- call lays the scene down, the minutes call adds to it (and finishes it
-- when both goals are done), the streak call adds a last touch. A ring on
-- its own (not the first of a set) is left to Reading Log.

local tri_st

if not D.ring then
    function D.ring(c, cx, cy, R, t, frac, track, fill, tone, which)
        frac = clamp01(frac)
        if which == 1 then
            tri_st = { c = c, cx = cx, cy = cy, R = R, f1 = frac, small = R < 22 }
            if R < 22 then
                c:disc(cx, cy, R, mix(P.light, tone.bg, 0.3))
                if frac > 0 then band(c, cx, cy, R, cy + R - 2 * R * frac, cy + R, P.a) end
                c:ring(cx, cy, R, max(1, R * 0.14), 1, P.frame, P.frame)
            else
                S1(c, cx, cy, R, frac, tone)
            end
            return true
        end
        local st = tri_st
        if not (st and st.c == c and st.cx == cx and st.cy == cy) then return false end
        if which == 2 then
            st.f2 = frac
            if st.small then
                if frac > 0 then c:ring(cx, cy, st.R + max(1.5, st.R * 0.22), max(1, st.R * 0.16), frac, mix(P.b, tone.bg, 0.75), P.b) end
            else
                S2(c, cx, cy, st.R, st.f1, frac, tone)
            end
            return true
        end
        if not st.small and S3 then S3(c, cx, cy, st.R, st.f1, st.f2 or 0, frac, tone) end
        tri_st = nil
        return true
    end
end

-- ─── progress bars: a track, the fill, and the style's rider ──────────────

if not D.bar then
    function D.bar(c, x, y, w, h, frac, tone, fill)
        frac = clamp01(frac)
        c:rect(floor(x), floor(y), floor(w), floor(h), mix(P.a, tone.bg, 0.78))
        if frac > 0 then cutbox(c, x, y, max(h, floor(w * frac + 0.5)), h, h * 0.45, P.a) end
        if h >= 6 and RIDER then
            local bx = x + max(h * 0.7, min(w - h * 0.7, w * frac))
            RIDER(c, bx, y + h / 2, h, tone)
        end
        return true
    end
end

-- ─── lines: the line, a dot with a light middle at every point ────────────

if not D.line then
    function D.line(c, pts, xs, ys, n, lw, fill, tone, o)
        local col = (o and o.series == 2) and P.b or (fill or P.a)
        c:polyline(pts, max(1.5, lw), col)
        for i = 1, n do
            c:disc(xs[i], ys[i], max(2, lw * 1.4), col)
            c:disc(xs[i], ys[i], max(1, lw * 0.6), WHITE)
        end
        return true
    end
end

-- ─── Today's timeline: a band, the sessions, the style's mark over each ───

if not D.timeline then
    function D.timeline(c, x, y, w, h, spans, now, tone)
        local my = y + h * 0.62
        local bh = max(2, h * 0.24)
        c:rect(floor(x), floor(my - bh / 2), floor(w), floor(bh), mix(P.light, tone.bg, 0.45))
        for si = 1, #spans do
            local s = spans[si]
            local a, b = x + w * clamp01(s[1]), x + w * clamp01(s[2])
            c:rect(floor(a), floor(my - bh / 2), max(2, floor(b - a)), floor(bh), (si % 2 == 1) and P.a or P.b)
            if ICON and h >= 8 then ICON(c, (a + b) / 2, my - h * 0.62, max(5, h * 0.8), tone) end
        end
        if now then
            local nx = x + w * now
            c:polyline({ nx, y, nx, my + bh / 2 }, max(1, h * 0.05), P.dark)
            c:disc(nx, y, max(1.5, h * 0.1), P.dark)
        end
        return true
    end
end

-- ─── Reading trends: a tinted tile, a round badge ─────────────────────────

if not D.trendTile then
    function D.trendTile(c, x, y, w, h, tone, i)
        cutbox(c, x, y, w, h, min(h * 0.18, 14), mix(tone.bg, P.light, 0.3))
        c:rect(floor(x + h * 0.12), floor(y + h * 0.86), floor(w - h * 0.24), max(2, floor(h * 0.06)), mix(P.a, tone.bg, 0.55))
        return true
    end
end

if not D.trendBadge then
    function D.trendBadge(c, cx, cy, r, dir, tone, fill)
        local col = (dir == "up") and P.good or ((dir == "down") and P.bad or P.a)
        c:disc(cx, cy, r, col)
        local a = r * 0.42
        local lw = max(1.5, r * 0.18)
        if dir == "up" then
            c:polyline({ cx - a, cy + a * 0.45, cx, cy - a * 0.5, cx + a, cy + a * 0.45 }, lw, WHITE)
        elseif dir == "down" then
            c:polyline({ cx - a, cy - a * 0.45, cx, cy + a * 0.5, cx + a, cy - a * 0.45 }, lw, WHITE)
        else
            c:polyline({ cx - a, cy, cx + a, cy }, lw, WHITE)
        end
        return true
    end
end

-- ─── the calendar: a framed tile, the style's mark on today ───────────────

if not D.calendarEmpty then
    function D.calendarEmpty(c, x, y, w, h, n, tone, o)
        local m = max(2, floor(min(w, h) * 0.07))
        local dw, dh = w - 2 * m, h - 2 * m
        if dw < 6 or dh < 6 then return false end
        local fillcol = o.future and mix(tone.bg, tone.track, 0.15) or mix(tone.bg, P.light, 0.35)
        cutframe(c, x + m, y + m, dw, dh, max(2, floor(min(dw, dh) * 0.18)), max(1, floor(min(dw, dh) * 0.04)),
            o.future and mix(P.frame, tone.bg, 0.55) or P.frame, fillcol)
        local size = o.num_px or max(10, floor(dh * 0.4))
        c:label(tostring(n), size, x + w / 2, y + h * 0.48, { bold = true, anchor = "c", valign = "mid", color = o.future and tone.muted or tone.fg })
        if o.today and ICON then ICON(c, x + w - m - dw * 0.2, y + m + dh * 0.2, max(4, dw * 0.3), tone) end
        return true
    end
end

-- ─── covers: the style's own trim ──────────────────────────────────────────

if not D.bookCover then
    function D.bookCover(c, x, y, w, h, tone, o)
        if COVER then COVER(c, x, y, w, h, o and o.pct, tone) end
        return true
    end
end

if not D.calendarCover then
    function D.calendarCover(c, x, y, w, h, tone, o)
        if COVER then COVER(c, x, y, w, h, nil, tone) end
        if o and o.today and ICON and w >= 12 then ICON(c, x + w * 0.78, y + h * 0.16, max(5, w * 0.3), tone) end
        return true
    end
end

-- ─── the Dashboard's tab bar: the style's row, a pill for the open tab ────

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

if not D.tabBar then
    function D.tabBar(c, x, y, w, h, cells, tone)
        local night = nightRow(tone)
        if night then
            c = nightCanvas(c)
            local real = {}
            for k, v in pairs(tone) do real[k] = v end
            real.bg, real.dark = flip(tone.bg), tone.dark
            tone = real
        end
        if DECOR then DECOR(c, x, y, w, h, tone) end
        for ci = 1, #cells do
            local cell = cells[ci]
            if cell.active then
                local cx = cell.x + cell.w / 2
                local pw = min(cell.w - 6, cell.label_w + h * 0.6)
                local ph = h * 0.56
                local px, py = floor(cx - pw / 2), floor(y + h * 0.48 - ph / 2)
                cutframe(c, px, py, pw, ph, ph * 0.32, max(2, floor(ph * 0.08)), P.pill_edge or WHITE, P.pill)
                cell.color = night and flip(P.pill_fg or WHITE) or (P.pill_fg or WHITE)
                cell.dy = -h * 0.02
            end
        end
        return true
    end
end

return D
