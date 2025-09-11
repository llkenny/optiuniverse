
import argparse
import math
import os
import sys
from pathlib import Path

import numpy as np

# Optional deps
try:
    import OpenEXR, Imath  # type: ignore
    HAS_OPENEXR = True
except Exception:
    HAS_OPENEXR = False

try:
    import imageio.v3 as iio  # type: ignore
    HAS_IMAGEIO = True
except Exception:
    HAS_IMAGEIO = False


def save_exr_gray(path: Path, img: np.ndarray) -> None:
    """
    Save a single-channel float32 image as EXR.
    Tries OpenEXR first (preferred), then imageio.
    """
    path = Path(path)
    h, w = img.shape[:2]
    if HAS_OPENEXR:
        # OpenEXR expects channels by name; store as "Y" (luminance) or "R"
        header = OpenEXR.Header(w, h)
        # 32-bit float pixel type
        pt = Imath.PixelType(Imath.PixelType.FLOAT)
        # OpenEXR wants row-major bytes per channel
        exr = OpenEXR.OutputFile(str(path), header)
        exr.writePixels({"R": img.astype(np.float32).tobytes()})
        exr.close()
        return
    if HAS_IMAGEIO:
        iio.imwrite(str(path), img.astype(np.float32))
        return
    raise RuntimeError("No EXR writer found. Install 'openexr' (OpenEXR) or 'imageio[pyexr]'.")


def make_atlas_from_volume(vol: np.ndarray, clamp01: bool = False):
    """
    vol: (D,H,W) or (H,W,D) float32
    Returns atlas (H*tiles, W*tiles) float32 and a dict with metadata.
    """
    vol = np.asarray(vol)
    if vol.ndim != 3:
        raise ValueError(f"Expected 3D volume, got shape {vol.shape}")
    # Ensure (D,H,W)
    if vol.shape[0] != vol.shape[1] or vol.shape[1] != vol.shape[2]:
        # Accept any D,H,W—just reorder if user passed (H,W,D)
        D, H, W = vol.shape
        if H*W == vol.shape[0]*vol.shape[1]:
            pass
    D, H, W = vol.shape
    tiles = int(math.ceil(math.sqrt(D)))
    atlas_h = tiles * H
    atlas_w = tiles * W
    atlas = np.zeros((atlas_h, atlas_w), dtype=np.float32)
    z = 0
    for ty in range(tiles):
        for tx in range(tiles):
            if z >= D:
                break
            y0 = ty * H
            x0 = tx * W
            atlas[y0:y0+H, x0:x0+W] = vol[z, :, :]
            z += 1
    if clamp01:
        atlas = np.clip(atlas, 0.0, 1.0)
    meta = {
        "depth": int(D),
        "tile_grid": int(tiles),
        "slice_size": [int(W), int(H)],
        "atlas_size": [int(atlas_w), int(atlas_h)],
        "layout": "row-major tiles (z increases along x first, then y)"
    }
    return atlas, meta


def main():
    p = argparse.ArgumentParser(description="Export 3D volume (.npy) as EXR atlas with metadata JSON.")
    p.add_argument("--input", required=True, help="Path to .npy volume (float32, shape D×H×W).")
    p.add_argument("--output", required=True, help="Path to output .exr")
    p.add_argument("--meta", help="Optional path to write metadata .json (atlas layout).")
    p.add_argument("--normalize", action="store_true", help="Normalize volume to [0,1] before export.")
    args = p.parse_args()

    vol = np.load(args.input)
    if vol.ndim != 3:
        raise SystemExit(f"ERROR: expected 3D volume, got shape {vol.shape}")

    vol = vol.astype(np.float32, copy=False)
    if args.normalize:
        vmin, vmax = float(vol.min()), float(vol.max())
        if vmax - vmin > 1e-9:
            vol = (vol - vmin) / (vmax - vmin)

    atlas, meta = make_atlas_from_volume(vol, clamp01=False)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    save_exr_gray(out_path, atlas)

    if args.meta:
        meta_path = Path(args.meta)
        meta_path.parent.mkdir(parents=True, exist_ok=True)
        import json
        json.dump(meta, open(meta_path, "w"), indent=2)

    print(f"Exported: {out_path}")
    if args.meta:
        print(f"Metadata: {args.meta}")
    print("Done.")

if __name__ == "__main__":
    main()
