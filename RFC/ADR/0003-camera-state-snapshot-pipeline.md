# ADR 0003: Camera State Snapshot Pipeline

Status: Accepted
Date: 21/05/26

## Context

The current camera update path mixes several responsibilities in the renderer:

- camera mode arbitration, such as navigation, arrival, trajectory, follow, and manual orbit
- gesture-driven camera mutations
- transition advancement over time
- scene-dependent target resolution from prepared render snapshots
- camera constraint application
- view and projection matrix construction

This makes `updateCamera(snapshot:delta:)` difficult to reason about because each branch can mutate different pieces of camera state or bypass the state object by writing matrices directly. It also makes the renderer responsible for knowing when camera variables have changed and when an existing matrix snapshot can be reused.

The desired architecture separates camera ownership from rendering. Camera modes and inputs should update canonical camera variables, a snapshot provider should derive immutable matrices from those variables, and `MetalRenderer` should consume matrices without owning camera behavior.

## Decision

Introduce a layered camera architecture:

```text
CameraController / UI
        |
        v
CameraCoordinator
        |
        v
CameraMode(s)
        |
        v
CameraState transaction commit
        |
        v
SnapshotProvider
        |
        v
MetalRenderer
```

1. `CameraState`
   Owns canonical camera variables and camera revision metadata.

2. Camera inputs and modes
   `CameraController` translates gestures and UI events into camera commands. Camera modes such as navigation, orbit, trajectory, follow, and arrival interpret accepted commands and time, then request state changes through transactions.

3. `CameraCoordinator`
   Owns camera mode priority, ownership, cancellation, and ticking. It decides which mode receives a command or time update, whether a command cancels or suspends another mode, and which transactional camera mutation is committed.

4. `SnapshotProvider`
   Reads committed camera state, scene snapshots, viewport data, and time-dependent mode requirements. It produces immutable camera snapshots containing render-ready matrices and derived camera values.

5. `MetalRenderer`
   Reads the latest camera snapshot and uses its matrices during command encoding. It does not arbitrate camera modes or mutate camera state as part of rendering.

Camera state changes must be committed through an explicit transaction/version mechanism. A transaction can batch multiple variable changes and commit them once. On commit, `CameraState` increments a camera revision and records enough dirty metadata for the snapshot provider to decide whether a new snapshot is required.

The snapshot provider should not rely on camera revision alone. It must also consider dependencies that can change the derived camera snapshot without a direct camera variable mutation:

- latest prepared scene snapshot revision
- followed object world position or framing radius changes
- navigation route progress changes
- active transition or inertia requiring per-tick evaluation
- viewport size or aspect changes
- projection inputs such as field of view, near plane, or far plane

The renderer should receive an immutable camera snapshot for the current render iteration. If none of the camera, scene, viewport, projection, or active time-dependent dependencies changed, the snapshot provider may reuse the previous camera snapshot and skip matrix recomputation.

## Consequences

`MetalRenderer` becomes a consumer of camera matrices instead of the owner of camera behavior. This narrows the renderer's responsibility to rendering and command encoding.

Camera mode priority becomes explicit. Conflicts such as manual control cancelling follow, navigation owning the camera while active, or trajectory pan only applying in trajectory mode should be resolved by the camera mode layer or a camera coordinator, not by renderer branches.

The coordinator must stay focused on routing and ownership. It should not perform matrix math or directly encode mode-specific camera behavior. Mode-specific transformations belong in the modes, and matrix derivation belongs in the snapshot provider.

`CameraState` becomes easier to validate because mutations pass through transactions. Batching also avoids multiple intermediate matrix rebuilds when one user action changes target, distance, orientation, and constraints together.

Snapshot reuse becomes deterministic. The system can skip camera snapshot work only when all relevant revisions and time-dependent requirements are unchanged.

Derived values such as camera position, offset, up vector, view matrix, and projection matrix should generally belong to immutable snapshots instead of being independently mutable state. This reduces stale or contradictory camera data.

The implementation should avoid letting every mode freely mutate state in incompatible ways. Modes should emit camera commands or transactional mutations through `CameraCoordinator` so ownership and cancellation rules remain visible.
