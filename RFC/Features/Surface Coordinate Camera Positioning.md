# Surface Coordinate Camera Positioning
Status: Draft [Draft, In Review, Accepted, Rejected, Superseded]
Date Created: 06/06/26

## Overview
OptiUniverse needs a camera-positioning path for future surface-bound objects such as lunar rovers,
Mars rovers, and bases on Solar System bodies.

V1 introduces an internal planetocentric surface-coordinate system. It does not render a visible
coordinate grid. The grid is a mathematical reference layer used for coordinate binding, debug
logging, and animated camera positioning.

The camera should move to a surface coordinate in two visible steps:

1. Show the selected Solar System body.
2. Rotate and position the camera so the view ray passes through the target surface point and the
   center of the selected body.

## Public Interfaces
Extend content models with optional surface-location data. This type belongs to `BaseModule` content
models and must not depend on `MetalModule`:

```json
{
  "surfaceLocation": {
    "bodyName": "Moon",
    "latitudeDegrees": -90,
    "longitudeDegrees": 0
  }
}
```

Add a focused Metal module facade:

```swift
@MainActor
public protocol MetalModuleSurfacePositioningControlling: AnyObject {
    func focusSurfaceCoordinates(
        on bodyName: String,
        latitudeDegrees: Float,
        longitudeDegrees: Float,
        animated: Bool
    )
}
```

Future content-facing helpers can wrap this API without exposing renderer internals to the app
target.

Do not add a public `SurfaceCoordinate` value in v1. The coordinate value used by math helpers should
stay internal to `MetalModule` unless a future public API needs to pass it across the module boundary.
The public facade can accept primitive latitude/longitude values, while `BaseModule` owns its own
decodable content DTO.

## ADR Compatibility
This RFC must preserve the architecture accepted in ADR 0002 and ADR 0003.

- ADR 0002: Public rendering integration continues to flow through `MetalModuleResources` and focused
  protocols. The app target should not depend on renderer internals, `MeshProvider`, `ModelLoader`,
  `CameraState`, or prepared snapshot types.
- ADR 0003: Surface positioning is a camera mode, not renderer behavior. UI and content commands enter
  through the facade, route through `CameraCoordinator`, and are executed by `SurfaceCameraOwner` /
  `SurfaceCameraMode`.
- `SurfaceCameraOwner` commits only `CameraState.Transaction` values. It must not mutate matrices,
  bypass `CameraState`, or write camera fields directly.
- `MetalRenderer` remains a consumer of immutable camera snapshots. It may call surface-coordinate
  debug helpers with the current snapshot, but it must not own surface camera priority or perform
  camera arbitration.
- `FeaturedObject.surfaceLocation` is a `BaseModule` content DTO. It should be converted at the app
  integration boundary into a `MetalModuleSurfacePositioningControlling` call by passing primitive
  body/latitude/longitude values.

## Coordinate Model
V1 uses model-frame planetocentric coordinates on a spherical reference surface.

- Latitude and longitude are expressed in degrees.
- `+Z` is north.
- The equator is the local `XY` plane.
- Longitude `0` is local `+X`.
- Positive longitude rotates toward local `+Y`.
- The reference surface is spherical. Terrain height and mesh-accurate picking are out of scope.
- Coordinates are stable in the body's local model frame, not IAU-accurate body-fixed coordinates.

Use the current prepared body transform from `PreparedPlanetRenderPacket` so coordinates follow the
rotating rendered body. Add prepared `surfaceRadius`, initially equal to the render/framing sphere
radius unless implementation shows a better existing radius.

## Stage 1: Coordinate Engine And Debug Logging
Implement the internal coordinate reference layer without changing user-facing UI or content
behavior.

Key changes:

- Add pure coordinate math helpers:
  - internal `SurfaceCoordinate` value in `MetalModule`
  - planetocentric lat/lon degrees to local unit vector
  - local unit vector to planetocentric lat/lon
  - world surface point from `PreparedPlanetRenderPacket`
  - camera ray to selected-body reference-sphere intersection
- Use `PreparedPlanetRenderPacket.baseModelMatrix` or equivalent body transform so coordinates stay
  stable in the rotating body frame.
- Add prepared `surfaceRadius`.
- Add throttled private `OSLog` debug output for the currently selected or followed body:
  - body name
  - latitude
  - longitude
  - frame id or simulation time
- Keep logging debug-only and non-observable in v1.

Verification:

- Unit tests for lat/lon axis conventions and round trips.
- Unit tests for ray-sphere hit, miss, and tangent cases.
- Manual verification by selecting Moon or Mars and confirming logs change predictably while orbiting
  the camera.
- Full app build:

```sh
xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' build CODE_SIGNING_ALLOWED=NO
```

## Stage 2: Surface Data And Animated Camera Focus
Add the first surface-bound content and the camera positioning mechanism.

Key changes:

- Extend `FeaturedObject` with optional `surfaceLocation`.
- Add Moon Base coordinates to `FeaturedObjects.json`:
  - `bodyName: "Moon"`
  - `latitudeDegrees: -90`
  - `longitudeDegrees: 0`
- Add `SurfaceCameraMode` and `SurfaceCameraOwner` behind `CameraCoordinator`.
- Add facade routing through `MetalModuleResources.surfacePositioning`.
- On `focusSurfaceCoordinates(...)`:
  - clear transfer preview
  - cancel route navigation without starting route completion behavior
  - phase 1: focus/show the host body using existing fit/follow behavior
  - phase 2: animate to the surface point
- Extend `CameraTransition.Frame` to optionally carry orientation:
  - existing target/distance transitions keep their behavior
  - surface transitions interpolate orientation with quaternion slerp
- Final surface-focus pose:
  - `cameraTarget = computed surface point`
  - camera view ray passes through surface point and body center
  - distance uses body-fit/current distance policy with minimum clearance above the body reference
    surface
- Wire the Moon Base content action to the surface-positioning facade.

Verification:

- Unit tests that existing featured-object JSON without `surfaceLocation` still decodes.
- Unit test fixture for Moon Base with `surfaceLocation`.
- Camera tests for final collinearity:
  `cameraWorldPosition -> surfacePoint -> bodyCenter`.
- Regression tests that existing follow, navigation, and transfer preview camera transitions still pass.
- Manual verification: selecting Moon Base animates to the Moon south pole and debug logs report
  approximately `lat = -90`.
- Full app build:

```sh
xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' build CODE_SIGNING_ALLOWED=NO
```

## Optional Later Stages
These are deliberately out of scope for the first two stages, but the design should not block them:

- Add a developer-facing SwiftUI debug overlay for current surface coordinates.
- Add visible coordinate-grid rendering for debugging or educational modes.
- Add body-specific coordinate metadata if the app needs IAU-like axes, prime meridians, or known
  landing-site coordinates.
- Add mesh-accurate ray picking and terrain height once the render assets expose suitable geometry.

## Assumptions And Risks
- V1 uses a spherical reference surface, not mesh terrain height.
- Coordinates are model-frame planetocentric coordinates, not IAU-accurate body-fixed coordinates.
- Longitude at the pole is accepted but visually degenerate; Moon Base south pole uses
  `longitudeDegrees: 0` as a stable placeholder.
- Debug coordinate display means private logs only, not a SwiftUI overlay.
- Existing camera ownership rules remain in force: route navigation and transfer preview can own the
  camera while active, and manual gestures cancel active surface positioning.
