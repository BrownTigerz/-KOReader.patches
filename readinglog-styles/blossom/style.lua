-- Blossom: white cards on a plum page, blossom pink and branch brown.
return {
    api = 1,
    id = "blossom",
    version = "2.1",
    name = "Blossom",
    description = "A cherry branch for the rings: blossoms open along it with your pages, petals drift down with your minutes and a little bird lands when both are done. Buds that open for the days, blossom sprigs in vases for the bar charts, a garland of blossoms for the year goal and a folding fan opening for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "heart",
        streak_flame_look = "heart",
        device_look = "hearts",
        pages_today_look = "note",
        pages_turned_look = "worm",
        total_pages_look = "worm",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 255, 238, 238 }, fg = { 68, 34, 51 }, border = { 204, 136, 170 },
        page = { 102, 34, 68 }, page_fg = { 255, 238, 238 }, square = true,
        accent = { label = "Blossom Pink", deep = { 204, 51, 119 }, bright = { 255, 136, 187 } },
        accent2 = { label = "Branch Brown", deep = { 119, 68, 34 }, bright = { 187, 136, 85 } },
    },
    draw = "draw.lua",
}
