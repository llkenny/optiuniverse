# Surface Coordinate Camera Positioning
Status: Accepted [Draft, In Review, Accepted, Rejected, Superseded]
Date Created: 06/06/26

## Overview
OptiUniverse needs a camera-positioning path for future surface-bound objects such as lunar rovers,
Mars rovers, and bases on Solar System bodies.

V1 introduces an internal planetocentric surface-coordinate system. It does not render a visible
coordinate grid. The grid is a mathematical reference layer used for coordinate binding, debug
logging, and animated camera positioning.

The camera should move to a surface coordinate in two visible steps:

1. Show the selected Solar System body.
2. Rotate the camera around the selected body center so the view ray passes through the target
   surface point and the center of the selected body.

After the surface rotation completes, the camera may apply a framing zoom that preserves the same
body-centered target and surface alignment.

## Public Interfaces
Extend destination content models with optional surface-location data. This type belongs to
`BaseModule` content models and must not depend on `MetalModule`:

```json
{
  "surfaceLocation": {
    "bodyName": "Moon",
    "latitudeDegrees": -90,
    "longitudeDegrees": 0
  }
}
```

Featured objects are lightweight proxies for destination objects. A featured card may resolve
surface-location data from the matching destination object, but the featured JSON does not own
surface coordinates.

App-level selection remains passive. Card models expose an `ObjectFollowTarget` containing the body
name and optional `SurfaceLocation`; views assign that model-provided target to app state and switch
to the objects screen.

Do not add a public `SurfaceCoordinate` value in v1. The coordinate value used by math helpers should
stay internal to `MetalModule` unless a future public API needs to pass it across the module boundary.
`BaseModule` owns its decodable content DTO, and `MetalModuleResources.followPlanet` converts that
DTO into the internal coordinate value.

## ADR Compatibility
This RFC must preserve the architecture accepted in ADR 0002 and ADR 0003.

- ADR 0002: Public rendering integration continues to flow through `MetalModuleResources` and focused
  protocols. The app target should not depend on renderer internals, `MeshProvider`, `ModelLoader`,
  `CameraState`, or prepared snapshot types.
- ADR 0003: Surface positioning is part of the follow camera path, not renderer behavior. UI and
  content commands enter through model-derived follow targets, route through `MetalModuleResources`
  and `CameraCoordinator.followPlanet`, and are executed by `FollowCameraOwner` with
  `SurfaceCameraOwner` / `SurfaceCameraMode` as follow-only implementation details.
- `SurfaceCameraOwner` commits only `CameraState.Transaction` values. It must not mutate matrices,
  bypass `CameraState`, or write camera fields directly.
- `MetalRenderer` remains a consumer of immutable camera snapshots. It may call surface-coordinate
  debug helpers with the current snapshot, but it must not own surface camera priority or perform
  camera arbitration.
- `DestinationObject.surfaceLocation` is a `BaseModule` content DTO. It is carried through
  destination and hero card models into an `ObjectFollowTarget`, then converted to Metal's internal
  `SurfaceCoordinate` at the resource boundary.

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

- Add `SurfaceLocation` to `BaseModule`.
- Extend `DestinationObject` with optional `surfaceLocation`.
- Add Moon Base coordinates to the `Moon Base` entry in `DestinationObjects.json`:
  - `bodyName: "Moon"`
  - `latitudeDegrees: -90`
  - `longitudeDegrees: 0`
- Keep `FeaturedObjects.json` as lightweight feature-card content. Its `Moon Base` item resolves
  surface coordinates from the matching destination object.
- Carry model-derived follow targets through `HeroCard` and `DestinationCardModel`.
- Keep view tap handling generic: assign the model-provided follow target, assign the selected body,
  and switch to `.objects`.
- Add `SurfaceCameraMode` and `SurfaceCameraOwner` inside the follow camera pipeline.
- On `MetalModuleResources.followPlanet(named:surfaceLocation:)`:
  - clear transfer preview
  - cancel route navigation without starting route completion behavior
  - phase 1: focus/show the host body using existing fit/follow behavior
  - phase 2: rotate around the host-body center until the surface coordinate is front-facing
  - phase 3: apply a distance-only 2x zoom while preserving the same body-centered surface alignment
- Keep `CameraTransition` target/distance behavior unchanged for non-surface transitions. Surface
  orientation interpolation is handled inside `SurfaceCameraOwner` with quaternion slerp.
- Final surface-focus pose:
  - `cameraTarget = host body center`
  - camera view ray passes through surface point and body center
  - body follow distance is preserved during surface rotation
  - the post-rotation zoom reduces distance by 2x without retargeting or changing alignment
  - steady surface follow recomputes orientation from the latest prepared snapshot so the coordinate
    follows the rotating body
- Repeatedly selecting the same surface object skips a redundant body-to-body transition and reruns
  only the surface alignment / zoom sequence.

Verification:

- Unit tests that existing destination JSON without `surfaceLocation` still decodes.
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
