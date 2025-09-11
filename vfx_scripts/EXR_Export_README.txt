EXR Export — OptiUniverse VFX-02

This script converts 3D noise volumes saved as .npy (float32, D×H×W)
into an EXR atlas (single-channel float), plus a JSON with atlas layout.

Usage:
  # Create a venv and install deps (one of the two is enough)
  python3 -m venv .venv && source .venv/bin/activate
  pip install openexr Imath  # Preferred (OpenEXR bindings)
  # or
  pip install imageio[pyav] imageio-ffmpeg  # imageio fallback for EXR

  # Export low and high volumes
  python export_volume_exr.py       --input Assets/Noise/noise_low_3d.npy       --output Assets/Noise/noise_low_3d.exr       --meta Assets/Noise/noise_low_3d.json       --normalize

  python export_volume_exr.py       --input Assets/Noise/noise_high_3d.npy       --output Assets/Noise/noise_high_3d.exr       --meta Assets/Noise/noise_high_3d.json       --normalize

Notes:
- The EXR stores an atlas of Z-slices laid out in a square tile grid.
- Metadata JSON includes depth, tile grid size, slice size, and atlas size.
- In shader, reconstruct (u,v,w) -> find z slice, map to tile; for smoother results,
  trilinearly blend between adjacent z-slices.
