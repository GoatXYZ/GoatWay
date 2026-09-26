local env = select(2, ...)
local Path = env.modules:Import("packages\\path")
local UIKit = env.modules:Import("packages\\ui-kit")
local GoatStyle = env.modules:New("packages\\goatway-style")

-- GoatQuest's design tokens, shared by the widgets, the settings and the
-- in-world frames. Flat ink and slate surfaces, white hairlines at low alpha,
-- square corners and one accent: GoatQuest gold in the settings, and the
-- accent the player picks (see Code/Style.lua) in the world.
-- Keep these in step with GoatQuest's Skins/Default/GoatQuest/Style.lua.

local function RGB(r, g, b)
    return { r = r / 255, g = g / 255, b = b / 255, a = 1 }
end

GoatStyle.Color = {
    Ink       = RGB(15, 17, 21),    -- #0F1115 window ground
    Slate     = RGB(21, 24, 29),    -- #15181D content column
    Ridge     = RGB(27, 31, 37),    -- #1B1F25 popups, menus
    Text      = RGB(236, 234, 230), -- #ECEAE6
    Soft      = RGB(197, 200, 205), -- #C5C8CD
    Muted     = RGB(141, 147, 156), -- #8D939C secondary text
    Dim       = RGB(111, 117, 126), -- #6F757E disabled
    Gold      = RGB(245, 191, 41),  -- #F5BF29 GoatQuest gold
    GoldHover = RGB(247, 204, 83),
    Blue      = RGB(122, 178, 235), -- repeatable and recurring quests
    Lilac     = RGB(205, 160, 240), -- important quests
    Orange    = RGB(240, 150, 70),  -- legendary quests
    White     = RGB(255, 255, 255),
    Black     = RGB(0, 0, 0)
}

GoatStyle.Hex = {}
for name, c in pairs(GoatStyle.Color) do
    GoatStyle.Hex[name] = string.format("|cff%02x%02x%02x", c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5)
end

--- A fresh UIKit colour (0-255 channels) for props such as :textColor().
--- UIKit converts colour values in place, so each use needs its own.
function GoatStyle.UIColor(name, alpha)
    local c = GoatStyle.Color[name]
    return UIKit.Define.Color_RGBA{ r = c.r * 255, g = c.g * 255, b = c.b * 255, a = alpha or 1 }
end

--- A plain colour table ({ r, g, b, a } in 0-1) for SetTextColor and SetColor.
function GoatStyle.RGBA(name, alpha)
    local c = GoatStyle.Color[name]
    return { r = c.r, g = c.g, b = c.b, a = alpha or 1 }
end

-- Fonts: static TTF instances shipped in Art/Fonts (SIL OFL; licences
-- alongside), the same files GoatQuest ships. A family gives each role its
-- own weight: body text, titles, and narrow numbers for distances.
GoatStyle.FONT_DIR = Path.Root .. "\\Art\\Fonts\\"
GoatStyle.Families = {
    {
        name   = "Archivo",
        body   = "Archivo-Regular.ttf",
        title  = "Archivo-SemiBold.ttf",
        number = "ArchivoNarrow-SemiBold.ttf"
    },
    {
        name   = "Atkinson Hyperlegible",
        body   = "AtkinsonHyperlegible-Regular.ttf",
        title  = "AtkinsonHyperlegible-Bold.ttf",
        number = "AtkinsonHyperlegible-Bold.ttf"
    }
}

-- None of the shipped fonts cover Cyrillic, Korean or Chinese.
local UNSUPPORTED_LOCALES = { koKR = true, zhCN = true, zhTW = true, ruRU = true }

function GoatStyle.HasFontCoverage()
    return not UNSUPPORTED_LOCALES[GetLocale()]
end

function GoatStyle.FamilyPath(family, role)
    return GoatStyle.FONT_DIR .. family[role or "body"]
end

--- The body, title and number fonts for the font setting. A GoatWay family
--- (stored as its body file) spreads over its weights; any other font is used
--- for every role.
function GoatStyle.ResolveFontRoles(fontPath)
    for _, family in ipairs(GoatStyle.Families) do
        if fontPath == GoatStyle.FamilyPath(family) then
            if not GoatStyle.HasFontCoverage() then break end
            return GoatStyle.FamilyPath(family, "body"), GoatStyle.FamilyPath(family, "title"), GoatStyle.FamilyPath(family, "number")
        end
    end
    if not fontPath or (not GoatStyle.HasFontCoverage() and fontPath:find(GoatStyle.FONT_DIR, 1, true)) then
        fontPath = GameFontNormal:GetFont()
    end
    return fontPath, fontPath, fontPath
end

--- A fixed GoatQuest face (the halo uses Atkinson Hyperlegible Bold), or the
--- game font where the shipped fonts have no glyphs.
function GoatStyle.FontPath(file)
    if not GoatStyle.HasFontCoverage() then return GameFontNormal:GetFont() end
    return GoatStyle.FONT_DIR .. file
end
