local env = select(2, ...)
local Path = env.modules:Import("packages\\path")
local UIKit = env.modules:Import("packages\\ui-kit")
local Frame, LayoutGrid, LayoutHorizontal, LayoutVertical, Text, ScrollContainer, LazyScrollContainer, ScrollBar, ScrollContainerEdge, Input, LinearSlider, HitRect, List, SecureButton, ModelScene = unpack(UIKit.UI.Frames)
local UIAnim = env.modules:Import("packages\\ui-anim")
local UICCommon = env.modules:Import("packages\\uic-common")
local UIFont = env.modules:Import("packages\\ui-font")
local GoatStyle = env.modules:Import("packages\\goatway-style")
local Settings_Preload = env.modules:Import("@\\Settings\\Preload")

do -- Setting
    local name = Settings_Preload.FRAME_NAME
    local id = Settings_Preload.FRAME_NAME

    -- GoatQuest's window: a slate content column, an ink sidebar behind a
    -- hairline, the gold rule along the top, and the mark and name at the
    -- head of the sidebar.
    local HEADER_HEIGHT = 64
    local RULE_HEIGHT = 2
    local PAD = 22

    local frame = Frame(name .. ".Frame", {
        Frame(name .. ".Rule")
            :id("Rule", id)
            :point(UIKit.Enum.Point.Top)
            :size(UIKit.Define.Percentage{ value = 100 }, RULE_HEIGHT)
            :frameLevel(20)
            :background(Settings_Preload.UIDEF.Divider)
            :backgroundColor(GoatStyle.UIColor("Gold")),

        Frame(name .. ".Sidebar", {
            Frame(name .. ".Sidebar.Divider")
                :id("Sidebar.Divider", id)
                :point(UIKit.Enum.Point.Right)
                :size(1, UIKit.Define.Percentage{ value = 100 })
                :background(Settings_Preload.UIDEF.Divider)
                :backgroundColor(GoatStyle.UIColor("White", 0.07)),

            Frame(name .. ".Sidebar.Header", {
                Frame(name .. ".Sidebar.Header.Logo")
                    :id("Sidebar.Header.Logo", id)
                    :point(UIKit.Enum.Point.Left)
                    :x(PAD - 4)
                    :size(34, 34)
                    :background(Settings_Preload.UIDEF.Logo),

                Text(name .. ".Sidebar.Header.Title")
                    :id("Sidebar.Header.Title", id)
                    :point(UIKit.Enum.Point.Left)
                    :x(PAD + 38)
                    :y(7)
                    :size(UIKit.UI.FIT, UIKit.UI.FIT)
                    :fontObject(UIFont.UIFontObjectNormal16)
                    :textColor(GoatStyle.UIColor("Text"))
                    :text(env.NAME),

                Text(name .. ".Sidebar.Header.Version")
                    :id("Sidebar.Header.Version", id)
                    :point(UIKit.Enum.Point.Left)
                    :x(PAD + 38)
                    :y(-10)
                    :size(UIKit.UI.FIT, UIKit.UI.FIT)
                    :fontObject(UIFont.UIFontObjectNormal11)
                    :textColor(GoatStyle.UIColor("Muted"))
                    :text(env.VERSION_STRING)
            })
                :id("Sidebar.Header", id)
                :point(UIKit.Enum.Point.Top)
                :y(-RULE_HEIGHT)
                :size(UIKit.Define.Percentage{ value = 100 }, HEADER_HEIGHT),

            Frame(name .. ".Sidebar.Content", {
                LayoutVertical(name .. ".Sidebar.Tab")
                    :id("Sidebar.Tab", id)
                    :point(UIKit.Enum.Point.Top)
                    :size(UIKit.Define.Percentage{ value = 100 }, UIKit.Define.Percentage{ value = 100, operator = "-", delta = 75 })
                    :layoutSpacing(3),

                LayoutVertical(name .. ".Sidebar.Footer")
                    :id("Sidebar.Footer", id)
                    :point(UIKit.Enum.Point.Bottom)
                    :size(UIKit.Define.Percentage{ value = 100 }, 75)
                    :layoutAlignmentV(UIKit.Enum.Direction.Trailing)
                    :layoutSpacing(3)
            })
                :id("Sidebar.Content", id)
                :size(UIKit.Define.Fill{ left = PAD - 10, right = PAD - 10, top = RULE_HEIGHT + HEADER_HEIGHT + 6, bottom = PAD })
        })
            :id("Sidebar", id)
            :point(UIKit.Enum.Point.Left)
            :size(212, UIKit.Define.Percentage{ value = 100 })
            :background(Settings_Preload.UIDEF.Divider)
            :backgroundColor(GoatStyle.UIColor("Ink")),

        Frame(name .. ".Content", {
            Frame(name .. ".Content.Container")
                :id("Content.Container", id)
                :point(UIKit.Enum.Point.Center)
                :size(UIKit.Define.Percentage{ value = 100, operator = "-", delta = 35 }, UIKit.Define.Percentage{ value = 100 })
        })
            :id("Content", id)
            :point(UIKit.Enum.Point.Right)
            :size(UIKit.Define.Percentage{ value = 100, operator = "-", delta = 212 }, UIKit.Define.Percentage{ value = 100 })
    })
        :background(Settings_Preload.UIDEF.Divider)
        :backgroundColor(GoatStyle.UIColor("Slate"))

    frame.Sidebar = UIKit.GetElementById("Sidebar", id)
    frame.Sidebar.Content = UIKit.GetElementById("Sidebar.Content", id)
    frame.Sidebar.Image = UIKit.GetElementById("Sidebar.Image", id)
    frame.Sidebar.Tab = UIKit.GetElementById("Sidebar.Tab", id)
    frame.Sidebar.Footer = UIKit.GetElementById("Sidebar.Footer", id)
    frame.Content = UIKit.GetElementById("Content", id)
    frame.Content.Container = UIKit.GetElementById("Content.Container", id)
    _G[name] = frame
end

do -- Prompt
    local name = Settings_Preload.FRAME_NAME
    local id = Settings_Preload.FRAME_NAME

    local frame = UICCommon.PromptText(name .. ".Prompt")
        :frameStrata(UIKit.Enum.FrameStrata.FullscreenDialog, 100)
        :parent(UIParent)
        :anchor(StaticPopup1)
        :point(UIKit.Enum.Point.Center)
        :_Render()

    frame:Hide()
    _G[Settings_Preload.FRAME_NAME].Prompt = frame
end

do -- Selection Menu
    local name = Settings_Preload.FRAME_NAME
    local id = Settings_Preload.FRAME_NAME

    local frame = UICCommon.SelectionMenu(name .. ".SelectionMenu")
        :parent(_G[Settings_Preload.FRAME_NAME])
        :frameStrata(UIKit.Enum.FrameStrata.FullscreenDialog)
        :size(175, UIKit.Define.Fit{})
        :_Render()

    frame:Hide()
    _G[Settings_Preload.FRAME_NAME].SelectionMenu = frame
end
