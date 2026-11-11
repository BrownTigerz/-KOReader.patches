-- Rain: pale cards on a storm-blue page, rain blue and raincoat yellow.
return {
    api = 1,
    id = "rain",
    version = "2.1",
    name = "Rain",
    description = "A rain gauge for the rings: it fills with your pages, the rain comes down with your minutes and a rainbow comes out when both are done. Raindrops that fill for the days, rain boots for the bar charts, an umbrella stand for the year goal and a paper boat sailing to the rainbow for the challenge.",
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
        surface = { 238, 238, 255 }, tint = { 221, 221, 238 }, fg = { 34, 51, 68 }, border = { 102, 136, 187 },
        page = { 51, 68, 119 }, page_fg = { 255, 255, 255 }, square = true,
        accent = { label = "Rain Blue", deep = { 17, 102, 204 }, bright = { 85, 170, 255 } },
        accent2 = { label = "Raincoat Yellow", deep = { 204, 153, 0 }, bright = { 255, 221, 51 } },
    },
    draw = "draw.lua",
}
