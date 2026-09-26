local env = select(2, ...)
local L = env.L
local Config = env.Config
local Path = env.modules:Import("packages\\path")
local CallbackRegistry = env.modules:Import("packages\\callback-registry")
local SavedVariables = env.modules:Import("packages\\saved-variables")
local GoatStyle = env.modules:Import("packages\\goatway-style")
local SharedUtil = env.modules:Import("@\\SharedUtil")
local Style = env.modules:Import("@\\Style")
local Waypoint_Cache = env.modules:Import("@\\Waypoint\\Cache")
local Waypoint_Director = env.modules:Import("@\\Waypoint\\Director")
local Waypoint_Enum = env.modules:Import("@\\Waypoint\\Enum")
local Halo = env.modules:New("@\\Halo")

-- GoatQuest's Halo as a Navigator style: a ring at the character's feet whose
-- notch points toward the destination, with the distance just outside it. On
-- arrival the ring lights up in the accent and says so. Same art, maths and
-- look as GoatQuest's Styles/Halo.lua.
--
-- Addons cannot draw in the 3D world, so the ring is a flat overlay at a fixed
-- screen position: UIParent's centre plus an offset (GoatQuest's ring
-- position, or the Ring Height option), because the default camera keeps the
-- character near the middle of the screen. The ring is a foreshortened ellipse, so "ahead" is its far (top)
-- side and "left" is its left end.
--
-- Direction: for a user waypoint (GoatQuest's arrow, /way, map pins, TomTom)
-- and for Blizzard's next-waypoint redirects, the true bearing from the
-- player's world position and facing. Otherwise the on-screen direction from
-- the ring to Blizzard's navigation frame.
--
-- When GoatQuest's own halo is on screen, this one steps aside so the two
-- rings never overlap.

local sin, cos, sqrt, atan2, floor, abs, pi = math.sin, math.cos, math.sqrt, math.atan2, math.floor, math.abs, math.pi
local type, tonumber = type, tonumber
local CreateFrame = CreateFrame
local GetPlayerFacing = GetPlayerFacing
local HBD = LibStub("HereBeDragons-2.0")

local TEXDIR = Path.Root .. "\\Art\\Halo\\"

---------------------------------------------------------------------------
-- Look (GoatQuest Styles/Halo.lua)
---------------------------------------------------------------------------

local RING = { 0.969, 0.961, 0.941, 0.62 } -- #F7F5F0 at 62%
Halo.RING = RING

-- ring.tga is a 512x128 canvas holding a 250x58 ellipse whose 4.5px stroke is
-- drawn inward. RX/RY are that stroke's centre line once the texture is drawn
-- at RING_W x RING_H, so the notch sits exactly on the visible line.
local RING_W, RING_H = 280, 70
local RX = RING_W * (250 - 2.25) / 512
local RY = RING_H * (58 - 2.25) / 128
Halo.RX, Halo.RY = RX, RY
Halo.DEFAULT_OFFSET = -90

local DOTS = 9 -- odd, so the middle dot sits on the point
local DOT_STEP = 5
local DOT_SIZE, DOT_UNDER = 6, 10
local CHEV_SIZE, CHEV_UNDER = 24, 30
local CHEV1, CHEV2, TEXT_OFF = 12, 24, 44
local ANGLE_EPS = 0.002
local UPDATE_INTERVAL = 1 / 30
Halo.DOTS, Halo.DOT_STEP, Halo.CHEV1, Halo.CHEV2, Halo.TEXT_OFF = DOTS, DOT_STEP, CHEV1, CHEV2, TEXT_OFF

---------------------------------------------------------------------------
-- Pure maths (exposed for tests)
---------------------------------------------------------------------------

--- Point on the ground ellipse for a nav angle (radians relative to facing,
--- 0 = ahead = the far/top side, increasing counter-clockwise) and the unit
--- outward normal there. Returns x, y, nx, ny relative to the ring centre.
function Halo.EllipsePoint(angle, rx, ry)
    local s, c = sin(angle), cos(angle)
    local nx, ny = -s / rx, c / ry
    local len = sqrt(nx * nx + ny * ny)
    return -s * rx, c * ry, nx / len, ny / len
end

--- Rotation that turns an up-pointing texture to point along (nx, ny).
function Halo.NormalRotation(nx, ny)
    return atan2(ny, nx) - pi / 2
end

local function Speed(t, rx, ry)
    local s, c = sin(t), cos(t)
    return sqrt(rx * rx * c * c + ry * ry * s * s)
end

--- Ellipse parameter reached by walking a signed arc length from parameter t.
function Halo.ArcStep(t, rx, ry, dist)
    local mid = t + 0.5 * dist / Speed(t, rx, ry)
    return t + dist / Speed(mid, rx, ry)
end

--- Nav angle from a world bearing and the player's facing (both radians,
--- counter-clockwise from north, as HereBeDragons and GetPlayerFacing give them).
function Halo.RelativeAngle(bearing, facing)
    return (bearing - facing) % (2 * pi)
end

--- Nav angle from a screen offset (dx right, dy up) between the ring and the
--- destination on screen: 0 straight up, counter-clockwise positive.
function Halo.ScreenAngle(dx, dy)
    return atan2(-dx, dy)
end

---------------------------------------------------------------------------
-- Where the destination is
---------------------------------------------------------------------------

--- World bearing to a point on a map, or nil when it is on another continent.
local function BearingToMapPoint(mapID, x, y)
    if not (mapID and x and y) then return end
    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    local dx, dy, dInstance = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
    if not (px and dx) or pInstance ~= dInstance then return end
    return (HBD:GetWorldVector(pInstance, px, py, dx, dy))
end

--- The true bearing to the current destination, when the game tells us where
--- it is: Blizzard's next-waypoint redirect on the player's map, or the user
--- waypoint.
function Halo.GetDestinationBearing()
    local redirect = Waypoint_Cache.Get("redirectInfo")
    if redirect and redirect.valid and redirect.x and redirect.y then
        return BearingToMapPoint(C_Map.GetBestMapForUnit("player"), redirect.x, redirect.y)
    end
    if C_SuperTrack.IsSuperTrackingUserWaypoint() then
        local point = C_Map.GetUserWaypoint()
        if point and point.position then
            return BearingToMapPoint(point.uiMapID, point.position.x, point.position.y)
        end
    end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function Place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", parent, "CENTER", x, y)
end

local function Tex(parent, layer, file, sublevel, size, r, g, b, a)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(TEXDIR .. file)
    if size then t:SetSize(size, size) end
    t:SetVertexColor(r, g, b, a)
    return t
end

local function Label(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if not fs:SetFont(GoatStyle.FontPath("AtkinsonHyperlegible-Bold.ttf"), 16, "OUTLINE") then
        fs:SetFont(GameFontNormal:GetFont(), 16, "OUTLINE")
    end
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.65)
    return fs
end

function Halo:Create()
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetFrameStrata("LOW")
    root:SetAllPoints(UIParent)
    root:EnableMouse(false)
    root:Hide()
    self.root = root

    -- The feet anchor stays unscaled, so its offset is in plain UI units. The
    -- ring hung off it takes the size setting through its own SetScale.
    local feet = CreateFrame("Frame", nil, root)
    feet:SetSize(1, 1)
    self.feet = feet

    local ring = CreateFrame("Frame", nil, feet)
    ring:SetSize(RING_W, RING_H)
    ring:SetPoint("CENTER", feet, "CENTER", 0, 0)
    self.ring = ring

    self.ringShadow = Tex(ring, "BACKGROUND", "ring-shadow.tga", 0, nil, 1, 1, 1, 0.8)
    self.ringShadow:SetSize(RING_W, RING_H)
    self.ringShadow:SetPoint("CENTER", ring, "CENTER", 0, 0)
    self.ringLine = Tex(ring, "BORDER", "ring.tga", 0, nil, RING[1], RING[2], RING[3], RING[4])
    self.ringLine:SetSize(RING_W, RING_H)
    self.ringLine:SetPoint("CENTER", ring, "CENTER", 0, 0)

    -- Dark copies under the accent keep the notch readable on bright ground.
    self.dots, self.dotUnders = {}, {}
    for i = 1, DOTS do
        self.dotUnders[i] = Tex(ring, "ARTWORK", "dot.tga", 1, DOT_UNDER, 0, 0, 0, 0.55)
        self.dots[i] = Tex(ring, "OVERLAY", "dot.tga", 1, DOT_SIZE, 1, 1, 1, 1)
    end
    self.chevrons, self.chevUnders = {}, {}
    for i = 1, 2 do
        self.chevUnders[i] = Tex(ring, "ARTWORK", "vchev.tga", 2, CHEV_UNDER, 0, 0, 0, 0.6)
        self.chevrons[i] = Tex(ring, "OVERLAY", "vchev.tga", 2, CHEV_SIZE, 1, 1, 1, 1)
    end

    self.distText = Label(ring)
    self.hereText = Label(ring)
    self.hereText:SetText(L["HALO_HERE"])
    self.hereText:SetPoint("BOTTOM", ring, "CENTER", 0, RY + 6)

    self.accent = { 1, 1, 1 }
    self.notchShown = true
    self:SetNotchShown(false)
    self:SetArrived(false)

    root:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
    return self
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

--- GoatQuest's saved ring position (x, offset), or nil when there is none.
function Halo.GetGoatQuestPosition()
    local gq = Style.GetGoatQuest()
    local profile = gq and gq.db and gq.db.profile
    if not profile then return end
    local x, offset = tonumber(profile.viewer_halo_x), tonumber(profile.viewer_halo_offset)
    if x or offset then return x or 0, offset or Halo.DEFAULT_OFFSET end
end

--- Ring position: GoatQuest's, so both add-ons put the ring at the same feet
--- (Match GoatQuest), or the Ring Height option.
function Halo.GetPosition()
    if Config.DBGlobal:GetVariable("HaloMatchGoatQuest") then
        local x, offset = Halo.GetGoatQuestPosition()
        if x then return x, offset end
    end
    return 0, tonumber(Config.DBGlobal:GetVariable("HaloOffset")) or Halo.DEFAULT_OFFSET
end

function Halo:ApplySettings()
    local x, offset = Halo.GetPosition()
    self.feet:ClearAllPoints()
    self.feet:SetPoint("CENTER", UIParent, "CENTER", x, offset)
    self.ring:SetScale(Config.DBGlobal:GetVariable("NavigatorScale") or 1)
    self.ring:SetAlpha(Config.DBGlobal:GetVariable("NavigatorAlpha") or 1)
    self.lastAngle, self.lastDist = nil, nil
    self:UpdateVisibility()
end

--- The notch, the chevrons and the arrived ring take the destination's colour
--- (the accent unless it is an unfinished quest, as on the marker).
function Halo:Tint(r, g, b)
    local a = self.accent
    if a[1] == r and a[2] == g and a[3] == b then return end
    a[1], a[2], a[3] = r, g, b
    for i = 1, DOTS do self.dots[i]:SetVertexColor(r, g, b, 1) end
    for i = 1, 2 do self.chevrons[i]:SetVertexColor(r, g, b, i == 1 and 1 or 0.75) end
    if self.arrived then self.ringLine:SetVertexColor(r, g, b, 0.9) end
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------

function Halo.IsEnabled()
    return Config.DBGlobal:GetVariable("NavigatorShow") == true
        and Config.DBGlobal:GetVariable("NavigatorStyle") == env.Enum.NavigatorStyle.Halo
end

--- True while GoatQuest's own halo ring is on screen.
function Halo.IsGoatQuestHaloShown()
    local gq = Style.GetGoatQuest()
    local ring = gq and gq.Styles and gq.Styles.Halo and gq.Styles.Halo.ring
    return ring ~= nil and ring.IsVisible ~= nil and ring:IsVisible() == true
end

function Halo:ShouldShow()
    return Halo.IsEnabled()
        and Waypoint_Director.isActive
        and not Waypoint_Director.IsSuperTrackedTargetIgnored()
        and GoatWayFrame:IsShown()
        and not Halo.IsGoatQuestHaloShown()
end

function Halo:UpdateVisibility()
    local shown = self:ShouldShow()
    if shown ~= self.root:IsShown() then
        self.root:SetShown(shown)
        self.lastAngle, self.lastDist = nil, nil
    end
end

---------------------------------------------------------------------------
-- The notch
---------------------------------------------------------------------------

function Halo:SetNotchShown(shown)
    if self.notchShown == shown then return end
    self.notchShown = shown
    for i = 1, DOTS do
        self.dots[i]:SetShown(shown)
        self.dotUnders[i]:SetShown(shown)
    end
    for i = 1, 2 do
        self.chevrons[i]:SetShown(shown)
        self.chevUnders[i]:SetShown(shown)
    end
    self.distText:SetShown(shown)
    self.lastAngle = nil
end

function Halo:SetArrived(on)
    if self.arrived == on then return end
    self.arrived = on
    if on then
        local a = self.accent
        self.ringLine:SetVertexColor(a[1], a[2], a[3], 0.9)
    else
        self.ringLine:SetVertexColor(RING[1], RING[2], RING[3], RING[4])
    end
    self.hereText:SetShown(on)
end

function Halo:PlaceNotch(angle)
    local ring = self.ring
    local px, py, nx, ny = Halo.EllipsePoint(angle, RX, RY)

    local mid = (DOTS + 1) / 2
    Place(self.dots[mid], ring, px, py)
    Place(self.dotUnders[mid], ring, px, py)
    for dir = -1, 1, 2 do
        local t = angle
        for k = 1, mid - 1 do
            t = Halo.ArcStep(t, RX, RY, dir * DOT_STEP)
            local x, y = -sin(t) * RX, cos(t) * RY
            local i = mid + dir * k
            Place(self.dots[i], ring, x, y)
            Place(self.dotUnders[i], ring, x, y)
        end
    end

    local rot = Halo.NormalRotation(nx, ny)
    local off = CHEV1
    for i = 1, 2 do
        local x, y = px + nx * off, py + ny * off
        Place(self.chevrons[i], ring, x, y)
        Place(self.chevUnders[i], ring, x, y)
        self.chevrons[i]:SetRotation(rot)
        self.chevUnders[i]:SetRotation(rot)
        off = CHEV2
    end

    Place(self.distText, ring, px + nx * TEXT_OFF, py + ny * TEXT_OFF)
end

--- The nav angle to the destination, or nil when there is no direction yet.
function Halo:GetAngle()
    local bearing = Halo.GetDestinationBearing()
    local facing = GetPlayerFacing and GetPlayerFacing()
    if bearing and facing then return Halo.RelativeAngle(bearing, facing) end

    local navFrame = Waypoint_Cache.navFrame
    if not navFrame then return end
    local fx, fy = self.ring:GetCenter()
    local nx, ny = navFrame:GetCenter()
    if not (fx and nx) then return end
    local rs, ns = self.ring:GetEffectiveScale(), navFrame:GetEffectiveScale()
    local dx, dy = nx * ns - fx * rs, ny * ns - fy * rs
    if dx * dx + dy * dy < 1 then return end
    return Halo.ScreenAngle(dx, dy)
end

function Halo:Update()
    local state = Waypoint_Cache.Get("state")
    if state == Waypoint_Enum.State.InvalidRange then
        self:SetNotchShown(false)
        self:SetArrived(true)
        self.ring:Show()
        return
    end
    self:SetArrived(false)

    local angle = (state ~= nil and state ~= Waypoint_Enum.State.Invalid) and self:GetAngle() or nil
    if not angle then
        self:SetNotchShown(false)
        self.ring:SetShown(state ~= nil and state ~= Waypoint_Enum.State.Invalid)
        return
    end
    self.ring:Show()
    self:SetNotchShown(true)

    local dist = Waypoint_Cache.Get("distance")
    local rounded = type(dist) == "number" and floor(dist + 0.5) or -1
    if rounded ~= self.lastDist then
        self.lastDist = rounded
        self.distText:SetText(rounded >= 0 and SharedUtil:FormatDistance(dist) or "")
    end

    local last = self.lastAngle
    if last and abs(angle - last) < ANGLE_EPS then return end
    self.lastAngle = angle
    self:PlaceNotch(angle)
end

local elapsedSinceUpdate = 0
function Halo:OnUpdate(elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < UPDATE_INTERVAL then return end
    elapsedSinceUpdate = 0
    self:UpdateVisibility()
    if self.root:IsShown() then self:Update() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function Refresh()
    if Halo.root then Halo:UpdateVisibility() end
end

local function Reapply()
    if Halo.root then Halo:ApplySettings() end
end

CallbackRegistry.Add("Preload.AddonReady", function()
    Halo:Create()
    local r, g, b = Style.GetAccentRGB()
    Halo:Tint(r, g, b)
    Halo:ApplySettings()

    -- Cinematics and a hidden UI hide GoatWay's frames; the ring goes with them.
    GoatWayFrame:HookScript("OnShow", Refresh)
    GoatWayFrame:HookScript("OnHide", Refresh)

    -- GoatQuest's ring can be hidden or moved at any time; recheck now and then.
    C_Timer.NewTicker(1, function()
        Refresh()
        if Config.DBGlobal:GetVariable("HaloMatchGoatQuest") then Reapply() end
    end)
end)

CallbackRegistry.Add("Waypoint.ActiveChanged", Refresh)
CallbackRegistry.Add("Waypoint.NavigationModeChanged", Refresh)
CallbackRegistry.Add("Waypoint.IgnoreSuperTrackedTarget", Refresh)
CallbackRegistry.Add("Waypoint.UpdateColor", function(color)
    if Halo.root and type(color) == "table" and color.r then Halo:Tint(color.r, color.g, color.b) end
end)

for _, key in ipairs({ "NavigatorShow", "NavigatorStyle", "NavigatorScale", "NavigatorAlpha", "HaloMatchGoatQuest", "HaloOffset" }) do
    SavedVariables.OnChange("GoatWayDB_Global", key, Reapply)
end
