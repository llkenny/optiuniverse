# OptiUniverse

OptiUniverse is an iOS 3D solar-system navigator built with SwiftUI and a technology-neutral `UniverseModule`. The universe scene is rendered with RealityKit through `RealityView`, with custom post-processing used for the final filmic look.

## Highlights

- Real-time 3D solar-system rendering with RealityKit and `RealityView`.
- SwiftUI interface with a featured-object carousel, destination cards, category filtering, and shared app state through Observation.
- Per-body USDZ model loading through RealityKit.
- JSON-driven object metadata for destination lists, featured objects, and planet simulation parameters.
- Orbital camera controls with pan, pinch, rotation, planet-follow transitions, and dynamic near-plane fitting.
- RealityKit materials, transparent atmosphere/ring layers, deterministic stars, Milky Way environment, transfer routes, and navigation markers.
- ACES-style tone mapping, bloom, vignette, and filmic color grading through RealityKit custom post-processing.
- Technology-neutral scene snapshots that feed camera, route, surface, and RealityKit entity updates.
- Supporting RFC/ADR documentation for rendering architecture decisions.

## Video and screenshots

<img width="200" alt="" src="https://github.com/user-attachments/assets/f9d963d4-5d6c-48dd-adef-a4ccb3a98a40" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/be1b065e-fcdf-462c-bd0c-6f9b1fc90fc5" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/34294a43-97aa-4f22-9d23-aef2f559b850" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/552a9dc7-fb6f-4420-b9d8-91d1e86845ff" />

[<video src="" style="width:100px"></video>](https://github.com/user-attachments/assets/fc05f8cc-b137-4dac-bda6-c2017a23e21f)

## Tech Stack

- Swift
- SwiftUI
- Observation
- RealityKit
- USDZ assets
- Metal Shading Language for the RealityKit post-processing effect only
- Swift Testing

## Current App Structure

```text
OptiUniverse/
  Features/
    HomeScreen/        SwiftUI discovery experience
    RootContainer/     Top-level app flow between home and 3D universe
  UIComponents/        Reusable SwiftUI components
  Resources/           JSON metadata, asset catalogs, colors, images
Modules/
  BaseModule/           Shared app models and services
  CommonTools/          Shared utilities
  UniverseModule/       Universe facade, simulation, camera, RealityKit scene, and PostFX
RFC/                   Rendering architecture notes and ADRs
vfx_scripts/           Experimental volume-noise export utilities
```

## Rendering Architecture

`UniverseModule` exposes a technology-neutral app boundary while RealityKit owns the final rendered frame:

1. `UniverseModuleFactory` creates the app-owned `UniverseModuleResources` facade.
2. `UniverseModuleResources` owns preparation, camera, navigation, transfer-orbit, snapshot, and scene-coordinator services.
3. `UniverseSceneSnapshotPipeline` builds immutable per-frame scene snapshots behind `SnapshotProvider`.
4. `UniverseSceneCoordinator` mutates one RealityKit entity hierarchy from complete camera, simulation, route, and presentation state.
5. `RealityView` owns the visible frame and installs the custom filmic PostFX effect.

## Content Model

The app currently includes solar-system destinations for the Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, and Neptune. Featured-object content is driven by JSON and backed by image assets for Saturn, Neptune, and Mars.

Planet simulation data lives in `Modules/UniverseModule/Sources/UniverseModule/Models/planets.json`, while UI destination content lives in `OptiUniverse/Resources/DestinationObjects.json` and `OptiUniverse/Resources/FeaturedObjects.json`.

## Why This Project Matters

OptiUniverse demonstrates work across the parts of iOS development that are often hard to show in small sample apps:

- 3D scene rendering and custom post-processing, not just UIKit or SwiftUI screens.
- Swift concurrency tradeoffs in a real-time scene pipeline.
- Modular UI composition with reusable SwiftUI components.
- Asset-heavy app organization with JSON configuration and catalogs.
- Documentation of technical decisions through RFCs and ADRs.

## Requirements

- Xcode with iOS Simulator support
- iOS 26.0 or newer deployment target
- An iOS 26-capable simulator or device

## Release 1 URLs

- Marketing URL: https://llkenny.github.io/optiuniverse/
- Support URL: https://llkenny.github.io/optiuniverse/support/

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

- Expand object selection in the universe scene.
- Add richer orbital effects such as satellites, belts, asteroids, and flyby-style transitions.
- Continue improving planet animation, material detail, and post-processing presets.
- Continue expanding focused coverage for data loading, view models, scene snapshots, and RealityKit scene behavior.
