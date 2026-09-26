"""Every string the code asks for exists in English, and clients whose script
the shipped fonts cannot draw fall back to the game font (as GoatQuest does)."""
from pathlib import Path
import re

import gwharness

ROOT = Path(__file__).resolve().parents[1]
defined = set(re.findall(r'^L\["([A-Za-z0-9_]+)"\]\s*=', (ROOT / "Locales/enUS.lua").read_text(encoding="utf-8"), re.M))

used = set()
for path in [ROOT / "Preload.lua", ROOT / "API.lua"] + list((ROOT / "Code").rglob("*.lua")):
    used |= set(re.findall(r'\bL\["([A-Za-z0-9_]+)"\]', path.read_text(encoding="utf-8")))
missing = sorted(used - defined)
assert not missing, f"Strings used but not defined in enUS: {missing}"
print(f"PASS locales: all {len(used)} strings the code uses are defined in English")

for locale in ("koKR", "zhCN", "ruRU"):
    lua = gwharness.new_runtime()
    lua.globals().Mock.locale = locale
    lua, g = gwharness.load_goatway(lua=lua)
    CustomFont = g.GW_ENV["module:packages\\ui-font\\custom-font"]
    names = list(CustomFont.GetFontNames().values())
    assert names[0] == "Game Font" and "Archivo" not in names, (locale, names)
    UIFont = g.GW_ENV["module:packages\\ui-font"]
    path = UIFont.GoatWayFooterFont.GetFont(UIFont.GoatWayFooterFont)[0]
    assert "GoatWay\\Art\\Fonts" not in path, (locale, path)
print("PASS locales: Korean, Chinese and Russian clients use the game font")
