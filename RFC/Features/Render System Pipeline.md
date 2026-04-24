# Render System Pipeline
Status: Accepted [Draft, In Review, Accepted, Rejected, Superseded]
Date Created: 19/04/26

## Overview
`PlanetsRenderer` currently needs mesh data from `ModelLoader`, which is an actor. With default actor isolation set to `MainActor`, the synchronous render path hits this warning:

```text
/Users/max/Work/iOS/My/OptiUniverse/OptiUniverse/Features/Metal/Renderers/PlanetsRenderer.swift:295:40
Call to actor-isolated instance method 'getMeshes(for:primaryMeshName:)' in a synchronous main actor-isolated context
```

The first attempted fix was to make mesh lookup async and call it from `Task` blocks inside the render path. That removes the direct actor-isolation warning, but it violates Metal command encoding lifetime rules. The render command encoder may already be ended by the time the task resumes, which produced this crash:

```text
-[MTLDebugRenderCommandEncoder setVertexBytes:length:attributeStride:atIndex:]:1764: failed assertion `Set Vertex Bytes Validation
invalid usage because encoding has ended.
'
```

The render system needs a hard split:

- An async preparation pipeline gathers actor-isolated data, resolves mesh lists, computes per-frame render inputs, and publishes a prepared snapshot.
- The renderer consumes the latest prepared snapshot every frame and only encodes draw commands synchronously.
- No render command encoder, command buffer encoding operation, or per-frame mutable renderer state should cross an `await` boundary.

Current staged changes show the direction, but should be treated as a failed experiment rather than the final design:

- `PlanetsRenderer.renderPlanets` now launches `Task` per planet while holding a `MTLRenderCommandEncoder`.
- `renderPlanet` and `loadedMeshes` are async.
- Camera fitting methods now await `framingRadius`, which introduced more ad-hoc tasks in `MetalRenderer`, `UniverseView`, and `CameraController`.
- `planetMeshes` remains a mutable dictionary on the renderer, with a FIXME about data races.

## Technical Design / Proposed Solution
Introduce a render preparation layer that owns asynchronous work and publishes immutable render snapshots.

### Pipeline Shape

```text
ModelLoader actor
    -> RenderPreparationPipeline async task
    -> PreparedRenderSnapshot
    -> PlanetsRenderer.renderPlanets(...) synchronous draw
```

### Responsibilities

`ModelLoader`

- Loads USDZ assets, Metal meshes, textures, and material metadata.
- Exposes async APIs used only by preparation code, never by command encoding code.
- Should not be queried from `PlanetsRenderer.renderPlanets`.

`RenderPreparationPipeline`

- Runs outside the active command encoder lifetime.
- Resolves each `Planet` to a stable list of `LoadedMesh` values.
- Computes render metadata that currently happens inside `renderPlanet` but does not require the encoder:
  - base model matrix
  - normalized scale
  - world model matrix
  - framing radius
  - world position
  - optional mesh/material packet references
- Publishes a complete `PreparedRenderSnapshot` for the renderer to read synchronously.
- Tracks in-flight work and cancellation so stale camera/selection updates do not race newer ones.

`PlanetsRenderer`

- Keeps the render loop synchronous.
- Reads the latest prepared snapshot at the start of `renderPlanets`.
- Computes only frame-local values that depend on the current view/projection/scene origin, such as MVP matrices and screen-space label positions.
- Encodes Metal commands immediately and never starts `Task` from inside command encoding.

`MetalRenderer`

- Advances time and camera state.
- Tells the preparation pipeline which frame inputs are needed.
- Draws using the latest available snapshot. If a newer snapshot is not ready, it reuses the previous complete snapshot rather than blocking the frame.

### Data Model

Possible types:

```swift
struct PreparedRenderSnapshot {
    let frameID: UInt64
    let simulationTime: Float
    let planets: [PreparedPlanetRenderPacket]
}

struct PreparedPlanetRenderPacket {
    let planetName: String
    let meshes: [LoadedMesh]
    let baseModelMatrix: float4x4
    let worldModelMatrix: float4x4
    let normalizedScale: Float
    let framingRadius: Float
    let worldPosition: SIMD3<Float>
}
```

The exact names can change, but the important property is that `PlanetsRenderer` receives everything it needs to draw without calling an actor.

### Frame Flow

1. App startup loads static planet definitions and starts mesh loading.
2. `ModelLoader` finishes loading Metal resources.
3. `RenderPreparationPipeline` builds an initial prepared snapshot.
4. Each display frame:
   - `MetalRenderer` advances simulation time.
   - `MetalRenderer` requests preparation for the next frame if no equivalent task is already in flight.
   - `PlanetsRenderer` draws the most recent completed snapshot synchronously.
   - Labels are updated from positions computed during synchronous drawing.
5. Camera fitting reads prepared `framingRadius` values from the latest snapshot or a dedicated prepared cache. It should not require actor lookup during gesture handling.

### Main Rule

After `makeRenderCommandEncoder`, command encoding must stay synchronous until `endEncoding`.

Allowed:

```swift
let snapshot = preparedSnapshot
planetsRenderer.renderPlanets(snapshot: snapshot, with: renderEncoder, ...)
renderEncoder.endEncoding()
```

Not allowed:

```swift
Task {
    await renderPlanet(with: renderEncoder, ...)
}
renderEncoder.endEncoding()
```

## Constraints and Risks
- `MTLRenderCommandEncoder` is only valid until `endEncoding`; it must never be captured by an async task.
- Actor calls can suspend. A render pass cannot wait for actor data after command encoding begins.
- `LoadedMesh`, `MTKMesh`, `MTLBuffer`, and `MTLTexture` are Metal resource wrappers. If Swift concurrency complains about sendability, prefer keeping publication and consumption on the same actor/main render context or introduce a narrow unchecked-sendable wrapper only after verifying Metal resource lifetime and thread-safety assumptions.
- The pipeline needs double-buffering or atomic snapshot replacement so the renderer never observes a partially prepared frame.
- If preparation falls behind, visual state may lag by one or more frames. That is acceptable if complete snapshots are reused and camera controls remain responsive.
- Camera follow, near-plane fitting, and pinch minimum distance currently depend on async `framingRadius`. Those values should be read from prepared metadata, not computed by querying `ModelLoader` during interaction callbacks.
- Mutable caches such as `planetMeshes` should move out of `PlanetsRenderer` or be replaced by immutable prepared data. A renderer-local cache is easy to turn into a data race once async tasks are introduced.

## Implementation Plan
1. Revert the failed render-path async experiment:
   - remove `Task` creation from `PlanetsRenderer.renderPlanets`
   - make `renderPlanet` synchronous again
   - stop passing `MTLRenderCommandEncoder` into async functions
2. Add prepared render data types:
   - `PreparedRenderSnapshot`
   - `PreparedPlanetRenderPacket`
   - optional lookup helpers for `framingRadius` and planet world position
3. Add a preparation owner:
   - name option: `RenderPreparationPipeline`
   - owns in-flight task tracking and cancellation
   - queries `ModelLoader` outside command encoding
   - publishes only complete snapshots
4. Change `PlanetsRenderer` to draw from a snapshot:
   - remove renderer-owned mesh lookup from the draw path
   - keep screen-label projection inside synchronous rendering
   - keep Metal command encoding unchanged except for using prepared packet data
5. Change camera fitting APIs:
   - `framingRadius` should come from the prepared snapshot/cache synchronously
   - remove ad-hoc `Task` calls from `updateProjectionMatrix`, `CameraController.handlePinch`, and selection handlers where possible
6. Add safeguards:
   - assert or document that render methods are synchronous and must not suspend
   - cancel stale preparation work when newer frame inputs supersede it
   - keep the last complete snapshot if preparation fails
7. Validate:
   - build with strict concurrency settings
   - run the app with Metal API validation enabled
   - verify planet drawing, labels, camera follow, near-plane adjustment, and pinch zoom
