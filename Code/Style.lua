local env = select(2, ...)
local Config = env.Config
local CallbackRegistry = env.modules:Import("packages\\callback-registry")
local SavedVariables = env.modules:Import("packages\\saved-variables")
local GoatStyle = env.modules:Import("packages\\goatway-style")
local Style = env.modules:New("@\\Style")

-- The in-world accent: the marker's stroke, the beam, the pinpoint's top
-- rule and chevrons, the Navigator and the halo's notch. Like the GoatQuest
-- viewer, it is the class colour or a colour the player picks, and by default
-- it simply follows GoatQuest so the two add-ons always match.
--
-- Callback: "Style.AccentChanged" (r, g, b) whenever the resolved accent
-- changes, including when it is changed in GoatQuest's options.

local UnitClass = UnitClass
local pcall = pcall
local type = type

-- Used only when neither CUSTOM_CLASS_COLORS, C_ClassColor nor
-- RAID_CLASS_COLORS is available (same table as GoatQuest).
local CLASS_FALLBACK = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 }, PRIEST = { 1.00, 1.00, 1.00 }, SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 }, MONK = { 0.00, 1.00, 0.60 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
    EVOKER = { 0.20, 0.58, 0.50 }
}

local GOLD = GoatStyle.Color.Gold

--- GoatQuest's public namespace, when GoatQuest is loaded.
function Style.GetGoatQuest()
    local gq = _G.GoatQuest
    if type(gq) == "table" then return gq end
end

function Style.GetClassColor()
    local _, class = UnitClass("player")
    if not class then return GOLD.r, GOLD.g, GOLD.b end
    local c = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]
    if not c and C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(class) end
    if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[class] end
    if c and c.r then return c.r, c.g, c.b end
    c = CLASS_FALLBACK[class]
    if c then return c[1], c[2], c[3] end
    return GOLD.r, GOLD.g, GOLD.b
end

--- The GoatQuest viewer's accent, or nil when GoatQuest (or its viewer) is
--- not loaded yet.
function Style.GetGoatQuestAccent()
    local gq = Style.GetGoatQuest()
    local styles = gq and gq.Styles
    if not (styles and styles.GetAccent and gq.db) then return end
    local ok, r, g, b = pcall(styles.GetAccent, styles)
    if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
end

--- The accent as r, g, b.
function Style.GetAccentRGB()
    local mode = Config.DBGlobal and Config.DBGlobal:GetVariable("AccentColorMode") or env.Enum.AccentMode.GoatQuest
    local AccentMode = env.Enum.AccentMode

    if mode == AccentMode.Class then
        return Style.GetClassColor()
    elseif mode == AccentMode.Gold then
        return GOLD.r, GOLD.g, GOLD.b
    elseif mode == AccentMode.Custom then
        local c = Config.DBGlobal:GetVariable("AccentColor")
        if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
            return c.r, c.g, c.b
        end
        return GOLD.r, GOLD.g, GOLD.b
    end

    local r, g, b = Style.GetGoatQuestAccent()
    if r then return r, g, b end
    return GOLD.r, GOLD.g, GOLD.b
end

--- The accent as a fresh { r, g, b, a } table, the shape the frames tint with.
function Style.GetAccent()
    local r, g, b = Style.GetAccentRGB()
    return { r = r, g = g, b = b, a = 1 }
end

-- Watch for changes. GoatQuest has no event for its accent, so a one-second
-- ticker compares; settings changes here fire at once.
do
    local lastR, lastG, lastB

    function Style.CheckAccent(force)
        local r, g, b = Style.GetAccentRGB()
        if not force and r == lastR and g == lastG and b == lastB then return end
        lastR, lastG, lastB = r, g, b
        CallbackRegistry.Trigger("Style.AccentChanged", r, g, b)
    end

    local function ForceCheck() Style.CheckAccent(true) end
    SavedVariables.OnChange("GoatWayDB_Global", "AccentColorMode", ForceCheck)
    SavedVariables.OnChange("GoatWayDB_Global", "AccentColor", ForceCheck)

    CallbackRegistry.Add("Preload.AddonReady", function()
        Style.CheckAccent(true)
        C_Timer.NewTicker(1, function() Style.CheckAccent(false) end)
    end)
end
