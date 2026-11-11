-- Fireworks: cream cards on a night-sky page, rocket red and spark gold.
return {
    api = 1,
    id = "fireworks",
    version = "2.1",
    name = "Fireworks",
    description = "A city skyline at night for the rings: a rocket climbs with your pages and bursts open, more fireworks go off with your minutes and a finale lights the sky when both are done. Bursts that grow for the days, rockets for the bar charts, a sky full of fireworks for the year goal and a countdown clock to midnight for the challenge.",
    author = "BrownTigerz",
    looks = {
        books_year_look = "neon",
        streak_flame_look = "neon",
        device_look = "monitor",
        pages_today_look = "counter",
        pages_turned_look = "counter",
        total_pages_look = "counter",
    },
    theme = {
        surface = { 255, 255, 238 }, tint = { 238, 238, 255 }, fg = { 34, 34, 51 }, border = { 102, 102, 153 },
        page = { 17, 17, 51 }, page_fg = { 255, 255, 255 }, square = true,
        accent = { label = "Rocket Red", deep = { 204, 17, 51 }, bright = { 255, 85, 102 } },
        accent2 = { label = "Spark Gold", deep = { 204, 153, 0 }, bright = { 255, 204, 51 } },
    },
    draw = "draw.lua",
}
