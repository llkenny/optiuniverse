# OptiUniverse

OptiUniverse is an iOS 3D solar-system navigator built with SwiftUI and a technology-neutral `UniverseModule`. The universe scene is rendered with RealityKit through `RealityView`, with custom post-processing used for the final filmic look.

## Highlights

- Real-time 3D solar-system rendering with RealityKit and `RealityView`.
- Offline JPL ephemerides and IAU body orientation synchronized to the current UTC date, with separate accelerated transfer playback.
- SwiftUI interface with a featured-object carousel, destination cards, category filtering, and shared app state through Observation.
- Per-body USDZ model loading through RealityKit.
- JSON-driven object metadata for destination lists, featured objects, and planet simulation parameters.
- Orbital camera controls with pan, pinch, rotation, planet-follow transitions, and dynamic near-plane fitting.
- RealityKit materials, transparent atmosphere/ring layers, deterministic stars, Milky Way environment, transfer routes, and navigation markers.
- ACES-style tone mapping, bloom, vignette, and filmic color grading through RealityKit custom post-processing.
- Technology-neutral scene snapshots that feed camera, route, surface, and RealityKit entity updates.
- Supporting RFC/ADR documentation for rendering architecture decisions.

## Missions

**Artemis II** follows a schematic Earth–Moon–Earth route with a lunar flyby,
a smooth approach to Earth's limb, and a short atmospheric descent to the surface.
The return arc depicts direct entry without a complete Earth orbit; it is not a
telemetry reconstruction or a geographically anchored splashdown track.

The home screen features one large **Missions** carousel in place of Featured Objects.
Cards show the launch date (UTC, formatted for the device locale), name, goals, and a short
description. Missions appear newest first: **Crew 13**, **Starship Flight 14**, then **Artemis II**.
Swipe or use the page indicator to choose a card; tap it to start the mission.

Starship plays a
60-second illustrative flight: launch, separation, a Super Heavy splashdown cutaway,
two complete visual Earth orbits, deployment of 26 Starlinks, and Starship reentry and
controlled ocean splashdown. The overlay shows the current phase, orbit count,
deployment count, progress, and playback ETA. Cancel clears the mission; camera gestures
allow manual viewing while playback continues.

This is a compressed cinematic interpretation, with enlarged vehicles and orbital
altitude for readability, rather than a telemetry reconstruction. Two visual orbits
approximate the shortened actual flight; engine failures and post-splashdown destruction
are omitted. Vehicles and satellites use reusable procedural RealityKit geometry and
follow the active playback clock, which suspends while the app is inactive.

References: [Flight report](https://apnews.com/article/262d3c58d56bf7a525b49115d6c5dfe8),
[Starlink deployment and splashdown](https://www.space.com/space-exploration/launches-spacecraft/spacex-starship-megarocket-flight-14-orbital-launch-success).

**Crew 13** plays a 60-second illustrative Earth-to-ISS flight: Falcon 9 launch
(0–8 s), first-stage separation (8–10 s), second-stage burn (10–16 s), Dragon
separation (16–18 s), orbital flight (18–36 s), ISS rendezvous (36–48 s), docking
(48–58 s), and a docked hold (58–60 s). The camera follows Dragon after booster
separation and frames both Dragon and ISS during approach. The overlay shows the
current phase, progress, and playback ETA. Camera gestures allow manual viewing;
backgrounding suspends playback. Completion or cancellation returns to an Earth overview.

Falcon 9, Crew Dragon, and ISS use reusable procedural RealityKit geometry, including
Dragon's opening nose cone and aligned docking ports. Vehicles and orbital altitude
are enlarged for readability; timing and trajectory are cinematic rather than telemetry.
ISS is a mission destination, not an additional celestial object. Booster recovery,
station stay, and the return flight are omitted.

## Video and screenshots

<img width="200" alt="" src="https://github.com/user-attachments/assets/f9d963d4-5d6c-48dd-adef-a4ccb3a98a40" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/be1b065e-fcdf-462c-bd0c-6f9b1fc90fc5" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/34294a43-97aa-4f22-9d23-aef2f559b850" />
<img width="200" alt="" src="https://github.com/user-attachments/assets/552a9dc7-fb6f-4420-b9d8-91d1e86845ff" />

[<video src="" style="width:100px"></video>](https://github.com/user-attachments/assets/fc05f8cc-b137-4dac-bda6-c2017a23e21f)

## Tech Stack

- Swift
- SwiftUI
- Observation
- RealityKit
- USDZ assets
- Metal Shading Language for the RealityKit post-processing effect only
- Swift Testing

## Current App Structure

```text
OptiUniverse/
  Features/
    HomeScreen/        SwiftUI discovery experience
    RootContainer/     Top-level app flow between home and 3D universe
  UIComponents/        Reusable SwiftUI components
  Resources/           JSON metadata, asset catalogs, colors, images
Modules/
  BaseModule/           Shared app models and services
  CommonTools/          Shared utilities
  UniverseModule/       Universe facade, simulation, camera, RealityKit scene, and PostFX
RFC/                   Rendering architecture notes and ADRs
vfx_scripts/           Experimental volume-noise export utilities
```

## Rendering Architecture

`UniverseModule` exposes a technology-neutral app boundary while RealityKit owns the final rendered frame:

1. `UniverseModuleFactory` creates the app-owned `UniverseModuleResources` facade.
2. `UniverseModuleResources` owns preparation, camera, navigation, transfer-orbit, snapshot, and scene-coordinator services.
3. `UniverseSceneSnapshotPipeline` builds immutable per-frame scene snapshots behind `SnapshotProvider`.
4. `UniverseSceneCoordinator` mutates one RealityKit entity hierarchy from complete camera, simulation, route, and presentation state.
5. `RealityView` owns the visible frame and installs the custom filmic PostFX effect.

## Atmosphere rendering diagnostics

On iOS/visionOS 27 and later, Earth and Venus opt out of RealityKit occlusion
culling for their complete body hierarchies to investigate flickering of nested
transparent atmosphere layers. Earlier OS versions retain the system behavior.
Materials, textures, animations, and camera projection are unchanged.

For an A/B comparison in a **Debug** build, add the environment variable
`OPTI_ATMOSPHERE_OCCLUSION_CULLING=system` in Xcode's **Edit Scheme → Run →
Arguments → Environment Variables**. Remove it (or set it to `disabled`) to test
the workaround. Release builds always use the workaround. The console category
`AtmosphereRendering` logs the selected mode once for Earth and Venus.

On physical iPhone 16 and iPhone 17 Air devices, compare five fresh launches per
mode. Immediately select Earth and then Venus and run 20 rotation/zoom cycles
for each. Repeat after three minutes and after Earth → Moon → Earth and
Venus → Mars → Venus. Record whether the surface, atmosphere, or complete body
disappears, along with frame rate, memory, and IOSurface/Metal allocation errors.
Only regard the culling hypothesis as confirmed if the baseline reproduces and
the workaround consistently avoids the issue. Test layer sorting and lower
resolution diagnostic textures separately if culling alone does not resolve it.

## Content Model

The app currently includes solar-system destinations for the Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, Neptune, and Pluto. Featured-object content is driven by JSON and backed by image assets for Jupiter, Saturn, and Moon Base.

Planet simulation data lives in `Modules/UniverseModule/Sources/UniverseModule/Models/planets.json`, while UI destination content lives in `OptiUniverse/Resources/DestinationObjects.json` and `OptiUniverse/Resources/FeaturedObjects.json`.

## Orbital simulation and transfers

The normal scene follows the device's current UTC date at 1×. Returning from the background or reopening the scene synchronizes planetary positions to the current date; camera transitions, atmospheric animation, and star effects advance only during active presentation. A compact UTC date and Live/Transfer preview/Mission replay indicator appears in iOS and visionOS.

All eleven bodies have offline geometric center positions and velocities from [JPL Horizons](https://ssd-api.jpl.nasa.gov/doc/horizons.html), relative to the Sun in the J2000 ecliptic frame, without light-time or aberration corrections. Earth uses its actual center (399), and Pluto uses its actual center (999), rather than their system barycenters. The Moon's state is heliocentric, including Earth's motion. The supported calendar range is January 1, 2000 through December 31, 2100 UTC. An extra data guard day supports UTC/TDB conversion at the upper boundary.

The approximately 36 MB archive is bundled with the app; there are no runtime network requests. Little-endian double-precision position/velocity records are interpolated with cubic Hermite polynomials. Generation checks every interval at its three quarter points, halves failing sampling steps, and requires errors below 1 km and 1 m/s relative to JPL. Independent checkpoints currently measure a maximum position residual below 0.48 km; the acceptance limit is 10 km relative to the source ephemeris, rather than an absolute prediction of future observations. The manifest records source solutions, request settings, coverage, and SHA-256 checksums. Invalid archives and uncovered dates produce explicit errors instead of falling back to the previous analytic model.

Ephemeris time is physical seconds since J2000 TDB. UTC is converted through TAI and TT using the [NAIF leap-second table and DELTET model](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls). Future UTC dates use the last announced leap-second offset; rebuild the archive/time table when new leap seconds are announced. Absolute positions, camera targets, spacecraft poses, and scene origins retain double precision. Rendering subtracts the camera origin before converting to float scene units, mapping `(x, y, z)` to `(x, z, -y)` at 0.000001 scene units per km.

Body poles and prime meridians follow the dated polynomial and periodic [IAU models in NAIF PCK](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc), evaluated in Swift. Surface latitude is planetocentric and positive longitude is east. A fixed 180° Y correction in the asset manifest aligns the imported sphere texture midpoint (initially -X) with the canonical +X prime meridian; Uranus additionally cancels its exported 90° X tilt before applying its IAU pole. Mesh UV tests verify zero longitude, east, and north for every model. These orientation models support visualization; high-accuracy Earth EOP, lunar binary PCK, ellipsoidal geodesy, and surveyed landing/launch coordinates are separate future work. Atmospheric cloud/belt animation in the Earth and Jupiter assets remains independent of the physical body orientation.

A zero-revolution prograde [Izzo Lambert solution](https://doi.org/10.1007/s10569-014-9587-y) connects the ephemeris state of Earth at departure to the destination at arrival. Flight duration still uses the conventional Hohmann estimate from the catalog's semi-major axes. A universal-variable two-body propagator supplies spacecraft positions. The catalog's fixed orbital elements remain metadata for duration estimates and explicit synthetic test collaborators; they do not drive the production scene. Transfers omit launch/capture burns, fuel constraints, gravity assists, and launch-window optimization.

Starting interplanetary navigation captures a fresh current-date solution and plays its physical duration over 30 active seconds. Bodies and their orientation use the same accelerated epoch, meeting the spacecraft at arrival. The intercept epoch is held until the existing completion handoff. Cancel or Done restores a current-date snapshot before handing the camera back to body follow. Backgrounding pauses preview playback without advancing presentation time. ETA shows playback time alongside physical flight duration.

Orbit guides sample ephemerides over one period when that period fits the archive, shifting the sampling window near coverage boundaries. Neptune and Pluto expose the available 2000–2100 arc instead of a complete orbit, marked **Orbit arc · 2000–2100**. This diagram limit does not block a transfer whose departure and arrival dates are covered. Out-of-range physical transfers remain unavailable with Retry/Close.

Artemis II, Starship Flight 14, and Crew 13 use **Mission replay**: bodies and their orientation follow the historical mission date while spacecraft retain their illustrative scenarios. Playback takes 16 active seconds for Artemis II and 60 for Starship and Crew 13. A shared clock maps cinematic time to historical event anchors with linear interpolation between anchors; the UTC indicator displays that same epoch. ETA remains playback time. Backgrounding pauses the replay, completion holds the final epoch, and Cancel or Done restores the current Live scene before camera handoff.

| Mission | Historical UTC anchors | Cinematic event |
| --- | --- | --- |
| Artemis II | April 1, 2026 22:35; April 6 23:00; April 11 00:07 | Launch; closest lunar approach at route progress 0.58; splashdown |
| Starship Flight 14 | September 28, 2026 ~12:48; ~13:22; ~13:52; ~15:28; ~15:56 | Launch; deployment starts at 19 s and finishes at 28.4 s; entry at 46 s; splashdown at 60 s |
| Crew 13 | October 1, 2026 15:10; 23:05 | Launch; docking at 58 s, with the docking epoch held through the final two seconds |

Dates have the published minute precision; all Flight 14 anchors are approximate and use the completed, shortened flight rather than the superseded ten-hour plan. Sources: [Artemis II launch](https://www.youtube.com/watch?v=_eeZQw9PBc0), [NASA lunar flyby updates](https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/), [NASA splashdown summary](https://ntrs.nasa.gov/api/citations/20260004348/downloads/Final%20-%20JANNAF%202026%20Presentation.pdf), [Flight 14 post-flight report](https://www.space.com/space-exploration/launches-spacecraft/spacex-starship-megarocket-flight-14-orbital-launch-success), and [NASA Crew 13 docking report](https://www.nasa.gov/blogs/spacestation/2026/10/01/dragon-docks-bringing-spacex-crew-13-to-station/).

Artemis uses stable segment progress, keeping the lunar encounter attached to the dated Moon and the direct entry attached to the dated Earth. Starship and Crew 13 capture launch orientation at their historical liftoff, preserve that flight plane, and follow Earth's translation. These are not spacecraft or ISS ephemerides: intermediate phases, visual orbit counts, enlarged geometry, and splashdown locations remain illustrative. Missing ephemeris data makes the mission unavailable with Retry/Close.

`UniverseModuleResources.celestialState(for:at:)` provides position in km, velocity in km/s, and a body-fixed-to-ecliptic orientation matrix; `simulationSnapshot` exposes the displayed UTC date, Live/Transfer preview/Mission replay mode, and data error.

### Regenerating and verifying the archive

Run from the repository root with Python 3 and curl:

```sh
python3 scripts/generate_ephemeris.py
python3 scripts/generate_ephemeris.py --verify-only
```

Downloads are serial, retried, and resumable through `.cache/ephemeris/`; this cache and raw responses are ignored by Git. The generator initially samples planets daily and the Moon every six hours, then refines complete request blocks in batches to avoid thousands of individual API requests. `--body Mars` regenerates one body. Commit the complete archive and manifest together after verification; ordinary app builds do not regenerate data.

Independent validation and reference-fixture regeneration also require `spiceypy==8.3.0` (CSPICE N0067):

```sh
python3 -m venv .cache/reference-validation
.cache/reference-validation/bin/pip install spiceypy==8.3.0
.cache/reference-validation/bin/python scripts/validate_ephemeris.py
```

Validation uses separate Horizons time-list requests plus SPICE orientation/time matrices, including leap-second boundaries, random epochs, and the end of 2100. It updates the committed test fixture in `UniverseModuleTests/Fixtures`; Swift unit tests consume that fixture offline. SPICE is not an application dependency.

## Why This Project Matters

OptiUniverse demonstrates work across the parts of iOS development that are often hard to show in small sample apps:

- 3D scene rendering and custom post-processing, not just UIKit or SwiftUI screens.
- Swift concurrency tradeoffs in a real-time scene pipeline.
- Modular UI composition with reusable SwiftUI components.
- Asset-heavy app organization with JSON configuration and catalogs.
- Documentation of technical decisions through RFCs and ADRs.

## Ratings and Reviews

On iOS, OptiUniverse becomes eligible for Apple's native review prompt after either three foreground sessions or two successfully started navigation routes (including missions). Returning from the background counts as a session; temporary system interruptions, failed route starts do not add counts.

The app waits until loading succeeds, navigation completes or is cancelled, and legal/object-info presentations are dismissed, then allows two seconds for the active interface to settle. Counters persist across updates. Another request requires a newer marketing version and at least 120 days since the last attempt. Existing installations start with zero tracked activity. StoreKit controls whether the prompt actually appears and does not report review submission; no custom rating screen is shown.

## Requirements

- Xcode with iOS Simulator support
- iOS 26.0 or newer deployment target
- An iOS 26-capable simulator or device

## Release 1 URLs

- Marketing URL: https://llkenny.github.io/optiuniverse/
- Support URL: https://llkenny.github.io/optiuniverse/support/

## Build

Open the project in Xcode:

```bash
open OptiUniverse.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project OptiUniverse.xcodeproj \
  -scheme OptiUniverse \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  build CODE_SIGNING_ALLOWED=NO
```

## Tests

The repository includes a Swift Testing target. Run it with:

```bash
xcodebuild -project OptiUniverse.xcodeproj \
  -scheme OptiUniverse \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  test CODE_SIGNING_ALLOWED=NO
```

## Roadmap

- Expand object selection in the universe scene.
- Add richer orbital effects such as satellites, belts, asteroids, and flyby-style transitions.
- Continue improving planet animation, material detail, and post-processing presets.
- Continue expanding focused coverage for data loading, view models, scene snapshots, and RealityKit scene behavior.
