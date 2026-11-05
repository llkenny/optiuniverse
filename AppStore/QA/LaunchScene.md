# N1 loading scene QA

## Visual review

In a Debug run, set `OPTI_LAUNCH_PREVIEW=1` for three seconds of waiting followed by the complete launch. Add `OPTI_LAUNCH_PREVIEW_TIME=2` to freeze a waiting frame, or `3.65` to freeze ascent; leave it unset for animation.
Remove it for normal startup. The preview does not prepare the universe and fades to the app background.
The source photograph and generated derivatives live in `OptiUniverse/Resources/LaunchScene/`;
prompts and processing notes are in `vfx_scripts/n1_launch_prompts.json` and `THIRD_PARTY_NOTICES.md`.

- Check iPhone 17, both iPhone Duo display configurations, and iPad, in portrait and landscape.
- Resize iPad windows, including narrow, square and short-wide sizes, during waiting and ascent.
- Inspect the rocket contour, open interstage trusses, tower connections, reconstructed vacancy and
  sky joins. No rectangular photo edge, duplicate rocket or tower, moving sky patch or bright fringe should appear.
- Check that the nozzle and exhaust remain attached, ground vapor persists after departure, and
  the navigation bars appear only after the dissolve with no blank intermediate frame.
- Judge the 916 × 1500 source at native iPad scale: archive softness is intentional; visible masks are not.

## Behavior

- Normal cold launch: loading continues while vapor animates; lift begins only when preparation succeeds.
- Fast readiness: final sequence takes about 1.73 seconds, plus at most one 33 ms presentation tick.
- Long readiness: no elapsed-time threshold can start the flight before resources are ready.
- Preparation error: show the existing error screen immediately. Retry starts a fresh scene.
- Background during waiting, ascent and dissolve: presentation time stays frozen while inactive;
  foregrounding continues without a jump or duplicate completion.
- Enable Reduce Motion before launch and during ascent: static scene and a 0.2-second fade; no flight.
- VoiceOver: announce Loading; home controls remain inaccessible until the overlay is dismissed.
- Missing/unreadable image in a diagnostic build: fallback loading presentation, then a short fade;
  app readiness must not depend on any visual asset or shader.
- Confirm review requests remain deferred until the launch finishes.

## Physical-device performance (manual)

Compare five cold launches against the previous build on the same device and thermal state.
Record resource-preparation duration separately from the deliberate final animation, peak resident
memory, main-thread stalls, animation FPS, and memory after dismissal. Target stable 30 FPS and no
material resource-loading regression. Repeat on the smaller Duo display and iPad during resize.
Simulator frame rate is not evidence of physical-device performance.

## Implementation validation — 2026-11-05

- Xcode 27.2, iPhone 17 Simulator with iOS 27.2: app build and full app test plan passed
  (81 Swift Testing tests plus 11 XCTest tests, zero failures). The two mounted-presentation tests
  also passed again after matching the production safe-area behavior.
- `swiftlint lint --strict`: 287 files, zero violations. `git diff --check`: clean.
- The exact required iOS 27.0 build destination is unavailable: that runtime is installed as
  unavailable on this host. Validation used the available 27.2 runtime; 27.0 validation is not claimed.
- Mounted real SwiftUI scene snapshots cover 402×874, 874×402, 466×678, 678×466,
  669×951, 951×669, 820×1180, 1180×820, 320×900, 500×500 and 1100×320 points.
- Inspected iPad waiting/ascent frames and an actual app startup recording, including the Home
  reveal. Generated sky seams, rough hand-cut truss holes and people moving with the base were
  removed during visual iteration. The final scene uses a photo-derived transparent rocket cutout.
- Local review artifacts are under ignored `build/LaunchPreview/`; `n1-preview.mp4` is a short
  excerpt of an actual Simulator startup, not a synthetic animation. Original full recordings are
  retained alongside it. The unmodified archival source remains bundled as a fallback photograph.
- Native Duo display switching could not be confirmed: `simctl launch` stalled when switching
  powered displays. That test process was stopped and both display power states restored. Duo
  sizes are covered by mounted UI tests; physical folding/display switching remains manual QA.
- Physical-device FPS, peak memory, loading-time comparison, VoiceOver exploration and hardware
  display transitions remain unmeasured. No device-performance claim is made from Simulator logs.
