-- Pumpkin: cream cards on a night-brown page, pumpkin orange and vine green.
return {
    api = 1,
    id = "pumpkin",
    version = "2.1",
    name = "Pumpkin",
    description = "A pumpkin patch at dusk for the rings: the pumpkin ripens with your pages, its carved face glows with your minutes and bats fly out when both are done. Pumpkins that ripen for the days, candy corn for the bar charts, pumpkins on the vine for the year goal and a hayride to the barn for the challenge.",
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
        surface = { 255, 255, 238 }, tint = { 255, 238, 204 }, fg = { 51, 34, 17 }, border = { 170, 102, 34 },
        page = { 51, 34, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Pumpkin", deep = { 221, 119, 17 }, bright = { 255, 153, 51 } },
        accent2 = { label = "Vine Green", deep = { 68, 136, 34 }, bright = { 119, 204, 85 } },
    },
    draw = "draw.lua",
}
