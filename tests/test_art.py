"""Every texture the code names exists, in a format and size the atlases expect."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import make_art  # noqa: E402

# Every Path.Root .. "\\..." texture reference in the code.
refs = set()
for path in list((ROOT / "Code").rglob("*.lua")) + list((ROOT / "packages").rglob("*.lua")) + [ROOT / "Preload.lua"]:
    for m in re.finditer(r'Path\.Root \.\. "((?:\\\\[\w-]+)+)"', path.read_text(encoding="utf-8")):
        rel = m.group(1).replace("\\\\", "/").lstrip("/")
        if not rel.startswith(("Art/", "packages/")) or rel.endswith(".ogg") or "/Sound/" in rel:
            continue
        refs.add(rel)
refs.discard("Art/Icons")  # the icon folder prefix, completed below

missing = []
for rel in sorted(refs):
    candidates = [ROOT / rel] if Path(rel).suffix else [ROOT / (rel + ".blp"), ROOT / (rel + ".tga")]
    if not any(c.is_file() for c in candidates):
        missing.append(rel)
assert not missing, f"Textures named in code but missing: {missing}"

# Quest icons the context icon code can ask for (Waypoint_ContextIcon.lua).
kinds = ["", "Important", "Campaign", "Legendary", "Artifact", "Calling", "Meta", "Recurring", "Repeatable"]
for status in ("Available", "Complete", "Incomplete"):
    for kind in kinds:
        icon = ROOT / "Art" / "Icons" / f"{status}{kind}Quest.blp"
        assert icon.is_file(), f"missing quest icon {icon.name}"

# Atlas sizes the UV rectangles in the Lua definitions assume.
SIZES = {
    "Art/Waypoint/Waypoint.blp": (1024, 1024),
    "Art/MapPinFrame/MapPinFrame.blp": (256, 128),
    "packages/uic-common/resources/common.blp": (512, 512),
    "Art/Settings/TabButton.blp": (256, 128),
    "Art/Settings/Widget-Container.blp": (128, 64),
    "Art/Settings/Widget-Background.blp": (64, 64),
    "Art/Icons/Logo.blp": (128, 128),
    "Art/Icons/GoatQuest.blp": (64, 64),
}
for rel, size in SIZES.items():
    img = make_art.read_blp(ROOT / rel)
    assert img.size == size, (rel, img.size)

# Every BLP GoatWay draws is the uncompressed BLP2 the client already loads.
drawn = [p for p in ROOT.rglob("*.blp") if "Mask" not in p.name and p.parent.name != "Primitives"]
for path in drawn:
    img = make_art.read_blp(path)
    w, h = img.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f"{path.name} is not a power of two"

# The tinted parts are white so the tint shows true; panels keep their ink.
wp = make_art.read_blp(ROOT / "Art/Waypoint/Waypoint.blp")
assert wp.getpixel((64, 128 + 64 - 59 + 3))[:3] == (255, 255, 255), "diamond stroke is white"
INK = (15, 17, 21)


def near_ink(px):
    return all(abs(c - i) <= 2 for c, i in zip(px[:3], INK))


# The diamond's ink sits over its dark keyline, so it may read a level darker.
px = wp.getpixel((64, 128 + 64))
assert near_ink(px) and px[3] > 200, ("diamond fill is GoatQuest ink", px)
px = wp.getpixel((128, 64))
assert near_ink(px) and px[3] > 230, ("pinpoint card is ink", px)

# The Halo uses GoatQuest's own textures.
for name in ("ring", "ring-shadow", "dot", "vchev", "chevron", "chevron-shadow"):
    assert (ROOT / "Art" / "Halo" / f"{name}.tga").is_file(), name
for font in ("Archivo-Regular", "Archivo-SemiBold", "ArchivoNarrow-SemiBold", "AtkinsonHyperlegible-Bold"):
    assert (ROOT / "Art" / "Fonts" / f"{font}.ttf").is_file(), font

print(f"PASS art: {len(refs)} texture references resolve; atlases, icons, halo and fonts in place")
