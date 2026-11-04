# Local validation — October 31, 2026

## Release assets: passed

- Twenty-two upload PNGs: twelve ordinary iPhone screenshots, eight iPhone Duo screenshots, one Header, and one Search Results image.
- All upload images have the expected dimensions, 8-bit RGB pixels, an sRGB profile, and no alpha channel or transparency chunk. The overview is also an opaque sRGB PNG.
- Fourteen original Simulator captures are retained. Ordinary iPhone captures are 1206 × 2622; each Duo capture has its native display and orientation dimensions.
- Complete captures are fitted proportionally inside each layout. No app UI, text, or planet rendering was repainted, generated, or retouched. Native viewport clipping of rings, planets, and orbital paths remains visible where the app produces it.
- Visual inspection covered the overview, all fourteen source captures, and the final portrait and landscape layouts. Headlines, subtitles, and controls fit. Duo portrait headline sizes were adjusted to prevent overlap. No loading indicators or window-switcher overlays remain in the selected captures.
- The Header matches the approved 1.9 export byte for byte. Search Results uses the unchanged advertising background with a fresh 1.10 foreground capture.
- The package contains seven English US metadata files. Character counts excluding the final newline: Description 1958/4000; Promotional Text 159/170; Keywords 91/100; What's New 595/4000.
- Manifest hashes cover upload assets, metadata, original captures, and the overview. The capture commit is preserved across later asset-only commits and validation runs.
- English upload instructions, release notes, TestFlight instructions, capture provenance, and reproducible composition/validation sources are included.
- The text scan found no private-key blocks, common credential-token patterns, Cyrillic text, absolute user-home paths, or simulator container paths in the new package and updated metadata/TestFlight text. `git diff --check` passed.

Run the local asset check from the repository root:

```sh
python3 AppStore/1.10/en-US/sources/validate.py
```

## Build and installed app provenance

New builds were performed through **Xcode 27.1 (27A9275)** against the current checkout, using the **iOS 27.1 SDK**. The Xcode activity records show successful app builds with zero errors and zero warnings:

| Run destination | Build start, UTC | Result |
|---|---|---|
| iPhone Duo / iOS 27.1 | 2026-10-31 07:19:28 | Succeeded |
| iPhone 17 / iOS 27.0 | 2026-10-31 07:25:00 | Succeeded |

The app was launched and exercised on both devices. Installed bundle metadata confirmed **1.10 (28)**. Both installed `OptiUniverse.debug.dylib` files match the built product by SHA-256:

```text
e899baee4c8e09bbc9848c643ab8ed2a7801efe168b32a80cb7848a68bc17a91
```

All captures use English US, dark appearance, and a 09:41 status-bar override. Duo was exercised across both displays and orientations, including object details and mission playback. The saved images show the actual native controls and available viewport in each pose.

The requested command-line build was attempted with code signing disabled and temporary DerivedData. It failed before building because sandbox restrictions prevented SwiftPM and Clang cache writes and CoreSimulator access. Two requests for expanded command-line access timed out in automatic approval review before execution. The successful Xcode UI builds above are the fallback validation; the requested command-line build is not reported as passed.

## Lint

The default `swiftlint lint --strict` inspected 262 files and found zero violations, but exited with a cache-write permission error. A strict run with `--no-cache` completed successfully with **zero violations in 262 files**. The final `swiftlint lint --strict --cache-path /private/tmp/optiuniverse-release-1.10-lint-cache` check also completed successfully with zero violations in 262 files. No app or test Swift sources were changed for this release package.

## Tests: assertions passed; clean run blocked

The OptiUniverse scheme was tested through Xcode on **iPhone 17 / iOS 27.0**. The console reported:

```text
Test Suite 'ObjectInfoLayoutTests' passed.
Executed 3 tests, with 0 failures (0 unexpected).
Test run with 67 tests in 13 suites passed.
```

The test process then stopped at **EXC_BAD_ACCESS (code=1, address=0x38)** in `libusd_ms.dylib`, inside `TfType::_IsAImplNoLock`, on the `com.apple.realityio.live-scene-update-queue` thread. The stack also included `CoreRealityIO` live-scene building. The stopped test process was ended through Xcode. This is **not a clean successful test run**, despite the passing assertions. The test build also reported eight existing unnecessary-`await` warnings. No unrelated app or test changes were made to address this failure.

Reading the final xcresult summary encountered report-cache write restrictions; automatic approval review for broader read-tool execution also timed out. Test results above are taken from Xcode's observed console and debugger state, not an inferred successful xcresult status.

## Release boundaries

The 1.9 package is unchanged. The user's pre-existing version/build edits in the Xcode project are preserved. No generated build products, simulator identifiers, absolute home-directory paths, credentials, or user-specific Xcode state are included in the package.

App Store Connect upload, placement previews, asset acceptance, and App Review have not been performed. Nothing was published or committed. Final acceptance of the prepared local assets remains subject to App Store Connect validation.
