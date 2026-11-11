-- Northern Lights drawings for Reading Log, by BrownTigerz. A winter night
-- in a round window for the rings: the aurora grows with your pages, stars
-- come out and the cabin lights up with your minutes. Night skies with an
-- aurora streak for the days, aurora curtains for the bar charts, an igloo
-- built block by block for the year goal and a dog sled racing to the cabin
-- for the challenge.
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

local NIGHT   = { 0, 34, 68 }
local NIGHT_T = { 0, 17, 51 }
local SNOW    = { 238, 255, 255 }
local SNOW_D  = { 187, 204, 238 }
local AUR     = { 0, 221, 136 }
local AUR_L   = { 153, 255, 204 }
local VIO     = { 153, 102, 255 }
local CABIN   = { 119, 68, 34 }
local ROOF    = { 68, 34, 34 }
local GLOW    = { 255, 204, 85 }
local STARC   = { 255, 255, 221 }
local FLAKE   = { 119, 187, 255 }
local DOG     = { 102, 102, 119 }

local P = { a = { 0, 170, 119 }, b = { 119, 68, 221 }, light = { 204, 238, 221 }, dark = NIGHT_T,
    frame = { 51, 85, 136 }, pill = { 0, 136, 102 }, pill_fg = WHITE, good = { 0, 153, 102 }, bad = { 204, 51, 85 } }

-- a fixed sprinkle of stars (x, y in -1..1 of the window)
local STARS = { { -0.55, -0.62 }, { -0.2, -0.78 }, { 0.3, -0.7 }, { 0.62, -0.45 }, { -0.75, -0.25 },
    { 0.1, -0.5 }, { 0.75, -0.15 }, { -0.4, -0.4 }, { 0.45, -0.2 }, { -0.05, -0.2 } }

local function snowflake(c, x, y, s, col)
    burst(c, x, y, 0, s * 0.5, 6, col, max(1, s * 0.09), pi / 6)
    c:disc(x, y, max(1, s * 0.1), col)
end

-- an aurora curtain: a soft wide streak with a bright core
local function curtain(c, x, top, len, w, col, core)
    if len < 1 then return end
    c:polyline({ x, top, x + w * 0.15, top + len }, max(1, w), col)
    c:polyline({ x, top, x + w * 0.15, top + len * 0.7 }, max(1, w * 0.35), core)
end

local function cabin(c, x, base, s, lit)
    c:rect(floor(x - s * 0.5), floor(base - s * 0.5), floor(s), floor(s * 0.5), CABIN)
    tri(c, x, base - s * 0.95, base - s * 0.48, s * 0.66, ROOF)
    tri(c, x, base - s * 0.95, base - s * 0.75, s * 0.28, SNOW)
    c:rect(floor(x - s * 0.16), floor(base - s * 0.38), max(2, floor(s * 0.3)), max(2, floor(s * 0.2)), mix(ROOF, GLOW, lit))
    c:rect(floor(x + s * 0.22), floor(base - s * 1.0), max(2, floor(s * 0.12)), floor(s * 0.3), ROOF)
end

local function sled(c, x, y, s)
    c:polyline({ x - s * 0.6, y, x + s * 0.5, y, x + s * 0.65, y - s * 0.15 }, max(1, s * 0.08), CABIN)
    c:rect(floor(x - s * 0.5), floor(y - s * 0.32), floor(s * 0.85), max(2, floor(s * 0.25)), { 204, 51, 51 })
end

local function dog(c, x, y, s)
    oval(c, x, y - s * 0.3, s * 0.38, s * 0.16, DOG)
    c:disc(x + s * 0.38, y - s * 0.45, max(1.5, s * 0.14), DOG)
    c:polyline({ x - s * 0.25, y - s * 0.2, x - s * 0.28, y }, max(1, s * 0.08), DOG)
    c:polyline({ x + s * 0.22, y - s * 0.2, x + s * 0.25, y }, max(1, s * 0.08), DOG)
end

local ICON = function(c, x, y, s, tone) snowflake(c, x, y, s, FLAKE) end
local RIDER = function(c, x, y, h, tone) sled(c, x, y - h * 0.55, h * 1.6) end
local DECOR = function(c, x, y, w, h, tone)
    wave(c, x, x + w, y + h * 0.12, h * 0.05, AUR, max(1, h * 0.05), max(3, floor(w / (h * 2))))
    local n = max(4, floor(w / (h * 1.4)))
    for k = 0, n do oval(c, x + w * k / n, y + h * 0.98, h * 0.55, h * 0.12, SNOW, nil, y + h) end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local n = max(3, floor(w / 10))
    for k = 0, n - 1 do
        local cx = x + w * (k + 0.5) / n
        oval(c, cx, y, w / n * 0.62, max(2, h * 0.04), SNOW, y, y + h)
        if k % 2 == 0 then tri(c, cx, y + h * 0.03, y + h * 0.1, w / n * 0.18, SNOW, true) end
    end
end

-- the scene: a winter night over snowy hills, a cabin on the right
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, NIGHT)
    band(c, cx, cy, R, cy - R, cy - R * 0.5, NIGHT_T)
    for i = 1, 5 do local s = STARS[i]; c:disc(cx + s[1] * R, cy + s[2] * R, max(1, R * 0.018), STARC) end
    -- the aurora: curtains drop further with the pages
    if f1 > 0 then
        for i = 0, 6 do
            local fx = -0.62 + 1.24 * i / 6
            local top = cy - R * (0.62 - 0.1 * sin(i * 1.3))
            local len = R * 0.7 * f1 * (0.75 + 0.25 * sin(i * 2.1 + 1))
            curtain(c, cx + fx * R, top, len, R * 0.17, mix(AUR, NIGHT, 0.45), AUR_L)
        end
    end
    -- hills
    band(c, cx, cy, R, cy + R * 0.42, cy + R, SNOW)
    oval(c, cx - R * 0.35, cy + R * 0.45, R * 0.55, R * 0.16, SNOW, nil, cy + R * 0.45)
    oval(c, cx + R * 0.45, cy + R * 0.42, R * 0.45, R * 0.2, SNOW_D, nil, cy + R * 0.42)
    oval(c, cx + R * 0.45, cy + R * 0.44, R * 0.43, R * 0.18, SNOW, nil, cy + R * 0.44)
    cabin(c, cx + R * 0.42, cy + R * 0.38, R * 0.32, 0)
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
    c:ring(cx, cy, R * 0.95, max(1, R * 0.015), 1, SNOW_D, SNOW_D)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    -- stars come out with the minutes, the cabin window warms up
    local n = floor(5 * f2 + 0.5)
    for i = 6, 5 + n do local s = STARS[i]; star(c, cx + s[1] * R, cy + s[2] * R, max(1.5, R * 0.04), STARC, 4, 0) end
    if f2 > 0 then cabin(c, cx + R * 0.42, cy + R * 0.38, R * 0.32, f2) end
    if f1 >= 1 and f2 >= 1 then
        -- both: a violet crown over the green and smoke from the chimney
        for i = 0, 4 do
            local fx = -0.45 + 0.9 * i / 4
            curtain(c, cx + fx * R, cy - R * 0.72, R * 0.32, R * 0.12, mix(VIO, NIGHT, 0.3), mix(VIO, WHITE, 0.4))
        end
        for k = 1, 3 do c:disc(cx + R * (0.5 + 0.04 * k), cy - R * (0.02 + 0.09 * k), R * (0.03 + 0.012 * k), SNOW_D) end
    end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then
        c:polyline({ cx - R * 0.6, cy - R * 0.45, cx - R * 0.25, cy - R * 0.3 }, max(1, R * 0.02), mix(STARC, NIGHT, 0.4))
        star(c, cx - R * 0.24, cy - R * 0.3, max(1.5, R * 0.045), STARC, 4, 0)
    end
end

-- ─── a day: a little night sky with an aurora streak ─────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local r = d * 0.4
    if o.future then
        c:ring(cx, cy, r, max(1, d * 0.03), 1, mix(P.frame, tone.bg, 0.6), mix(P.frame, tone.bg, 0.6))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    c:disc(cx, cy, r, NIGHT)
    band(c, cx, cy, r, cy + r * 0.45, cy + r, SNOW)
    if fp > 0 then
        for i = -1, 1 do curtain(c, cx + i * r * 0.42, cy - r * 0.6, r * 0.95 * fp, r * 0.28, mix(AUR, NIGHT, 0.4), AUR_L) end
    end
    if fm >= 1 then star(c, cx + r * 0.45, cy - r * 0.5, max(1.2, r * 0.16), STARC, 4, 0) end
    c:ring(cx, cy, r, max(1, d * 0.035), 1, o.today and AUR or P.frame, o.today and AUR or P.frame)
    if o.today then c:ring(cx, cy, d * 0.48, max(1, d * 0.03), 1, AUR, AUR) end
    return true
end

-- ─── bar charts: aurora curtains ─────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 4 then return false end
    local r = min(w / 2, h / 2)
    c:rrect(x, y, w, h, r, mix(AUR, VIO, 0.6))
    c:rrect(x, floor(y + h * 0.3), w, max(1, floor(h * 0.7)), r, mix(AUR, VIO, 0.25))
    c:rrect(x, floor(y + h * 0.6), w, max(1, floor(h * 0.4)), r, AUR)
    c:rect(floor(x + w * 0.42), floor(y + r), max(1, floor(w * 0.14)), max(1, floor(h - 2 * r)), mix(AUR_L, WHITE, 0.3))
    if o.current then star(c, x + w / 2, y - w * 0.4, max(2, w * 0.3), GLOW, 4, 0) end
    return true
end

-- ─── the year goal: an igloo, one ice block per book ─────────────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local base = y + h * 0.96
    local r = min(w * 0.46, h * 0.9)
    local cx = x + w / 2
    local rows = (n <= 6) and 2 or ((n <= 14) and 3 or 4)
    local rh = r / rows
    -- slots per row, from the widths
    local widths, sum = {}, 0
    for k = 1, rows do
        local mid = (k - 0.5) * rh
        widths[k] = sqrt(max(0, r * r - mid * mid))
        sum = sum + widths[k]
    end
    local counts, used = {}, 0
    for k = 1, rows do counts[k] = max(1, floor(n * widths[k] / sum + 0.5)); used = used + counts[k] end
    counts[1] = counts[1] + (n - used)
    c:rrect(floor(cx - r * 1.05), floor(base - 2), floor(r * 2.1), max(3, floor(h * 0.04)), 2, SNOW_D)
    local i = 0
    for k = 1, rows do
        local yb = base - rh * (k - 1)
        local half = widths[k]
        local cnt = max(1, counts[k])
        local bw = 2 * half / cnt
        for j = 0, cnt - 1 do
            i = i + 1
            local bx = cx - half + bw * j
            local col = (i <= lit) and SNOW or mix(SNOW_D, tone.bg, 0.6)
            local edge = (i <= lit) and FLAKE or mix(SNOW_D, tone.bg, 0.3)
            c:frame(floor(bx + 1), floor(yb - rh + 1), max(3, floor(bw - 2)), max(3, floor(rh - 2)), max(1, floor(rh * 0.15)), 1, edge, col)
        end
    end
    -- the door
    band(c, cx, base, r * 0.28, base - r * 0.28, base, NIGHT)
    return true
end

-- ─── the challenge: a dog sled racing to the cabin under the aurora ──────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local x, y, w, h = cx - R, cy - R * 0.85, 2 * R, R * 1.7
    c:rrect(floor(x), floor(y), floor(w), floor(h), R * 0.16, NIGHT)
    for i = 0, 5 do curtain(c, x + w * (0.12 + 0.15 * i), y + h * 0.1, h * 0.3, R * 0.12, mix(AUR, NIGHT, 0.45), AUR_L) end
    local gy = y + h * 0.7
    c:rrect(floor(x), floor(gy), floor(w), floor(y + h - gy), R * 0.16, SNOW)
    c:rect(floor(x), floor(gy), floor(w), floor(R * 0.1), SNOW)
    cabin(c, x + w * 0.84, gy + R * 0.02, R * 0.36, frac >= 1 and 1 or 0)
    -- tracks behind the sled
    local sx = x + w * 0.1 + w * 0.56 * frac
    if frac > 0.03 then c:polyline({ x + w * 0.06, gy + R * 0.2, sx - R * 0.2, gy + R * 0.2 }, max(1, R * 0.02), SNOW_D) end
    sled(c, sx, gy + R * 0.2, R * 0.38)
    dog(c, sx + R * 0.36, gy + R * 0.2, R * 0.32)
    dog(c, sx + R * 0.66, gy + R * 0.2, R * 0.32)
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
