-- Poppy: white cards on a field-green page, poppy red and wheat gold.
return {
    api = 1,
    id = "poppy",
    version = "2.1",
    name = "Poppy",
    description = "A poppy in a wheat field for the rings: its petals turn red with your pages, more poppies open in the field with your minutes and a dove flies over when both are done. Buds that bloom for the days, poppies on tall stems for the bar charts, a poppy field for the year goal and a wreath of poppies for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "plaque",
        streak_flame_look = "candle",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 238, 238, 221 }, fg = { 34, 51, 34 }, border = { 136, 153, 119 },
        page = { 34, 68, 34 }, page_fg = { 255, 255, 238 }, square = true,
        accent = { label = "Poppy Red", deep = { 204, 34, 34 }, bright = { 255, 85, 85 } },
        accent2 = { label = "Wheat Gold", deep = { 187, 136, 34 }, bright = { 238, 204, 102 } },
    },
    draw = "draw.lua",
}
