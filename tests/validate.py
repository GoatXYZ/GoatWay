"""Offline GoatWay checks. Requires Python 3.10+ with lupa (Lua 5.1) and Pillow.

    py -3 tests/validate.py

Runs the load-graph check below, then every tests/test_*.py file.
"""
from pathlib import Path
import runpy
import sys
import xml.etree.ElementTree as ET

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS))

lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
loaded = []
seen = set()


def visit(path):
    path = path.resolve()
    assert path.is_relative_to(ROOT), f"Load dependency outside the addon: {path}"
    assert path.is_file(), f"Missing load dependency: {path}"
    # WoW resolves paths case-insensitively on Windows but not on macOS.
    actual = {p.name for p in path.parent.iterdir()}
    assert path.name in actual, f"Case mismatch for {path.name} in {path.parent}"
    if path in seen:
        return
    seen.add(path)
    data = path.read_bytes().removeprefix(b"\xef\xbb\xbf")
    if path.suffix == ".lua":
        lua.compile(data)
        loaded.append(path)
    elif path.suffix == ".xml":
        tree = ET.fromstring(data)
        for element in tree.iter():
            tag = element.tag.split("}")[-1]
            if tag in {"Include", "Script"} and element.get("file"):
                visit(path.parent / element.get("file").replace("\\", "/"))


def toc_files():
    for line in (ROOT / "GoatWay.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            yield ROOT / line.replace("\\", "/")


for entry in toc_files():
    visit(entry)
print(f"PASS load graph: {len(loaded)} Lua files compile under Lua 5.1")

failed = 0
for test in sorted(TESTS.glob("test_*.py")):
    try:
        runpy.run_path(str(test), run_name="__main__")
    except Exception as exc:  # report every failing file, not just the first
        failed += 1
        print(f"FAIL {test.name}: {type(exc).__name__}: {exc}")
        import traceback
        traceback.print_exc()
if failed:
    sys.exit(f"{failed} test file(s) failed")
print("All GoatWay checks passed.")
