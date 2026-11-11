-- Golden Wheat: white cards on a harvest-brown page, wheat gold and barn
-- red.
return {
    api = 1,
    id = "golden_wheat",
    version = "2.1",
    name = "Golden Wheat",
    description = "Harvest on the farm for the rings: the silo fills with grain with your pages, the windmill turns with your minutes and the harvest moon rises when both are done. Sheaves for the days, wheat stalks for the bar charts, round hay bales for the year goal and the combine cutting the field for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "plaque",
        pages_turned_look = "book",
        total_pages_look = "ledger",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 255, 238, 187 }, fg = { 68, 51, 17 }, border = { 187, 153, 68 },
        page = { 85, 51, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Wheat Gold", deep = { 187, 136, 17 }, bright = { 238, 204, 85 } },
        accent2 = { label = "Barn Red", deep = { 170, 34, 34 }, bright = { 238, 102, 85 } },
    },
    draw = "draw.lua",
}
