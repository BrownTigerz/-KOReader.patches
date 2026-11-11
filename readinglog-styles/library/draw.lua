-- Library drawings for Reading Log, by BrownTigerz. A reading desk in the
-- library for the rings: the open book fills with lines as you read your
-- pages, the green lamp warms up with your minutes and a bookmark and a cup
-- of tea appear when both are done. Books that open for the days, stacks of
-- books for the bar charts, a bookshelf for the year goal and the library
-- ladder for the challenge.
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

local WALL   = { 102, 51, 34 }
local WALL_D = { 68, 34, 17 }
local SHELF  = { 136, 85, 51 }
local DESK   = { 119, 68, 34 }
local DESK_L = { 170, 119, 68 }
local PAGE   = { 255, 250, 238 }
local INK    = { 68, 68, 85 }
local BURG   = { 136, 34, 51 }
local NAVY   = { 34, 68, 136 }
local FOREST = { 34, 102, 68 }
local OCHRE  = { 204, 153, 51 }
local PLUM   = { 102, 51, 102 }
local LAMP   = { 34, 119, 68 }
local BRASS  = { 204, 170, 85 }
local GLOW   = { 255, 238, 170 }
local TEA    = { 238, 238, 238 }
local SPINES = { BURG, NAVY, FOREST, OCHRE, PLUM, { 85, 102, 119 } }

local P = { a = BURG, b = NAVY, light = { 238, 221, 187 }, dark = WALL_D,
    frame = SHELF, pill = BURG, pill_fg = { 255, 238, 204 }, pill_edge = BRASS, good = FOREST, bad = BURG }

local function openBook(c, x, y, w, h, lines)
    c:rect(floor(x - w / 2 - h * 0.04), floor(y + h * 0.06), floor(w + h * 0.08), floor(h), BURG)
    c:rect(floor(x - w / 2), floor(y), floor(w / 2 - 1), floor(h), PAGE)
    c:rect(floor(x + 1), floor(y), floor(w / 2 - 1), floor(h), PAGE)
    c:polyline({ x, y, x, y + h }, max(1, h * 0.03), mix(PAGE, INK, 0.3))
    local per = 6
    for i = 0, lines - 1 do
        local side = (i < per) and -1 or 1
        local row = i % per
        local ly = y + h * (0.16 + 0.13 * row)
        local lx0 = (side < 0) and (x - w / 2 + w * 0.06) or (x + w * 0.06)
        local lw = w * 0.38 * ((row == per - 1) and 0.6 or 1)
        c:rect(floor(lx0), floor(ly), floor(lw), max(1, floor(h * 0.04)), INK)
    end
end

local function bookmark(c, x, y, s)
    c:rect(floor(x - s * 0.15), floor(y), max(2, floor(s * 0.3)), floor(s), BURG)
    tri(c, x, y + s * 0.75, y + s, s * 0.15, PAGE, false)
end

local function spine(c, x, y, w, h, col)
    c:rect(floor(x), floor(y), max(1, floor(w)), floor(h), col)
    c:rect(floor(x), floor(y + h * 0.15), max(1, floor(w)), max(1, floor(h * 0.05)), BRASS)
    c:rect(floor(x), floor(y + h * 0.8), max(1, floor(w)), max(1, floor(h * 0.05)), BRASS)
end

local ICON = function(c, x, y, s, tone) openBook(c, x, y - s * 0.2, s * 0.8, s * 0.4, 4) end
local RIDER = function(c, x, y, h, tone) bookmark(c, x, y - h * 0.9, h * 1.5) end
local DECOR = function(c, x, y, w, h, tone)
    c:rect(floor(x), floor(y + h * 0.9), floor(w), max(2, floor(h * 0.1)), SHELF)
    local bx = x + h * 0.1
    local k = 0
    while bx < x + w - h * 0.1 do
        local bw = h * (0.08 + 0.03 * ((k * 7) % 3))
        local bh = h * (0.1 + 0.03 * ((k * 5) % 3))
        if (k % 7) ~= 3 then spine(c, bx, y + h * 0.9 - bh, bw, bh, SPINES[k % #SPINES + 1]) end
        bx = bx + bw + 1
        k = k + 1
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local pw, ph = w * 0.42, h * 0.18
    c:rect(floor(x + w - pw - w * 0.06), floor(y + h - ph - h * 0.05), floor(pw), floor(ph), PAGE)
    for k = 1, 3 do c:rect(floor(x + w - pw - w * 0.02), floor(y + h - ph - h * 0.05 + ph * k / 4), floor(pw * 0.8), 1, NAVY) end
end

-- the scene: shelves on the wall, a desk, an open book under the lamp
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, WALL)
    for r = 0, 2 do
        local sy = cy - R * (0.55 - 0.32 * r)
        local half = sqrt(max(0, R * R - (sy - cy) ^ 2))
        c:rect(floor(cx - half), floor(sy), floor(2 * half), max(2, floor(R * 0.04)), SHELF)
        local bx = cx - half + R * 0.06
        local k = r * 3
        while bx < cx + half - R * 0.1 do
            local bw = R * (0.05 + 0.02 * ((k * 7) % 3))
            local bh = R * (0.2 + 0.05 * ((k * 5) % 3))
            local top = sy - bh
            local thalf = sqrt(max(0, R * R - (top - cy) ^ 2))
            if bx > cx - thalf + 2 and bx + bw < cx + thalf - 2 then spine(c, bx, top, bw, bh, SPINES[k % #SPINES + 1]) end
            bx = bx + bw + 1
            k = k + 1
        end
    end
    local desk = cy + R * 0.42
    band(c, cx, cy, R, desk, cy + R, DESK)
    band(c, cx, cy, R, desk, desk + R * 0.05, DESK_L)
    openBook(c, cx - R * 0.05, desk - R * 0.18, R * 0.85, R * 0.4, floor(12 * f1 + 1e-6))
    -- the lamp, cold for now
    local lx = cx + R * 0.55
    c:rect(floor(lx - R * 0.015), floor(desk - R * 0.5), max(2, floor(R * 0.03)), floor(R * 0.5), BRASS)
    oval(c, lx, desk - R * 0.03, R * 0.1, R * 0.03, BRASS)
    trap(c, lx - R * 0.05, desk - R * 0.62, desk - R * 0.5, R * 0.08, R * 0.16, LAMP)
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local desk = cy + R * 0.42
    local lx = cx + R * 0.55
    if f2 > 0 then
        -- the lamp warms the page
        trap(c, lx - R * 0.05, desk - R * 0.5, desk - R * 0.16, R * 0.15, R * (0.15 + 0.3 * f2), mix(WALL, GLOW, 0.35 * f2))
        trap(c, lx - R * 0.05, desk - R * 0.62, desk - R * 0.5, R * 0.08, R * 0.16, LAMP)
        c:rect(floor(lx - R * 0.17), floor(desk - R * 0.51), floor(R * 0.24), max(1, floor(R * 0.03)), GLOW)
        openBook(c, cx - R * 0.05, desk - R * 0.18, R * 0.85, R * 0.4, floor(12 * f1 + 1e-6))
    end
    if f1 >= 1 and f2 >= 1 then
        bookmark(c, cx - R * 0.08, desk - R * 0.24, R * 0.4)
        local tx = cx - R * 0.62
        c:rect(floor(tx - R * 0.08), floor(desk - R * 0.14), floor(R * 0.16), floor(R * 0.14), TEA)
        c:ring(tx + R * 0.1, desk - R * 0.08, R * 0.05, max(1, R * 0.02), 1, TEA, TEA)
        for k = 1, 2 do c:polyline({ tx - R * 0.03 + k * R * 0.03, desk - R * 0.18, tx - R * 0.05 + k * R * 0.03, desk - R * 0.3 }, max(1, R * 0.015), mix(TEA, WALL, 0.3)) end
    end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then
        local gx, gy = cx - R * 0.35, cy + R * 0.62
        c:ring(gx - R * 0.07, gy, R * 0.055, max(1, R * 0.015), 1, BRASS, BRASS)
        c:ring(gx + R * 0.07, gy, R * 0.055, max(1, R * 0.015), 1, BRASS, BRASS)
        c:polyline({ gx - R * 0.015, gy, gx + R * 0.015, gy }, max(1, R * 0.015), BRASS)
    end
end

-- ─── a day: a book that opens with the pages ────────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    if o.future then
        c:rect(floor(cx - d * 0.18), floor(cy - d * 0.25), floor(d * 0.36), floor(d * 0.5), mix(SHELF, tone.bg, 0.7))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    if fp <= 0.05 then
        spine(c, cx - d * 0.18, cy - d * 0.28, d * 0.36, d * 0.56, mix(BURG, tone.bg, 0.3))
    else
        openBook(c, cx, cy - d * 0.18, d * 0.82, d * 0.38, floor(12 * fp + 1e-6))
    end
    if fm >= 1 then bookmark(c, cx + d * 0.22, cy - d * 0.3, d * 0.3) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, BURG, BURG) end
    return true
end

-- ─── bar charts: stacks of books ─────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 4 then return false end
    local bh = max(3, w * 0.32)
    local n = max(1, floor(h / bh))
    local rest = h - n * bh
    for k = 0, n - 1 do
        local by = y + rest + k * bh
        local inset = w * 0.06 * ((k * 3) % 3)
        local col = SPINES[(k + (o.i or 0)) % #SPINES + 1]
        c:rect(floor(x + inset), floor(by), max(2, floor(w - inset * 1.2)), max(1, floor(bh - 1)), col)
        c:rect(floor(x + inset + w * 0.1), floor(by + bh * 0.3), max(1, floor(w * 0.6)), max(1, floor(bh * 0.18)), PAGE)
    end
    if o.current then openBook(c, x + w / 2, y + rest - w * 0.45, w * 1.1, w * 0.4, 6) end
    return true
end

-- ─── the year goal: a bookshelf, one book per book read ──────────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local rows = (n <= 12) and 2 or 3
    local cols = floor((n + rows - 1) / rows)
    local rh = h / rows
    c:rect(floor(x), floor(y), floor(w), floor(h), mix(WALL, tone.bg, 0.55))
    local i = 0
    for r = 0, rows - 1 do
        local sy = y + rh * (r + 1) - rh * 0.1
        c:rect(floor(x), floor(sy), floor(w), max(2, floor(rh * 0.1)), SHELF)
        local bw = w * 0.9 / cols
        for k = 0, cols - 1 do
            i = i + 1
            if i <= n then
                local bh = rh * (0.6 + 0.15 * ((i * 7) % 3) / 2)
                local bx = x + w * 0.05 + bw * k
                if i <= lit then spine(c, bx + 1, sy - bh, bw - 2, bh, SPINES[(i - 1) % #SPINES + 1])
                else c:rect(floor(bx + 1), floor(sy - bh * 0.5), max(1, floor(bw - 2)), max(1, floor(rh * 0.03)), mix(SHELF, tone.bg, 0.5)) end
            end
        end
    end
    return true
end

-- ─── the challenge: up the library ladder ────────────────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local top, base = cy - R * 0.9, cy + R * 0.85
    c:rect(floor(cx - R * 0.85), floor(top), floor(R * 1.7), floor(base - top), mix(WALL, tone.bg, 0.25))
    for r = 0, 3 do
        local sy = top + (base - top) * (r + 1) / 4 - R * 0.03
        c:rect(floor(cx - R * 0.85), floor(sy), floor(R * 1.7), max(2, floor(R * 0.05)), SHELF)
        for k = 0, 9 do
            if (k + r) % 4 ~= 1 then spine(c, cx - R * 0.8 + k * R * 0.16, sy - R * 0.3, R * 0.13, R * 0.3, SPINES[(k + r) % #SPINES + 1]) end
        end
    end
    -- the ladder, and a reader as high as the challenge
    local lx = cx + R * 0.15
    c:polyline({ lx - R * 0.15, base, lx - R * 0.05, top + R * 0.05 }, max(2, R * 0.04), DESK_L)
    c:polyline({ lx + R * 0.15, base, lx + R * 0.25, top + R * 0.05 }, max(2, R * 0.04), DESK_L)
    for k = 1, 8 do
        local f = k / 9
        local ry = base - (base - top) * f
        c:polyline({ lx - R * 0.15 + R * 0.1 * f, ry, lx + R * 0.15 + R * 0.1 * f, ry }, max(1, R * 0.025), DESK_L)
    end
    local py = base - (base - top - R * 0.2) * frac
    local px = lx + R * 0.05 + R * 0.1 * frac
    c:disc(px, py - R * 0.32, R * 0.07, { 238, 204, 170 })
    c:rect(floor(px - R * 0.07), floor(py - R * 0.25), floor(R * 0.14), floor(R * 0.18), NAVY)
    c:polyline({ px - R * 0.04, py - R * 0.07, px - R * 0.06, py }, max(1, R * 0.03), INK)
    c:polyline({ px + R * 0.04, py - R * 0.07, px + R * 0.06, py }, max(1, R * 0.03), INK)
    if frac >= 1 then
        c:disc(px + R * 0.25, py - R * 0.22, R * 0.12, mix(GLOW, tone.bg, 0.2))
        spine(c, px + R * 0.2, py - R * 0.32, R * 0.1, R * 0.22, OCHRE)
    end
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
