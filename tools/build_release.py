"""Build a GitHub release ZIP without GitHub Actions or third-party packages."""

from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ADDON = "GoatWay"
RUNTIME_DIRS = {"Art", "Code", "libs", "Locales", "packages", "Sound"}
ROOT_FILES = {"README.md"}
ROOT_SUFFIXES = {".lua", ".xml", ".toc"}
EXCLUDED_PARTS = {"tests", "tools", "design", "__pycache__"}


def version() -> str:
    toc = (ROOT / f"{ADDON}.toc").read_text(encoding="utf-8-sig")
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", toc, re.MULTILINE)
    if not match:
        raise SystemExit("Missing semantic version in TOC")
    value = match.group(1)
    preload = (ROOT / "Preload.lua").read_text(encoding="utf-8-sig")
    if f'env.VERSION_STRING = "{value}"' not in preload:
        raise SystemExit("Preload.lua version differs from the TOC")
    return value


def release_files() -> list[tuple[str, Path]]:
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    result = []
    for relative in filter(None, tracked.decode("utf-8").split("\0")):
        parts = PurePosixPath(relative).parts
        if any(part in EXCLUDED_PARTS for part in parts):
            continue
        if len(parts) == 1:
            if relative not in ROOT_FILES and PurePosixPath(relative).suffix.lower() not in ROOT_SUFFIXES:
                continue
        elif parts[0] not in RUNTIME_DIRS:
            continue
        path = ROOT.joinpath(*parts)
        if not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise SystemExit(f"Missing or external tracked file: {relative}")
        result.append((f"{ADDON}/{relative}", path))
    if f"{ADDON}/{ADDON}.toc" not in {name for name, _ in result}:
        raise SystemExit("Release is missing its primary TOC")
    return sorted(result)


def main() -> None:
    value = version()
    archive = ROOT / "dist" / f"{ADDON}-{value}.zip"
    archive.parent.mkdir(exist_ok=True)
    files = release_files()
    with zipfile.ZipFile(archive, "w") as output:
        for name, path in files:
            entry = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o644 << 16
            output.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None:
            raise SystemExit("Release ZIP failed its integrity check")
    print(f"Built {archive} ({len(files)} files)")


if __name__ == "__main__":
    main()
