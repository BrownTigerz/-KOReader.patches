-- Garden: white cards on a soil-brown page, leaf green and tomato red.
return {
    api = 1,
    id = "garden",
    version = "2.1",
    name = "Garden",
    description = "A raised garden bed for the rings: tomatoes, carrots and lettuce grow with your pages, the watering can pours with your minutes and a butterfly visits when both are done. Seeds that sprout for the days, carrots for the bar charts, a harvest crate for the year goal and a wheelbarrow full of vegetables for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 238, 255, 221 }, fg = { 51, 51, 34 }, border = { 119, 153, 85 },
        page = { 68, 51, 34 }, page_fg = { 238, 255, 221 }, square = true,
        accent = { label = "Leaf Green", deep = { 51, 136, 34 }, bright = { 119, 204, 85 } },
        accent2 = { label = "Tomato Red", deep = { 204, 51, 34 }, bright = { 255, 119, 85 } },
    },
    draw = "draw.lua",
}
