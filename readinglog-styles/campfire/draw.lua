-- Campfire drawings for Reading Log, by BrownTigerz. A campfire under the
-- stars for the rings: the fire builds with your pages, sparks fly and a
-- marshmallow toasts with your minutes, and the tent glows when both are
-- done. Flames for the days and the bar charts, a stack of s'mores for the
-- year goal and a trail up the mountain to the tent for the challenge.
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

local NIGHT  = { 17, 34, 68 }
local NIGHT2 = { 34, 51, 85 }
local MOUNT  = { 51, 68, 102 }
local MOUNT_D = { 34, 51, 68 }
local GROUND = { 51, 51, 51 }
local LOG    = { 119, 68, 34 }
local LOG_D  = { 85, 51, 17 }
local F_RED  = { 221, 51, 17 }
local F_ORG  = { 255, 136, 17 }
local F_YEL  = { 255, 221, 68 }
local SPARK  = { 255, 204, 85 }
local STARC  = { 255, 255, 221 }
local TENT   = { 204, 102, 51 }
local TENT_D = { 153, 68, 34 }
local GLOW   = { 255, 221, 136 }
local MALLOW = { 255, 255, 238 }
local TOAST  = { 204, 136, 68 }
local CRACK  = { 221, 170, 102 }
local CRACK_D = { 187, 136, 68 }
local CHOC   = { 102, 51, 34 }
local STICK  = { 153, 102, 51 }

local P = { a = F_ORG, b = F_RED, light = { 255, 238, 204 }, dark = NIGHT,
    frame = { 136, 85, 51 }, pill = { 170, 68, 0 }, pill_fg = WHITE, pill_edge = F_YEL, good = { 85, 153, 68 }, bad = F_RED }

-- a flame: red outside, orange, then a yellow heart
local function flame(c, x, base, h, w)
    if h < 2 then return end
    c:disc(x, base - w * 0.45, w * 0.5, F_RED)
    tri(c, x, base - h, base - w * 0.45, w * 0.5, F_RED)
    c:disc(x, base - w * 0.38, w * 0.36, F_ORG)
    tri(c, x, base - h * 0.78, base - w * 0.38, w * 0.36, F_ORG)
    c:disc(x, base - w * 0.3, w * 0.2, F_YEL)
    tri(c, x, base - h * 0.5, base - w * 0.3, w * 0.2, F_YEL)
end

local function logs(c, x, base, s)
    c:polyline({ x - s * 0.5, base, x + s * 0.4, base - s * 0.18 }, max(2, s * 0.14), LOG)
    c:polyline({ x + s * 0.5, base, x - s * 0.4, base - s * 0.18 }, max(2, s * 0.14), LOG_D)
end

local function tent(c, x, base, s, glow)
    tri(c, x, base - s * 0.75, base, s * 0.55, TENT)
    tri(c, x, base - s * 0.75, base, s * 0.2, glow and GLOW or TENT_D)
    c:polyline({ x, base - s * 0.75, x, base - s * 0.85 }, max(1, s * 0.04), LOG_D)
end

local function smore(c, x, y, w, h, col)
    c:rect(floor(x - w / 2), floor(y + h * 0.6), floor(w), max(1, floor(h * 0.4)), col or CRACK)
    c:rect(floor(x - w * 0.46), floor(y + h * 0.38), floor(w * 0.92), max(1, floor(h * 0.24)), MALLOW)
    c:rect(floor(x - w * 0.44), floor(y + h * 0.28), floor(w * 0.88), max(1, floor(h * 0.12)), CHOC)
    c:rect(floor(x - w / 2), floor(y), floor(w), max(1, floor(h * 0.3)), col or CRACK)
    c:polyline({ x - w * 0.3, y + h * 0.15, x + w * 0.3, y + h * 0.15 }, max(1, h * 0.05), CRACK_D)
end

local function mallow(c, x, y, s, toast)
    c:polyline({ x - s * 1.4, y + s * 0.9, x, y }, max(1, s * 0.15), STICK)
    oval(c, x + s * 0.1, y - s * 0.05, s * 0.38, s * 0.3, mix(MALLOW, TOAST, toast))
end

local ICON = function(c, x, y, s, tone) flame(c, x, y + s * 0.35, s * 0.8, s * 0.42) end
local RIDER = function(c, x, y, h, tone) mallow(c, x, y - h * 0.4, h * 0.9, 0.6) end
local DECOR = function(c, x, y, w, h, tone)
    c:rect(floor(x), floor(y + h * 0.92), floor(w), max(2, floor(h * 0.06)), LOG)
    for k = 0, floor(w / (h * 0.35)) do
        local ex = x + k * h * 0.35 + h * 0.15
        local ey = y + h * (0.84 - 0.12 * ((k * 3) % 4) / 3)
        c:disc(ex, ey, max(1, h * 0.03), (k % 2 == 0) and SPARK or F_ORG)
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local gh = max(3, h * 0.08)
    c:rect(floor(x), floor(y + h - gh), floor(w), floor(gh), mix(F_ORG, LOG_D, 0.3))
    local n = max(2, floor(w / 12))
    for k = 0, n - 1 do tri(c, x + w * (k + 0.5) / n, y + h - gh * 2.2, y + h - gh, w / n * 0.3, F_ORG) end
end

-- the scene: a night by the mountains; the fire builds with the pages
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, NIGHT)
    band(c, cx, cy, R, cy - R * 0.1, cy + R, NIGHT2)
    local stars = { { -0.5, -0.6 }, { -0.1, -0.75 }, { 0.35, -0.62 }, { 0.6, -0.35 }, { -0.7, -0.25 }, { 0.15, -0.4 } }
    for i = 1, #stars do c:disc(cx + stars[i][1] * R, cy + stars[i][2] * R, max(1, R * 0.018), STARC) end
    tri(c, cx - R * 0.3, cy - R * 0.35, cy + R * 0.35, R * 0.55, MOUNT)
    tri(c, cx + R * 0.42, cy - R * 0.12, cy + R * 0.35, R * 0.45, MOUNT_D)
    tri(c, cx - R * 0.3, cy - R * 0.35, cy - R * 0.2, R * 0.08, STARC)
    local ground = cy + R * 0.35
    band(c, cx, cy, R, ground, cy + R, GROUND)
    -- the glow, the fire, the logs
    local fx, fb = cx - R * 0.1, cy + R * 0.66
    if f1 > 0 then
        oval(c, fx, fb, R * (0.3 + 0.35 * f1), R * 0.12, mix(GROUND, F_ORG, 0.35))
        flame(c, fx, fb, R * (0.15 + 0.55 * f1), R * (0.12 + 0.2 * f1))
        flame(c, fx - R * 0.13, fb, R * (0.1 + 0.3 * f1), R * (0.08 + 0.1 * f1))
        flame(c, fx + R * 0.13, fb, R * (0.1 + 0.32 * f1), R * (0.08 + 0.1 * f1))
    end
    logs(c, fx, fb + R * 0.04, R * 0.42)
    for k = -1, 1, 2 do c:disc(fx + k * R * 0.3, fb + R * 0.06, R * 0.06, MOUNT) end
    tent(c, cx + R * 0.5, cy + R * 0.62, R * 0.45, false)
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local fx, fb = cx - R * 0.1, cy + R * 0.66
    local n = floor(8 * f2 + 0.5)
    for k = 1, n do
        local sx = fx + R * 0.25 * sin(k * 2.4)
        local sy = fb - R * (0.35 + 0.08 * k)
        if (sx - cx) ^ 2 + (sy - cy) ^ 2 < (R * 0.9) ^ 2 then c:disc(sx, sy, max(1, R * 0.02), SPARK) end
    end
    if f2 > 0 then mallow(c, fx - R * 0.42, fb - R * 0.38, R * 0.12, f2) end
    if f1 >= 1 and f2 >= 1 then
        tent(c, cx + R * 0.5, cy + R * 0.62, R * 0.45, true)
        c:disc(cx + R * 0.45, cy - R * 0.55, R * 0.12, STARC)
        c:disc(cx + R * 0.5, cy - R * 0.58, R * 0.1, NIGHT)
    end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then
        c:polyline({ cx - R * 0.65, cy - R * 0.5, cx - R * 0.42, cy - R * 0.42 }, max(1, R * 0.015), mix(STARC, NIGHT, 0.4))
        c:disc(cx - R * 0.42, cy - R * 0.42, max(1.5, R * 0.025), STARC)
    end
end

-- ─── a day: a fire that grows with the pages ─────────────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    local base = cy + d * 0.3
    if o.future then
        logs(c, cx, base, d * 0.5)
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    if fp > 0 then flame(c, cx, base - d * 0.02, d * (0.2 + 0.5 * fp), d * (0.15 + 0.2 * fp))
    else c:disc(cx, base - d * 0.06, max(1.5, d * 0.06), mix(F_ORG, tone.bg, 0.4)) end
    logs(c, cx, base + d * 0.04, d * 0.6)
    if fm >= 1 then c:disc(cx + d * 0.25, cy - d * 0.3, max(1, d * 0.05), SPARK); c:disc(cx - d * 0.2, cy - d * 0.38, max(1, d * 0.04), SPARK) end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, F_ORG, F_ORG) end
    return true
end

-- ─── bar charts: columns of flame ────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 6 then return false end
    local cx = x + w / 2
    flame(c, cx, y + h, h, w * (o.current and 0.62 or 0.52))
    if o.current then for k = 1, 3 do c:disc(cx + w * 0.3 * sin(k * 2), y - w * 0.3 * k, max(1, w * 0.07), SPARK) end end
    return true
end

-- ─── the year goal: s'mores, one per book ────────────────────────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cols = (n <= 6) and n or ((n <= 12) and 6 or 8)
    local rows = max(1, floor((n + cols - 1) / cols))
    local cw, rh = w / cols, h / rows
    local sw, sh = min(cw * 0.8, rh * 1.0), min(rh * 0.75, cw * 0.75)
    for i = 1, n do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local sx, sy = x + cw * (col + 0.5), y + rh * row + (rh - sh) / 2
        if i <= lit then smore(c, sx, sy, sw, sh)
        else c:rect(floor(sx - sw / 2), floor(sy + sh * 0.6), floor(sw), max(1, floor(sh * 0.4)), mix(CRACK, tone.bg, 0.75)) end
    end
    return true
end

-- ─── the challenge: the trail up the mountain to the tent ────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local base = cy + R * 0.8
    tri(c, cx, cy - R * 0.75, base, R * 0.95, MOUNT)
    tri(c, cx + R * 0.15, cy - R * 0.75, base, R * 0.55, MOUNT_D)
    tri(c, cx, cy - R * 0.75, cy - R * 0.45, R * 0.28, STARC)
    -- the trail zigzags up; a hiker is as far as the challenge
    local path = { -0.75, 0.75, 0.3, 0.45, -0.35, 0.15, 0.15, -0.12, -0.05, -0.42 }
    local pts = {}
    for i = 1, #path, 2 do pts[#pts + 1] = cx + path[i] * R; pts[#pts + 1] = cy + path[i + 1] * R end
    for i = 1, #pts - 3, 2 do
        local x0, y0, x1, y1 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        for k = 0, 5 do
            local f = k / 6
            c:disc(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, max(1, R * 0.018), mix(CRACK, MOUNT, 0.2))
        end
    end
    local segs = (#pts / 2) - 1
    local pos = frac * segs
    local si = min(segs - 1, floor(pos))
    local f = pos - si
    local hx = pts[si * 2 + 1] + (pts[si * 2 + 3] - pts[si * 2 + 1]) * f
    local hy = pts[si * 2 + 2] + (pts[si * 2 + 4] - pts[si * 2 + 2]) * f
    tent(c, cx - R * 0.05, cy - R * 0.42, R * 0.3, frac >= 1)
    c:disc(hx, hy - R * 0.2, R * 0.05, CRACK)
    c:polyline({ hx, hy - R * 0.15, hx, hy - R * 0.03 }, max(2, R * 0.05), F_RED)
    c:rect(floor(hx - R * 0.07), floor(hy - R * 0.15), floor(R * 0.05), floor(R * 0.1), TENT_D)
    c:polyline({ hx, hy - R * 0.03, hx - R * 0.04, hy + R * 0.05 }, max(1, R * 0.025), MOUNT_D)
    c:polyline({ hx, hy - R * 0.03, hx + R * 0.04, hy + R * 0.05 }, max(1, R * 0.025), MOUNT_D)
    if frac >= 1 then flame(c, cx + R * 0.25, cy - R * 0.4, R * 0.18, R * 0.1) end
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
