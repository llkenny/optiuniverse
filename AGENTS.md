# AGENTS

## Overview
This repository hosts **OptiUniverse**, an iOS 3D universe navigator focused on high-fidelity rendering of celestial objects with Swift, SwiftUI, and MetalKit.

## Development Guidelines
- Use Swift for app code and MetalKit/Metal Shading Language for rendering work.
- OptiUniverse supports iPhone, both displays of iPhone Duo, and iPad. Account for all of them in new UI work. Check portrait, landscape, and window resizing where supported.
- Prioritise visual fidelity and performance when rendering 3D objects.
- Keep code modular, readable, and documented where the rendering logic is not obvious.
- Preserve the existing project structure unless there is a strong reason to reorganise it.
- Avoid committing user-specific files, generated build output, secrets, or local machine metadata.

## Testing
- After final edits and before completing every task, run `swiftlint lint --strict` from the repository root. Resolve all reported violations before completion. If the check cannot run, explicitly report the blocker and do not claim lint validation passed.
- Ensure the project builds before committing:
  `xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' build CODE_SIGNING_ALLOWED=NO`
- Run unit tests when available:
  `xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO`
  
## Package Test Notes
- `BaseModule` and `UniverseModule` schemes in `OptiUniverse.xcodeproj` may not be configured for the `test` action. To run module tests, invoke Xcode from the package directory:
  `xcodebuild -scheme BaseModule -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation`
  `xcodebuild -scheme UniverseModule -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation`
- Package-directory test runs may generate `Modules/*/Package.resolved`; remove it unless it is intentionally part of the change.

## Release Hygiene
- When asked to prepare a new release, create its manual QA issue using the `Create release QA issue` workflow in `.github/workflows/release-qa.yml`. Determine the candidate marketing version, build number and full published commit SHA, select the applicable diagnostic IDs from `AppStore/QA/Scenarios.md`, and dispatch the workflow from `main` with those inputs. Wait for completion and include the resulting issue URL in the release PR and the final response.
- Reuse the existing QA issue when the version, build, commit and diagnostic selection match. A new build gets a new issue. Record manual QA results in the issue, using the Markdown report only as a fallback. See the Release QA section in `README.md` for dispatch and local generation commands.
- Check the repository for credentials or private material before publishing.
- Keep `README.md` accurate when app capabilities or setup steps change.
- Treat rendering assets as part of the product surface: keep filenames, formats, and references consistent.
