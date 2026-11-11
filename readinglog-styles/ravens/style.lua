-- Ravens: pale cards on a moonlit-violet page, raven blue and moon silver.
return {
    api = 1,
    id = "ravens",
    version = "2.1",
    name = "Ravens",
    description = "A moonlit branch for the rings: the moon waxes with your pages, ravens gather on the branch with your minutes and their trinket glints when both are done. Moon phases for the days, feathers for the bar charts, a raven's nest of shiny trinkets for the year goal and a raven crossing the moon for the challenge.",
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
        surface = { 238, 238, 255 }, tint = { 221, 221, 238 }, fg = { 34, 34, 51 }, border = { 119, 119, 153 },
        page = { 51, 34, 85 }, page_fg = { 238, 238, 255 }, square = true,
        accent = { label = "Raven Blue", deep = { 51, 68, 119 }, bright = { 136, 153, 221 } },
        accent2 = { label = "Moon Silver", deep = { 119, 119, 136 }, bright = { 204, 204, 221 } },
    },
    draw = "draw.lua",
}
