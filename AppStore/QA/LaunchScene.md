# Illustrated launch diorama QA

## Presentation and diagnostics

The five local PNG layers are in `OptiUniverse/Resources/LaunchDiorama/`. Provenance, processing
and hashes are in `vfx_scripts/illustrated_launch_assets.json`; attribution is mirrored in
`THIRD_PARTY_NOTICES.md` and Legal & Credits. The design represents a fictional launch.

The pad diameter is **4/9 of the short window edge**, 33% larger than the first iPhone iteration.
All layers share one coordinate system and nozzle anchor. Short windows limit ascent to keep
the rocket visible; rotation/resizing preserve sequence state. Platforms decode up to 1536 px,
other sprites up to 1024 px, once per presentation. Canvas updates follow a 30 Hz display link.

Debug-only preview settings:

- `OPTI_LAUNCH_PREVIEW=1`: three seconds of waiting, then release, ascent and fade.
- `OPTI_LAUNCH_PREVIEW_TIME=2`: static ignition; `4.1`: static ascent.
- Remove both settings for a real startup. The isolated preview finishes on its dark background.

The real startup prepares Home and native navigation underneath the overlay. Interaction,
accessibility of the covered interface and rating requests remain gated until completion.
Release takes 0.18 s, ascent 1.2 s and fade 0.35 s. Reduce Motion freezes the illustration and
uses a 0.2 s fade. Missing, unreadable or still-pending artwork uses the fallback indicator and
short fade as soon as the app is ready. Inactive scenes stop their display link; dismissal
invalidates it, cancels decoding and releases the view's image references.

## Verified behavior — 2026-11-08

| Scenario | Evidence |
| --- | --- |
| Instant / long preparation; flight only after readiness; one completion | Controller tests, including readiness at 0, 0.01, 20 and 300 s |
| Background during waiting, release, ascent and fade; removal cancels completion | Mounted presentation tests; physical iPhone background/return smoke check |
| Error and retry | Presentation removal/retry tests; real Simulator error from invalid manifest contents, restored before tapping Try Again in the same process; fresh diorama followed by Home |
| Missing / late artwork | Empty-bundle and deliberately delayed-decoder presentation tests; readiness completes without waiting for decorative images |
| Reduce Motion before launch / during flight / during fade | Controller and mounted tests; system setting enabled on physical iPhone, static scene and Home observed; original setting restored |
| VoiceOver | Physical iPhone: focus outlines observed on the single loading element and then the Home navigation title; no artwork elements exposed. VoiceOver restored to its original off state. Speech audio was not captured |
| Window changes during flight | Mounted live-window test changes Duo and narrow/wide sizes without restarting the sequence or duplicating completion |
| Rating requests and mounted universe scene | Existing review coordinator and root scene lifecycle regressions passed |

Resource-fault experiments changed only installed Simulator copies; original files were restored.
No diagnostic corruption or preview setting is included in the physical-device installation.

## Device and window coverage

- Physical iPhone 16, iOS 27.2: portrait and landscape composition, normal transition, system
  Reduce Motion, VoiceOver focus, background and return. Signed Release build installed.
- iPhone Duo Simulator: both native displays, portrait and landscape. Device Hub Closed/Open
  actions used during an ordinary loading run; the same app process continued to Home.
- iPad A16 Simulator: portrait/landscape, native zoomed and restored window modes, normal startup
  through Home. Arbitrary narrow, square and short-wide sizes additionally use mounted UIKit windows.
- Three rendered stages (smoke, ignition, ascent) at 13 sizes: 402×874, 874×402, 466×678,
  678×466, 669×951, 951×669, 820×1180, 1180×820, 1024×1366, 1366×1024, 320×900,
  500×500 and 1100×320 points. Nozzle anchors and rocket bounds are asserted separately.
- Physical Duo/iPad performance and hardware folding remain outside available hardware coverage.
  visionOS retains its existing loading view; this change does not adapt the diorama to visionOS.

Local review files (ignored, not release resources) are under `build/LaunchDioramaQA/`:
`composition-review.png`, 39 images in `comparisons/`, native-device Simulator screenshots,
startup recordings, ten successful Instruments traces, XML exports and `measurements.csv`.
Mounted snapshots are geometry evidence; they are not hardware screenshots or performance evidence.
A Duo recording goes dark while its recorded display is inactive during folding.

## Physical iPhone measurements

Five fresh-process launches per version, Release optimization, no debugger, same iPhone 16 on
USB power and iOS 27.2. The baseline is the first iPhone diorama with only the same diagnostic
intervals added. OS disk/shader caches are retained; these are not device-reboot measurements.
All ten successful recordings report nominal thermal state.

Intervals: `my.OptiUniverse` / `Launch`, named `Resource preparation`, `Diorama decoding` and
`Launch finishing`. The final interval begins when presentation accepts readiness. The latter
is foreground presentation time; preparation and decoding can overlap.

| Metric, median (range) | First iPhone version | Updated version |
| --- | --- | --- |
| Resource preparation, seconds | 4.530 (4.518–4.851) | 4.534 (4.519–4.707) |
| Diorama decode, milliseconds | 51.5 (50.8–53.0) | 49.3 (45.8–82.8) |
| Finishing interval, seconds | 1.654 (1.636–1.665) | 1.747 (1.729–1.755) |
| Sampled peak physical footprint, MiB | 1629.1 (1589.2–1640.3) | 1630.8 (1587.5–1660.6) |
| Sampled peak resident memory, MiB | 578.2 (568.0–591.9) | 523.8 (411.8–693.1) |
| Resident memory ≥5 s after dismissal, MiB | 274.4 (179.1–283.1) | 280.2 (279.2–294.0) |
| Physical footprint ≥5 s after dismissal, MiB | 1477.3 (1467.5–1486.2) | 1479.3 (1472.9–1496.8) |
| Full one-second waiting samples, median CA FPS | 28 | 30 |
| Full one-second finishing samples, median CA FPS | 27 | 30 |

Preparation differs by about 0.1% in this small sample. Final presentation stays below the 1.9 s
budget. The new display link removes the old sleep timer's pacing drift and synchronizes the
readiness timestamp between callbacks. Post-dismissal footprint differs by about 2 MiB in median;
this sample does not establish a leak-free long-running process or a diorama-only allocation total.

Memory is for the entire app, including universe assets, sampled by Activity Monitor; fast peaks
can be missed. Core Animation FPS is a coarse compositor estimate, not per-frame Canvas timing.
Most complete updated animation samples are 29–30 FPS; the first run also contains 48/59 FPS
compositor samples. Boundary samples around Home construction can report 24–25 FPS. Samples
straddling dismissal/static Home are excluded from the two FPS medians; static Home's zero FPS
is expected. These measurements do not prove every frame meets a strict 33 ms deadline.

Reproduce the lightweight recording without the very large GPU frame captures in Animation Hitches:

```sh
xcrun xctrace record --template 'Activity Monitor' \
  --instrument 'Core Animation FPS' --instrument os_signpost --instrument 'Thermal State' \
  --device DEVICE_ID --time-limit 15s --output launch.trace --launch -- my.OptiUniverse
xcrun xctrace export --input launch.trace --toc
```

## Build and test results

- Strict SwiftLint: zero violations after final source edits.
- iPhone 17 Simulator, iOS 27.2: app build and full suite passed, **83 Swift Testing tests +
  17 XCTest tests**. After the final controller naming cleanup, the affected presentation,
  sequence and review suites passed again (**21 Swift Testing + 8 XCTest**).
- Package-directory tests passed: **BaseModule 4, UniverseModule 286, CommonTools 3**.
- Signed physical-device Release build passed. The finished bundle contains no N1 artwork or
  photographic launch implementation. Source N1 shader, authoring references and credits removed.
  Final installation succeeded; the automatic reopen was rejected because the phone had locked.
  The earlier physical checks and measurements used the same visual implementation before the final naming cleanup.
- The required iPhone 17 / iOS 27.0 destination is unavailable on this host; the exact build
  invocation fails destination selection. Available iOS 27.2 was used for builds and tests.
- Earlier disk-exhaustion recordings and the overloaded first full-suite run were discarded.
  Temporary recording buffers and obsolete OptiUniverse build output were removed; the full
  suite then passed, including the two orbit tests that initially timed out under that load.
