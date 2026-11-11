-- Lanterns: cream cards on a festival-red page, lantern gold and red.
return {
    api = 1,
    id = "lanterns",
    version = "2.1",
    name = "Lanterns",
    description = "A paper lantern for the rings: it fills red with your pages, glows and grows its tassel with your minutes, and shines when both are done. Small lanterns for the days, tall lanterns for the bar charts, a row of lanterns under the eaves for the year goal and a dragon dance chasing the pearl for the challenge.",
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
        surface = { 255, 238, 221 }, tint = { 255, 221, 187 }, fg = { 68, 17, 0 }, border = { 187, 136, 0 },
        page = { 119, 0, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Lantern Gold", deep = { 204, 136, 0 }, bright = { 255, 204, 51 } },
        accent2 = { label = "Festival Red", deep = { 187, 0, 34 }, bright = { 255, 68, 68 } },
    },
    draw = "draw.lua",
}
