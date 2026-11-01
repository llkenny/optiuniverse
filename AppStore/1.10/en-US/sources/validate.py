#!/usr/bin/env python3
"""Validate release assets; pass --write-manifest after regenerating exports."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[2]
LIMITS = {"description.txt": 4000, "release_notes.txt": 4000,
          "promotional_text.txt": 170, "keywords.txt": 100}
SCENES = ["01-saturn", "02-jupiter", "03-orbits", "04-earth", "05-home", "06-crew13"]
DUO = [
    ("01-outer-portrait-saturn", 1398, 2034, "outer", "portrait"),
    ("02-outer-portrait-crew13", 1398, 2034, "outer", "portrait"),
    ("03-outer-landscape-earth", 2034, 1398, "outer", "landscape"),
    ("04-outer-landscape-orbits", 2034, 1398, "outer", "landscape"),
    ("05-inner-portrait-home", 2007, 2853, "inner", "portrait"),
    ("06-inner-portrait-jupiter", 2007, 2853, "inner", "portrait"),
    ("07-inner-landscape-jupiter", 2853, 2007, "inner", "landscape"),
    ("08-inner-landscape-crew13", 2853, 2007, "inner", "landscape"),
]


def png_info(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    offset = 8
    chunks = {}
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunks[kind] = data[offset + 8:offset + 8 + size]
        offset += size + 12
    width, height, depth, color = struct.unpack(">IIBB", chunks[b"IHDR"][:10])
    return width, height, depth, color, chunks


def record(path, width=None, height=None, upload=False):
    assert path.is_file(), f"Missing {path.relative_to(ROOT)}"
    result = {"path": path.relative_to(ROOT).as_posix(),
              "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.suffix == ".png":
        actual_width, actual_height, depth, color, chunks = png_info(path)
        assert (actual_width, actual_height) == (width, height), result["path"]
        result.update(width=width, height=height, format="PNG")
        if upload:
            assert depth == 8 and color == 2 and b"tRNS" not in chunks, result["path"]
            assert b"sRGB" in chunks or (b"iCCP" in chunks and b"sRGB" in chunks[b"iCCP"]), result["path"]
            result.update(color_space="sRGB", alpha=False)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-manifest", action="store_true")
    args = parser.parse_args()
    metadata = []
    for path in sorted((ROOT / "metadata").glob("*.txt")):
        content = path.read_text()
        assert content.isascii(), path.name
        assert content.endswith("\n"), path.name
        assert path.read_bytes() == (REPO / "fastlane/metadata/en-US" / path.name).read_bytes(), path.name
        item = record(path)
        if path.name in LIMITS:
            item.update(characters=len(content.rstrip("\n")), limit=LIMITS[path.name])
            assert item["characters"] <= item["limit"], path.name
        metadata.append(item)
    assert len(metadata) == 7
    exports, captures = [], []
    for width, height in [(1320, 2868), (1206, 2622)]:
        for scene in SCENES:
            exports.append(record(ROOT / f"screenshots/{width}x{height}/{scene}.png", width, height, True))
    for scene in SCENES:
        item = record(ROOT / f"sources/captures/iphone17/{scene}.png", 1206, 2622)
        item.update(device="iPhone 17", runtime="iOS 27.0", display="built-in", orientation="portrait")
        captures.append(item)
    for scene, width, height, display, orientation in DUO:
        exports.append(record(ROOT / f"screenshots/duo/{width}x{height}/{scene}.png", width, height, True))
        item = record(ROOT / f"sources/captures/duo/{scene}.png", width, height)
        item.update(device="iPhone Duo", runtime="iOS 27.1", display=display, orientation=orientation)
        captures.append(item)
    for name, width, height in [("header", 3840, 1646), ("search-results", 3840, 2560)]:
        exports.append(record(ROOT / f"creative/{name}-{width}x{height}.png", width, height, True))
    assert (ROOT / "creative/header-3840x1646.png").read_bytes() == (REPO / "AppStore/1.9/en-US/creative/header-3840x1646.png").read_bytes()
    overview = record(ROOT / "preview.png", 2200, 2200, True)
    target = ROOT / "manifest.json"
    existing = json.loads(target.read_text()) if target.exists() else {}
    capture_commit = existing.get("checkout_commit") or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    manifest = dict(app="OptiUniverse", version="1.10", build="28", locale="en-US",
                    prepared_date="2026-10-31",
                    checkout_commit=capture_commit,
                    capture_source=dict(new_app_build_performed=True, build_tool="Xcode 27.1 (27A9275)",
                                        sdk="iOS Simulator 27.1", status_bar_time="09:41",
                                        appearance="dark", launch_locale="en_US", app_version="1.10", app_build="28",
                                        app_code_file="OptiUniverse.debug.dylib",
                                        app_code_sha256="e899baee4c8e09bbc9848c643ab8ed2a7801efe168b32a80cb7848a68bc17a91",
                                        installed_app_code_matches_built_product=True),
                    exports=exports, metadata=metadata, captures=captures, overview=overview)
    if args.write_manifest:
        target.write_text(json.dumps(manifest, indent=2) + "\n")
    else:
        assert json.loads(target.read_text()) == manifest, "Manifest differs; regenerate after intentional changes."
    print(f"Validated {len(exports)} upload PNGs, {len(captures)} original captures, 7 metadata files, and preview.")
    print("Metadata counts:", {item["path"]: item.get("characters") for item in metadata if "characters" in item})


if __name__ == "__main__":
    main()
