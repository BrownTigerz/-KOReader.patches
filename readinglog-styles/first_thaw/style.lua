-- First Thaw: white cards on a meltwater-blue page, meltwater blue and first
-- green.
return {
    api = 1,
    id = "first_thaw",
    version = "2.1",
    name = "First Thaw",
    description = "Spring melt for the rings: the snow melts off the field with your pages, crocuses come up with your minutes and a robin and the sun come out when both are done. Icicles dripping for the days, snowdrops for the bar charts, crocuses breaking through the snow for the year goal and the river ice breaking up for the challenge.",
    author = "BrownTigerz",
    looks = {
        pages_today_look = "note",
        pages_turned_look = "worm",
        total_pages_look = "worm",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 238, 238, 255 }, fg = { 34, 51, 68 }, border = { 136, 170, 204 },
        page = { 34, 68, 102 }, page_fg = { 238, 255, 255 }, square = true,
        accent = { label = "Meltwater", deep = { 0, 119, 187 }, bright = { 85, 187, 255 } },
        accent2 = { label = "First Green", deep = { 34, 136, 68 }, bright = { 119, 221, 136 } },
    },
    draw = "draw.lua",
}
