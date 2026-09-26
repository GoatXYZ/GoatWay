local env = select(2, ...)
local UIFont = env.modules:Import("packages\\ui-font")
local UIFont_FontUtil = env.modules:Import("packages\\ui-font\\font-util")

-- In-world text. The files are set from the Font option in Preload.lua
-- (FontHandler); with the default Archivo family the destination name is
-- SemiBold, and distance and arrival time use the narrow cut, as in the
-- GoatQuest viewer.

local function WorldFont(name, size)
    local font = UIFont_FontUtil:CreateFontObject(name)
    font:SetFont(GameFontNormal:GetFont(), size, "")
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
    return font
end

UIFont.GoatWayFooterTitleFont = WorldFont("GoatWayFooterTitleFont", 10)
UIFont.GoatWayFooterFont = WorldFont("GoatWayFooterFont", 10)
UIFont.GoatWayPinpointFont = WorldFont("GoatWayPinpointFont", 11)
