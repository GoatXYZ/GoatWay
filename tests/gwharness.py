"""Load all of GoatWay into a fresh Lua 5.1 runtime over tests/wowmock.lua.

    lua, g = load_goatway(before_login=callable)

Files run in TOC order with WoW's (addonName, addonTable) varargs. After
loading, ADDON_LOADED, PLAYER_LOGIN and PLAYER_ENTERING_WORLD fire and a
little time passes, as on a real login.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
TESTS = Path(__file__).resolve().parent


def load_order():
    files = []

    def visit(path):
        if path.suffix == ".lua":
            files.append(path)
            return
        tree = ET.fromstring(path.read_bytes())
        for element in tree.iter():
            tag = element.tag.split("}")[-1]
            if tag in {"Include", "Script"} and element.get("file"):
                visit((path.parent / element.get("file").replace("\\", "/")).resolve())

    for line in (ROOT / "GoatWay.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            visit((ROOT / line.replace("\\", "/")).resolve())
    return files


def new_runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((TESTS / "wowmock.lua").read_text(encoding="utf-8"))
    return lua


def load_goatway(before_login=None, lua=None):
    lua = lua or new_runtime()
    g = lua.globals()
    g.GW_ENV = lua.table()
    run_file = lua.eval("""function(path, label)
        local chunk, err = loadfile(path)
        if not chunk then error(err, 0) end
        local ok, runErr = xpcall(function() chunk("GoatWay", GW_ENV) end, debug.traceback)
        if not ok then error(label .. ": " .. tostring(runErr), 0) end
    end""")
    for path in load_order():
        run_file(str(path), str(path.relative_to(ROOT)))
    if before_login:
        before_login(lua, g)
    fire = g.Mock.fire
    fire("ADDON_LOADED", "GoatWay")
    g.Mock.loggedIn = True
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD", True, False)
    # HereBeDragons builds its zone table from game data; give it the test zone
    # (the mock's map model: width, height, left, top on instance 0).
    lua.execute("""
        local w = Mock.world
        LibStub("HereBeDragons-2.0").mapData[w.playerMap] = { w.mapSize[1], w.mapSize[2], Mock.MAP_LEFT, Mock.MAP_TOP, instance = 0 }
    """)
    g.Mock.advance(0.5)
    return lua, g


def unknown_globals(g):
    return sorted(str(k) for k in g.Mock.unknown.keys())
