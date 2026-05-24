# ADR 0002: Metal Module Factory Resource Facade

Status: Accepted
Date: 19/05/26

## Context

`MeshProvider` is currently constructed outside `MetalModule`, in the main app target, so startup can preload render data before showing the universe view. The same concrete provider is then passed back into `MetalModule` through `UniverseView`.

That shape makes `MeshProvider` part of the public module boundary even though it owns internal rendering resources. A protocol that only exposes `prepare() async` covers the app target preload use case, but it does not cover the renderer use case. `MetalRenderer` still needs the provider's `MTLDevice` and `ModelLoader` to create command queues and prepare render snapshots.

Expanding `MeshProviderProtocol` to expose those requirements would make the protocol a public representation of Metal implementation details. That would weaken encapsulation instead of improving it.

## Decision

Introduce a public `MetalModuleFactory` that creates a public `MetalModuleResources` facade.

The app target should own one resources instance, use it for startup preloading, pass it into `UniverseView`, and call facade methods for rendering-related actions:

```swift
let metalResources = MetalModuleFactory.makeResources()
await metalResources.prepare()
UniverseView(resources: metalResources)
```

`MetalModuleResources` becomes the public integration surface for the app target. It exposes preloading directly and groups rendering controls through focused protocols:

- `prepare() async`
- `MetalModuleNavigationControlling`
  - `navigationSnapshot`
  - `navigationCameraFollowEnabled`
  - `startNavigation(to:)`
  - `pauseNavigation()`
  - `resumeNavigation()`
  - `cancelNavigation()`
  - `doneNavigation()`
  - `setNavigationCameraFollowEnabled(_:)`
- `MetalModuleTransferOrbitControlling`
  - `showTransferOrbit(to:)`

Keep `MeshProvider`, `ModelLoader`, `MTLDevice`, and renderer wiring internal to `MetalModule`.

## Consequences

The app target no longer constructs or depends on concrete Metal resource owners. It depends on a single facade that represents the supported public rendering integration API.

Preloading remains explicit, so the loading screen can still wait for mesh preparation and app data fetches before showing the main experience.

`UniverseView` construction becomes simpler because it receives one resources object instead of separate mesh, orbit, and navigation dependencies.

The public Metal module surface becomes smaller and more stable. The facade can grow deliberately as the app needs new rendering controls, without exposing lower-level renderer dependencies.
