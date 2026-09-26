"""GoatWay running end to end over the WoW mock: login, /way, the marker,
pinpoint and halo in the GoatQuest style, the settings window, and the
unknown-global net."""
import math

import gwharness

GOLD = (245 / 255, 191 / 255, 41 / 255)
TEXT = (236 / 255, 234 / 255, 230 / 255)
MUTED = (141 / 255, 147 / 255, 156 / 255)
FONTS = "Interface\\AddOns\\GoatWay\\Art\\Fonts\\"


def close(a, b, eps=1e-3):
    return all(abs(x - y) < eps for x, y in zip(a, b))


def rgb(*values):
    return tuple(values[:3])


lua, g = gwharness.load_goatway()
M, env = g.Mock, g.GW_ENV
UIFont = env["module:packages\\ui-font"]

# --- Login: SavedVariables, fonts, slash commands --------------------------
assert g.GoatWayDB_Global is not None, "GoatWayDB_Global is created on login"
assert g.GoatWayDB_Global.fontPath == FONTS + "Archivo-Regular.ttf", g.GoatWayDB_Global.fontPath
assert UIFont.GoatWayFooterTitleFont.GetFont(UIFont.GoatWayFooterTitleFont)[0] == FONTS + "Archivo-SemiBold.ttf"
assert UIFont.GoatWayFooterFont.GetFont(UIFont.GoatWayFooterFont)[0] == FONTS + "ArchivoNarrow-SemiBold.ttf"
assert UIFont.GoatWayPinpointFont.GetFont(UIFont.GoatWayPinpointFont)[0] == FONTS + "Archivo-Regular.ttf"
assert UIFont.UIFontObjectNormal12.GetFont(UIFont.UIFontObjectNormal12)[0] == FONTS + "Archivo-Regular.ttf"
assert UIFont.UIFontObjectNormal14.GetFont(UIFont.UIFontObjectNormal14)[0] == FONTS + "Archivo-SemiBold.ttf"
assert (g.SLASH_GOATWAY1, g.SLASH_GOATWAY2, g.SLASH_GOATWAY_WAY1) == ("/goatway", "/gw", "/way")
print("PASS runtime: login, SavedVariables, GoatQuest fonts, slash commands")

# --- /way: the in-world marker ---------------------------------------------
M.world.distance = 400
g.SlashCmdList.GOATWAY_WAY("50 40 Home")
M.advance(1.0)
MapPin = env["module:@\\MapPin"]
nav = MapPin.GetUserNavigation()
assert (nav.name, nav.flags, nav.mapID) == ("Home", "GoatWay_SlashWay", 1436)
Director = env["module:@\\Waypoint\\Director"]
assert Director.isActive and Director.navigationMode == 1, "Waypoint mode"

W = g.GoatWayWaypointFrame
assert W.IsShown(W)
stroke = W.ContextIcon.BackgroundTexture.GetTextureObject(W.ContextIcon.BackgroundTexture)
assert close(rgb(*stroke.GetVertexColor(stroke)), GOLD), "marker stroke takes the accent (GoatQuest gold)"
info, dist, eta = W.Footer.InfoText, W.Footer.DistanceText, W.Footer.ArrivalTimeText
assert info.GetText(info) == "Home"
assert dist.GetText(dist) == "400 yds", dist.GetText(dist)
assert close(rgb(*info.GetTextColor(info)), TEXT), "destination name in the text colour"
assert close(rgb(*dist.GetTextColor(dist)), GOLD), "distance in the accent"
assert close(rgb(*eta.GetTextColor(eta)), MUTED), "arrival time muted"
print("PASS runtime: /way marker in GoatQuest colours and type")

# --- Pinpoint: the ink card with the accent rule ---------------------------
M.world.distance = 60
M.advance(0.5)
assert Director.navigationMode == 2, "Pinpoint mode inside 100 yds on Forever"
P = g.GoatWayPinpointFrame
assert P.IsShown(P)
rule = P.Foreground.RuleTexture
assert [rule.GetPoint(rule, i)[0] for i in (1, 2)] == ["TOPLEFT", "TOPRIGHT"] and rule.GetHeight(rule) == 2,     "the rule spans the card's top edge"
card = P.Foreground.BackgroundTexture.GetTextureObject(P.Foreground.BackgroundTexture)
assert close(rgb(*rule.GetVertexColor(rule)), GOLD), "top rule takes the accent"
assert close(rgb(*card.GetVertexColor(card)), (1, 1, 1)), "the card keeps its ink"
content = P.Foreground.Content
# The name, then the coordinates as a muted second line (GoatQuest #8D939C).
assert content.GetText(content) == "Home\n|cff8d939c50.0, 40.0|r", repr(content.GetText(content))
assert close(rgb(*content.GetTextColor(content)), TEXT)
print("PASS runtime: pinpoint card with accent rule")

# --- Halo -------------------------------------------------------------------
Halo = env["module:@\\Halo"]
M.world.distance = 400
M.world.facing = 0
g.SlashCmdList.GOATWAY("halo")
M.advance(0.5)
assert g.GoatWayDB_Global.NavigatorStyle == 2
assert "Navigator set to Halo." in M.chat[len(M.chat)]
assert Halo.root.IsShown(Halo.root), "halo shows while a destination is tracked"


def middle_dot():
    mid = (Halo.DOTS + 1) // 2
    dot = Halo.dots[mid]
    point = dot.GetPoint(dot)
    return point[3], point[4]


# The waypoint is due north of the player (y 0.40 vs 0.50).
x, y = middle_dot()
assert abs(x) < 0.5 and abs(y - Halo.RY) < 0.5, ("facing north: notch on the far side", x, y)
d = Halo.distText
assert d.GetText(d) == "400 yds"
M.world.facing = math.pi / 2  # facing west: north is to the right
M.advance(0.2)
x, y = middle_dot()
assert abs(x - Halo.RX) < 0.5 and abs(y) < 0.5, ("facing west: notch on the right", x, y)
dot = Halo.dots[(Halo.DOTS + 1) // 2]
assert close(rgb(*dot.GetVertexColor(dot)), GOLD), "notch takes the destination colour"

M.world.distance = 10  # inside the 25 yd arrival radius
M.advance(0.5)
assert Halo.arrived and Halo.hereText.IsShown(Halo.hereText), "arrived: the ring says Here"
line = Halo.ringLine
assert close(rgb(*line.GetVertexColor(line)), GOLD), "arrived ring lights up in the accent"
assert not Halo.notchShown
print("PASS runtime: halo points by world bearing and facing, then arrives")

g.SlashCmdList.GOATWAY("arrow")
M.advance(0.2)
assert g.GoatWayDB_Global.NavigatorStyle == 1 and not Halo.root.IsShown(Halo.root)

# --- Settings window --------------------------------------------------------
g.GoatWayAPI.OpenSettingsUI()
frame = g.GoatWaySettingFrame
assert frame.IsShown(frame)
Setting = env["module:@\\Settings"]
Constructor = env["module:@\\Settings\\Constructor"]
tabs = len(Constructor.Tabs)
assert tabs >= 6, tabs
for i in range(1, tabs + 1):
    Setting.OpenTabByIndex(Setting, i)
M.advance(0.3)
title = frame.Sidebar.Header if hasattr(frame.Sidebar, "Header") else None
texts = [fs.GetText(fs) for fs in M.fontStrings.values() if fs.GetText(fs)]
assert "GoatWay" in texts and "1.0.0" in texts, "sidebar header shows the name and version"
print(f"PASS runtime: settings window builds all {tabs} tabs")

# --- Unknown globals are real Blizzard names, never GoatWay typos ----------
expected_nil = {"GoatWayAPI", "GoatWayDB_Global", "GoatWayDB_Global_Persistent", "GoatWayDB_Local",
                "GoatWayDB_Local_Persistent", "GoatQuest"}
suspicious = [n for n in gwharness.unknown_globals(g)
              if (n.startswith("GoatWay") or n.startswith("Waypoint") or n.startswith("WUI")) and n not in expected_nil]
assert not suspicious, f"GoatWay reads undefined globals: {suspicious}"
print("PASS runtime: no undefined GoatWay globals")

# --- Waypoint UI enabled alongside: say so once ----------------------------
lua2, g2 = gwharness.load_goatway(before_login=lambda lua, g: lua.execute("Mock.world.addons.WaypointUI = true"))
notices = [m for m in g2.Mock.chat.values() if "Waypoint UI is also enabled" in m]
assert len(notices) == 1, list(g2.Mock.chat.values())
lua3, g3 = gwharness.load_goatway()
assert not any("Waypoint UI" in m for m in g3.Mock.chat.values())
print("PASS runtime: warns once when Waypoint UI is also enabled")
