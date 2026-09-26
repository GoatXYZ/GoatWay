"""The shipped add-on says GoatWay everywhere; Waypoint UI appears only as credit."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# Old identifiers must not survive the rebrand anywhere in code.
OLD_IDENTIFIERS = re.compile(r"\bWUI|WaypointUI|WaypointDB|WAYPOINT_UI")
# The old name may appear only as credit (comments, the TOC author line, the
# About panel's "Based On" strings) or when naming the other add-on in the
# conflict notice.
OLD_NAME = re.compile(r"Waypoint UI")
CREDIT_KEYS = ("CONFIG_ABOUT_BASEDON_WAYPOINTUI", "## Author:", 'L["WAYPOINTUI_CONFLICT"]', 'IsAddOnLoaded("WaypointUI")')

offenders = []
for path in ROOT.rglob("*"):
    if ".git" in path.parts or "tests" in path.parts or not path.is_file():
        continue
    if path.suffix not in {".lua", ".xml", ".toc"}:
        continue
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        credit = stripped.startswith("--") or any(key in line for key in CREDIT_KEYS)
        if (OLD_IDENTIFIERS.search(line) or OLD_NAME.search(line)) and not credit:
            offenders.append(f"{path.relative_to(ROOT)}:{n}: {stripped}")
assert not offenders, "Old branding left in code:\n" + "\n".join(offenders)

toc = (ROOT / "GoatWay.toc").read_text(encoding="utf-8")
assert "## Interface: 16001" in toc, "GoatWay targets WoW Forever (interface 16001)"
assert "## Title: |cfff4bf2aGoatWay|r" in toc, "Title uses GoatQuest gold"
assert "GoatWayDB_Global" in toc and "GoatWayAPI_OpenSettingsUI" in toc
assert re.search(r"## OptionalDeps:.*\bGoatQuest\b", toc), "GoatQuest must load first so GoatWay can follow it"
assert not list(ROOT.glob("*.toc"))[1:], "Ship a single TOC"

readme = (ROOT / "README.md").read_text(encoding="utf-8")
assert "AdaptiveX" in readme and "Waypoint UI" in readme, "README names the original project"

print("PASS branding: GoatWay name, SavedVariables, API and source attribution")
