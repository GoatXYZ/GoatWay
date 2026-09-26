-- A permissive WoW API mock for loading all of GoatWay offline (Lua 5.1 via lupa).
--
-- Frames, textures, font strings and font objects keep the state the tests
-- read back: shown and visible, alpha, scale, points and sizes, scripts and
-- hooks, textures, vertex colours, text and fonts. Events, C_Timer and
-- OnUpdate run on demand (Mock.fire, Mock.advance). The retail APIs GoatWay's
-- navigation reads (super tracking, user waypoints, the navigation frame,
-- facing and position) are modelled on Mock.world.
--
-- Any other global the add-on reads resolves to a stub that can be called and
-- indexed. Mock.unknown records those names, so a test can check that every
-- one is a real Blizzard API and not a typo in GoatWay's own code.

Mock = {
    time = 0,
    timers = {},
    events = {},
    unknown = {},
    updaters = {},
    calls = {},
    locale = "enUS",
    class = "PALADIN",
    world = {
        superTracking = nil,   -- nil, "user" or "quest"
        userWaypoint = nil,    -- { uiMapID, position = { x, y } }
        navShown = false,
        navCenter = { 900, 500 },
        distance = 0,
        facing = 0,
        playerMap = 1436,
        playerPos = { 0.5, 0.5 }, -- map coordinates on playerMap
        mapSize = { 3000, 2000 }, -- yards
        addons = { GoatWay = true },
    },
}

local function noop() end
local unpack = unpack

---------------------------------------------------------------------------
-- Stubs for everything not modelled
---------------------------------------------------------------------------

local StubMeta = {}
local function Stub(name)
    return setmetatable({ __stub = name }, StubMeta)
end
StubMeta.__index = function(t, k)
    if k == "__stub" then return rawget(t, "__stub") end
    local s = Stub(rawget(t, "__stub") .. "." .. tostring(k))
    rawset(t, k, s)
    return s
end
StubMeta.__call = function() return nil end
Mock.Stub = Stub

---------------------------------------------------------------------------
-- UI objects
---------------------------------------------------------------------------

-- Like real frames, unknown keys read as nil. Setters with no state the tests
-- read are listed as no-ops.
local Methods = {}
for _, name in ipairs({
    "SetClampedToScreen", "SetClampRectInsets", "SetMovable", "SetResizable", "SetResizeBounds", "SetDontSavePosition",
    "EnableMouseWheel", "EnableMouseMotion", "RegisterForDrag", "RegisterForClicks", "EnableKeyboard",
    "SetClipsChildren", "SetIgnoreParentAlpha", "SetPropagateMouseClicks", "SetPropagateMouseMotion",
    "SetPropagateKeyboardInput", "StartMoving", "StartSizing", "StopMovingOrSizing", "SetToplevel", "SetHitRectInsets",
    "SetDrawLayer", "SetTextureSliceMargins", "SetTextureSliceMode", "SetSnapToPixelGrid", "SetTexelSnappingBias",
    "SetDesaturated", "SetDesaturation", "SetMask", "AddMaskTexture", "RemoveMaskTexture", "SetGradient", "SetHorizTile",
    "SetVertTile", "SetWordWrap", "SetNonSpaceWrap", "SetIndentedWordWrap", "SetMaxLines", "SetSpacing", "SetJustifyV",
    "SetTextHeight", "SetAlphaGradient", "SetFixedFrameStrata", "SetFixedFrameLevel", "SetAutoFocus", "SetMultiLine",
    "SetMaxLetters", "SetNumeric", "SetTextInsets", "SetCursorPosition", "HighlightText", "ClearFocus", "SetFocus",
    "SetHistoryLines", "SetCountInvisibleLetters", "SetBlinkSpeed", "SetHighlightColor", "SetOrientation",
    "SetObeyStepOnDrag", "SetThumbTexture", "SetStepsPerPage", "SetVerticalScroll", "SetHorizontalScroll",
    "UpdateScrollChildRect", "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetPassThroughButtons",
    "SetFlattensRenderLayers", "SetIsFrameBuffer", "SetUsingParentLevel", "Play", "Stop", "Pause", "SetLooping",
    "SetDuration", "SetFromAlpha", "SetToAlpha", "SetOrder", "SetSmoothing", "SetOffset", "SetScaleFrom", "SetScaleTo",
    "SetStartDelay", "SetEndDelay", "SetTarget", "SetChildKey", "SetDegrees", "SetOrigin", "AddLine", "AddDoubleLine",
    "SetOwner", "ClearLines", "SetEnabled", "Enable", "Disable", "SetChecked", "SetButtonState", "LockHighlight",
    "UnlockHighlight", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture",
    "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject", "SetAttribute", "SetStartPoint",
    "SetEndPoint", "SetThickness", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetCollapsesLayout",
    "SetFrameBuffer", "SetDepth", "SetIgnoreParentScale", "TriggerEvent", "Raise", "Lower", "SetUserPlaced",
    "SetPropagateGamePadInput", "SetHyperlinksEnabled", "SetEditMode", "SetTextToFit", "SetTextScale",
    "SetScrollChildRect", "SetCameraPosition", "SetCameraOrientationByYawPitchRoll", "SetLightDirection",
    "ClearPointsOffset", "AdjustPointsOffset", "SetAllPointsOffset", "SetShadowOffsetX",
}) do Methods[name] = noop end
local ObjectMeta = { __index = Methods }
local allObjects = {}
local fontStrings = {}

local function NewObject(kind, name, parent)
    local o = setmetatable({
        __kind = kind, __name = name, __parent = parent, __shown = true,
        __scripts = {}, __hooks = {}, __points = {}, __w = 0, __h = 0,
        __scale = 1, __alpha = 1, __children = {}, __regions = {},
        __strata = "MEDIUM", __level = 1, __vertex = { 1, 1, 1, 1 },
        __rotation = 0, __text = nil, __mouse = false,
    }, ObjectMeta)
    if parent and parent.__children then table.insert(parent.__children, o) end
    table.insert(allObjects, o)
    if name then
        name = name:gsub("%$parent", parent and parent.__name or "")
        o.__name = name
        _G[name] = o
    end
    return o
end
Mock.NewObject = NewObject

function Methods:GetName() return self.__name end
function Methods:GetDebugName() return self.__name or self.__kind end
function Methods:GetObjectType() return self.__kind end
function Methods:IsObjectType(t) return self.__kind == t or t == "Frame" or t == "Region" end
function Methods:IsForbidden() return false end
function Methods:GetParent() return self.__parent end
function Methods:SetParent(p)
    if self.__parent and self.__parent.__children then
        for i, c in ipairs(self.__parent.__children) do if c == self then table.remove(self.__parent.__children, i) break end end
    end
    self.__parent = p
    if p and p.__children then table.insert(p.__children, self) end
end
function Methods:GetChildren() return unpack(self.__children) end
function Methods:GetNumChildren() return #self.__children end
function Methods:GetRegions() return unpack(self.__regions) end

local function RunScript(self, script, ...)
    local fn = self.__scripts[script]
    if fn then fn(self, ...) end
    for _, hook in ipairs(self.__hooks[script] or {}) do hook(self, ...) end
end
Mock.RunScript = RunScript

function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local o = self
    while o do
        if not o.__shown then return false end
        o = o.__parent
    end
    return true
end
function Methods:Show()
    if self.__shown then return end
    self.__shown = true
    if self:IsVisible() then RunScript(self, "OnShow") end
end
function Methods:Hide()
    if not self.__shown then return end
    local wasVisible = self:IsVisible()
    self.__shown = false
    if wasVisible then RunScript(self, "OnHide") end
end
function Methods:SetShown(shown) if shown then self:Show() else self:Hide() end end

function Methods:SetScript(script, fn) self.__scripts[script] = fn end
function Methods:GetScript(script) return self.__scripts[script] end
function Methods:HasScript() return true end
function Methods:HookScript(script, fn)
    self.__hooks[script] = self.__hooks[script] or {}
    table.insert(self.__hooks[script], fn)
end

function Methods:RegisterEvent(e)
    Mock.events[e] = Mock.events[e] or {}
    Mock.events[e][self] = true
end
Methods.RegisterUnitEvent = Methods.RegisterEvent
function Methods:UnregisterEvent(e) if Mock.events[e] then Mock.events[e][self] = nil end end
function Methods:UnregisterAllEvents() for _, set in pairs(Mock.events) do set[self] = nil end end
function Methods:IsEventRegistered(e) return Mock.events[e] and Mock.events[e][self] or false end

function Methods:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    if type(relPoint) == "number" then relPoint, x, y = nil, relPoint, x end
    table.insert(self.__points, { point, rel or self.__parent, relPoint or point, x or 0, y or 0 })
end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:SetAllPoints(rel) self.__points = { { "TOPLEFT", rel or self.__parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel or self.__parent, "BOTTOMRIGHT", 0, 0 } } end
function Methods:GetPoint(i)
    local p = self.__points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Methods:GetNumPoints() return #self.__points end

function Methods:SetSize(w, h) self.__w, self.__h = w or 0, h or 0 end
function Methods:SetWidth(w) self.__w = w or 0 end
function Methods:SetHeight(h) self.__h = h or 0 end
function Methods:GetWidth() return self.__w end
function Methods:GetHeight() return self.__h end
function Methods:GetSize() return self.__w, self.__h end

-- Geometry resolves through the first anchor only (enough for the tests).
function Methods:GetCenter()
    if self.__center then return self.__center[1], self.__center[2] end
    local p = self.__points[1]
    if p and p[2] and p[2] ~= self and p[2].GetCenter then
        local cx, cy = p[2]:GetCenter()
        return (cx or 0) + (p[4] or 0), (cy or 0) + (p[5] or 0)
    end
    return 683, 384
end
function Methods:GetLeft() local x = self:GetCenter() return x - self.__w / 2 end
function Methods:GetRight() local x = self:GetCenter() return x + self.__w / 2 end
function Methods:GetTop() local _, y = self:GetCenter() return y + self.__h / 2 end
function Methods:GetBottom() local _, y = self:GetCenter() return y - self.__h / 2 end
function Methods:GetRect() return self:GetLeft(), self:GetBottom(), self.__w, self.__h end
function Methods:GetScaledRect() return self:GetRect() end
function Methods:GetBoundsRect() return self:GetRect() end

function Methods:SetScale(s) self.__scale = s end
function Methods:GetScale() return self.__scale end
function Methods:GetEffectiveScale()
    local s, o = 1, self
    while o do s = s * (o.__scale or 1) o = o.__parent end
    return s
end
function Methods:SetIgnoreParentScale(v) self.__ignoreScale = v end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetAlpha() return self.__alpha end
function Methods:GetEffectiveAlpha() return self.__alpha end
function Methods:SetFrameStrata(s) self.__strata = s end
function Methods:GetFrameStrata() return self.__strata end
function Methods:SetFrameLevel(l) self.__level = l end
function Methods:GetFrameLevel() return self.__level end
function Methods:EnableMouse(v) self.__mouse = v end
function Methods:IsMouseEnabled() return self.__mouse end
function Methods:IsMouseOver() return false end
function Methods:IsMouseMotionEnabled() return false end
function Methods:IsMouseClickEnabled() return false end
function Methods:IsDragging() return false end
function Methods:GetID() return self.__id or 0 end
function Methods:SetID(id) self.__id = id end
function Methods:IsProtected() return false end
function Methods:CanChangeProtectedState() return true end

local function NewRegion(self, kind, name)
    local r = NewObject(kind, name, self)
    table.insert(self.__regions, r)
    return r
end
function Methods:CreateTexture(name) return NewRegion(self, "Texture", name) end
function Methods:CreateMaskTexture(name) return NewRegion(self, "MaskTexture", name) end
function Methods:CreateLine(name) return NewRegion(self, "Line", name) end
function Methods:CreateFontString(name)
    local fs = NewRegion(self, "FontString", name)
    fs.__font = { "Fonts\\FRIZQT__.TTF", 12, "" }
    table.insert(fontStrings, fs)
    return fs
end
function Methods:CreateAnimationGroup(name) return NewObject("AnimationGroup", name, self) end
function Methods:CreateAnimation(kind, name) return NewObject("Animation", name, self) end

-- Textures
function Methods:SetTexture(t) self.__texture = t return true end
function Methods:GetTexture() return self.__texture end
function Methods:SetColorTexture(r, g, b, a) self.__texture = "color" self.__vertex = { r, g, b, a or 1 } end
function Methods:SetVertexColor(r, g, b, a) self.__vertex = { r, g, b, a or 1 } end
function Methods:GetVertexColor() return unpack(self.__vertex) end
function Methods:SetAtlas(a) self.__atlas = a return true end
function Methods:GetAtlas() return self.__atlas end
function Methods:SetRotation(r) self.__rotation = r end
function Methods:GetRotation() return self.__rotation end
function Methods:SetTexCoord(...) self.__texCoord = { ... } end
function Methods:GetTexCoord() return unpack(self.__texCoord or { 0, 1, 0, 1 }) end
function Methods:IsDesaturated() return false end
function Methods:GetBlendMode() return self.__blend or "BLEND" end
function Methods:SetBlendMode(b) self.__blend = b end

-- Font strings and font objects
function Methods:SetText(t) self.__text = t end
function Methods:GetText() return self.__text end
function Methods:SetFormattedText(fmt, ...) self.__text = fmt:format(...) end
function Methods:SetFont(path, size, flags) self.__font = { path, size, flags } return true end
function Methods:GetFont()
    if self.__fontObject and not self.__font then return self.__fontObject:GetFont() end
    local f = self.__font or { "Fonts\\FRIZQT__.TTF", 12, "" }
    return f[1], f[2], f[3]
end
function Methods:SetFontObject(o) self.__fontObject = o self.__font = nil end
function Methods:GetFontObject() return self.__fontObject end
function Methods:SetTextColor(r, g, b, a) self.__textColor = { r, g, b, a or 1 } end
function Methods:GetTextColor() return unpack(self.__textColor or { 1, 1, 1, 1 }) end
function Methods:SetShadowColor(...) self.__shadowColor = { ... } end
function Methods:GetShadowColor() return unpack(self.__shadowColor or { 0, 0, 0, 1 }) end
function Methods:SetShadowOffset(x, y) self.__shadowOffset = { x, y } end
function Methods:GetShadowOffset() return unpack(self.__shadowOffset or { 0, 0 }) end
function Methods:GetStringWidth() return #(self.__text or "") * 6 end
Methods.GetUnboundedStringWidth = Methods.GetStringWidth
function Methods:GetStringHeight() return self.__text and 12 or 0 end
function Methods:GetLineHeight() return 12 end
function Methods:GetNumLines() return 1 end
function Methods:GetSpacing() return 0 end
function Methods:GetJustifyH() return self.__justifyH or "CENTER" end
function Methods:SetJustifyH(j) self.__justifyH = j end
function Methods:GetJustifyV() return "MIDDLE" end
function Methods:IsTruncated() return false end
function Methods:GetWrappedWidth() return self:GetStringWidth() end
function Methods:CopyFontObject(o) if o and o.GetFont then self.__font = { o:GetFont() } end end

-- Edit boxes, scroll frames, sliders, buttons
function Methods:GetCursorPosition() return 0 end
function Methods:HasFocus() return false end
function Methods:GetNumLetters() return #(self.__text or "") end
function Methods:IsMultiLine() return false end
function Methods:GetMaxLetters() return 0 end
function Methods:GetVerticalScroll() return 0 end
function Methods:GetHorizontalScroll() return 0 end
function Methods:GetVerticalScrollRange() return 0 end
function Methods:GetHorizontalScrollRange() return 0 end
function Methods:GetScrollChild() return self.__scrollChild end
function Methods:SetScrollChild(c) self.__scrollChild = c end
function Methods:GetValue() return self.__value or 0 end
function Methods:SetValue(v) self.__value = v end
function Methods:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function Methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Methods:GetValueStep() return self.__step or 1 end
function Methods:SetValueStep(s) self.__step = s end
function Methods:GetButtonState() return "NORMAL" end
function Methods:IsEnabled() return true end
function Methods:GetChecked() return false end
function Methods:IsPlaying() return false end
function Methods:GetDuration() return 0 end
function Methods:GetProgress() return 0 end
function Methods:GetElapsed() return 0 end
function Methods:GetNumAnimations() return 0 end

-- Model scenes
function Methods:GetActorByTag() return nil end
function Methods:CreateActor() return NewObject("Actor") end

function CreateFrame(kind, name, parent, template)
    local f = NewObject(kind or "Frame", name, parent)
    if kind == "EditBox" then
        -- Edit boxes come with their text region and caret texture.
        f:CreateFontString()
        f:CreateTexture()
        function f:HasText() return (self.__text or "") ~= "" end
    end
    if template and template:find("BackdropTemplate") then
        f.SetBackdrop = noop
        f.SetBackdropColor = noop
        f.SetBackdropBorderColor = noop
    end
    return f
end

function CreateFont(name)
    local f = NewObject("Font", name)
    f.__font = { "Fonts\\FRIZQT__.TTF", 12, "" }
    return f
end

UIParent = NewObject("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1366, 768
UIParent.__center = { 683, 384 }
WorldFrame = NewObject("Frame", "WorldFrame")
WorldFrame.__w, WorldFrame.__h = 1366, 768
WorldFrame.__center = { 683, 384 }
Minimap = NewObject("Frame", "Minimap", UIParent)
Minimap.__w, Minimap.__h = 140, 140
function Minimap:GetZoom() return 0 end
function Minimap:GetZoomLevels() return 6 end
function Minimap:SetZoom() end
function Minimap:GetViewRadius() return 200 end
WorldMapFrame = NewObject("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.ScrollContainer = NewObject("Frame", nil, WorldMapFrame)
WorldMapFrame.ScrollContainer.Child = NewObject("Frame", nil, WorldMapFrame.ScrollContainer)
WorldMapFrame.__shown = false
WorldMapFrame.pinPools = {}
WorldMapFrame.dataProviders = {}
function WorldMapFrame:GetMapID() return Mock.world.playerMap end
function WorldMapFrame:AddDataProvider(provider)
    self.dataProviders[provider] = true
    if provider.OnAdded then provider:OnAdded(self) end
end
function WorldMapFrame:RemoveDataProvider() end
function WorldMapFrame:AcquirePin() return NewObject("Frame", nil, WorldMapFrame) end
function WorldMapFrame:RemoveAllPinsByTemplate() end
function WorldMapFrame:EnumeratePinsByTemplate() return function() end end
function WorldMapFrame:RegisterCallback() end
function WorldMapFrame:GetCanvas() return self.ScrollContainer.Child end
function WorldMapFrame:RemovePin() end
function WorldMapFrame:GetCanvasContainer() return self.ScrollContainer end
function WorldMapFrame:GetCanvasScale() return 1 end
function WorldMapFrame:GetGlobalPinScale() return 1 end
function WorldMapFrame:EnumerateAllPins() return function() end end
function WorldMapFrame:SetMapID() end
function WorldMapFrame:AddCanvasClickHandler() end
function WorldMapFrame:RemoveCanvasClickHandler() end
function WorldMapFrame:GetNormalizedCursorPosition() return 0.5, 0.5 end
function WorldMapFrame:IsMaximized() return false end
SuperTrackedFrame = NewObject("Frame", "SuperTrackedFrame", UIParent)
SuperTrackedFrame.Icon = SuperTrackedFrame:CreateTexture()
SuperTrackedFrame.Icon.__texture = 3308452
StaticPopup1 = NewObject("Frame", "StaticPopup1", UIParent)
GameTooltip = NewObject("GameTooltip", "GameTooltip", UIParent)
function GameTooltip:IsOwned(o) return self.__owner == o end
function GameTooltip:SetOwner(o) self.__owner = o end
function GameTooltip:SetText(t) self.__text = t end
function GameTooltip:SetHyperlink() end
function GameTooltip:SetItemByID() end
function GameTooltip:SetSpellByID() end
GameFontNormal = CreateFont("GameFontNormal")
GameFontHighlight = CreateFont("GameFontHighlight")
SystemFont_Shadow_Med1 = CreateFont("SystemFont_Shadow_Med1")
SettingsPanel = NewObject("Frame", "SettingsPanel", UIParent)
SettingsPanel.Container = NewObject("Frame", nil, SettingsPanel)
SettingsPanel.Container.SettingsCanvas = NewObject("Frame", nil, SettingsPanel.Container)
SettingsPanel.Container.SettingsCanvas.__w, SettingsPanel.Container.SettingsCanvas.__h = 660, 560
DEFAULT_CHAT_FRAME = NewObject("Frame", "DEFAULT_CHAT_FRAME", UIParent)
Mock.chat = {}
function DEFAULT_CHAT_FRAME:AddMessage(msg) table.insert(Mock.chat, msg) end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- The navigation frame Blizzard places over the super-tracked target.
Mock.navFrame = NewObject("Frame", "NavigationFrame", UIParent)
Mock.navFrame.__w, Mock.navFrame.__h = 1, 1

Mock.allObjects = allObjects
Mock.fontStrings = fontStrings

---------------------------------------------------------------------------
-- Events, timers, OnUpdate
---------------------------------------------------------------------------

function Mock.fire(event, ...)
    local targets = {}
    for f in pairs(Mock.events[event] or {}) do table.insert(targets, f) end
    for _, f in ipairs(targets) do RunScript(f, "OnEvent", event, ...) end
end

local function NewTimer(delay, fn, iterations)
    local t = { at = Mock.time + delay, delay = delay, fn = fn, left = iterations, cancelled = false }
    function t:Cancel() self.cancelled = true end
    function t:IsCancelled() return self.cancelled end
    table.insert(Mock.timers, t)
    return t
end

C_Timer = {
    After = function(delay, fn) NewTimer(delay, fn, 1) end,
    NewTimer = function(delay, fn) return NewTimer(delay, fn, 1) end,
    NewTicker = function(delay, fn, n) return NewTimer(delay, fn, n or math.huge) end,
}

--- Advance time by dt in steps: timers, then OnUpdate on visible frames.
function Mock.advance(dt, step)
    step = step or 0.05
    local target = Mock.time + dt
    while Mock.time < target - 1e-9 do
        local s = math.min(step, target - Mock.time)
        Mock.time = Mock.time + s
        local due = {}
        for _, t in ipairs(Mock.timers) do
            if not t.cancelled and t.at <= Mock.time + 1e-9 then table.insert(due, t) end
        end
        for _, t in ipairs(due) do
            t.left = t.left - 1
            if t.left <= 0 then t.cancelled = true else t.at = t.at + t.delay end
            t.fn(t)
        end
        local live = {}
        for _, t in ipairs(Mock.timers) do if not t.cancelled then table.insert(live, t) end end
        Mock.timers = live
        for _, f in ipairs(allObjects) do
            if f.__scripts.OnUpdate and f:IsVisible() then RunScript(f, "OnUpdate", s) end
        end
    end
end

function GetTime() return Mock.time end
function GetTimePreciseSec() return Mock.time end
function debugprofilestop() return Mock.time * 1000 end
function GetFramerate() return 60 end

---------------------------------------------------------------------------
-- Lua and FrameXML helpers
---------------------------------------------------------------------------

tinsert, tremove, wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
string.split = function(sep, s) return strsplit(sep, s) end

-- WoW's bit library (32-bit, unsigned results are enough here).
bit = {}
local function bitop(a, b, fn)
    local r, p = 0, 1
    a, b = a % 4294967296, b % 4294967296
    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        if fn(x, y) then r = r + p end
        a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
end
function bit.band(a, b, ...) local r = bitop(a, b, function(x, y) return x == 1 and y == 1 end) if ... then return bit.band(r, ...) end return r end
function bit.bor(a, b, ...) local r = bitop(a, b, function(x, y) return x == 1 or y == 1 end) if ... then return bit.bor(r, ...) end return r end
function bit.bxor(a, b) return bitop(a, b, function(x, y) return x ~= y end) end
function bit.bnot(a) return 4294967295 - (a % 4294967296) end
function bit.lshift(a, n) return (a * 2 ^ n) % 4294967296 end
function bit.rshift(a, n) return math.floor((a % 4294967296) / 2 ^ n) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s, limit)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do table.insert(out, piece) end
    return unpack(out)
end
strlower, strupper, strfind, strsub, strlen, strmatch, gsub = string.lower, string.upper, string.find, string.sub, string.len, string.match, string.gsub
format = string.format
floor, ceil, abs, min, max, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
Clamp = function(v, lo, hi) return math.min(math.max(v, lo), hi) end
Lerp = function(a, b, t) return a + (b - a) * t end
BreakUpLargeNumbers = function(n) return tostring(n) end
FormatLargeNumber = BreakUpLargeNumbers

function Mixin(obj, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do obj[k] = v end
    end
    return obj
end
function CreateFromMixins(...) return Mixin({}, ...) end
MapCanvasDataProviderMixin = {
    GetMap = function(self) return self.owningMap end,
    OnAdded = function(self, map) self.owningMap = map end,
    OnRemoved = function(self) self.owningMap = nil end,
    RemoveAllData = function() end,
    RefreshAllData = function() end,
}
MapCanvasPinMixin = {}
function CreateUnsecuredRegionPoolInstance() return { Acquire = function() return CreateFrame("Frame") end, Release = function() end, ReleaseAll = function() end } end
function CreateFramePool(kind, parent) return { Acquire = function() return CreateFrame(kind or "Frame", nil, parent) end, Release = function() end, ReleaseAll = function() end, EnumerateActive = function() return function() end end } end
CreateFramePoolCollection = function() return { CreateFramePool = CreateFramePool, ReleaseAll = function() end } end
function CreateAndInitFromMixin(mixin, ...) local o = CreateFromMixins(mixin) if o.Init then o:Init(...) end return o end

function hooksecurefunc(tbl, method, hook)
    if type(tbl) == "string" then tbl, method, hook = _G, tbl, method end
    local orig = tbl[method]
    assert(type(orig) == "function", "hooksecurefunc: no function " .. tostring(method))
    tbl[method] = function(...)
        local r = { orig(...) }
        hook(...)
        return unpack(r)
    end
end

local Vector2DMixin = {}
function Vector2DMixin:SetXY(x, y) self.x, self.y = x, y end
function Vector2DMixin:GetXY() return self.x, self.y end
function CreateVector2D(x, y) return Mixin({ x = x, y = y }, Vector2DMixin) end
function Vector2D_CalculateAngleBetween(x1, y1, x2, y2) return math.atan2(y2, x2) - math.atan2(y1, x1) end

local ColorMixin = {}
function ColorMixin:GetRGB() return self.r, self.g, self.b end
function ColorMixin:GetRGBA() return self.r, self.g, self.b, self.a end
function ColorMixin:WrapTextInColorCode(t) return t end
function ColorMixin:GenerateHexColor() return "ffffffff" end
function CreateColor(r, g, b, a) return Mixin({ r = r, g = g, b = b, a = a or 1 }, ColorMixin) end
RAID_CLASS_COLORS = { PALADIN = CreateColor(0.96, 0.55, 0.73), MAGE = CreateColor(0.25, 0.78, 0.92) }
for _, name in ipairs({ "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "GRAY_FONT_COLOR", "WHITE_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR", "DISABLED_FONT_COLOR", "YELLOW_FONT_COLOR", "LIGHTGRAY_FONT_COLOR" }) do
    _G[name] = CreateColor(1, 0.82, 0)
end

function GetBuildInfo() return "1.60.1", "70009", "Sep 1 2026", 16001 end
function GetLocale() return Mock.locale end
function UnitClass() return "Paladin", Mock.class end
function UnitName() return "Goat" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 20 end
function UnitGUID() return "Player-1-00000001" end
function UnitIsDeadOrGhost() return false end
function UnitAffectingCombat() return false end
function UnitOnTaxi() return false end
function GetRealmName() return "Forever" end
function GetScreenWidth() return 1366 end
function GetScreenHeight() return 768 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetCursorPosition() return 0, 0 end
function GetCameraZoom() return 15 end
function InCombatLockdown() return false end
function IsInInstance() return false, "none" end
function IsPlayerMoving() return false end
function IsFlying() return false end
function IsMounted() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetUnitSpeed() return 7, 7, 7, 4.72 end
function GetCVar() return "1" end
function GetCVarBool() return true end
function SetCVar() return true end
function PlaySound() return true, 1 end
function PlaySoundFile() return true, 1 end
function StopSound() end
function ReloadUI() Mock.reloaded = true end
function GetPlayerFacing() return Mock.world.facing end
function IsLoggedIn() return Mock.loggedIn == true end
function GetQuestLogCompletionText() return nil end
function IsQuestComplete() return false end
function GetMouseFocus() return nil end
function GetMouseFoci() return {} end
function SetUIVisibility() end
function SetItemRef() end
function ChatFrame_OnHyperlinkShow() end
function OpenWorldMap() end
function ToggleWorldMap() end
function GetItemInfo() return nil end
function GetSpellInfo() return nil end
function GetNumGroupMembers() return 0 end
function GetZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "" end
function GetRealZoneText() return "Elwynn Forest" end
function GetMinimapZoneText() return "Elwynn Forest" end
function geterrorhandler() return function(err) error(err, 0) end end
function securecallfunction(fn, ...) return fn(...) end
function secureexecuterange(t, fn, ...) for k, v in pairs(t) do fn(k, v, ...) end end
function issecretvalue() return false end
function canaccessvalue() return true end

EventRegistry = {
    RegisterCallback = noop, UnregisterCallback = noop, TriggerEvent = noop,
    RegisterFrameEventAndCallback = noop, UnregisterFrameEventAndCallback = noop,
}
SlashCmdList = {}
hash_SlashCmdList = {}
SOUNDKIT = setmetatable({}, { __index = function(t, k) return 1000 end })
MAP_PIN = "Map Pin"
CLOSE = "Close"
OKAY = "Okay"
YES, NO, ACCEPT, CANCEL = "Yes", "No", "Accept", "Cancel"
LOCALE_enUS = true

-- UnitPosition returns world y (north), x (west), z, instance for the map model below.
function UnitPosition(unit)
    local w = Mock.world
    local x, y = Mock.MapToWorld(w.playerMap, w.playerPos[1], w.playerPos[2])
    return y, x, 0, 0
end

---------------------------------------------------------------------------
-- Map model: one zone, uiMapID Mock.world.playerMap, on instance 0.
-- HBD world x (west) = left - width * mapX, y (north) = top - height * mapY.
---------------------------------------------------------------------------

Mock.MAP_LEFT, Mock.MAP_TOP = 0, 0
function Mock.MapToWorld(mapID, x, y)
    local w, h = Mock.world.mapSize[1], Mock.world.mapSize[2]
    return Mock.MAP_LEFT - w * x, Mock.MAP_TOP - h * y
end

local function MapPoint(mapID, x, y)
    return { uiMapID = mapID, position = CreateVector2D(x, y), z = nil }
end
UiMapPoint = {
    CreateFromCoordinates = function(mapID, x, y) return MapPoint(mapID, x, y) end,
    CreateFromVector2D = function(mapID, v) return MapPoint(mapID, v.x, v.y) end,
}

C_Map = {
    GetBestMapForUnit = function() return Mock.world.playerMap end,
    GetMapInfo = function(id) return { mapID = id, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 } end,
    GetPlayerMapPosition = function() return CreateVector2D(Mock.world.playerPos[1], Mock.world.playerPos[2]) end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(point)
        table.insert(Mock.calls, "SetUserWaypoint")
        Mock.world.userWaypoint = { uiMapID = point.uiMapID, position = CreateVector2D(point.position.x, point.position.y) }
        Mock.fire("USER_WAYPOINT_UPDATED")
    end,
    GetUserWaypoint = function() return Mock.world.userWaypoint end,
    HasUserWaypoint = function() return Mock.world.userWaypoint ~= nil end,
    ClearUserWaypoint = function()
        table.insert(Mock.calls, "ClearUserWaypoint")
        Mock.world.userWaypoint = nil
        if Mock.world.superTracking == "user" then Mock.world.superTracking = nil end
        Mock.fire("USER_WAYPOINT_UPDATED")
    end,
    GetUserWaypointHyperlink = function() return "|Hworldmap:1436:5000:5000|h[Map Pin]|h" end,
    GetWorldPosFromMapPos = function(mapID, pos) return 0, CreateVector2D(Mock.MapToWorld(mapID, pos.x, pos.y)) end,
    GetMapPosFromWorldPos = function() return Mock.world.playerMap, CreateVector2D(0.5, 0.5) end,
    GetMapRectOnMap = function() return 0, 1, 0, 1 end,
    GetMapChildrenInfo = function() return {} end,
    GetMapGroupID = function() return nil end,
    GetMapGroupMembersInfo = function() return {} end,
    GetMapInfoAtPosition = function(id) return C_Map.GetMapInfo(id) end,
    GetMapWorldSize = function() return Mock.world.mapSize[1], Mock.world.mapSize[2] end,
}

C_SuperTrack = {
    IsSuperTrackingAnything = function() return Mock.world.superTracking ~= nil end,
    IsSuperTrackingUserWaypoint = function() return Mock.world.superTracking == "user" end,
    IsSuperTrackingQuest = function() return Mock.world.superTracking == "quest" end,
    SetSuperTrackedUserWaypoint = function(on)
        table.insert(Mock.calls, "SetSuperTrackedUserWaypoint")
        local had = Mock.world.superTracking ~= nil
        if on then Mock.world.superTracking = "user" elseif Mock.world.superTracking == "user" then Mock.world.superTracking = nil end
        Mock.world.navShown = on and true or false
        Mock.fire("SUPER_TRACKING_CHANGED")
        -- The client creates the navigation frame when tracking starts.
        if not had and Mock.world.superTracking then Mock.fire("NAVIGATION_FRAME_CREATED") end
        if had and not Mock.world.superTracking then Mock.fire("NAVIGATION_FRAME_DESTROYED") end
    end,
    GetHighestPrioritySuperTrackingType = function()
        if Mock.world.superTracking == "user" then return Enum.SuperTrackingType.UserWaypoint end
        if Mock.world.superTracking == "quest" then return Enum.SuperTrackingType.Quest end
    end,
    GetSuperTrackedQuestID = function() return Mock.world.superTracking == "quest" and Mock.world.questID or nil end,
    GetSuperTrackedItemName = function() return Mock.world.superTracking and "Map Pin" or nil, nil end,
    GetSuperTrackedContent = function() return nil, nil end,
    GetSuperTrackedMapPin = function() return nil, nil end,
    GetSuperTrackedVignette = function() return nil end,
    GetNextWaypointForMap = function() return nil end,
    ClearAllSuperTracked = function() Mock.world.superTracking = nil Mock.fire("SUPER_TRACKING_CHANGED") end,
    SetSuperTrackedQuestID = function(id) Mock.world.questID = id Mock.world.superTracking = id and "quest" or nil Mock.fire("SUPER_TRACKING_CHANGED") end,
}

C_Navigation = {
    GetFrame = function() return Mock.world.superTracking and Mock.navFrame or nil end,
    GetDistance = function() return Mock.world.superTracking and Mock.world.distance or 0 end,
    WasClampedToScreen = function() return false end,
    HasValidScreenPosition = function() return true end,
}

C_AddOns = {
    IsAddOnLoaded = function(name) return Mock.world.addons[name] == true end,
    LoadAddOn = function() return false end,
    GetAddOnEnableState = function(name) return Mock.world.addons[name] and 2 or 0 end,
    GetAddOnMetadata = function() return nil end,
}

C_Minimap = { IsInsideQuestBlob = function() return false end, GetViewRadius = function() return 200 end }
C_QuestInfoSystem = { GetQuestClassification = function() return Enum.QuestClassification.Normal end }
C_QuestLog = {
    IsComplete = function() return false end,
    ReadyForTurnIn = function() return false end,
    IsOnQuest = function() return true end,
    IsRepeatableQuest = function() return false end,
    IsWorldQuest = function() return false end,
    GetQuestType = function() return 0 end,
    GetTitleForQuestID = function() return "A Quest" end,
    GetQuestObjectives = function() return {} end,
    GetLogIndexForQuestID = function() return nil end,
}
C_ClassColor = { GetClassColor = function(class) return RAID_CLASS_COLORS[class] end }

-- Blizzard's Settings panel: opening a category shows its canvas frame.
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local category = { frame = frame, name = name, id = #Mock.calls + 1000 }
        function category:GetID() return self.id end
        Mock.settingsCategory = category
        return category
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function()
        local frame = Mock.settingsCategory and Mock.settingsCategory.frame
        if frame then frame:Show() end
    end,
}

Enum = {
    SuperTrackingType = { Quest = 0, UserWaypoint = 1, Corpse = 2, Scenario = 3, Content = 4, PartyMember = 5, MapPin = 6, Vignette = 7 },
    QuestClassification = { Important = 0, Legendary = 1, Campaign = 2, Calling = 3, Meta = 4, Recurring = 5, Questline = 6, Normal = 7, BonusObjective = 8, Threat = 9, WorldQuest = 10 },
    QuestTag = { Legendary = 83 },
    UITextureSliceMode = { Stretched = 0, Tiled = 1 },
    HousingPlotOwnerType = { None = 0, Self = 1, Friend = 2, Stranger = 3 },
    SuperTrackingMapPinType = { AreaPOI = 0, QuestOffer = 1, TaxiNode = 2, DigSite = 3, HousingPlot = 4 },
}
setmetatable(Enum, { __index = function(t, k) local s = Stub("Enum." .. k) rawset(t, k, s) return s end })

-- Retail-only namespaces GoatWay touches but these tests do not exercise.
for _, name in ipairs({ "C_HousingNeighborhood", "C_GossipInfo", "C_AreaPoiInfo", "C_Container", "C_Item",
    "C_TaskQuest", "C_VignetteInfo", "C_TaxiMap", "C_Housing", "C_Spell", "C_UnitAuras", "C_PartyInfo" }) do
    _G[name] = Stub(name)
end

---------------------------------------------------------------------------
-- The unknown-global net: any other global reads as nil, and is recorded.
---------------------------------------------------------------------------

setmetatable(_G, {
    __index = function(t, k)
        if type(k) == "string" then Mock.unknown[k] = true end
        return nil
    end
})
