# ADR 0001: Render Pipeline MainActor Isolation

Status: Accepted
Date: 25/04/26

## Context

The render system pipeline separates asynchronous preparation from synchronous Metal command encoding. `ModelLoader` remains an actor because mesh loading and mesh lookup are isolated resource operations. The app target also uses default `MainActor` isolation, so new render-system types become main-actor isolated unless explicitly marked otherwise.

The RFC requires that no command encoder, command buffer encoding operation, or per-frame mutable renderer state crosses an `await` boundary. At the same time, prepared render metadata should be reusable by camera fitting and label projection without forcing unrelated pure math onto the main actor.

## Decision

Keep the preparation owner and render integration on `MainActor`:

- `RenderPreparationPipeline` stays `@MainActor`.
- `MetalRenderer` camera, follow, projection, and draw coordination methods stay on the app's default `MainActor`.
- `PlanetsRenderer.renderPlanets` and its draw helpers stay on the app's default `MainActor` and remain synchronous.
- `ModelLoader` remains its own actor and is only awaited by preparation code before command encoding begins.

Move only pure value helpers out of `MainActor`:

- `PreparedRenderSnapshot.planet(named:)`
- `PreparedRenderSnapshot.framingRadius(ofPlanetNamed:)`
- `PreparedRenderSnapshot.worldPosition(ofPlanetNamed:)`
- `Planet.modelMatrix(at:)`
- pure `float4x4` matrix factory helpers

These helpers are marked `nonisolated` because they only read immutable value data or perform matrix math. They do not touch UIKit, `MTLRenderCommandEncoder`, mutable renderer state, the mesh cache, or actor-isolated loader state.

This only removes actor isolation from the helper methods themselves. It does not move existing call sites off the main thread. For example, `MetalRenderer.updateProjectionMatrix()` is still part of main-actor render coordination, so its call to `float4x4.perspective(...)` still executes on the main thread even though the matrix helper is `nonisolated`.

## Consequences

Prepared snapshot publication remains serialized with the main render context, avoiding partial-frame visibility and keeping Metal resource lifetime assumptions narrow.

Camera and gesture code can synchronously read the latest complete snapshot without introducing ad-hoc tasks.

The nonisolated helpers can be reused from future background preparation code if the pipeline later moves more packet-building math off the main actor.

Moving more execution off `MainActor` is deferred. That requires a more explicit ownership model for:

- which actor owns `latestSnapshot` publication and replacement
- which actor owns the mesh cache
- how stale preparation tasks are cancelled or superseded
- how `LoadedMesh`, `MTKMesh`, `MTLBuffer`, and `MTLTexture` cross actor boundaries
- how the render loop consumes snapshots without seeing partially prepared state
- which camera/projection updates must stay synchronized with UIKit and `MTKView` callbacks

Until that ownership model exists, render coordination, camera state, snapshot publication, and Metal command encoding stay on the main render context. Pure helpers are `nonisolated` so they are ready for future off-main callers, but current main-actor callers still execute them on the main thread.
