-- Campfire: cream cards on a night-forest page, ember orange and fire gold.
return {
    api = 1,
    id = "campfire",
    version = "2.1",
    name = "Campfire",
    description = "A campfire under the stars for the rings: the fire builds with your pages, sparks fly and a marshmallow toasts with your minutes, and the tent glows when both are done. Flames for the days and the bar charts, a stack of s'mores for the year goal and a trail up the mountain to the tent for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "plaque",
        streak_flame_look = "candle",
        device_look = "candle",
        pages_today_look = "card",
        pages_turned_look = "book",
        total_pages_look = "ledger",
    },
    theme = {
        surface = { 255, 238, 204 }, tint = { 238, 221, 187 }, fg = { 51, 34, 17 }, border = { 136, 85, 51 },
        page = { 34, 34, 51 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Ember Orange", deep = { 204, 85, 17 }, bright = { 255, 136, 51 } },
        accent2 = { label = "Fire Gold", deep = { 187, 136, 17 }, bright = { 255, 204, 68 } },
    },
    draw = "draw.lua",
}
