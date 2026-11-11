-- Meadow: white cards on a sky-blue page, grass green and wildflower pink.
return {
    api = 1,
    id = "meadow",
    version = "2.1",
    name = "Meadow",
    description = "A hillside meadow for the rings: wildflowers bloom across it with your pages, a kite climbs with your minutes and butterflies come when both are done. Daisies for the days, tufts of wildflowers for the bar charts, a bouquet in a jar for the year goal and a kite flying higher for the challenge.",
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
        surface = { 255, 255, 255 }, tint = { 238, 255, 221 }, fg = { 34, 68, 34 }, border = { 102, 170, 85 },
        page = { 34, 85, 136 }, page_fg = { 238, 255, 255 }, square = true,
        accent = { label = "Grass Green", deep = { 51, 136, 51 }, bright = { 119, 204, 102 } },
        accent2 = { label = "Wildflower Pink", deep = { 204, 68, 136 }, bright = { 255, 136, 187 } },
    },
    draw = "draw.lua",
}
