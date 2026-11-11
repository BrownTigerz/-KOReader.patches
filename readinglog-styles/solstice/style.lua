-- Solstice: white cards on a dusk-orange page, sun gold and sky blue.
return {
    api = 1,
    id = "solstice",
    version = "2.1",
    name = "Solstice",
    description = "Midsummer for the rings: the sun rises between the standing stones with your pages, its rays reach out with your minutes and a halo rings it when both are done. The sun's path across each day, standing stones for the bar charts, a midsummer flower crown for the year goal and a maypole wrapping in ribbons for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "plaque",
        pages_today_look = "note",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 255, 238, 204 }, fg = { 68, 51, 17 }, border = { 221, 153, 51 },
        page = { 153, 68, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Sun Gold", deep = { 204, 136, 0 }, bright = { 255, 204, 51 } },
        accent2 = { label = "Sky Blue", deep = { 34, 119, 187 }, bright = { 102, 187, 255 } },
    },
    draw = "draw.lua",
}
