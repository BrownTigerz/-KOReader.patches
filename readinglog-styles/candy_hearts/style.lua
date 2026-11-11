-- Candy Hearts: white cards on a raspberry page, heart red and candy pink.
return {
    api = 1,
    id = "candy_hearts",
    version = "2.1",
    name = "Candy Hearts",
    description = "A heart-shaped candy box for the rings: it fills red with your pages, lace runs round it with your minutes and a gold bow goes on when both are done. Conversation hearts for the days, stacks of candy hearts for the bar charts, a candy jar for the year goal and a box of chocolates for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 255, 238, 238 }, fg = { 68, 17, 34 }, border = { 221, 136, 170 },
        page = { 153, 17, 68 }, page_fg = { 255, 238, 238 }, square = true,
        accent = { label = "Heart Red", deep = { 204, 0, 51 }, bright = { 255, 85, 119 } },
        accent2 = { label = "Candy Pink", deep = { 221, 68, 136 }, bright = { 255, 153, 204 } },
    },
    draw = "draw.lua",
}
