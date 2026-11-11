-- Ravens drawings for Reading Log, by BrownTigerz. A moonlit branch for the
-- rings: the moon waxes with your pages, ravens gather on the branch with
-- your minutes and their trinket glints when both are done. Moon phases for
-- the days, feathers for the bar charts, a raven's nest of shiny trinkets
-- for the year goal and a raven crossing the moon for the challenge.
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

local SKY    = { 85, 68, 136 }
local SKY_T  = { 51, 34, 102 }
local SKY_H  = { 136, 119, 187 }
local MOON   = { 255, 255, 221 }
local MOON_D = { 221, 221, 187 }
local BRANCH = { 51, 34, 34 }
local RAVEN  = { 34, 34, 51 }
local SHEEN  = { 102, 119, 170 }
local EYE    = { 255, 204, 51 }
local GOLD   = { 238, 187, 34 }
local SILVER = { 204, 204, 221 }
local GEM_R  = { 221, 51, 85 }
local GEM_B  = { 51, 153, 221 }
local GEM_G  = { 51, 187, 119 }
local NEST   = { 119, 85, 51 }
local NEST_D = { 85, 51, 34 }
local WIRE   = { 68, 68, 85 }
local TRINKETS = { GOLD, SILVER, GEM_R, GEM_B, GEM_G }

local P = { a = { 68, 85, 153 }, b = SILVER, light = { 221, 221, 238 }, dark = SKY_T,
    frame = { 119, 119, 153 }, pill = { 51, 68, 119 }, pill_fg = WHITE, pill_edge = SILVER, good = GEM_G, bad = GEM_R }

-- a raven perched (facing right), with a blue sheen and a gold eye so it shows on dark
local function raven(c, x, y, s)
    oval(c, x, y, s * 0.42, s * 0.28, RAVEN)
    c:polyline({ x - s * 0.35, y + s * 0.05, x - s * 0.75, y + s * 0.25 }, max(1, s * 0.18), RAVEN)
    c:disc(x + s * 0.35, y - s * 0.22, s * 0.2, RAVEN)
    tri(c, x + s * 0.62, y - s * 0.26, y - s * 0.12, s * 0.12, RAVEN)
    c:polyline({ x - s * 0.25, y - s * 0.12, x + s * 0.2, y - s * 0.2 }, max(1, s * 0.07), SHEEN)
    c:disc(x + s * 0.4, y - s * 0.26, max(1, s * 0.05), EYE)
    c:polyline({ x - s * 0.05, y + s * 0.25, x - s * 0.05, y + s * 0.38 }, max(1, s * 0.05), RAVEN)
    c:polyline({ x + s * 0.1, y + s * 0.25, x + s * 0.1, y + s * 0.38 }, max(1, s * 0.05), RAVEN)
end

-- a raven in flight
local function flier(c, x, y, s)
    c:polyline({ x - s * 0.8, y - s * 0.35, x - s * 0.3, y - s * 0.05, x, y }, max(1, s * 0.22), RAVEN)
    c:polyline({ x + s * 0.8, y - s * 0.35, x + s * 0.3, y - s * 0.05, x, y }, max(1, s * 0.22), RAVEN)
    oval(c, x, y, s * 0.3, s * 0.14, RAVEN)
    c:disc(x + s * 0.3, y - s * 0.04, s * 0.12, RAVEN)
    c:disc(x + s * 0.33, y - s * 0.06, max(1, s * 0.04), EYE)
end

local function feather(c, x, top, bottom, w, col)
    local h = bottom - top
    oval(c, x, top + h * 0.45, w * 0.5, h * 0.45, col)
    c:polyline({ x, top, x, bottom }, max(1, w * 0.08), mix(col, WHITE, 0.4))
    for k = 1, 4 do c:polyline({ x, top + h * k / 6, x + w * 0.4, top + h * (k / 6 - 0.06) }, max(1, w * 0.04), mix(col, SKY_T, 0.4)) end
end

local function moonPhase(c, x, y, r, f, bg)
    c:disc(x, y, r, MOON)
    c:disc(x - r * 0.3, y - r * 0.2, r * 0.18, MOON_D)
    c:disc(x + r * 0.25, y + r * 0.3, r * 0.12, MOON_D)
    if f < 1 then c:disc(x - r * 2 * f - r * 0.05, y, r * 1.02, bg) end
end

local ICON = function(c, x, y, s, tone) feather(c, x, y - s * 0.45, y + s * 0.45, s * 0.35, SHEEN) end
local RIDER = function(c, x, y, h, tone) raven(c, x, y - h * 0.65, h * 0.9) end
local DECOR = function(c, x, y, w, h, tone)
    local pts = {}
    for i = 0, 20 do local f = i / 20; pts[#pts + 1] = x + w * f; pts[#pts + 1] = y + h * 0.12 + h * 0.08 * sin(pi * f * 3) ^ 2 end
    c:polyline(pts, max(1, h * 0.03), tone.dark and SILVER or WIRE)
    local n = max(3, floor(w / (h * 3)))
    for k = 0, n - 1 do
        local f = (k + 0.5) / n
        raven(c, x + w * f, y + h * 0.12 + h * 0.08 * sin(pi * f * 3) ^ 2 - h * 0.16, h * 0.32)
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    feather(c, x + w * 0.85, y + h * 0.02, y + h * 0.2, max(3, w * 0.12), RAVEN)
end

-- the scene: a moonlit branch; the moon waxes with the pages
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, SKY)
    band(c, cx, cy, R, cy - R, cy - R * 0.4, SKY_T)
    band(c, cx, cy, R, cy + R * 0.4, cy + R, SKY_H)
    for k = 0, 5 do c:disc(cx + R * (-0.7 + 0.28 * k), cy - R * (0.7 - 0.12 * ((k * 3) % 3)), max(1, R * 0.015), MOON) end
    if f1 > 0 then moonPhase(c, cx + R * 0.3, cy - R * 0.32, R * 0.3, f1, SKY) end
    -- the branch from the left
    c:polyline({ cx - R, cy + R * 0.28, cx - R * 0.3, cy + R * 0.2, cx + R * 0.35, cy + R * 0.3, cx + R * 0.8, cy + R * 0.2 }, max(3, R * 0.07), BRANCH)
    c:polyline({ cx - R * 0.3, cy + R * 0.2, cx - R * 0.42, cy - R * 0.05 }, max(2, R * 0.035), BRANCH)
    c:polyline({ cx + R * 0.35, cy + R * 0.3, cx + R * 0.5, cy + R * 0.55 }, max(2, R * 0.035), BRANCH)
    c:polyline({ cx + R * 0.1, cy + R * 0.26, cx + R * 0.2, cy + R * 0.05 }, max(1, R * 0.025), BRANCH)
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local perches = { { -0.55, 0.22 }, { 0.0, 0.24 }, { 0.5, 0.25 } }
    local n = floor(3 * f2 + 1e-6)
    for i = 1, n do raven(c, cx + perches[i][1] * R, cy + perches[i][2] * R - R * 0.14, R * 0.26) end
    if f1 >= 1 and f2 >= 1 then
        -- the middle raven holds a key that glints
        local kx, ky = cx + R * 0.18, cy + R * 0.05
        c:ring(kx, ky, R * 0.03, max(1, R * 0.015), 1, GOLD, GOLD)
        c:polyline({ kx + R * 0.03, ky, kx + R * 0.12, ky }, max(1, R * 0.015), GOLD)
        star(c, kx + R * 0.05, ky - R * 0.08, max(1.5, R * 0.04), WHITE, 4, 0)
    end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then feather(c, cx - R * 0.25, cy + R * 0.45, cy + R * 0.68, R * 0.06, RAVEN) end
end

-- ─── a day: the moon's phase, by the pages ───────────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local r = d * 0.36
    if o.future then
        c:ring(cx, cy, r * 0.85, max(1, d * 0.03), 1, mix(SKY_H, tone.bg, 0.5), mix(SKY_H, tone.bg, 0.5))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    c:disc(cx, cy, r * 1.15, SKY_T)
    if fp > 0 then moonPhase(c, cx, cy, r, fp, SKY_T) end
    if fm >= 1 then star(c, cx + r * 0.9, cy - r * 0.9, max(1.5, d * 0.07), MOON, 4, 0) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, P.a, P.a) end
    return true
end

-- ─── bar charts: feathers ────────────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 6 then return false end
    feather(c, x + w / 2, y, y + h, w * 0.95, o.current and SHEEN or RAVEN)
    if o.current then raven(c, x + w / 2, y - w * 0.4, w * 0.6) end
    return true
end

-- ─── the year goal: a raven's nest of shiny things, one per book ─────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cx = x + w / 2
    local rx, ry = min(w * 0.46, h * 1.1), h * 0.32
    local ny = y + h * 0.66
    -- the trinkets sit in the bowl of the nest
    local cols = (n <= 8) and 4 or ((n <= 16) and 6 or 8)
    local rows = max(1, floor((n + cols - 1) / cols))
    local s = min(rx * 1.6 / cols, h * 0.55 / rows) * 0.42
    for i = 1, lit do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local tx = cx - rx * 0.8 + rx * 1.6 * (col + 0.5) / cols + ((row % 2 == 1) and s * 0.6 or 0)
        local ty = ny - s * 0.4 - row * s * 1.5
        local t = (i - 1) % #TRINKETS + 1
        if t == 1 then c:disc(tx, ty, s, GOLD); c:ring(tx, ty, s * 0.7, max(1, s * 0.12), 1, mix(GOLD, BRANCH, 0.3), mix(GOLD, BRANCH, 0.3))
        elseif t == 2 then c:ring(tx, ty, s * 0.6, max(1, s * 0.25), 1, SILVER, SILVER); c:polyline({ tx + s * 0.5, ty, tx + s * 1.3, ty }, max(1, s * 0.25), SILVER)
        else star(c, tx, ty, s, TRINKETS[t], 4, 0) end
    end
    oval(c, cx, ny, rx, ry, NEST, ny - ry * 0.1)
    for k = 0, 8 do
        local f = k / 8
        c:polyline({ cx - rx + rx * 2 * f, ny + ry * 0.1, cx - rx + rx * 2 * min(1, f + 0.2), ny + ry * 0.55 }, max(1, ry * 0.06), NEST_D)
        c:polyline({ cx - rx + rx * 2 * f, ny + ry * 0.55, cx - rx + rx * 2 * max(0, f - 0.2), ny + ry * 0.2 }, max(1, ry * 0.05), mix(NEST, WHITE, 0.2))
    end
    if lit == 0 then c:disc(cx, ny - ry * 0.05, max(1, ry * 0.1), NEST_D) end
    return true
end

-- ─── the challenge: a raven crossing the moon ────────────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    c:disc(cx, cy, R * 0.82, SKY_T)
    moonPhase(c, cx, cy, R * 0.6, 1, SKY_T)
    local fx = cx - R * 0.95 + R * 1.7 * frac
    local fy = cy + R * 0.3 - R * 0.6 * sin(pi * frac)
    local pts = {}
    for i = 0, 10 do
        local f = frac * i / 10
        pts[#pts + 1] = cx - R * 0.95 + R * 1.7 * f
        pts[#pts + 1] = cy + R * 0.3 - R * 0.6 * sin(pi * f)
    end
    if frac > 0.03 then
        for i = 1, #pts - 2, 4 do c:disc(pts[i], pts[i + 1], max(1, R * 0.012), SILVER) end
    end
    flier(c, fx, fy, R * 0.32)
    if frac >= 1 then raven(c, cx + R * 0.72, cy + R * 0.62, R * 0.3) end
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
