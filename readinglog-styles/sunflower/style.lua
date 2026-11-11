-- Sunflower: white cards on a field-green page, sunflower yellow and seed
-- brown.
return {
    api = 1,
    id = "sunflower",
    version = "2.1",
    name = "Sunflower",
    description = "One big sunflower for the rings: seeds fill its middle with your pages, its petals light up with your minutes and a bee lands when both are done. Sunflowers that open for the days, tall stalks for the bar charts, sunflowers peeking over the fence for the year goal and a sunflower growing past the measuring stick for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 255, 255, 221 }, fg = { 68, 51, 17 }, border = { 170, 153, 51 },
        page = { 51, 85, 34 }, page_fg = { 255, 255, 221 }, square = true,
        accent = { label = "Sunflower Yellow", deep = { 204, 153, 0 }, bright = { 255, 221, 51 } },
        accent2 = { label = "Seed Brown", deep = { 119, 68, 17 }, bright = { 187, 136, 68 } },
    },
    draw = "draw.lua",
}
