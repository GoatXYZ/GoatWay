local env = select(2, ...)
local L = env.L
local Config = env.Config
local Path = env.modules:Import("packages\\path")
local SavedVariables = env.modules:Import("packages\\saved-variables")
local MapPin = env.modules:Import("@\\MapPin")
local SupportedAddons = env.modules:Import("@\\SupportedAddons")
local Style = env.modules:Import("@\\Style")
local SupportedAddons_GoatQuest = env.modules:New("@\\SupportedAddons\\GoatQuest")

-- Follows GoatQuest's guide arrow. Whatever the arrow points at (the step's
-- waypoint, or the next leg of a travel route such as a flight master) becomes
-- GoatWay's destination: an in-world marker with the step's title and the goat
-- as its icon, tinted with the accent GoatQuest uses.
--
-- GoatQuest's arrow keeps its waypoint on GoatQuest.Pointer.ArrowFrame.waypoint
-- (map ID and 0-1 coordinates). GoatWay post-hooks Pointer:ShowArrow and
-- Pointer:HideArrow for an immediate update, and checks twice a second in case
-- the arrow is changed some other way. Only a new location re-navigates: the
-- title carries live progress (3/8 boars), and re-navigating on each kill
-- would replay the marker's intro every time.
--
-- Corpse arrows are left alone; the game already tracks your corpse.

SupportedAddons_GoatQuest.FLAG = "GoatQuest_Waypoint"
SupportedAddons_GoatQuest.ICON = Path.Root .. "\\Art\\Icons\\GoatQuest"

local FLAG = SupportedAddons_GoatQuest.FLAG
local POLL_INTERVAL = 0.5
local SAME_PLACE = 0.0002 -- map units; about a yard on a typical zone

local type, tonumber, pcall, abs = type, tonumber, pcall, math.abs

local function IsModuleEnabled() return Config.DBGlobal:GetVariable("GoatQuestSupportEnabled") == true end

-- What GoatWay last took from the arrow, and a location the player declined.
local followed = { mapID = nil, x = nil, y = nil }
local declined = { mapID = nil, x = nil, y = nil }
local pending = { name = nil, mapID = nil, x = nil, y = nil }

local function SamePlace(a, mapID, x, y)
    return a.mapID == mapID and a.x and abs(a.x - x) < SAME_PLACE and abs(a.y - y) < SAME_PLACE
end

--- A single line of plain text: no colour codes, textures or second lines.
function SupportedAddons_GoatQuest.CleanTitle(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:match("^[^\n]*") or text
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return text
end

--- The waypoint GoatQuest's arrow points at: mapID, x, y (0-1) and a title,
--- or nil when there is none (or it is a corpse).
function SupportedAddons_GoatQuest.GetArrowWaypoint()
    local gq = Style.GetGoatQuest()
    local pointer = gq and gq.Pointer
    local frame = pointer and pointer.ArrowFrame
    local way = frame and frame.waypoint
    if type(way) ~= "table" or way.type == "corpse" then return end

    local mapID, x, y = tonumber(way.m), tonumber(way.x), tonumber(way.y)
    if not (mapID and x and y) then return end

    -- The fixed titles first; the arrow title can change with progress.
    local title = way.arrowtitle or way.title
    if not title and way.GetArrowTitle then
        local ok, text = pcall(way.GetArrowTitle, way)
        if ok then title = text end
    end
    return mapID, x, y, SupportedAddons_GoatQuest.CleanTitle(title)
end

local function Follow(name, mapID, x, y)
    followed.mapID, followed.x, followed.y = mapID, x, y
    MapPin.NewUserNavigation({
        name           = name or L["GOATQUEST_WAYPOINT"],
        mapID          = mapID,
        x              = x * 100,
        y              = y * 100,
        flags          = FLAG,
        iconTexture    = SupportedAddons_GoatQuest.ICON,
        requestRecolor = true,
        suppressAudio  = true
    })
end

local function HandleAccept()
    if pending.mapID then Follow(pending.name, pending.mapID, pending.x, pending.y) end
end

local function HandleDecline()
    declined.mapID, declined.x, declined.y = pending.mapID, pending.x, pending.y
end

local REPLACE_PROMPT_INFO = {
    text         = L["GOATQUEST_REPLACEPROMPT"],
    options      = {
        {
            text     = L["REPLACE"],
            callback = HandleAccept
        },
        {
            text     = L["CANCEL"],
            callback = HandleDecline
        }
    },
    hideOnEscape = true,
    timeout      = 10
}

--- Bring GoatWay's destination in line with GoatQuest's arrow.
function SupportedAddons_GoatQuest.Sync()
    if not IsModuleEnabled() then return end

    local mapID, x, y, name = SupportedAddons_GoatQuest.GetArrowWaypoint()
    if not mapID then
        followed.mapID, followed.x, followed.y = nil, nil, nil
        if MapPin.IsUserNavigationFlagged(FLAG) then MapPin.ClearUserNavigation() end
        return
    end

    if SamePlace(followed, mapID, x, y) or SamePlace(declined, mapID, x, y) then return end

    if Config.DBGlobal:GetVariable("GoatQuestAutoReplaceWaypoint") == true
        or not C_SuperTrack.IsSuperTrackingAnything()
        or MapPin.IsUserNavigationFlagged(FLAG) then
        Follow(name, mapID, x, y)
    else
        pending.name, pending.mapID, pending.x, pending.y = name, mapID, x, y
        -- Ask once per location, even if the prompt times out.
        declined.mapID, declined.x, declined.y = mapID, x, y
        GoatWaySharedPrompt:Open(REPLACE_PROMPT_INFO, name or L["GOATQUEST_WAYPOINT"])
    end
end

--- Forget what was followed, so the next Sync follows the arrow again.
function SupportedAddons_GoatQuest.Reset()
    followed.mapID, followed.x, followed.y = nil, nil, nil
    declined.mapID, declined.x, declined.y = nil, nil, nil
end

local function OnSettingChanged()
    SupportedAddons_GoatQuest.Reset()
    if IsModuleEnabled() then
        SupportedAddons_GoatQuest.Sync()
    elseif MapPin.IsUserNavigationFlagged(FLAG) then
        MapPin.ClearUserNavigation()
    end
end

local function OnAddonLoad()
    local syncQueued = false
    local function QueueSync()
        if syncQueued then return end
        syncQueued = true
        C_Timer.After(0, function()
            syncQueued = false
            SupportedAddons_GoatQuest.Sync()
        end)
    end

    local gq = Style.GetGoatQuest()
    local pointer = gq and gq.Pointer
    if pointer then
        for _, method in ipairs({ "ShowArrow", "HideArrow" }) do
            if type(pointer[method]) == "function" then hooksecurefunc(pointer, method, QueueSync) end
        end
    end
    C_Timer.NewTicker(POLL_INTERVAL, SupportedAddons_GoatQuest.Sync)
    QueueSync()

    -- Do not carry a guide waypoint into the next session; GoatQuest sets its
    -- arrow again on login and GoatWay follows it.
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDONS_UNLOADING")
    f:SetScript("OnEvent", function()
        if MapPin.IsUserNavigationFlagged(FLAG) then
            MapPin.ClearUserNavigation()
        end
    end)
end

SavedVariables.OnChange("GoatWayDB_Global", "GoatQuestSupportEnabled", OnSettingChanged)
SavedVariables.OnChange("GoatWayDB_Global", "GoatQuestAutoReplaceWaypoint", OnSettingChanged)

SupportedAddons.Add("GoatQuest", OnAddonLoad)
