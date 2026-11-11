-- Candy Hearts drawings for Reading Log, by BrownTigerz. A heart-shaped
-- candy box for the rings: it fills red with your pages, lace runs round it
-- with your minutes and a gold bow goes on when both are done. Conversation
-- hearts for the days, stacks of candy hearts for the bar charts, a candy
-- jar for the year goal and a box of chocolates for the challenge.
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

local PINK    = { 255, 170, 204 }
local PINK_L  = { 255, 221, 238 }
local PINK_D  = { 221, 68, 136 }
local RED     = { 221, 17, 68 }
local RED_D   = { 153, 0, 51 }
local CHOC    = { 102, 51, 34 }
local CHOC_L  = { 153, 85, 51 }
local MINT    = { 170, 238, 204 }
local LAV     = { 204, 187, 255 }
local LEMON   = { 255, 238, 153 }
local GOLD    = { 238, 187, 34 }
local CANDY   = { PINK, MINT, LAV, LEMON, { 255, 204, 170 } }

local P = { a = RED, b = PINK_D, light = PINK_L, dark = RED_D,
    frame = PINK_D, pill = RED, pill_fg = WHITE, pill_edge = PINK, good = { 34, 153, 102 }, bad = RED_D }

-- a heart filled from the bottom up to a level (ya), in rows
local function heartFrom(c, cx, cy, s, col, ya)
    local r = s * 0.27
    band(c, cx - r * 0.95, cy - s * 0.12, r, ya, cy + s, col)
    band(c, cx + r * 0.95, cy - s * 0.12, r, ya, cy + s, col)
    local top, bottom, hw = cy - s * 0.12, cy + s * 0.5, r * 1.95
    local st = step(s)
    local yy = max(top, floor(ya))
    while yy < bottom do
        local hh = min(st, bottom - yy)
        local half = hw * (1 - (yy + hh / 2 - top) / (bottom - top))
        if half > 0.4 then c:rect(floor(cx - half + 0.5), floor(yy), max(1, floor(2 * half + 0.5)), max(1, floor(hh + 0.5)), col) end
        yy = yy + st
    end
end

-- a point on the heart's outline (t from 0 to 1, round from the top dip)
local function heartPoint(cx, cy, s, t)
    local a = t * 2 * pi
    local hx = 16 * sin(a) ^ 3
    local hy = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
    return cx + hx * s * 0.031, cy - hy * s * 0.031 + s * 0.02
end

local function bow(c, x, y, s)
    tri(c, x - s * 0.5, y - s * 0.35, y + s * 0.35, s * 0.4, GOLD, false)
    c:disc(x - s * 0.45, y, s * 0.3, GOLD)
    c:disc(x + s * 0.45, y, s * 0.3, GOLD)
    c:disc(x, y, s * 0.2, mix(GOLD, CHOC, 0.3))
    c:polyline({ x - s * 0.1, y, x - s * 0.35, y + s * 0.6 }, max(1, s * 0.14), GOLD)
    c:polyline({ x + s * 0.1, y, x + s * 0.35, y + s * 0.6 }, max(1, s * 0.14), GOLD)
end

local ICON = function(c, x, y, s, tone) heart(c, x, y, s * 0.8, RED) end
local RIDER = function(c, x, y, h, tone)
    heart(c, x, y - h * 0.1, h * 1.6, RED)
    c:disc(x - h * 0.3, y - h * 0.4, max(1, h * 0.15), PINK_L)
end
local DECOR = function(c, x, y, w, h, tone)
    local n = max(8, floor(w / (h * 0.3)))
    for k = 0, n do c:disc(x + w * k / n, y + h * 0.95, h * 0.09, PINK_L) end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local s = max(6, w * 0.28)
    c:disc(x + s * 0.5, y + s * 0.5, s * 0.55, WHITE)
    heart(c, x + s * 0.5, y + s * 0.52, s * 0.62, RED)
end

-- the box: a lace edge, then the heart that fills with the pages
local function S1(c, cx, cy, R, f1, tone)
    local s = R * 1.7
    local hy = cy + R * 0.05
    heart(c, cx, hy, s * 1.06, PINK_D)
    heart(c, cx, hy, s, PINK_L)
    if f1 > 0 then
        local top, bottom = hy - s * 0.4, hy + s * 0.5
        heartFrom(c, cx, hy, s, RED, bottom - (bottom - top) * f1)
    end
    c:disc(cx - s * 0.26, hy - s * 0.22, s * 0.06, mix(WHITE, PINK, 0.3))
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local s = R * 1.7
    local hy = cy + R * 0.05
    -- lace dots round the heart, as many as the minutes
    local n = 30
    local lit = floor(n * f2 + 0.5)
    for k = 0, lit - 1 do
        local px, py = heartPoint(cx, hy, s * 1.06, k / n)
        c:disc(px, py, max(1.5, R * 0.035), WHITE)
        c:disc(px, py, max(1, R * 0.018), PINK_D)
    end
    if f1 >= 1 and f2 >= 1 then bow(c, cx, hy - s * 0.42, R * 0.32) end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then
        heart(c, cx + R * 0.72, cy - R * 0.6, R * 0.2, PINK)
        heart(c, cx - R * 0.75, cy + R * 0.55, R * 0.16, LAV)
    end
end

-- ─── a day: a conversation heart, filling with the pages ─────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local s = d * 0.82
    if o.future then
        heart(c, cx, cy, s * 0.7, mix(PINK, tone.bg, 0.65))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    heart(c, cx, cy, s, PINK_L)
    if fp > 0 then
        local top, bottom = cy - s * 0.4, cy + s * 0.5
        heartFrom(c, cx, cy, s, (fp >= 1) and RED or PINK, bottom - (bottom - top) * fp)
    end
    if fm >= 1 then
        c:polyline({ cx - s * 0.18, cy - s * 0.02, cx + s * 0.18, cy - s * 0.02 }, max(1, s * 0.05), WHITE)
        c:polyline({ cx - s * 0.12, cy + s * 0.1, cx + s * 0.12, cy + s * 0.1 }, max(1, s * 0.05), WHITE)
    end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, RED, RED) end
    return true
end

-- ─── bar charts: stacks of candy hearts ──────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 5 or h < 5 then return false end
    local s = w * 0.95
    local gap = s * 0.62
    local n = max(1, floor(h / gap))
    local cx = x + w / 2
    for k = 0, n - 1 do
        local hy = y + h - gap * (k + 0.5)
        local col = o.current and ((k % 2 == 0) and RED or PINK_D) or CANDY[(k + (o.i or 0)) % #CANDY + 1]
        heart(c, cx, hy, s, col)
    end
    if o.current then heart(c, cx, y - w * 0.3, w * 0.7, RED) end
    return true
end

-- ─── the year goal: a candy jar, one heart per book ──────────────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local jw, jh = min(w * 0.6, h * 0.9), h * 0.82
    local jx, jy = x + (w - jw) / 2, y + h * 0.16
    c:rect(floor(jx + jw * 0.12), floor(y + h * 0.02), floor(jw * 0.76), max(3, floor(h * 0.1)), PINK_D)
    c:rect(floor(jx), floor(jy), floor(jw), floor(jh), mix(WHITE, LAV, 0.25))
    c:rect(floor(jx), floor(jy), max(2, floor(jw * 0.05)), floor(jh), mix(WHITE, LAV, 0.55))
    local cols = (n <= 8) and 3 or 4
    local rows = max(1, floor((n + cols - 1) / cols))
    local cw, rh = jw * 0.86 / cols, jh * 0.9 / max(rows, 3)
    local s = min(cw, rh) * 0.95
    for i = 1, lit do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local hx = jx + jw * 0.07 + cw * (col + 0.5) + ((row % 2 == 1) and cw * 0.15 or 0)
        local hy = jy + jh - rh * (row + 0.55)
        heart(c, min(hx, jx + jw - s * 0.5), hy, s, CANDY[(i - 1) % #CANDY + 1])
    end
    c:rect(floor(jx + jw * 0.25), floor(jy + jh * 0.35), floor(jw * 0.5), max(3, floor(jh * 0.18)), WHITE)
    heart(c, jx + jw / 2, jy + jh * 0.44, jh * 0.12, RED)
    return true
end

-- ─── the challenge: a box of chocolates, filling up ──────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local s = R * 1.95
    heart(c, cx, cy + R * 0.05, s, RED_D)
    heart(c, cx, cy + R * 0.05, s * 0.9, CHOC)
    -- chocolates in the heart, as many as the challenge has filled
    local spots = { { 0, 0.28 }, { -0.22, 0.08 }, { 0.22, 0.08 }, { 0, -0.05 }, { -0.42, -0.14 }, { 0.42, -0.14 },
        { -0.2, -0.22 }, { 0.2, -0.22 }, { 0, 0.5 } }
    local n = floor(#spots * frac + 1e-6)
    for i = 1, #spots do
        local sp = spots[i]
        local px, py = cx + sp[1] * R, cy + sp[2] * R
        c:disc(px, py, R * 0.13, CHOC_L)
        if i <= n then
            c:disc(px, py, R * 0.11, (i % 3 == 0) and PINK or ((i % 3 == 1) and CHOC_L or mix(CHOC, BLACK, 0.2)))
            c:polyline({ px - R * 0.05, py - R * 0.03, px + R * 0.05, py - R * 0.03 }, max(1, R * 0.02), (i % 3 == 0) and RED or PINK_L)
        end
    end
    if frac >= 1 then bow(c, cx, cy - R * 0.62, R * 0.36) end
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
