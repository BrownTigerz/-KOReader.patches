-- Hearth: white cards on a brick-red page, brick and flame gold.
return {
    api = 1,
    id = "hearth",
    version = "2.1",
    name = "Hearth",
    description = "A fireplace for the rings: the fire builds with your pages, the kettle steams and the mug fills with your minutes, and the cat curls up on the rug when both are done. Mugs of cocoa for the days, brick chimneys for the bar charts, a patchwork quilt for the year goal and a scarf being knitted for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 255, 238, 204 }, fg = { 68, 34, 17 }, border = { 170, 102, 51 },
        page = { 119, 34, 17 }, page_fg = { 255, 238, 221 }, square = true,
        accent = { label = "Brick", deep = { 170, 51, 34 }, bright = { 221, 102, 68 } },
        accent2 = { label = "Flame Gold", deep = { 204, 136, 17 }, bright = { 255, 187, 51 } },
    },
    draw = "draw.lua",
}
