-- Fair: cream cards on an evening-purple page, fairground red and midway
-- gold.
return {
    api = 1,
    id = "fair",
    version = "2.1",
    name = "Fair",
    description = "A Ferris wheel at dusk for the rings: its cars light up with your pages, the rim lights come on with your minutes and balloons float up when both are done. Balloons that fill for the days, cotton candy for the bar charts, a prize shelf of teddy bears for the year goal and the high striker ringing the bell for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "neon",
        streak_flame_look = "neon",
        device_look = "monitor",
        pages_today_look = "counter",
        pages_turned_look = "counter",
        total_pages_look = "counter",
    },
    theme = {
        surface = { 255, 255, 238 }, tint = { 238, 221, 255 }, fg = { 51, 34, 68 }, border = { 153, 102, 187 },
        page = { 51, 34, 85 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Fairground Red", deep = { 204, 34, 68 }, bright = { 255, 85, 119 } },
        accent2 = { label = "Midway Gold", deep = { 187, 136, 17 }, bright = { 255, 204, 68 } },
    },
    draw = "draw.lua",
}
