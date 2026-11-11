-- Autumn Leaves drawings for Reading Log, by BrownTigerz. A park bench in
-- the fall for the rings: the leaf pile grows with your pages, leaves drift
-- down with your minutes and a squirrel comes by when both are done. Leaves
-- turning colour for the days, columns of leaves for the bar charts, a
-- scrapbook of pressed leaves for the year goal and a leaf pile big enough
-- to jump in for the challenge.
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

local SKY    = { 238, 221, 204 }
local SKY_T  = { 221, 187, 153 }
local PATH   = { 187, 170, 136 }
local GRASS  = { 136, 136, 68 }
local BENCH  = { 119, 68, 34 }
local BENCH_D = { 68, 51, 34 }
local LAMP   = { 51, 51, 51 }
local GLOW   = { 255, 221, 136 }
local RED    = { 204, 51, 17 }
local ORANGE = { 238, 119, 17 }
local GOLD   = { 238, 187, 34 }
local BROWN  = { 153, 85, 34 }
local GREEN  = { 119, 153, 51 }
local SQUIR  = { 170, 102, 51 }
local PAPER  = { 255, 250, 238 }
local TAPE   = { 238, 221, 170 }
local KID    = { 68, 102, 170 }
local LEAVES = { RED, ORANGE, GOLD, BROWN }

local P = { a = ORANGE, b = RED, light = { 255, 238, 204 }, dark = { 119, 51, 17 },
    frame = { 187, 119, 68 }, pill = RED, pill_fg = WHITE, pill_edge = GOLD, good = GREEN, bad = RED }

-- a leaf: an oval with a vein and a stem, at an angle
local function leaf(c, x, y, s, col, a)
    a = a or -0.6
    local dx, dy = cos(a), sin(a)
    for k = -2, 2 do c:disc(x + dx * s * 0.18 * k, y + dy * s * 0.18 * k, s * (0.3 - 0.05 * abs(k)), col) end
    c:polyline({ x - dx * s * 0.5, y - dy * s * 0.5, x + dx * s * 0.42, y + dy * s * 0.42 }, max(1, s * 0.05), mix(col, BENCH_D, 0.5))
    c:polyline({ x - dx * s * 0.45, y - dy * s * 0.45, x - dx * s * 0.68, y - dy * s * 0.68 }, max(1, s * 0.06), BENCH_D)
end

local function pile(c, x, base, rx, ry)
    oval(c, x, base, rx, ry, BROWN, nil, base)
    for k = 0, 13 do
        local f = k / 13
        local px = x - rx * 0.85 + rx * 1.7 * f
        local py = base - ry * 0.85 * sqrt(max(0, 1 - (2 * f - 1) ^ 2)) + ry * 0.15 * ((k * 3) % 3) / 2
        leaf(c, px, py, ry * 0.4, LEAVES[k % #LEAVES + 1], -0.6 + k * 0.5)
    end
end

local function squirrel(c, x, y, s)
    oval(c, x - s * 0.35, y - s * 0.35, s * 0.25, s * 0.42, SQUIR)
    oval(c, x, y, s * 0.28, s * 0.22, SQUIR)
    c:disc(x + s * 0.25, y - s * 0.2, s * 0.15, SQUIR)
    c:disc(x + s * 0.3, y - s * 0.24, max(1, s * 0.04), BLACK)
    c:disc(x + s * 0.18, y - s * 0.38, s * 0.06, SQUIR)
    c:disc(x + s * 0.35, y + s * 0.02, s * 0.08, BROWN)
end

local ICON = function(c, x, y, s, tone) leaf(c, x, y, s * 0.75, ORANGE) end
local RIDER = function(c, x, y, h, tone) leaf(c, x, y - h * 0.4, h * 1.3, RED, -0.3) end
local DECOR = function(c, x, y, w, h, tone)
    local pts = {}
    for i = 0, 20 do pts[#pts + 1] = x + w * i / 20; pts[#pts + 1] = y + h * 0.82 + h * 0.06 * sin(i * 1.3) end
    c:polyline(pts, max(1, h * 0.03), BENCH)
    local n = max(6, floor(w / (h * 0.5)))
    for k = 0, n do leaf(c, x + w * k / n, y + h * 0.84 + h * 0.06 * sin(k * 1.3 * 20 / n), h * 0.14, LEAVES[k % #LEAVES + 1], 1.2 + k * 0.4) end
end
local COVER = function(c, x, y, w, h, pct, tone)
    leaf(c, x + w * 0.82, y + h * 0.07, max(4, w * 0.14), ORANGE, 0.4)
    leaf(c, x + w * 0.68, y + h * 0.05, max(3, w * 0.1), RED, -0.8)
end

-- the scene: a park bench under a lamp; the leaf pile grows with the pages
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, SKY)
    band(c, cx, cy, R, cy - R, cy - R * 0.4, SKY_T)
    local ground = cy + R * 0.35
    band(c, cx, cy, R, ground, cy + R, GRASS)
    band(c, cx, cy, R, ground + R * 0.15, ground + R * 0.35, PATH)
    -- the lamp post
    local lx = cx + R * 0.62
    c:rect(floor(lx - R * 0.02), floor(cy - R * 0.55), max(2, floor(R * 0.04)), floor(ground - cy + R * 0.55), LAMP)
    trap(c, lx, cy - R * 0.7, cy - R * 0.55, R * 0.05, R * 0.09, LAMP)
    -- the bench
    local bx = cx - R * 0.1
    c:rect(floor(bx - R * 0.42), floor(ground - R * 0.38), floor(R * 0.84), max(2, floor(R * 0.06)), BENCH)
    c:rect(floor(bx - R * 0.42), floor(ground - R * 0.28), floor(R * 0.84), max(2, floor(R * 0.06)), BENCH)
    c:rect(floor(bx - R * 0.45), floor(ground - R * 0.16), floor(R * 0.9), max(2, floor(R * 0.07)), BENCH)
    for k = -1, 1, 2 do c:rect(floor(bx + k * R * 0.36 - R * 0.02), floor(ground - R * 0.38), max(2, floor(R * 0.04)), floor(R * 0.38), BENCH_D) end
    if f1 > 0 then pile(c, cx - R * 0.05, ground + R * 0.12, R * (0.2 + 0.4 * f1), R * (0.06 + 0.22 * f1)) end
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local spots = { { -0.55, -0.5 }, { -0.1, -0.62 }, { 0.3, -0.35 }, { -0.35, -0.2 }, { 0.1, -0.15 }, { -0.7, 0.0 } }
    local n = floor(#spots * f2 + 0.5)
    for i = 1, n do leaf(c, cx + spots[i][1] * R, cy + spots[i][2] * R, R * 0.12, LEAVES[i % #LEAVES + 1], i * 0.9) end
    if f2 > 0 then c:disc(cx + R * 0.62, cy - R * 0.6, R * 0.06 * (1 + f2), GLOW) end
    if f1 >= 1 and f2 >= 1 then squirrel(c, cx + R * 0.18, cy + R * 0.12, R * 0.25) end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then leaf(c, cx - R * 0.68, cy + R * 0.6, R * 0.12, GOLD, 0.8) end
end

-- ─── a day: a leaf turning with the pages ────────────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    if o.future then
        leaf(c, cx, cy, d * 0.55, mix(GREEN, tone.bg, 0.7))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    local col
    if fp <= 0 then col = GREEN elseif fp < 0.5 then col = mix(GREEN, GOLD, fp * 2) elseif fp < 1 then col = mix(GOLD, ORANGE, (fp - 0.5) * 2) else col = RED end
    leaf(c, cx, cy, d * 0.85, col)
    if fm >= 1 then leaf(c, cx + d * 0.3, cy + d * 0.3, d * 0.3, GOLD, 0.6) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, RED, RED) end
    return true
end

-- ─── bar charts: columns of leaves ───────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 6 then return false end
    local s = w * 0.9
    local n = max(1, floor(h / (s * 0.5)))
    for k = 0, n - 1 do
        local ly = y + h - s * 0.3 - (h - s * 0.4) * k / max(1, n - 1)
        local col = o.current and ((k % 2 == 0) and RED or ORANGE) or LEAVES[(k + (o.i or 0)) % #LEAVES + 1]
        leaf(c, x + w / 2 + ((k % 2 == 0) and -w * 0.08 or w * 0.08), ly, s, col, (k % 2 == 0) and -0.4 or 0.4 + pi)
    end
    return true
end

-- ─── the year goal: a scrapbook of pressed leaves, one per book ──────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cols = (n <= 6) and 3 or ((n <= 12) and 4 or 6)
    local rows = max(1, floor((n + cols - 1) / cols))
    local bw, bh = min(w * 0.96, h * 1.6), h * 0.96
    local bx, by = x + (w - bw) / 2, y + (h - bh) / 2
    c:rect(floor(bx), floor(by), floor(bw), floor(bh), mix(PAPER, TAPE, 0.4))
    c:rect(floor(bx + bw / 2 - 1), floor(by), 2, floor(bh), mix(TAPE, BENCH, 0.3))
    local cw, rh = bw / cols, bh / rows
    for i = 1, n do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local px, py = bx + cw * (col + 0.5), by + rh * (row + 0.5)
        local s = min(cw, rh) * 0.7
        if i <= lit then
            leaf(c, px, py, s, LEAVES[(i - 1) % #LEAVES + 1], -0.8 + (i % 3) * 0.5)
            c:rect(floor(px - s * 0.2), floor(py - s * 0.48), floor(s * 0.4), max(2, floor(s * 0.12)), TAPE)
        else
            c:frame(floor(px - s * 0.4), floor(py - s * 0.4), floor(s * 0.8), floor(s * 0.8), 0, 1, mix(TAPE, BENCH, 0.2), mix(PAPER, TAPE, 0.4))
        end
    end
    return true
end

-- ─── the challenge: a leaf pile big enough to jump in ────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local base = cy + R * 0.75
    c:rect(floor(cx - R), floor(base), floor(2 * R), floor(R * 0.15), GRASS)
    -- the rake leaning in
    c:polyline({ cx + R * 0.75, base, cx + R * 0.45, cy - R * 0.55 }, max(2, R * 0.04), BENCH)
    for k = -2, 2 do c:polyline({ cx + R * (0.45 + 0.04 * k), cy - R * 0.55, cx + R * (0.43 + 0.06 * k), cy - R * 0.68 }, max(1, R * 0.02), LAMP) end
    if frac > 0 then pile(c, cx - R * 0.1, base, R * (0.25 + 0.5 * frac), R * (0.08 + 0.55 * frac)) end
    if frac >= 1 then
        -- someone mid-jump
        local kx, ky = cx - R * 0.1, cy - R * 0.45
        c:disc(kx, ky - R * 0.12, R * 0.07, { 238, 204, 170 })
        c:polyline({ kx, ky - R * 0.05, kx, ky + R * 0.12 }, max(2, R * 0.06), KID)
        c:polyline({ kx, ky, kx - R * 0.15, ky - R * 0.12 }, max(1, R * 0.03), KID)
        c:polyline({ kx, ky, kx + R * 0.15, ky - R * 0.12 }, max(1, R * 0.03), KID)
        c:polyline({ kx, ky + R * 0.12, kx - R * 0.1, ky + R * 0.22 }, max(1, R * 0.03), BENCH_D)
        c:polyline({ kx, ky + R * 0.12, kx + R * 0.1, ky + R * 0.22 }, max(1, R * 0.03), BENCH_D)
        for k = 0, 3 do leaf(c, kx + R * 0.3 * cos(k * 1.6), ky + R * 0.25 * sin(k * 1.6), R * 0.08, LEAVES[k + 1], k) end
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
