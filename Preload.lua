local env = select(2, ...)
local Sound = env.modules:Import("packages\\sound")
local CallbackRegistry = env.modules:Import("packages\\callback-registry")
local UIFont = env.modules:Import("packages\\ui-font")
local CVarUtil = env.modules:Import("packages\\cvar-util")
local SavedVariables = env.modules:Import("packages\\saved-variables")
local SlashCommand = env.modules:Import("packages\\slash-command")
local Path = env.modules:Import("packages\\path")
local Utils_InlineIcon = env.modules:Import("packages\\utils\\inline-icon")
local GenericEnum = env.modules:Import("packages\\generic-enum")
local WoWClient = env.modules:Import("packages\\wow-client")
local GoatStyle = env.modules:Import("packages\\goatway-style")
local MapPin = env.modules:Await("@\\MapPin")

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded


env.NAME = "GoatWay"
env.NAME_COLORED = "|cfff4bf2aGoatWay|r"
env.LOGO = Path.Root .. "\\Art\\Icons\\Logo"
env.LOGO_ALT = Path.Root .. "\\Art\\Icons\\Logo-White"
env.VERSION_STRING = "1.0.0"
env.VERSION_NUMBER = 010000
env.DEBUG_MODE = false


local L = {}; env.L = L


local Enum = {}; env.Enum = Enum
do
    -- GoatQuest's palette. Destinations and quests ready to turn in take the
    -- accent (Code/Style.lua); these values are its GoatQuest gold fallback
    -- and the starting points of the custom colours.
    Enum.ColorRGB01 = {
        Other           = GoatStyle.RGBA("Gold"),
        NormalQuest     = GoatStyle.RGBA("Gold"),
        RepeatableQuest = GoatStyle.RGBA("Blue"),
        ImportantQuest  = GoatStyle.RGBA("Lilac"),
        IncompleteQuest = GoatStyle.RGBA("Soft")
    }

    Enum.ColorHEX = {
        Other           = GoatStyle.Hex.Gold,
        NormalQuest     = GoatStyle.Hex.Gold,
        RepeatableQuest = GoatStyle.Hex.Blue,
        ImportantQuest  = GoatStyle.Hex.Lilac,
        IncompleteQuest = GoatStyle.Hex.Soft
    }

    -- Where the accent comes from. "GoatQuest" follows the GoatQuest viewer's
    -- accent when GoatQuest is loaded, and is GoatQuest gold otherwise.
    Enum.AccentMode = {
        GoatQuest = 1,
        Class     = 2,
        Gold      = 3,
        Custom    = 4
    }

    -- How the Navigator points the way: an arrow at the screen edge, or
    -- GoatQuest's halo, a ring at the character's feet.
    Enum.NavigatorStyle = {
        Arrow = 1,
        Halo  = 2
    }

    Enum.Sound = {
        FileMap           = {
            [89712] = Path.Root .. "\\Sound\\SPELL_PR_Artifact_LightsWrath_Cast_05.ogg",
            [17318] = Path.Root .. "\\Sound\\LFG_DungeonReady.ogg",
            [13827] = Path.Root .. "\\Sound\\Glyph_MajorCreate.ogg"
        },
        WaypointShow      = SOUNDKIT.UI_RUNECARVING_OPEN_MAIN_WINDOW,
        PinpointShow      = SOUNDKIT.UI_RUNECARVING_CLOSE_MAIN_WINDOW,
        NewUserNavigation = 89712,
        ProximityEntry    = 17318,
        ProximityLeaving  = 13827
    }

    Enum.PathProvider = {
        None          = 1,
        FarstriderLib = 2,
        Mapzeroth     = 3
    }

    Enum.ContextIconAppearance = {
        Diamond = 1,
        Circle  = 2
    }

    Enum.ContextIconScaleOffset = {
        [Enum.ContextIconAppearance.Diamond] = 1,
        [Enum.ContextIconAppearance.Circle]  = 0.85
    }
end


local Config = {}; env.Config = Config
do
    Config.DBGlobal = nil
    Config.DBGlobalPersistent = nil
    Config.DBLocal = nil
    Config.DBLocalPersistent = nil

    local NAME_GLOBAL = "GoatWayDB_Global"
    local NAME_GLOBAL_PERSISTENT = "GoatWayDB_Global_Persistent"
    local NAME_LOCAL = "GoatWayDB_Local"
    local NAME_LOCAL_PERSISTENT = "GoatWayDB_Local_Persistent"

    ---@format enable
    local DB_GLOBAL_DEFAULTS = {
        lastLoadedVersion                          = nil,
        fontPath                                   = nil,

        WaypointSystemType                         = 1,
        DistanceThresholdPinpoint                  = WoWClient.IS_FOREVER and 100 or 325,
        DistanceThresholdHidden                    = 25,
        AlwaysShow                                 = false,
        RightClickToClear                          = true,
        BackgroundPreview                          = true,
        PrefMetric                                 = false,
        WaypointScale                              = 1,
        WaypointUseWorldScale                      = true,
        WaypointScaleMin                           = 0.01,
        WaypointScaleMax                           = 2,
        ContextIconAppearance                      = Enum.ContextIconAppearance.Diamond,
        WaypointAlpha                              = 1,
        WaypointBeam                               = true,
        WaypointBeamAlpha                          = 1,
        WaypointDistanceTextFontFlags              = 1, --UIFont.Enum.FontFlags
        WaypointDistanceText                       = true,
        WaypointDistanceTextType                   = 1,
        WaypointDistanceTextScale                  = 1,
        WaypointDistanceTextAlpha                  = 0.7,
        WaypointDistanceSubtextAlpha               = 0.7,
        PinpointFontFlags                          = 1, --UIFont.Enum.FontFlags
        PinpointTextAlignment                      = 1,
        PinpointAllowInQuestArea                   = false,
        PinpointScale                              = 1,
        PinpointAlpha                              = 1,
        PinpointShowContextIcon                    = true,
        PinpointInfo                               = true,
        PinpointInfoExtended                       = true,
        NavigatorShow                              = true,
        NavigatorShowContextIcon                   = true,
        NavigatorShowArrow                         = true,
        NavigatorScale                             = 1,
        NavigatorArrowScale                        = 1,
        NavigatorAlpha                             = 1,
        NavigatorDistance                          = 1,
        NavigatorDynamicDistance                   = true,

        CustomColor                                = false,
        CustomColorQuestIncomplete                 = { r = Enum.ColorRGB01.IncompleteQuest.r, g = Enum.ColorRGB01.IncompleteQuest.g, b = Enum.ColorRGB01.IncompleteQuest.b, a = 1 },
        CustomColorQuestIncompleteTint             = false,
        CustomColorQuestIncompleteTintBeam         = true,
        CustomColorQuestIncompleteBeam             = { r = Enum.ColorRGB01.IncompleteQuest.r, g = Enum.ColorRGB01.IncompleteQuest.g, b = Enum.ColorRGB01.IncompleteQuest.b, a = 1 },
        CustomColorQuestComplete                   = { r = Enum.ColorRGB01.NormalQuest.r, g = Enum.ColorRGB01.NormalQuest.g, b = Enum.ColorRGB01.NormalQuest.b, a = 1 },
        CustomColorQuestCompleteTint               = false,
        CustomColorQuestCompleteTintBeam           = true,
        CustomColorQuestCompleteBeam               = { r = Enum.ColorRGB01.NormalQuest.r, g = Enum.ColorRGB01.NormalQuest.g, b = Enum.ColorRGB01.NormalQuest.b, a = 1 },
        CustomColorQuestCompleteRepeatable         = { r = Enum.ColorRGB01.RepeatableQuest.r, g = Enum.ColorRGB01.RepeatableQuest.g, b = Enum.ColorRGB01.RepeatableQuest.b, a = 1 },
        CustomColorQuestCompleteRepeatableTint     = false,
        CustomColorQuestCompleteRepeatableTintBeam = true,
        CustomColorQuestCompleteRepeatableBeam     = { r = Enum.ColorRGB01.RepeatableQuest.r, g = Enum.ColorRGB01.RepeatableQuest.g, b = Enum.ColorRGB01.RepeatableQuest.b, a = 1 },
        CustomColorQuestCompleteImportant          = { r = Enum.ColorRGB01.ImportantQuest.r, g = Enum.ColorRGB01.ImportantQuest.g, b = Enum.ColorRGB01.ImportantQuest.b, a = 1 },
        CustomColorQuestCompleteImportantTint      = false,
        CustomColorQuestCompleteImportantTintBeam  = true,
        CustomColorQuestCompleteImportantBeam      = { r = Enum.ColorRGB01.ImportantQuest.r, g = Enum.ColorRGB01.ImportantQuest.g, b = Enum.ColorRGB01.ImportantQuest.b, a = 1 },
        CustomColorOther                           = { r = Enum.ColorRGB01.Other.r, g = Enum.ColorRGB01.Other.g, b = Enum.ColorRGB01.Other.b, a = 1 },
        CustomColorOtherTint                       = false,
        CustomColorOtherTintBeam                   = true,
        CustomColorOtherBeam                       = { r = Enum.ColorRGB01.Other.r, g = Enum.ColorRGB01.Other.g, b = Enum.ColorRGB01.Other.b, a = 1 },

        AudioGlobal                                = true,
        AudioProximity                             = false,
        AudioProximityDistance                     = 200,
        AudioProximitySound                        = Enum.Sound.ProximityEntry,
        AudioProximityLeavingDistance              = 200,
        AudioProximityLeavingSound                 = Enum.Sound.ProximityLeaving,
        AudioCustom                                = false,
        AudioCustomShowWaypoint                    = Enum.Sound.WaypointShow,
        AudioCustomShowPinpoint                    = Enum.Sound.PinpointShow,
        AudioCustomNewUserNavigation               = Enum.Sound.NewUserNavigation,

        CustomMapPinsEnabled                       = false,
        PathfindingEnabled                         = false,
        PathfindingProvider                        = Enum.PathProvider.None,
        AutoTrackPlacedPinEnabled                  = true,
        AutoTrackChatLinkPinEnabled                = true,
        GuidePinAssistantEnabled                   = true,

        TomTomSupportEnabled                       = true,
        TomTomAutoReplaceWaypoint                  = true,
        DugisSupportEnabled                        = true,
        DugisAutoReplaceWaypoint                   = true,
        APRSupportEnabled                          = false,
        APRAutoReplaceWaypoint                     = true,
        SilverDragonSupportEnabled                 = false,

        AccentColorMode                            = Enum.AccentMode.GoatQuest,
        AccentColor                                = GoatStyle.RGBA("Gold"),
        NavigatorStyle                             = Enum.NavigatorStyle.Arrow,
        HaloMatchGoatQuest                         = true,
        HaloOffset                                 = -90,
        GoatQuestSupportEnabled                    = true,
        GoatQuestAutoReplaceWaypoint               = true
    }
    local DB_GLOBAL_PERSISTENT_DEFAULTS = {}
    local DB_LOCAL_DEFAULTS = {
        mapPinSessionData = nil
    }
    local DB_LOCAL_PERSISTENT_DEFAULTS = {}
    ---@format disable

    -- GoatWay starts from fresh SavedVariables, so Waypoint UI's migrations
    -- (from its pre-1.0 AceDB profiles and its old font setting) never apply.
    -- Add steps here when a GoatWay release renames or removes a setting.
    local DB_GLOBAL_MIGRATION            = {}
    local DB_GLOBAL_PERSISTENT_MIGRATION = {}

    function Config.LoadDB()
        if GoatWayDB_Global and GoatWayDB_Global.lastLoadedVersion == env.VERSION_NUMBER then
            -- Same version, skip migration
            SavedVariables.RegisterDatabase(NAME_GLOBAL).defaults(DB_GLOBAL_DEFAULTS)
            SavedVariables.RegisterDatabase(NAME_GLOBAL_PERSISTENT).defaults(DB_GLOBAL_PERSISTENT_DEFAULTS)
        else
            -- Migrate if new version
            SavedVariables.RegisterDatabase(NAME_GLOBAL).defaults(DB_GLOBAL_DEFAULTS).migrationPlan(DB_GLOBAL_MIGRATION)
            SavedVariables.RegisterDatabase(NAME_GLOBAL_PERSISTENT).defaults(DB_GLOBAL_PERSISTENT_DEFAULTS).migrationPlan(DB_GLOBAL_PERSISTENT_MIGRATION)
        end

        SavedVariables.RegisterDatabase(NAME_LOCAL).defaults(DB_LOCAL_DEFAULTS)
        SavedVariables.RegisterDatabase(NAME_LOCAL_PERSISTENT).defaults(DB_LOCAL_PERSISTENT_DEFAULTS)

        Config.DBGlobal = SavedVariables.GetDatabase(NAME_GLOBAL)
        Config.DBGlobalPersistent = SavedVariables.GetDatabase(NAME_GLOBAL_PERSISTENT)
        Config.DBLocal = SavedVariables.GetDatabase(NAME_LOCAL)
        Config.DBLocalPersistent = SavedVariables.GetDatabase(NAME_LOCAL_PERSISTENT)

        CallbackRegistry.Trigger("Preload.DatabaseReady")
    end
end


local SlashCmdRegister = {}
do
    local Handlers = {}
    do -- /way
        local GetBestMapForUnit = C_Map.GetBestMapForUnit

        local INLINE_ADDON_ICON = Utils_InlineIcon.New(env.LOGO_ALT, 16, 16)
        local PIPE = Utils_InlineIcon.New(Path.Root .. "\\Art\\Icons\\Pipe", 16, 16)
        local WAY_COMMAND_ICON = Path.Root .. "\\Art\\Icons\\Navigation"

        local INVALID_WAY_LINE_1 = INLINE_ADDON_ICON .. " /way " .. GenericEnum.ColorHEX.NORMAL_FONT_COLOR .. "#<mapID> <x> <y> <name>" .. "|r"
        local INVALID_WAY_LINE_2 = PIPE .. " /way " .. GenericEnum.ColorHEX.NORMAL_FONT_COLOR .. "<x> <y> <name>" .. "|r"
        local INVALID_WAY_LINE_3 = PIPE .. " /way " .. GenericEnum.ColorHEX.NORMAL_FONT_COLOR .. "reset" .. "|r"
        local INVALID_WAY_LINE_4 = PIPE .. " /way " .. GenericEnum.ColorHEX.NORMAL_FONT_COLOR .. "paste" .. "|r"

        local function ThrowSlashWayError()
            DEFAULT_CHAT_FRAME:AddMessage(INVALID_WAY_LINE_1)
            DEFAULT_CHAT_FRAME:AddMessage(INVALID_WAY_LINE_2)
            DEFAULT_CHAT_FRAME:AddMessage(INVALID_WAY_LINE_3)

            if Config.DBGlobal:GetVariable("CustomMapPinsEnabled") then
                DEFAULT_CHAT_FRAME:AddMessage(INVALID_WAY_LINE_4)
            end
        end

        local function HandlePasteWayCommands()
            MapPin.PasteWayCommands(GoatWaySharedInputPrompt.Input:GetInput():GetText(), {
                flags          = "GoatWay_SlashWay",
                iconTexture    = WAY_COMMAND_ICON,
                requestRecolor = true
            })
        end

        function Handlers.HandleSlashCmd_Way(inputMessage)
            local isTomTomLoaded = IsAddOnLoaded("TomTom")
            if not inputMessage or inputMessage == "" then
                if not isTomTomLoaded then
                    return ThrowSlashWayError()
                end
                return
            end

            if Config.DBGlobal:GetVariable("CustomMapPinsEnabled") and inputMessage:lower():match("^%s*paste%s*$") then
                GoatWaySharedInputPrompt:Open({
                    text         = L["WAY_PASTE_PROMPT"],
                    inputText    = "",
                    autoFocus    = true,
                    options      = {
                        {
                            text     = L["PASTE"],
                            callback = HandlePasteWayCommands
                        },
                        {
                            text     = L["CANCEL"],
                            callback = nil
                        }
                    },
                    hideOnEscape = true
                })
                return
            end

            local parsedLine = MapPin.ParseWayCommand(inputMessage, GetBestMapForUnit("player"))
            if not parsedLine then
                if not isTomTomLoaded then
                    return ThrowSlashWayError()
                end
                return
            end

            if parsedLine.command == "clear" then
                return GoatWayAPI.Navigation.ClearUserNavigation(nil, true)
            end

            if isTomTomLoaded then
                return
            end

            if not MapPin.IsMultiPinEnabled() then
                local userNavigation = MapPin.NewUserNavigation({
                    name           = parsedLine.name,
                    mapID          = parsedLine.mapID,
                    x              = parsedLine.x,
                    y              = parsedLine.y,
                    flags          = "GoatWay_SlashWay",
                    iconTexture    = WAY_COMMAND_ICON,
                    requestRecolor = true
                })
                if not userNavigation then
                    return ThrowSlashWayError()
                end
                return
            end

            local pinInfo, pinID = MapPin.NewGeneratedPin({
                name           = parsedLine.name,
                mapID          = parsedLine.mapID,
                x              = parsedLine.x,
                y              = parsedLine.y,
                flags          = "GoatWay_SlashWay",
                iconTexture    = WAY_COMMAND_ICON,
                requestRecolor = true
            })
            if not pinInfo or not pinID then
                if not isTomTomLoaded then
                    return ThrowSlashWayError()
                end
                return
            end

            MapPin.NewUserNavigationFromPin(pinID)
        end
    end
    do -- /goatway /gw
        function Handlers.HandleSlashCmd_GoatWay(_, tokens)
            local firstToken = tokens[1] and tokens[1]:lower()

            if not firstToken then
                GoatWayAPI.OpenSettingsUI()
            elseif firstToken == "reset" or firstToken == "clear" or firstToken == "r" or firstToken == "c" then
                GoatWayAPI.Navigation.ClearDestination()
            elseif firstToken == "arrow" or firstToken == "halo" then
                -- Same words as GoatQuest's /gqviewer arrow|halo.
                Config.DBGlobal:SetVariable("NavigatorStyle", firstToken == "halo" and Enum.NavigatorStyle.Halo or Enum.NavigatorStyle.Arrow)
                DEFAULT_CHAT_FRAME:AddMessage(env.NAME_COLORED .. ": " .. L[firstToken == "halo" and "SLASH_NAVIGATOR_HALO" or "SLASH_NAVIGATOR_ARROW"])
            else
                DEFAULT_CHAT_FRAME:AddMessage(env.NAME_COLORED .. ": " .. L["SLASH_USAGE"])
            end
        end
    end

    local Schema = {
        -- /way
        {
            name     = "GOATWAY_WAY",
            hook     = "TOMTOM_WAY",
            command  = "way",
            callback = Handlers.HandleSlashCmd_Way
        },
        -- /goatway /gw
        {
            name     = "GOATWAY",
            hook     = nil,
            command  = { "goatway", "gw" },
            callback = Handlers.HandleSlashCmd_GoatWay
        }
    }

    function SlashCmdRegister.LoadSchema()
        SlashCommand.AddFromSchema(Schema)
    end
end


local SoundHandler = {}
do
    local function UpdateMainSoundLayer()
        local Settings_AudioGlobal = Config.DBGlobal:GetVariable("AudioGlobal")

        if Settings_AudioGlobal == true then
            Sound.SetEnabled("Main", true)
        elseif Settings_AudioGlobal == false then
            Sound.SetEnabled("Main", false)
        end
    end

    SavedVariables.OnChange("GoatWayDB_Global", "AudioGlobal", UpdateMainSoundLayer)

    function SoundHandler.Load()
        UpdateMainSoundLayer()
    end
end


local FontHandler = {}
do
    local function UpdateFonts()
        UIFont.CustomFont:RefreshFontList()

        local fontPath = Config.DBGlobal:GetVariable("fontPath")
        if fontPath == nil or not UIFont.CustomFont.FontExists(fontPath) then
            fontPath = UIFont.CustomFont.GetFontPathForIndex(1)
        end

        local bodyPath, titlePath, numberPath = GoatStyle.ResolveFontRoles(fontPath)
        local footerFlags = UIFont.Enum.FontFlags[Config.DBGlobal:GetVariable("WaypointDistanceTextFontFlags") or 1]

        UIFont.GoatWayFooterTitleFont:SetFontFile(titlePath)
        UIFont.GoatWayFooterTitleFont:SetFontFlags(footerFlags)
        UIFont.GoatWayFooterFont:SetFontFile(numberPath)
        UIFont.GoatWayFooterFont:SetFontFlags(footerFlags)
        UIFont.GoatWayPinpointFont:SetFontFile(bodyPath)
        UIFont.GoatWayPinpointFont:SetFontFlags(UIFont.Enum.FontFlags[Config.DBGlobal:GetVariable("PinpointFontFlags") or 1])

        UIFont.SetNormalFont(bodyPath, titlePath)
        Config.DBGlobal:SetVariable("fontPath", fontPath)
    end

    SavedVariables.OnChange("GoatWayDB_Global", "fontPath", UpdateFonts)
    SavedVariables.OnChange("GoatWayDB_Global", "WaypointDistanceTextFontFlags", UpdateFonts)
    SavedVariables.OnChange("GoatWayDB_Global", "PinpointFontFlags", UpdateFonts)

    function FontHandler.Load()
        UpdateFonts()
    end
end


local function LoadAddon()
    Config.LoadDB()
    SlashCmdRegister.LoadSchema()
    SoundHandler.Load()

    CVarUtil.SetCVar("showInGameNavigation", true, CVarUtil.Enum.TemporaryType.UntilLogout)
    Config.DBGlobal:SetVariable("lastLoadedVersion", env.VERSION_NUMBER)
    CallbackRegistry.Trigger("Preload.AddonReady")
end

-- GoatWay is a restyled Waypoint UI: with both enabled, two markers track the
-- same destination and both hide the game's own. Say so once per session.
local function WarnAboutTheOriginalAddon()
    if IsAddOnLoaded("WaypointUI") then
        DEFAULT_CHAT_FRAME:AddMessage(env.NAME_COLORED .. ": " .. L["WAYPOINTUI_CONFLICT"])
    end
end

CallbackRegistry.Add("WoWClient.OnAddonLoaded", LoadAddon)
CallbackRegistry.Add("WoWClient.OnPlayerLogin", FontHandler.Load)
CallbackRegistry.Add("WoWClient.OnPlayerLogin", WarnAboutTheOriginalAddon)
