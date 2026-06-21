# Complete Metal-to-RealityKit Migration
Status: Draft [Draft, In Review, Accepted, Rejected, Superseded]
Date Created: 18/06/26

## Overview
OptiUniverse currently renders its universe with a custom `MTKView` pipeline owned by
`MetalModule`. The implementation provides the required camera modes, celestial simulation,
navigation routes, transfer-orbit previews, surface positioning, high-dynamic-range rendering, and
filmic post-processing, but the renderer also owns substantial low-level resource, synchronization,
and draw-pass code.

The target architecture moves scene presentation and rendering to RealityKit while retaining the
existing product behavior and high-fidelity visual direction. The final scene surface is SwiftUI's
`RealityView`, and the rendering package is renamed to the technology-neutral `UniverseModule`.

Complete migration means that application-owned Metal rendering is removed. The only handwritten
Metal permitted in the final architecture is the implementation of
`RealityFoundation.PostProcessEffect` used by RealityView's custom post-processing hook. Reality
Composer Pro Shader Graph assets, RealityKit materials, and geometry built with `MeshResource` or
`LowLevelMesh` are allowed because RealityKit remains responsible for their rendering.

## Goals
- Make `RealityView` the single owner of the final rendered frame.
- Rename the public rendering package and API from `MetalModule` to `UniverseModule`.
- Preserve all current camera, navigation, transfer-orbit, surface-coordinate, and overlay behavior.
- Preserve or improve the visual fidelity of every celestial object and scene effect.
- Package celestial assets as independently loadable, editable per-body resources.
- Remove direct Metal and MetalKit rendering code except for RealityKit post-processing.
- Sustain 60 frames per second on the blocking physical-device performance target.

## Non-Goals
- Replacing the existing celestial simulation, navigation path math, or camera ownership rules.
- Introducing AR world tracking or making the universe scene depend on a device camera feed.
- Adding mesh-accurate terrain, new celestial content, or new navigation features during migration.
- Maintaining source compatibility for the old `MetalModule` package or public type names.
- Requiring pixel-identical output between different rendering engines.

## Platform And Public Interface
`UniverseModule` requires iOS 26. RealityView itself is available earlier, but
`RealityViewRenderingEffects.customPostProcessing` and `PostProcessEffect` require iOS 26. The app
already targets iOS 26, so the package should expose one supported path instead of availability-gated
rendering behavior.

Rename the local package directory, Swift package, library product, target, test target, Xcode package
reference, imports, and public integration types:

| Current | Target |
| --- | --- |
| `MetalModule` | `UniverseModule` |
| `MetalModuleFactory` | `UniverseModuleFactory` |
| `MetalModuleResources` | `UniverseModuleResources` |
| `MetalModuleNavigationControlling` | `UniverseNavigationControlling` |
| `MetalModuleTransferOrbitControlling` | `UniverseTransferOrbitControlling` |

`UniverseView` keeps its existing name and becomes a native SwiftUI view backed by `RealityView`.
The app continues to own one resources facade, await `prepare()`, pass the facade to `UniverseView`,
observe navigation state, invoke navigation and transfer-orbit controls, and report object-info
overlay framing. The method behavior and observable state remain stable even though the owning types
are renamed. No deprecated aliases or compatibility products are retained.

The app target must not import RealityKit implementation types or construct entities, asset loaders,
camera components, or post-processing pipelines. Those remain internal to `UniverseModule`.

## Target Architecture

### Scene Ownership
The final `RealityView` owns one entity hierarchy:

```text
UniverseRoot
|-- Environment
|-- StarField
|-- CelestialSystemRoot
|   |-- Sun
|   `-- BodyOrbitTransform
|       `-- BodyRotationTransform
|           `-- BodyVisualRoot
|-- TransferOrbit
|-- NavigationRoute
|   `-- NavigationMarker
`-- VirtualCamera
```

An internal `UniverseSceneCoordinator` owns the entity references and applies immutable simulation,
camera, route, and presentation state on `MainActor`. RealityView's scene-update subscription
advances the existing controllers and simulation, requests the current snapshots, and then applies a
complete update to the entity hierarchy. Entity mutation must not be distributed through SwiftUI
views or app-level feature code.

The existing camera arbitration, camera modes, `CameraState`, transitions, route playback,
transfer-orbit controller, surface-coordinate math, and navigation controller remain behavioral
owners. Metal-specific mesh packets and draw configurations are replaced by technology-neutral body
and scene snapshots containing transforms, radii, simulation time, route state, and camera inputs.

### Camera And Precision
RealityView uses a virtual camera entity driven by the existing immutable camera snapshot. The scene
coordinator applies the snapshot's world pose and projection each frame. Use
`ProjectiveTransformCameraComponent` for the existing custom projection matrix so dynamic near/far
planes and the object-info overlay's vertical center offset remain exact. A simpler
`PerspectiveCameraComponent` may be used only when it produces equivalent behavior.

Solar System distances cannot be applied directly as large single-precision RealityKit transforms.
Preserve the current floating-origin rule: simulation and navigation retain stable world-space
values, while the rendered root is rebased around the camera target before transforms are assigned
to entities. Bodies, routes, markers, surface anchors, and camera snapshots must use the same origin
for an update so they cannot drift relative to each other.

### Assets
Commit both editable Reality Composer Pro source and runtime USDZ exports inside `UniverseModule`.
Runtime assets use one USDZ per body: Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus,
Neptune, and Pluto. Checked-in exports are the runtime inputs; the RCP source is the editable source
of truth. Document fixed export settings and validate exports in tests so re-exporting does not
silently change scale, axes, pivots, names, or material bindings.

Replace the monolithic `high_resolution_solar_system.usdz` lookup with an internal manifest. Each
entry contains:

- stable body identity and display name
- USDZ filename and canonical root entity name
- optional parent body identity
- model-to-universe scale and reference radius
- pivot and orientation correction
- render/framing and surface radii when they differ

Orbital distance, orbital speed, axial rotation, and other simulation metadata remain structured
data rather than being inferred from asset transforms. The manifest loader must reject duplicate
identities, missing files, missing canonical roots, invalid bounds, and non-finite transform values.

Each export must preserve the current product surface for that body, including rings, cloud and
atmosphere shells, emissive surfaces, transparent geometry, normal maps, and roughness data. Rebuild
materials with RealityKit physically based or unlit materials and RCP Shader Graphs. Do not use
`CustomMaterial`, `MaterialFunction`, or handwritten Metal surface or geometry shaders.

### Procedural Scene Content
Generate transfer paths, navigation routes, and markers as RealityKit entities. Static or infrequently
changing paths should use generated `MeshResource` geometry. Dynamic route progress may update a
`LowLevelMesh` or entity transforms without allocating a new hierarchy every frame. Use unlit or
emissive RealityKit materials for the current neon appearance.

Implement the star field with RealityKit-owned VFX/particle assets or batched generated geometry.
The selected implementation must preserve deterministic placement, depth, brightness variation,
subtle twinkle, and camera-relative stability while satisfying the performance gate. The Milky Way
environment becomes `RealityViewEnvironment.skybox` or an equivalent RealityKit-owned environment.

### Post-Processing Boundary
Port the filmic preset to an internal type conforming to `PostProcessEffect`, installed through
`RealityViewRenderingEffects.customPostProcessing`. Keep all handwritten Metal and its Swift pipeline
setup in a dedicated `PostProcessing` directory. The effect may read RealityKit's source color and
depth textures and encode into the provided target texture on the provided command buffer; it must
not create a parallel scene renderer.

The final source tree may import `Metal` only from the post-processing implementation. Bloom, tone
mapping, saturation, contrast, tint, and vignette should match the approved filmic reference.

## Sequential Migration
The migration is sequential rather than a second complete renderer selected by a user-facing feature
flag. Every stage must build, test, and leave one clear owner for each subsystem.

### Stage 0: Baseline And Controls
- Capture Metal reference images for the visual matrix in this RFC.
- Record loading time, peak memory, frame-time distribution, dropped frames, and thermal state for
  each performance scenario.
- Add internal scene-ownership switches that can suppress individual Metal subsystems while their
  RealityKit equivalents are developed. These switches are migration scaffolding, not public API.

### Stage 1: Technology-Neutral Module
- Rename the package and public API to `UniverseModule` without changing renderer behavior.
- Rename test targets, schemes, imports, Xcode package references, log subsystems, and app-owned
  resource variables.
- Preserve the facade boundary and all existing controller behavior.

### Stage 2: RealityView Foundation
- Place a transparent RealityView layer above the legacy Metal view.
- Add the asset repository, entity hierarchy, scene coordinator, virtual camera, shared origin, and
  scene-update subscription.
- Feed both renderers from the same simulation and camera snapshots; do not allow each layer to
  advance time independently.

### Stage 3: Celestial Bodies
- Convert and approve bodies individually, including body-specific transparent and emissive layers.
- After a body passes asset, behavior, visual, and performance checks, enable its RealityKit entity
  and disable its Metal draw.
- Keep camera framing and surface-radius values sourced from technology-neutral body state.

The current Stage 3 rollout is intentionally limited to Sun and Neptune. Their checked-in USDZ
assets are required scene content, are loaded before presentation, and become the exclusive
RealityKit-owned celestial bodies after preparation succeeds. All other bodies remain Metal-owned
until their individual assets and visual reviews are complete.

Stage 3 implementation evidence recorded on 19 June 2026:

- the app build and app test action passed on the documented iPhone 17 Pro, iOS 26.4 simulator
- all 124 UniverseModule tests passed, including asset, ownership, transform, reverse-depth camera,
  cancellation, retry, and presentation-radius coverage
- BaseModule and CommonTools package tests passed
- simulator reviews passed for Sun and Neptune close follow, Sun emission and corona, Neptune
  material fidelity, single-renderer ownership, and object-info overlay framing

Simulator review is diagnostic only. The RFC's physical-device visual and performance gates remain
required before the final RealityKit-only release candidate.

### Stage 4: Routes And Effects
- Migrate the transfer orbit, navigation route, navigation marker, environment, and stars.
- Validate route progress, pause/resume, camera-follow toggling, arrival, cancellation, and transfer
  preview behavior after each owner changes.
- Keep the legacy Metal layer only for subsystems that have not yet moved.

The Stage 4 implementation also completes RealityKit ownership for the remaining celestial bodies so
the opaque RealityKit environment cannot cover Metal-owned planets in the temporary layered renderer.
Sun and Neptune continue to use their standalone USDZ assets. The other nine bodies are loaded by
name from one cached `high_resolution_solar_system.usdz`; its obsolete skin bindings are removed so
RealityKit imports the unchanged static meshes and materials. This shared runtime source is migration
scaffolding: editable per-body Reality Composer Pro projects and standalone USDZ exports are still
required before Stage 6 removes the monolithic asset.

Stage 4 keeps the legacy view solely as Stage 5 scaffolding. Once scene preparation commits, Metal
suppresses every visible subsystem while RealityKit owns all eleven bodies, the Milky Way environment,
the deterministic star field, both route presentations, and the navigation marker. Whole-frame filmic
post-processing remains disabled until Stage 5 because the two layers do not share a final color target.

### Stage 5: Single RealityKit Frame
- Make RealityView own every visible scene subsystem.
- Remove the legacy layer and enable the RealityView custom post-process effect for the whole frame.
- Run the complete parity, visual, asset, performance, build, and test gates.

Stage 5 implementation evidence recorded on 21 June 2026:

- `UniverseView` presents one RealityView and an input-only transparent gesture host; it no longer
  constructs the legacy `MTKView`, and production sources contain one scene-update subscription
- the filmic effect is installed through `RealityViewRenderingEffects.customPostProcessing`, with
  target-format pipeline caching and an unmodified-color fallback covered by GPU tests
- all 138 UniverseModule tests passed, including PostFX layout, library, pipeline-cache, encoding,
  fallback-copy, gesture configuration, and trajectory-gating coverage
- BaseModule and CommonTools package tests passed, as did the documented app build and app test action
- an iPhone 17 Pro, iOS 26.4 simulator launch completed required asset loading without a PostFX failure
  or blank application frame

The interactive simulator visual matrix and the RFC's physical iPhone 16 performance gates remain
pending. This evidence does not approve Stage 6 removal or a RealityKit-only release candidate.

### Stage 6: Removal
- Delete `MTKView`, Metal renderers, Metal model-loader wrappers, Metal prepared-mesh packets,
  renderer-specific ownership switches, the monolithic USDZ, and non-PostFX Metal shaders.
- Remove temporary layer synchronization and cross-renderer diagnostics.
- Update repository documentation and accepted architecture diagrams to the final names and flow.

During Stages 2 through 4, the RealityKit foreground and Metal background do not share a depth
buffer. Incorrect cross-layer occlusion and incomplete full-frame post-processing are accepted only
as documented development limitations. They must not be present in the release candidate, and the
final Metal removal is blocked until one RealityView owns the entire frame.

## Failure Handling
- `prepare()` reports asset preparation failure without exposing RealityKit types to the app. The
  loading screen must not transition to a partially constructed required scene.
- Optional visual layers may fall back to an approved simpler RealityKit material; missing required
  body assets, roots, or transforms are fatal preparation errors in debug and surfaced errors in
  production.
- A failed per-frame procedural update keeps the last complete route or scene state rather than
  publishing a partially updated hierarchy.
- Scene-update subscriptions, asynchronous asset tasks, and entity references are cancelled or
  released when `UniverseView` leaves the hierarchy.
- Post-processing preparation failure falls back to RealityKit's unmodified rendered color and is
  recorded; it must not crash the scene or create a blank frame.

## Acceptance Gates

### Feature Parity
Final Metal removal requires all of the following to work through RealityKit:

- orbital and axial body motion
- body selection, follow, repeat selection, and manual camera gestures
- surface-coordinate positioning and steady follow
- object-info overlay framing and projection offset
- transfer-orbit preview and trajectory camera interaction
- navigation creation, playback, pause, resume, cancellation, completion, marker, and camera-follow
  toggle
- route and transfer path rendering
- rings, atmospheres, clouds, transparency, emissive bodies, stars, environment, and filmic PostFX
- initial loading, cancellation, teardown, and error behavior

### Automated Tests
- Preserve the existing camera, transition, navigation, route, transfer-orbit, surface-coordinate,
  snapshot, star-field, and PostFX parameter tests under the renamed test target.
- Add manifest tests for uniqueness, finite metadata, expected body coverage, and valid parent links.
- Load every USDZ in a test, resolve its canonical root, verify non-empty finite bounds, and detect
  missing referenced textures or materials.
- Add scene-coordinator tests for body hierarchy, floating-origin rebasing, simulation-time updates,
  camera pose/projection application, route ownership, teardown, and last-complete-state behavior.
- Add regression tests proving that navigation and transfer controllers advance exactly once per
  scene update while both layers exist.

### Visual Review
Capture fixed Metal references before Stage 2 and compare them with RealityKit captures using the
same viewport, camera pose, simulation time, exposure, and content state. The review matrix covers:

- overview and close framing for all eleven bodies
- Earth clouds/atmosphere, Jupiter atmosphere, Saturn rings, and Sun emission/corona
- near/far clipping and object-info overlay framing
- Moon and Mars surface targets
- transfer path, navigation route, marker, and arrival state
- star field, Milky Way environment, transparency ordering, and filmic PostFX

Pixel identity is not required because the engines use different lighting and rasterization paths.
Every matrix entry requires explicit visual approval. Missing geometry, material regressions,
unreadable routes, unstable transparency, clipping, visible origin jumps, or a material loss of
fidelity blocks final removal. Approved RealityKit captures become the new regression references.

### Performance
The blocking reference is a physical iPhone 16 running an optimized Release build. Begin each run at
nominal thermal state, allow the scene to warm up, measure for at least 60 seconds, run every scenario
three times, and use the median result. Measure overview orbit, close body follow, surface focus,
transfer preview, navigation playback, and the visually densest body/environment combination.

RealityKit must meet all of these gates:

- p95 application frame time at or below 16.67 ms
- sustained 60 frames per second without recurring hitch clusters
- peak resident memory no more than 10 percent above the recorded Metal baseline
- initial required-scene load time no more than 10 percent above the recorded Metal baseline
- no unbounded entity, mesh, texture, subscription, or task growth across repeated presentations

Record CPU, GPU, memory, loading, dropped-frame, and thermal results with the RFC implementation
evidence. Simulator measurements are diagnostic only and cannot satisfy this gate.

### Build And Source Audit
The app build and all available app/package tests must pass using the repository's documented iPhone
17 Pro, iOS 26.4 simulator commands.

Before final removal, audit production sources. No `MetalModule`, `MetalRenderer`, `MTKView`,
`MetalKit`, `MTLRenderCommandEncoder`, handwritten Metal surface shader, or compatibility alias may
remain. `import Metal`, Metal resource types, command encoding, and `.metal` source are confined to
the RealityKit post-processing implementation.

## Documentation And ADR Impact
- This RFC supersedes ADR 0001's Metal command-encoding isolation decision at final cutover. Its
  broader rule of publishing complete state before rendering remains applicable.
- This RFC supersedes ADR 0002's technology-specific names while preserving its factory/resource
  facade and encapsulation decision.
- ADR 0003 remains accepted. Its camera ownership and immutable snapshot decisions are retained with
  technology-neutral consumer names.
- The accepted render-system pipeline continues to govern the legacy Metal layer during the staged
  migration. It becomes historical once Stage 6 deletes that layer.
- Surface-coordinate and surface-anchor RFCs retain their behavior but use `UniverseModule` and
  technology-neutral scene/body snapshot terminology.
- Update `README.md` when Stage 1 changes the package name and again if the final asset workflow or
  setup instructions require user-visible documentation.

## Risks And Mitigations
- **RealityKit material mismatch:** approve bodies individually and retain RCP source plus runtime
  exports so material work remains editable and reviewable.
- **Large-coordinate precision:** enforce one floating-origin conversion path and test bodies,
  routes, anchors, and camera state together.
- **Layered migration artifacts:** restrict layering to development stages and forbid it in release
  candidates.
- **Procedural geometry cost:** reuse entity hierarchies and mesh buffers; profile representative
  paths before replacing their Metal owners.
- **Asset size or load regression:** split assets per body, load required content deliberately, and
  enforce the load-time and memory gates.
- **PostFX API coupling:** isolate all Metal in one RealityKit effect and provide an unmodified-color
  fallback if effect preparation fails.
- **Behavior drift during renderer work:** keep controllers and camera modes intact and require their
  existing tests to pass at every stage.
