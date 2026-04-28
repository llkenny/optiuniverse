# OptiUniverse

OptiUniverse is an iOS 3D solar-system navigator built with SwiftUI, MetalKit, and custom Metal shaders. The app combines a polished SwiftUI discovery interface with a real-time Metal scene for exploring celestial objects, following planets, and rendering high-fidelity space visuals on device.

The project is an active personal iOS rendering portfolio piece. It focuses on practical graphics engineering, clean Swift architecture, and production-minded app structure rather than a static demo.

## Highlights

- Real-time 3D solar-system rendering with MetalKit and Metal Shading Language.
- SwiftUI interface with a featured-object carousel, destination cards, category filtering, and shared app state through Observation.
- USDZ-based model loading through Model I/O and MetalKit.
- JSON-driven object metadata for destination lists, featured objects, and planet simulation parameters.
- Orbital camera controls with pan, pinch, rotation, planet-follow transitions, and dynamic near-plane fitting.
- HDR render target, MSAA, ACES-style tone mapping, bloom, vignette, lens dirt support, and optional dreamy post-processing.
- Physically inspired material shading with texture, normal, roughness, metallic, ambient occlusion, emissive, opacity, and transparent-pass handling.
- Render preparation pipeline that keeps async model lookup outside Metal command encoding.
- Supporting RFC/ADR documentation for rendering architecture decisions.

## Video and screenshots

https://github.com/user-attachments/assets/3b1e8aba-406c-43b4-b3e6-0d8072ca9d54
<img width="400" alt="" src="https://github.com/user-attachments/assets/f9d963d4-5d6c-48dd-adef-a4ccb3a98a40" />
<img width="400" alt="" src="https://github.com/user-attachments/assets/be1b065e-fcdf-462c-bd0c-6f9b1fc90fc5" />
<img width="400" alt="" src="https://github.com/user-attachments/assets/34294a43-97aa-4f22-9d23-aef2f559b850" />
<img width="400" alt="" src="https://github.com/user-attachments/assets/552a9dc7-fb6f-4420-b9d8-91d1e86845ff" />



## Tech Stack

- Swift
- SwiftUI
- Observation
- MetalKit
- Metal Shading Language
- Model I/O
- USDZ assets
- Swift Testing

## Current App Structure

```text
OptiUniverse/
  Features/
    HomeScreen/        SwiftUI discovery experience
    Metal/             Metal view, renderer, shaders, camera, model loading
    RootContainer/     Top-level app flow between home and 3D universe
  Services/            Data providers and app-facing protocols
  UIComponents/        Reusable SwiftUI components
  Resources/           JSON metadata, asset catalogs, colors, images
RFC/                   Rendering architecture notes and ADRs
vfx_scripts/           Experimental volume-noise export utilities
```

## Rendering Architecture

The Metal path is organized around a clear split between preparation and command encoding:

1. `ModelLoader` loads USDZ meshes, Metal buffers, textures, and material data.
2. `RenderPreparationPipeline` resolves async mesh access and builds immutable per-frame render snapshots.
3. `MetalRenderer` owns the `MTKViewDelegate` loop, camera state, HDR/MSAA targets, and post-processing pass.
4. `PlanetsRenderer` consumes prepared snapshots synchronously while encoding draw commands.
5. Metal shaders handle material lighting, texture sampling, transparency, tone mapping, bloom, and final color grading.

This avoids crossing `await` boundaries while a `MTLRenderCommandEncoder` is active, which keeps the render loop predictable and compatible with Metal API validation.

## Content Model

The app currently includes solar-system destinations for the Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, and Neptune. Featured-object content is driven by JSON and backed by image assets for Saturn, Neptune, and Mars.

Planet simulation data lives in `OptiUniverse/Features/Metal/Models/planets.json`, while UI destination content lives in `OptiUniverse/Resources/DestinationObjects.json` and `OptiUniverse/Resources/FeaturedObjects.json`.

## Why This Project Matters

OptiUniverse demonstrates work across the parts of iOS development that are often hard to show in small sample apps:

- GPU rendering and shader authoring, not just UIKit or SwiftUI screens.
- Swift concurrency tradeoffs in a real render loop.
- Modular UI composition with reusable SwiftUI components.
- Asset-heavy app organization with JSON configuration and catalogs.
- Documentation of technical decisions through RFCs and ADRs.

## Requirements

- Xcode with iOS Simulator support
- iOS 18.0 or newer deployment target
- A Metal-capable simulator or device

## Build

Open the project in Xcode:

```bash
open OptiUniverse.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project OptiUniverse.xcodeproj \
  -scheme OptiUniverse \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  build CODE_SIGNING_ALLOWED=NO
```

## Tests

The repository includes a Swift Testing target. Run it with:

```bash
xcodebuild -project OptiUniverse.xcodeproj \
  -scheme OptiUniverse \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  test CODE_SIGNING_ALLOWED=NO
```

## Roadmap

- Expand object selection in the Metal scene.
- Add richer orbital effects such as satellites, belts, asteroids, and flyby-style transitions.
- Continue improving planet animation, material detail, and post-processing presets.
- Replace placeholder tests with focused coverage for data loading, view models, and render-preparation logic.
