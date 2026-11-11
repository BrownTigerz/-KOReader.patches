-- Star: pale cards on a midnight page, star gold and night blue.
return {
    api = 1,
    id = "star",
    version = "2.1",
    name = "Star",
    description = "A wishing star over a sleeping village for the rings: the star's points light with your pages, more stars come out and windows glow with your minutes and the star shines when both are done. Stars filling with gold for the days, stacks of stars for the bar charts, an advent calendar of doors for the year goal and a shooting star crossing the sky for the challenge.",
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
        surface = { 238, 238, 255 }, tint = { 221, 221, 238 }, fg = { 34, 34, 68 }, border = { 119, 119, 170 },
        page = { 17, 17, 68 }, page_fg = { 255, 238, 170 }, square = true,
        accent = { label = "Star Gold", deep = { 187, 136, 0 }, bright = { 255, 221, 68 } },
        accent2 = { label = "Night Blue", deep = { 51, 68, 153 }, bright = { 136, 153, 255 } },
    },
    draw = "draw.lua",
}
