# AGENTS

## Overview
This repository hosts **OptiUniverse**, an iOS 3D universe navigator focused on high-fidelity rendering of celestial objects with Swift, SwiftUI, and MetalKit.

## Development Guidelines
- Use Swift for app code and MetalKit/Metal Shading Language for rendering work.
- Prioritise visual fidelity and performance when rendering 3D objects.
- Keep code modular, readable, and documented where the rendering logic is not obvious.
- Preserve the existing project structure unless there is a strong reason to reorganise it.
- Avoid committing user-specific files, generated build output, secrets, or local machine metadata.

## Testing
- Ensure the project builds before committing:
  `xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 16' build CODE_SIGNING_ALLOWED=NO`
- Run unit tests when available:
  `xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO`

## Release Hygiene
- Check the repository for credentials or private material before publishing.
- Keep `README.md` accurate when app capabilities or setup steps change.
- Treat rendering assets as part of the product surface: keep filenames, formats, and references consistent.
