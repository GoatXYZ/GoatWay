"""GoatWay follows GoatQuest: the arrow's waypoint becomes the destination,
the accent and ring position come from GoatQuest, and GoatWay's halo steps
aside for GoatQuest's."""
import gwharness

MAGE = (0.25, 0.78, 0.92)
GOLD = (245 / 255, 191 / 255, 41 / 255)


def close(a, b, eps=1e-3):
    return all(abs(x - y) < eps for x, y in zip(a, b))


def fake_goatquest(lua, g):
    # The parts of GoatQuest GoatWay reads: the public GoatQuest table, the
    # Pointer's arrow waypoint and Show/HideArrow, the viewer's accent and
    # halo ring, and the saved ring position.
    lua.execute("""
        GoatQuest = {
            Pointer = { ArrowFrame = {} },
            Styles = { accent = { 0.25, 0.78, 0.92 }, Halo = { ring = CreateFrame("Frame") } },
            db = { profile = { viewer_halo_offset = -120, viewer_halo_x = 14 } },
        }
        GoatQuest.Styles.Halo.ring:Hide()
        function GoatQuest.Styles:GetAccent() return unpack(self.accent) end
        function GoatQuest.Pointer:ShowArrow(way) self.ArrowFrame.waypoint = way end
        function GoatQuest.Pointer:HideArrow() self.ArrowFrame.waypoint = nil end
        Mock.world.addons.GoatQuest = true
        Mock.world.distance = 300
    """)


lua, g = gwharness.load_goatway(before_login=fake_goatquest)
M, env = g.Mock, g.GW_ENV
MapPin = env["module:@\\MapPin"]
GQ = env["module:@\\SupportedAddons\\GoatQuest"]
Halo = env["module:@\\Halo"]
Pointer = g.GoatQuest.Pointer
show_arrow = lua.eval("function(t) GoatQuest.Pointer:ShowArrow(t) end")
hide_arrow = lua.eval("function() GoatQuest.Pointer:HideArrow() end")


def way(**fields):
    t = lua.table()
    for k, v in fields.items():
        t[k] = v
    return t


def set_calls():
    return sum(1 for c in M.calls.values() if c == "SetUserWaypoint")


# Nothing to follow yet.
assert MapPin.GetUserNavigation() is None

# The arrow points somewhere: GoatWay marks it, named from the fixed title.
show_arrow(way(m=1436, x=0.42, y=0.61, type="way",
               arrowtitle="|cffffd100Boars|r in |TInterface\\Icons\\X:0|tWestfall\n|cffaaaaaaVia the road|r"))
M.advance(0.2)
nav = MapPin.GetUserNavigation()
assert nav is not None and nav.flags == "GoatQuest_Waypoint", "follows the arrow"
assert nav.name == "Boars in Westfall", repr(nav.name)
assert abs(nav.x - 0.42) < 1e-6 and abs(nav.y - 0.61) < 1e-6 and nav.mapID == 1436
assert str(nav.iconTexture).endswith("Art\\Icons\\GoatQuest")
print("PASS goatquest: follows the arrow with a clean title and the goat icon")

# The marker takes GoatQuest's accent (a mage's class colour here).
W = g.GoatWayWaypointFrame
assert W.IsShown(W)
stroke = W.ContextIcon.BackgroundTexture.GetTextureObject(W.ContextIcon.BackgroundTexture)
assert close(stroke.GetVertexColor(stroke)[:3], MAGE), stroke.GetVertexColor(stroke)
dist = W.Footer.DistanceText
assert close(dist.GetTextColor(dist)[:3], MAGE)

# GoatQuest's accent changes; GoatWay follows within a second.
lua.execute("GoatQuest.Styles.accent = { 0.96, 0.55, 0.73 }")
M.advance(1.1)
assert close(stroke.GetVertexColor(stroke)[:3], (0.96, 0.55, 0.73)), "re-tints when GoatQuest's accent changes"
print("PASS goatquest: marker matches GoatQuest's accent and follows changes")

# Progress in the title (same place) does not re-navigate.
before = set_calls()
show_arrow(way(m=1436, x=0.42, y=0.61, type="way", arrowtitle="Boars 4/8"))
M.advance(1.0)
assert set_calls() == before and MapPin.GetUserNavigation().name == "Boars in Westfall"

# A new place does.
show_arrow(way(m=1436, x=0.30, y=0.20, type="route", title="Flight Master"))
M.advance(0.2)
nav = MapPin.GetUserNavigation()
assert set_calls() > before and nav.name == "Flight Master" and abs(nav.x - 0.30) < 1e-6
print("PASS goatquest: re-navigates on a new place, not on progress")

# Corpse arrows are the game's; the arrow hiding clears GoatWay's mark.
show_arrow(way(m=1436, x=0.9, y=0.9, type="corpse", title="Your corpse"))
M.advance(0.6)
assert MapPin.GetUserNavigation() is None or MapPin.GetUserNavigation().name != "Your corpse"
hide_arrow()
M.advance(0.2)
assert MapPin.GetUserNavigation() is None, "cleared with the arrow"
print("PASS goatquest: ignores corpse arrows and clears with the arrow")

# Turned off: the arrow is not followed.
g.GoatWayDB_Global.GoatQuestSupportEnabled = False
show_arrow(way(m=1436, x=0.5, y=0.5, type="way", title="Elsewhere"))
M.advance(1.0)
assert MapPin.GetUserNavigation() is None
g.GoatWayDB_Global.GoatQuestSupportEnabled = True
GQ.Reset()

# Auto-replace off while tracking a quest: ask first, and only once.
prompt_opens = lua.eval("""function()
    local n = 0
    hooksecurefunc(GoatWaySharedPrompt, "Open", function() n = n + 1 end)
    return function() return n end
end""")()
g.GoatWayDB_Global.GoatQuestAutoReplaceWaypoint = False
lua.execute("C_SuperTrack.SetSuperTrackedQuestID(123)")
show_arrow(way(m=1436, x=0.55, y=0.45, type="way", title="Next Step"))
M.advance(0.3)
prompt = g.GoatWaySharedPrompt
assert prompt_opens() == 1 and prompt.IsShown(prompt), "prompts before replacing another destination"
assert MapPin.GetUserNavigation() is None
text = prompt.Text.GetText(prompt.Text)
assert "Next Step" in text and "GoatQuest" in text, text
lua.execute("GoatWaySharedPrompt:HidePrompt()")
M.advance(2.0)
assert prompt_opens() == 1, "a dismissed prompt is not repeated for the same place"
assert MapPin.GetUserNavigation() is None

# Accepting the prompt follows the arrow.
show_arrow(way(m=1436, x=0.65, y=0.35, type="way", title="Step After"))
M.advance(0.3)
assert prompt_opens() == 2
primary = lua.eval("""function(label)
    for _, element in ipairs(Mock.allObjects) do
        if type(rawget(element, "value")) == "table" and element.value.text == label and element:IsVisible() then
            return element.isRed
        end
    end
end""")
assert primary("Replace") is True and primary("Cancel") is False, "GoatQuest dialog: gold Replace, neutral Cancel"
accept = lua.eval("""function()
    for _, element in ipairs(Mock.allObjects) do
        if rawget(element, "index") == 1 and type(rawget(element, "value")) == "table"
            and element.value.text == "Replace" and element:IsVisible() then
            element.value.callback()
            return true
        end
    end
end""")
assert accept(), "the prompt's first option is Replace"
M.advance(0.2)
assert MapPin.GetUserNavigation().name == "Step After"
g.GoatWayDB_Global.GoatQuestAutoReplaceWaypoint = True
print("PASS goatquest: asks before replacing, once per place, and follows on Replace")

# Halo: GoatQuest's ring position, and stepping aside for GoatQuest's halo.
assert tuple(Halo.GetPosition()) == (14, -120), Halo.GetPosition()
g.GoatWayDB_Global.HaloMatchGoatQuest = False
assert tuple(Halo.GetPosition()) == (0, -90)
g.GoatWayDB_Global.HaloMatchGoatQuest = True

GQ.Reset()
show_arrow(way(m=1436, x=0.5, y=0.3, type="way", title="North"))
g.SlashCmdList.GOATWAY("halo")
M.advance(0.5)
assert Halo.root.IsShown(Halo.root)
ring = g.GoatQuest.Styles.Halo.ring
ring.Show(ring)
M.advance(1.1)
assert not Halo.root.IsShown(Halo.root), "steps aside while GoatQuest's halo is on screen"
ring.Hide(ring)
M.advance(1.1)
assert Halo.root.IsShown(Halo.root)
print("PASS goatquest: halo uses GoatQuest's ring position and never doubles up")
