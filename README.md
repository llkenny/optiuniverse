# OptiUniverse

OptiUniverse is an iOS app for exploring a stylized 3D solar system with SwiftUI, MetalKit, and custom Metal shaders. The current build focuses on high-fidelity rendering of the Sun, planets, corona effects, and post-processing.

## Features

- Real-time solar system view rendered with MetalKit
- Procedural Sun rendering with custom Metal shaders
- Orbiting planets with label overlays and camera follow controls
- Quality presets for performance and visual tuning
- Post-processing pipeline with HDR rendering and bloom-style effects
- QA hooks for profiling and export workflows during development

## Tech Stack

- Swift
- SwiftUI
- MetalKit
- Metal Shading Language
- Xcode project-based build

## Requirements

- macOS with Xcode 16.4 or newer
- iOS 18.0 deployment target

## Build

```bash
xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 16' build CODE_SIGNING_ALLOWED=NO
```

## Test

```bash
xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO
```

## Project Structure

- `OptiUniverse/Renderers`: Metal render orchestration and scene rendering
- `OptiUniverse/Shaders`: Metal shader sources for the Sun, corona, prominences, and post FX
- `OptiUniverse/Models`: Planet models and JSON-driven solar system data
- `OptiUniverse/Resources`: textures and quality preset data
- `OptiUniverseTests`: test target

## Notes For Public Distribution

- No API keys, private keys, or `.env` files were found during a repository scan.
- The repository contains development-only QA hooks and profiling utilities.
- Xcode user-specific files and Finder metadata should remain untracked.

## License

No license file is currently included. Add one before publishing publicly if you want to permit reuse.
