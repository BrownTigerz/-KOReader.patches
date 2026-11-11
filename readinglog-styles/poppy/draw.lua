-- Poppy drawings for Reading Log, by BrownTigerz. A poppy in a wheat field
-- for the rings: its petals turn red with your pages, more poppies open in
-- the field with your minutes and a dove flies over when both are done. Buds
-- that bloom for the days, poppies on tall stems for the bar charts, a poppy
-- field for the year goal and a wreath of poppies for the challenge.
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

local SKY    = { 204, 221, 238 }
local SKY_H  = { 238, 238, 221 }
local WHEAT  = { 221, 187, 102 }
local WHEAT_D = { 187, 153, 68 }
local RED    = { 221, 34, 34 }
local RED_D  = { 170, 17, 17 }
local PALE   = { 238, 187, 170 }
local CENTER = { 34, 17, 17 }
local STEM   = { 85, 119, 68 }
local STEM_L = { 136, 170, 102 }
local DOVE   = { 255, 255, 255 }
local DOVE_D = { 204, 204, 221 }
local WREATH = { 51, 102, 51 }

local P = { a = RED, b = WHEAT_D, light = { 255, 238, 221 }, dark = { 34, 68, 34 },
    frame = { 136, 153, 119 }, pill = RED, pill_fg = WHITE, pill_edge = WHEAT, good = STEM, bad = RED_D }

-- a poppy from the front: four round petals, lit one by one, a dark middle
local function poppy(c, x, y, r, lit)
    lit = lit or 4
    local spots = { { -0.42, -0.32 }, { 0.42, -0.32 }, { 0.42, 0.34 }, { -0.42, 0.34 } }
    for k = 1, 4 do
        local col = (k <= lit) and ((k % 2 == 0) and RED_D or RED) or PALE
        c:disc(x + spots[k][1] * r, y + spots[k][2] * r, r * 0.62, col)
    end
    c:disc(x, y, r * 0.28, CENTER)
    for k = 0, 5 do
        local a = k * pi / 3
        c:disc(x + r * 0.3 * cos(a), y + r * 0.3 * sin(a), max(1, r * 0.06), CENTER)
    end
end

local function bud(c, x, y, r)
    oval(c, x, y, r * 0.3, r * 0.42, STEM_L)
    c:polyline({ x, y + r * 0.4, x, y + r * 1.2 }, max(1, r * 0.1), STEM)
end

local function wheat(c, x, base, h)
    c:polyline({ x, base, x, base - h }, max(1, h * 0.03), WHEAT_D)
    for k = 0, 3 do
        local ky = base - h + k * h * 0.08
        oval(c, x - h * 0.03, ky, h * 0.025, h * 0.045, WHEAT)
        oval(c, x + h * 0.03, ky, h * 0.025, h * 0.045, WHEAT)
    end
end

local function dove(c, x, y, s)
    oval(c, x, y, s * 0.45, s * 0.18, DOVE)
    tri(c, x - s * 0.05, y - s * 0.6, y, s * 0.3, DOVE_D)
    tri(c, x + s * 0.02, y - s * 0.55, y - s * 0.05, s * 0.22, DOVE)
    c:disc(x + s * 0.42, y - s * 0.08, s * 0.14, DOVE)
    tri(c, x + s * 0.6, y - s * 0.1, y - s * 0.04, s * 0.04, WHEAT_D)
    c:polyline({ x - s * 0.4, y, x - s * 0.7, y - s * 0.1 }, max(1, s * 0.16), DOVE_D)
end

local function butterfly(c, x, y, s)
    c:disc(x - s * 0.28, y - s * 0.1, s * 0.26, DOVE)
    c:disc(x + s * 0.28, y - s * 0.1, s * 0.26, DOVE)
    c:disc(x - s * 0.2, y + s * 0.18, s * 0.16, DOVE_D)
    c:disc(x + s * 0.2, y + s * 0.18, s * 0.16, DOVE_D)
    c:polyline({ x, y - s * 0.3, x, y + s * 0.3 }, max(1, s * 0.08), CENTER)
end

local ICON = function(c, x, y, s, tone) poppy(c, x, y, s * 0.4) end
local RIDER = function(c, x, y, h, tone) butterfly(c, x, y - h * 0.5, h * 1.1) end
local DECOR = function(c, x, y, w, h, tone)
    local n = max(6, floor(w / (h * 0.8)))
    for k = 0, n do
        local px = x + w * k / n
        local ph = h * (0.18 + 0.08 * ((k * 3) % 3) / 2)
        c:polyline({ px, y + h, px, y + h - ph }, max(1, h * 0.03), STEM_L)
        poppy(c, px, y + h - ph, h * 0.09)
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local r = max(4, w * 0.13)
    c:polyline({ x + r * 1.2, y + r * 1.2, x + r * 2.1, y + r * 2.3 }, max(1, r * 0.25), STEM)
    poppy(c, x + r * 1.2, y + r * 1.2, r)
end

-- the scene: a poppy in a wheat field; its petals turn red with the pages
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, SKY)
    band(c, cx, cy, R, cy - R * 0.05, cy + R * 0.25, SKY_H)
    local horizon = cy + R * 0.25
    band(c, cx, cy, R, horizon, cy + R, WHEAT)
    band(c, cx, cy, R, horizon + R * 0.3, cy + R, WHEAT_D)
    for k = 0, 8 do
        local wx = cx - R * 0.75 + R * 0.19 * k
        if abs(wx - cx) > R * 0.2 then wheat(c, wx, cy + R * 0.85 - R * 0.1 * sin(k), R * 0.55) end
    end
    c:polyline({ cx, cy + R * 0.95, cx + R * 0.04, cy - R * 0.1 }, max(2, R * 0.05), STEM)
    oval(c, cx - R * 0.12, cy + R * 0.45, R * 0.12, R * 0.05, STEM_L)
    poppy(c, cx + R * 0.04, cy - R * 0.25, R * 0.42, floor(4 * f1 + 1e-6))
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local spots = { { -0.62, 0.38 }, { 0.6, 0.42 }, { -0.35, 0.6 }, { 0.42, 0.66 }, { -0.7, 0.2 }, { 0.72, 0.18 } }
    local n = floor(#spots * f2 + 0.5)
    for i = 1, n do
        local sp = spots[i]
        c:polyline({ cx + sp[1] * R, cy + sp[2] * R, cx + sp[1] * R, cy + (sp[2] + 0.2) * R }, max(1, R * 0.02), STEM)
        poppy(c, cx + sp[1] * R, cy + sp[2] * R, R * 0.08)
    end
    if f1 >= 1 and f2 >= 1 then dove(c, cx - R * 0.45, cy - R * 0.55, R * 0.3) end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then butterfly(c, cx + R * 0.55, cy - R * 0.45, R * 0.14) end
end

-- ─── a day: a bud that blooms with the pages ─────────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    if o.future then
        bud(c, cx, cy - d * 0.1, d * 0.3)
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    if fp <= 0.05 then bud(c, cx, cy - d * 0.1, d * 0.4)
    else
        c:polyline({ cx, cy + d * 0.45, cx, cy + d * 0.1 }, max(1, d * 0.04), STEM)
        poppy(c, cx, cy - d * 0.05, d * 0.36, max(1, floor(4 * fp + 0.5)))
    end
    if fm >= 1 then oval(c, cx + d * 0.3, cy + d * 0.3, d * 0.1, d * 0.05, STEM_L) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, RED, RED) end
    return true
end

-- ─── bar charts: poppies on tall stems ───────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 6 then return false end
    local cx = x + w / 2
    c:polyline({ cx, y + h, cx, y + w * 0.3 }, max(1.5, w * 0.12), STEM)
    for k = 1, floor(h / (w * 1.4)) do
        local ly = y + h - k * w * 1.2
        if ly > y + w then oval(c, cx + ((k % 2 == 0) and w * 0.25 or -w * 0.25), ly, w * 0.25, w * 0.1, STEM_L) end
    end
    poppy(c, cx, y + w * 0.15, w * (o.current and 0.6 or 0.48))
    return true
end

-- ─── the year goal: a poppy field, one poppy per book ───────────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    c:rect(floor(x), floor(y + h * 0.3), floor(w), floor(h * 0.7), mix(WHEAT, tone.bg, 0.5))
    c:rect(floor(x), floor(y + h * 0.3), floor(w), max(2, floor(h * 0.04)), WHEAT_D)
    -- rows nearer the front are bigger
    local rows = (n <= 8) and 2 or 3
    local i = 0
    local placed = 0
    for r = 0, rows - 1 do
        local cnt = floor(n / rows) + ((r < n % rows) and 1 or 0)
        local ry = y + h * (0.38 + 0.6 * (r + 0.5) / rows)
        local s = h * (0.07 + 0.05 * r)
        for k = 0, cnt - 1 do
            i = i + 1
            placed = placed + 1
            local px = x + w * (k + 0.5) / cnt + ((r % 2 == 1) and w * 0.02 or 0)
            c:polyline({ px, ry + s * 0.4, px, ry + s * 1.6 }, max(1, s * 0.15), STEM)
            if i <= lit then poppy(c, px, ry, s) else bud(c, px, ry + s * 0.4, s * 0.8) end
        end
    end
    return true
end

-- ─── the challenge: a wreath of poppies ─────────────────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local r = R * 0.68
    c:ring(cx, cy, r + R * 0.12, max(3, R * 0.22), 1, WREATH, WREATH)
    for k = 0, 23 do
        local a = k * 2 * pi / 24
        oval(c, cx + (r + R * 0.12) * cos(a), cy + (r + R * 0.12) * sin(a), R * 0.07, R * 0.04, (k % 2 == 0) and STEM_L or STEM)
    end
    local n = 10
    local lit = floor(n * frac + 1e-6)
    for k = 0, n - 1 do
        local a = -pi / 2 + k * 2 * pi / n
        local px, py = cx + (r + R * 0.12) * cos(a), cy + (r + R * 0.12) * sin(a)
        if k < lit then poppy(c, px, py, R * 0.15) else c:disc(px, py, R * 0.04, STEM_L) end
    end
    if frac >= 1 then
        c:rect(floor(cx - R * 0.06), floor(cy + r + R * 0.05), floor(R * 0.12), floor(R * 0.25), RED)
        tri(c, cx - R * 0.1, cy + r + R * 0.1, cy + r + R * 0.35, R * 0.06, RED_D)
        tri(c, cx + R * 0.1, cy + r + R * 0.1, cy + r + R * 0.35, R * 0.06, RED_D)
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
