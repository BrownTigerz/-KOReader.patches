-- Maple: cream cards on a sugar-shack brown page, maple red and syrup amber.
return {
    api = 1,
    id = "maple",
    version = "2.1",
    name = "Maple",
    description = "Sugaring season for the rings: a sap bucket on a maple fills with your pages, drips fall and the sugar shack steams with your minutes. Maple leaves that turn red for the days, syrup bottles for the bar charts, a stack of pancakes for the year goal and a jug of syrup filling up for the challenge.",
    author = "BrownTigerz",
    looks = {
        device_look = "candle",
        pages_today_look = "card",
        total_pages_look = "ledger",
    },
    theme = {
        surface = { 255, 255, 238 }, tint = { 255, 238, 204 }, fg = { 51, 34, 17 }, border = { 204, 119, 34 },
        page = { 85, 51, 17 }, page_fg = { 255, 238, 204 }, square = true,
        accent = { label = "Maple Red", deep = { 204, 51, 17 }, bright = { 255, 102, 51 } },
        accent2 = { label = "Amber", deep = { 204, 136, 0 }, bright = { 255, 187, 51 } },
    },
    draw = "draw.lua",
}
