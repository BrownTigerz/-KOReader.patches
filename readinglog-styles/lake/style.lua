-- Lake: white cards on a deep lake-blue page, lake blue and pine green
-- with a paddleboard orange. A lake in a round window for the rings, lily
-- pads for the days, pines for the bar charts, a canoe rack for the year
-- goal and a paddleboard crossing to an island for the challenge.
return {
    api = 1,
    id = "lake",
    version = "2.1",
    name = "Lake",
    description = "A lake in a round window for the rings: the water rises with your pages, the sun climbs over the pines with your minutes and a paddleboarder heads out when both are done. Lily pads that flower for the days, pines for the bar charts, a canoe rack for the year goal and a paddleboard crossing to an island for the challenge.",
    author = "BrownTigerz",
    looks = {
        pages_today_look = "note",
        pages_turned_look = "book",
    },
    theme = {
        surface = { 255, 255, 255 }, tint = { 221, 238, 255 }, fg = { 17, 51, 68 }, border = { 68, 136, 187 },
        page = { 17, 51, 85 }, page_fg = { 238, 238, 255 }, square = true,
        accent = { label = "Lake Blue", deep = { 34, 119, 204 }, bright = { 102, 187, 255 } },
        accent2 = { label = "Pine", deep = { 34, 119, 68 }, bright = { 119, 204, 136 } },
    },
    draw = "draw.lua",
}
