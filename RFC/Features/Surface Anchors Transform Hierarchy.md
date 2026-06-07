# Surface Anchors Transform Hierarchy
Status: Draft [Draft, In Review, Accepted, Rejected, Superseded]
Date Created: 07/06/26

## Overview
Surface-bound destinations such as Moon Base should eventually be represented as scene anchors in a
transform hierarchy, not only as latitude/longitude values interpreted by camera code.

The intended hierarchy is:

```text
SolarSystem
└── MoonTransform
    └── LunarBaseAnchor
        └── Optional visual marker / model
```

Each object owns a local coordinate space. The Moon has a world transform produced by simulation and
render preparation. Moon Base has a local body-relative position or transform. The engine resolves
the final Moon Base world pose by composing parent and child transforms.

The current implementation already computes a surface point from Moon-local coordinates and the
prepared Moon transform. This RFC proposes turning that implicit calculation into an explicit anchor
model that camera, rendering, and future interaction systems can share.

## Goals
- Model surface objects as body-relative anchors with stable local coordinates.
- Keep destination content data independent from renderer internals.
- Let camera follow an anchor world pose instead of owning surface-coordinate interpretation.
- Allow optional marker/model rendering to attach to the same anchor later.
- Preserve the existing body-follow pipeline and manual gesture cancellation behavior.

## Proposed Model
Content can continue to describe surface destinations with the existing shape:

```json
{
  "surfaceLocation": {
    "bodyName": "Moon",
    "latitudeDegrees": -90,
    "longitudeDegrees": 0
  }
}
```

MetalModule should convert that content DTO into an internal anchor description:

```swift
struct SurfaceAnchorDescriptor {
    let id: String
    let parentBodyName: String
    let coordinate: SurfaceCoordinate
}
```

Render preparation resolves the descriptor against the latest prepared parent body packet:

```swift
struct ResolvedSurfaceAnchor {
    let id: String
    let parentBodyName: String
    let localTransform: float4x4
    let worldTransform: float4x4
    let surfaceNormalWorld: SIMD3<Float>
}
```

Exact type names can change. The important boundary is that `BaseModule` owns decodable content,
while `MetalModule` owns internal coordinate math, transform composition, and render-ready anchor
resolution.

## Camera Integration
The follow pipeline should accept a follow target that can resolve to either:

- a body center, such as `Moon`
- a body-relative surface anchor, such as `MoonBaseAnchor`

For surface anchors:

- phase 1 follows the parent body using existing body fit behavior
- phase 2 rotates the camera around the parent body center until the anchor is front-facing
- optional zoom or framing policy applies after anchor alignment
- steady follow recomputes the anchor world pose from the latest prepared snapshot so it follows the
  rotating parent body

Camera code should ask an anchor resolver for the current world pose and surface normal. It should
not directly convert latitude/longitude to world coordinates once the anchor system exists.

## Render Integration
Surface anchors do not require visible rendering in the first implementation stage.

Later, renderers can attach optional visuals to anchors:

- a debug marker
- a destination pin
- a small model
- an interaction hit target

The renderer should consume resolved anchor packets from prepared snapshots, just like it consumes
prepared planet packets. It should not query content providers or perform coordinate conversion
during command encoding.

## Implementation Plan
1. Add internal anchor descriptors and resolved-anchor packets in `MetalModule`.
2. Extend render preparation to resolve surface anchors from destination content and prepared parent
   body transforms.
3. Move surface-coordinate world-point calculation out of `SurfaceCameraMode` into an anchor
   resolver.
4. Update follow/surface camera code to consume resolved anchor pose and normal.
5. Keep existing `surfaceLocation` content data as the source of truth for Moon Base.
6. Add optional debug rendering only after camera behavior is stable.

## Verification
- Build the app after each stage:

```sh
xcodebuild -project OptiUniverse.xcodeproj -scheme OptiUniverse -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' build CODE_SIGNING_ALLOWED=NO
```

- Verify Moon Base still selects the rendered Moon as parent body.
- Verify Moon Base alignment follows Moon rotation over time.
- Verify repeated Moon Base selection can re-align the camera without an unnecessary Moon-to-Moon
  transition.
- Future tests should cover local-to-world anchor transform composition and camera collinearity with
  the resolved anchor normal.

## Assumptions And Risks
- V1 anchors can remain spherical-reference anchors; mesh-accurate terrain height is out of scope.
- Anchor local coordinates are model-frame coordinates, not IAU-accurate body-fixed coordinates.
- Destination content should keep using simple decodable data; no public Metal transform type should
  leak into `BaseModule`.
- The main risk is overbuilding a scene graph too early. The recommended first step is a narrow
  anchor resolver that can later grow into a fuller transform hierarchy.
