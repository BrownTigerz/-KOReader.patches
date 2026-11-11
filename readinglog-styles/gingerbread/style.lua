-- Gingerbread: cream cards on a gingerbread-brown page, candy red and mint.
return {
    api = 1,
    id = "gingerbread",
    version = "2.1",
    name = "Gingerbread",
    description = "A gingerbread house for the rings: the icing is piped on with your pages, gumdrops go on and the windows light with your minutes and the chimney smokes when both are done. Gingerbread cookies iced for the days, candy canes for the bar charts, a tray of cookies for the year goal and a gingerbread man running for the finish for the challenge.",
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
        surface = { 255, 255, 238 }, tint = { 255, 238, 204 }, fg = { 68, 34, 17 }, border = { 153, 102, 51 },
        page = { 102, 68, 34 }, page_fg = { 255, 255, 238 }, square = true,
        accent = { label = "Candy Red", deep = { 204, 34, 34 }, bright = { 255, 102, 85 } },
        accent2 = { label = "Mint", deep = { 34, 153, 102 }, bright = { 102, 221, 153 } },
    },
    draw = "draw.lua",
}
