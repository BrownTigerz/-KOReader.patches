-- Library: cream cards on a walnut page, burgundy and ink blue.
return {
    api = 1,
    id = "library",
    version = "2.1",
    name = "Library",
    description = "A reading desk in the library for the rings: the open book fills with lines as you read your pages, the green lamp warms up with your minutes and a bookmark and a cup of tea appear when both are done. Books that open for the days, stacks of books for the bar charts, a bookshelf for the year goal and the library ladder for the challenge.",
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
        surface = { 255, 255, 238 }, tint = { 238, 221, 187 }, fg = { 51, 34, 17 }, border = { 153, 119, 68 },
        page = { 68, 34, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Burgundy", deep = { 136, 34, 51 }, bright = { 221, 102, 119 } },
        accent2 = { label = "Ink Blue", deep = { 34, 68, 136 }, bright = { 102, 153, 221 } },
    },
    draw = "draw.lua",
}
