-- Autumn Leaves: white cards on a rust page, rust red and autumn gold.
return {
    api = 1,
    id = "autumn_leaves",
    version = "2.1",
    name = "Autumn Leaves",
    description = "A park bench in the fall for the rings: the leaf pile grows with your pages, leaves drift down with your minutes and a squirrel comes by when both are done. Leaves turning colour for the days, columns of leaves for the bar charts, a scrapbook of pressed leaves for the year goal and a leaf pile big enough to jump in for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 255, 238, 204 }, fg = { 51, 34, 17 }, border = { 187, 119, 68 },
        page = { 119, 51, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Rust Red", deep = { 187, 68, 17 }, bright = { 255, 119, 68 } },
        accent2 = { label = "Autumn Gold", deep = { 204, 153, 17 }, bright = { 255, 204, 51 } },
    },
    draw = "draw.lua",
}
