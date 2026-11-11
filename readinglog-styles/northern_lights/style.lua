-- Northern Lights: cream cards on a midnight page, aurora green and violet.
return {
    api = 1,
    id = "northern_lights",
    version = "2.1",
    name = "Northern Lights",
    description = "A winter night in a round window for the rings: the aurora grows with your pages, stars come out and the cabin lights up with your minutes. Night skies with an aurora streak for the days, aurora curtains for the bar charts, an igloo built block by block for the year goal and a dog sled racing to the cabin for the challenge.",
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
        surface = { 255, 255, 238 }, tint = { 238, 238, 221 }, fg = { 17, 34, 51 }, border = { 102, 136, 187 },
        page = { 0, 17, 51 }, page_fg = { 238, 255, 255 }, square = true,
        accent = { label = "Aurora Green", deep = { 0, 153, 102 }, bright = { 0, 238, 153 } },
        accent2 = { label = "Violet", deep = { 102, 51, 204 }, bright = { 170, 136, 255 } },
    },
    draw = "draw.lua",
}
