-- Hearth drawings for Reading Log, by BrownTigerz. A fireplace for the
-- rings: the fire builds with your pages, the kettle steams and the mug
-- fills with your minutes, and the cat curls up on the rug when both are
-- done. Mugs of cocoa for the days, brick chimneys for the bar charts, a
-- patchwork quilt for the year goal and a scarf being knitted for the
-- challenge.
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

local WALL   = { 238, 221, 187 }
local BRICK  = { 170, 68, 51 }
local BRICK_D = { 119, 51, 34 }
local MORTAR = { 204, 170, 153 }
local SOOT   = { 34, 17, 17 }
local MANTEL = { 119, 68, 34 }
local LOG    = { 119, 68, 34 }
local F_RED  = { 221, 51, 17 }
local F_ORG  = { 255, 136, 17 }
local F_YEL  = { 255, 221, 68 }
local KETTLE = { 51, 51, 68 }
local STEAM  = { 238, 238, 238 }
local MUG    = { 68, 119, 170 }
local MUG2   = { 221, 85, 68 }
local COCOA  = { 119, 68, 34 }
local MALLOW = { 255, 255, 238 }
local RUG    = { 153, 51, 68 }
local RUG_L  = { 204, 119, 102 }
local CAT    = { 238, 153, 68 }
local CAT_D  = { 187, 102, 34 }
local YARN   = { 204, 51, 85 }
local QUILT  = { { 204, 68, 68 }, { 238, 187, 85 }, { 102, 153, 187 }, { 136, 170, 102 }, { 238, 153, 136 }, { 170, 119, 187 } }
local SCARF  = { { 204, 51, 51 }, { 238, 238, 238 }, { 51, 119, 85 } }

local P = { a = BRICK, b = { 221, 153, 17 }, light = { 255, 238, 221 }, dark = BRICK_D,
    frame = { 170, 102, 51 }, pill = BRICK, pill_fg = WHITE, pill_edge = F_YEL, good = { 85, 136, 68 }, bad = BRICK_D }

local function flame(c, x, base, h, w)
    if h < 2 then return end
    c:disc(x, base - w * 0.45, w * 0.5, F_RED)
    tri(c, x, base - h, base - w * 0.45, w * 0.5, F_RED)
    c:disc(x, base - w * 0.38, w * 0.36, F_ORG)
    tri(c, x, base - h * 0.75, base - w * 0.38, w * 0.36, F_ORG)
    c:disc(x, base - w * 0.3, w * 0.2, F_YEL)
end

local function bricks(c, x, y, w, h, bh)
    c:rect(floor(x), floor(y), floor(w), floor(h), BRICK)
    local row = 0
    local yy = y
    while yy < y + h do
        c:rect(floor(x), floor(yy), floor(w), 1, MORTAR)
        local off = (row % 2 == 0) and 0 or bh
        local xx = x + off
        while xx < x + w do
            c:rect(floor(xx), floor(yy), 1, floor(min(bh, y + h - yy)), MORTAR)
            xx = xx + bh * 2
        end
        yy = yy + bh
        row = row + 1
    end
end

local function mug(c, x, y, s, fill, col)
    c:ring(x + s * 0.32, y + s * 0.05, s * 0.14, max(1, s * 0.06), 1, col, col)
    c:rect(floor(x - s * 0.3), floor(y - s * 0.3), floor(s * 0.6), floor(s * 0.6), col)
    if fill > 0 then
        local top = y - s * 0.24 + s * 0.48 * (1 - fill)
        c:rect(floor(x - s * 0.24), floor(top), floor(s * 0.48), max(1, floor(y + s * 0.24 - top)), COCOA)
    end
end

local function cat(c, x, y, s)
    oval(c, x, y, s * 0.5, s * 0.25, CAT)
    c:disc(x + s * 0.4, y - s * 0.08, s * 0.2, CAT)
    tri(c, x + s * 0.3, y - s * 0.38, y - s * 0.2, s * 0.06, CAT)
    tri(c, x + s * 0.5, y - s * 0.38, y - s * 0.2, s * 0.06, CAT)
    c:polyline({ x - s * 0.45, y + s * 0.05, x - s * 0.2, y + s * 0.22, x + s * 0.2, y + s * 0.22 }, max(1, s * 0.1), CAT_D)
    for k = -1, 1 do c:rect(floor(x + k * s * 0.18), floor(y - s * 0.22), max(1, floor(s * 0.06)), floor(s * 0.15), CAT_D) end
end

local function yarnball(c, x, y, r)
    c:disc(x, y, r, YARN)
    for k = 0, 2 do arc(c, x, y, r * (0.4 + 0.2 * k), pi * 0.2 * k, pi * (1 + 0.2 * k), mix(YARN, WHITE, 0.35), max(1, r * 0.1)) end
end

local ICON = function(c, x, y, s, tone) mug(c, x, y, s * 0.5, 0.8, MUG2) end
local RIDER = function(c, x, y, h, tone)
    yarnball(c, x, y - h * 0.35, h * 0.6)
end
local DECOR = function(c, x, y, w, h, tone)
    c:rect(floor(x), floor(y + h * 0.86), floor(w), max(3, floor(h * 0.12)), MANTEL)
    local n = max(3, floor(w / (h * 2.2)))
    for k = 0, n do
        local kx = x + w * (k + 0.4) / (n + 0.8)
        c:rect(floor(kx - h * 0.03), floor(y + h * 0.78), max(2, floor(h * 0.06)), floor(h * 0.09), STEAM)
        c:disc(kx, y + h * 0.75, max(1.5, h * 0.035), F_YEL)
    end
end
local COVER = function(c, x, y, w, h, pct, tone)
    local ch = max(4, h * 0.1)
    c:rect(floor(x), floor(y + h - ch), floor(w), floor(ch), SCARF[1])
    for k = 0, floor(w / 4) do c:rect(floor(x + k * 4), floor(y + h - ch), 1, floor(ch), mix(SCARF[1], BLACK, 0.25)) end
end

-- the scene: a brick fireplace; the fire builds with the pages
local function S1(c, cx, cy, R, f1, tone)
    band(c, cx, cy, R, cy - R, cy + R, WALL)
    local fx0, fx1 = cx - R * 0.62, cx + R * 0.62
    local top, floorY = cy - R * 0.55, cy + R * 0.55
    bricks(c, fx0, top, fx1 - fx0, floorY - top, R * 0.09)
    c:rect(floor(fx0 - R * 0.08), floor(top - R * 0.08), floor(fx1 - fx0 + R * 0.16), max(3, floor(R * 0.1)), MANTEL)
    -- the firebox, arched
    local bx0, bx1, btop = cx - R * 0.38, cx + R * 0.38, cy - R * 0.08
    c:rect(floor(bx0), floor(btop), floor(bx1 - bx0), floor(floorY - btop), SOOT)
    band(c, cx, btop, R * 0.38, btop - R * 0.38, btop, SOOT)
    if f1 > 0 then
        flame(c, cx, floorY - R * 0.08, R * (0.12 + 0.45 * f1), R * (0.1 + 0.16 * f1))
        flame(c, cx - R * 0.14, floorY - R * 0.08, R * (0.08 + 0.25 * f1), R * (0.06 + 0.08 * f1))
        flame(c, cx + R * 0.14, floorY - R * 0.08, R * (0.08 + 0.28 * f1), R * (0.06 + 0.08 * f1))
    end
    c:polyline({ cx - R * 0.25, floorY - R * 0.04, cx + R * 0.2, floorY - R * 0.12 }, max(2, R * 0.07), LOG)
    c:polyline({ cx + R * 0.25, floorY - R * 0.04, cx - R * 0.2, floorY - R * 0.12 }, max(2, R * 0.07), mix(LOG, BLACK, 0.2))
    band(c, cx, cy, R, floorY, cy + R, mix(WALL, MANTEL, 0.35))
    oval(c, cx, cy + R * 0.75, R * 0.55, R * 0.12, RUG)
    oval(c, cx, cy + R * 0.75, R * 0.42, R * 0.08, RUG_L)
    c:ring(cx, cy, R, max(2, R * 0.05), 1, P.frame, P.frame)
end

local function S2(c, cx, cy, R, f1, f2, tone)
    local top = cy - R * 0.55
    if f2 > 0 then
        mug(c, cx - R * 0.42, top - R * 0.2, R * 0.2, f2, MUG)
        -- the kettle on the mantel, steaming
        local kx = cx + R * 0.38
        oval(c, kx, top - R * 0.17, R * 0.14, R * 0.1, KETTLE)
        c:polyline({ kx + R * 0.12, top - R * 0.17, kx + R * 0.24, top - R * 0.27 }, max(2, R * 0.04), KETTLE)
        local n = floor(3 * f2 + 0.5)
        for k = 1, n do c:disc(kx + R * (0.26 + 0.04 * k), top - R * (0.3 + 0.08 * k), R * (0.03 + 0.012 * k), STEAM) end
    end
    if f1 >= 1 and f2 >= 1 then
        cat(c, cx - R * 0.08, cy + R * 0.7, R * 0.3)
        c:disc(cx - R * 0.42, top - R * 0.36, R * 0.04, MALLOW)
    end
end

local function S3(c, cx, cy, R, f1, f2, f3, tone)
    if f3 > 0 then yarnball(c, cx + R * 0.42, cy + R * 0.78, R * 0.08) end
end

-- ─── a day: a mug of cocoa, filling with the pages ───────────────────────────

function D.day(c, cx, cy, d, fp, fm, tone, o)
    if o.future then
        mug(c, cx, cy, d * 0.55, 0, mix(MUG, tone.bg, 0.65))
        return true
    end
    fp, fm = clamp01(fp), clamp01(fm)
    mug(c, cx, cy + d * 0.05, d * 0.7, fp, (fp >= 1) and MUG2 or MUG)
    if fm >= 1 then
        c:disc(cx - d * 0.06, cy - d * 0.12, d * 0.06, MALLOW)
        c:disc(cx + d * 0.06, cy - d * 0.14, d * 0.06, MALLOW)
        c:polyline({ cx, cy - d * 0.25, cx + d * 0.04, cy - d * 0.42 }, max(1, d * 0.03), mix(STEAM, tone.fg, 0.2))
    end
    if o.today then c:ring(cx, cy, d * 0.48, max(1.5, d * 0.04), 1, BRICK, BRICK) end
    return true
end

-- ─── bar charts: brick chimneys ──────────────────────────────────────────────

function D.chartBar(c, x, y, w, h, tone, fill, o)
    if w < 4 or h < 4 then return false end
    bricks(c, x, y + w * 0.2, w, max(1, h - w * 0.2), max(3, w * 0.22))
    c:rect(floor(x - w * 0.08), floor(y), floor(w * 1.16), max(2, floor(w * 0.22)), BRICK_D)
    if o.current then
        for k = 1, 3 do c:disc(x + w * (0.5 + 0.12 * k), y - w * 0.3 * k, w * (0.15 + 0.05 * k), STEAM) end
    end
    return true
end

-- ─── the year goal: a patchwork quilt, one patch per book ───────────────────

function D.goal(c, x, y, w, h, done, target, tone)
    local n = (target and target > 0) and min(target, 24) or 12
    local per = (target and target > 0) and target / n or 1
    local lit = (target and target > 0) and floor(min(done or 0, target) / per + 1e-6) or 0
    local cols = (n <= 6) and 3 or ((n <= 12) and 4 or 6)
    local rows = max(1, floor((n + cols - 1) / cols))
    local side = min(w * 0.9 / cols, h * 0.92 / rows)
    local qw, qh = side * cols, side * rows
    local qx, qy = x + (w - qw) / 2, y + (h - qh) / 2
    c:rect(floor(qx - side * 0.08), floor(qy - side * 0.08), floor(qw + side * 0.16), floor(qh + side * 0.16), BRICK_D)
    for i = 1, cols * rows do
        local row, col = floor((i - 1) / cols), (i - 1) % cols
        local px, py = qx + side * col, qy + side * row
        if i <= lit and i <= n then
            local a = QUILT[(i - 1) % #QUILT + 1]
            local b = QUILT[(i + 2) % #QUILT + 1]
            c:rect(floor(px), floor(py), floor(side - 1), floor(side - 1), a)
            if i % 3 == 0 then tri(c, px + side / 2, py + side * 0.15, py + side * 0.85, side * 0.35, b)
            elseif i % 3 == 1 then c:rect(floor(px + side * 0.25), floor(py + side * 0.25), floor(side * 0.5), floor(side * 0.5), b)
            else c:disc(px + side / 2, py + side / 2, side * 0.28, b) end
        else
            c:rect(floor(px), floor(py), floor(side - 1), floor(side - 1), mix(WALL, tone.bg, 0.4))
            c:polyline({ px + side * 0.2, py + side * 0.2, px + side * 0.8, py + side * 0.8 }, 1, mix(MORTAR, tone.bg, 0.3))
        end
    end
    return true
end

-- ─── the challenge: a scarf on the needles, growing ──────────────────────────

function D.challenge(c, cx, cy, R, frac, tone, fill)
    frac = clamp01(frac)
    local top = cy - R * 0.62
    local sw = R * 0.5
    c:polyline({ cx - R * 0.6, top - R * 0.12, cx + R * 0.15, top + R * 0.02 }, max(2, R * 0.04), MANTEL)
    c:polyline({ cx + R * 0.6, top - R * 0.12, cx - R * 0.15, top + R * 0.02 }, max(2, R * 0.04), MANTEL)
    local len = R * 1.4 * max(0.05, frac)
    local stripe = R * 0.12
    local yy = top
    local k = 0
    while yy < top + len do
        local hh = min(stripe, top + len - yy)
        c:rect(floor(cx - sw / 2), floor(yy), floor(sw), max(1, floor(hh)), SCARF[k % #SCARF + 1])
        yy = yy + stripe
        k = k + 1
    end
    for kk = 0, floor(sw / 4) do c:rect(floor(cx - sw / 2 + kk * 4), floor(top), 1, floor(len), mix(BLACK, WHITE, 0.6)) end
    if frac >= 1 then
        for t = -2, 2 do c:polyline({ cx + t * sw * 0.2, top + len, cx + t * sw * 0.22, top + len + R * 0.18 }, max(1, R * 0.03), SCARF[1]) end
    end
    yarnball(c, cx + R * 0.55, cy + R * 0.62, R * 0.2)
    c:polyline({ cx + R * 0.4, cy + R * 0.55, cx + sw * 0.3, top + R * 0.02 }, max(1, R * 0.015), YARN)
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
