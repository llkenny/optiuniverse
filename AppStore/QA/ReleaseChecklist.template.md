# OptiUniverse release QA

Copy this file to `AppStore/<version>/QA-<build>.md` for each release candidate. Keep it in the version directory so the scenario links resolve. Complete the report for the exact build you plan to ship and link it from the release PR. Start a new report for a new build. Documentation changes alone can use the report for the same build.

## Candidate

- Version and build:
- Candidate source commit:
- Scenario catalog revision (commit or PR permalink):
- QA date or date range (UTC):
- Tester(s):
- Release PR:
- Decision and reviewer:

## Test environments

Enter the actual model, OS version, physical device or simulator, and install source/type. For example, record TestFlight clean install, TestFlight over the previous public release, simulator Release build, or Xcode Debug clean install. Use the same candidate version, build number and source commit for all release runs. The Xcode development diagnostics use the candidate commit. Reuse a device across roles when possible. If a role uses more than one configuration, distinguish them with suffixes such as `DEV-2` and note the exact configuration on the affected run.

| Role | Device model | OS version | Physical or simulator | Install source/type and build |
| --- | --- | --- | --- | --- |
| BASE · primary iPhone | | | | |
| HW · physical iPhone | | | Physical | |
| UPD · previous release → candidate | | | | |
| MIN · iPhone on iOS 26.0 | | | | |
| DUO · iPhone Duo, iOS 27.1 or later | | | | |
| PAD · iPad | | | | |
| DEV · Xcode development build | | | | |
| DIAG · disposable device for clock changes | | | | |

## Results

Use the linked steps and expected results. Enter one outcome per row. `PASS` means every assigned check passed. `FAIL` means an expectation was violated. `BLOCKED` means a required setup, device or dependency prevented completion. `N/A` applies only to conditional diagnostics whose trigger does not apply. Explain each `FAIL`, `BLOCKED` and `N/A` in Notes. Include an issue or other evidence link and the date and outcome of any retest. Keep the original outcome in Notes when updating the Result after a retest. Add the tester or date in Notes when they differ from the candidate fields. Attach evidence with personal data removed.

### Required functional runs

Use the primary iPhone in portrait unless noted. Use a physical iPhone for the hardware row. If `BASE` and `HW` are the same device, use one traversal for camera and rendering checks and record the results separately.

| Scenario | Configuration | Result | Notes / issue / retest |
| --- | --- | --- | --- |
| [QA-INSTALL · Clean offline launch](../QA/Scenarios.md#qa-install) | BASE · portrait · fresh install | | |
| [QA-UPDATE · Upgrade](../QA/Scenarios.md#qa-update) | UPD · portrait · previous public build overlaid with candidate | | |
| [QA-DISCOVERY · Catalog and filters](../QA/Scenarios.md#qa-discovery) | BASE · portrait | | |
| [QA-CAMERA · Selection and camera](../QA/Scenarios.md#qa-camera) | BASE · portrait | | |
| [QA-RENDER · 3D rendering](../QA/Scenarios.md#qa-render) | HW · portrait · candidate | | |
| [QA-DETAILS · Object details](../QA/Scenarios.md#qa-details) | BASE · compact | | |
| [QA-PREVIEW · Transfer preview](../QA/Scenarios.md#qa-preview) | BASE · portrait | | |
| [QA-FLIGHT · Transfer playback](../QA/Scenarios.md#qa-flight) | BASE · portrait | | |
| [QA-LIFECYCLE · Background and resume](../QA/Scenarios.md#qa-lifecycle) | BASE · portrait · steps 1–2 | | |
| [QA-LIFECYCLE · Exact Live UTC](../QA/Scenarios.md#qa-lifecycle) | DEV · portrait · step 3 | | |
| [QA-MISSION · Shared controls](../QA/Scenarios.md#qa-mission) | BASE · portrait | | |
| [QA-ARTEMIS · Artemis II](../QA/Scenarios.md#qa-artemis) | BASE · portrait | | |
| [QA-STARSHIP · Starship Flight 14](../QA/Scenarios.md#qa-starship) | BASE · portrait | | |
| [QA-CREW · Crew 13](../QA/Scenarios.md#qa-crew) | BASE · portrait | | |
| [QA-VOYAGER · Voyager 1](../QA/Scenarios.md#qa-voyager) | BASE · portrait | | |
| [QA-VOSTOK · Vostok 1](../QA/Scenarios.md#qa-vostok) | BASE · portrait | | |
| [QA-TEXT · Large text](../QA/Scenarios.md#qa-text) | BASE · landscape or short resizable window | | |
| [QA-VOICEOVER · Navigation and escape](../QA/Scenarios.md#qa-voiceover) | BASE · portrait | | |
| [QA-CREDITS · Attribution and links](../QA/Scenarios.md#qa-credits) | BASE · portrait · online | | |
| [QA-REVIEW · Native prompt](../QA/Scenarios.md#qa-review) | DEV · portrait · two clean runs | | |
| [QA-MIN-OS · Compatibility smoke](../QA/Scenarios.md#qa-min-os) | MIN · portrait | | |

### Required device and layout runs

The functional run covers compact portrait on iPhone. Use the fixed-pose rows below for layout and framing, and use the resize rows to check what stays in place during transitions. For Duo and iPad, record the actual poses or sizes exercised in Notes. Device Hub and iPad Simulator are acceptable for these rows.

| Scenario | Configuration | Result | Notes / issue / retest |
| --- | --- | --- | --- |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | BASE · iPhone landscape | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | DUO · outer portrait | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | DUO · outer landscape | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | DUO · inner portrait | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | DUO · inner landscape | | |
| [QA-RESIZE-HOME · Discovery state](../QA/Scenarios.md#qa-resize-home) | DUO · fold, unfold and rotate | | |
| [QA-RESIZE-INFO · Reading position](../QA/Scenarios.md#qa-resize-info) | DUO · bottom ↔ trailing panel | | |
| [QA-RESIZE-PREVIEW · Toolbar placement](../QA/Scenarios.md#qa-resize-preview) | DUO · vertical ↔ horizontal bar, both Split View positions | | |
| [QA-RESIZE-MISSION · Playback continuity](../QA/Scenarios.md#qa-resize-mission) | DUO · display and rotation changes, both Split View positions | | |
| [QA-TEXT · Large text](../QA/Scenarios.md#qa-text) | DUO · short inner Split View window with asymmetric insets | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | PAD · full-screen portrait | | |
| [QA-POSE · Layout and framing](../QA/Scenarios.md#qa-pose) | PAD · full-screen landscape | | |
| [QA-RESIZE-HOME · Discovery state](../QA/Scenarios.md#qa-resize-home) | PAD · tall/square ↔ wide window | | |
| [QA-RESIZE-INFO · Reading position](../QA/Scenarios.md#qa-resize-info) | PAD · bottom ↔ trailing panel | | |
| [QA-RESIZE-PREVIEW · Toolbar placement](../QA/Scenarios.md#qa-resize-preview) | PAD · narrow ↔ wide window | | |
| [QA-RESIZE-MISSION · Playback continuity](../QA/Scenarios.md#qa-resize-mission) | PAD · narrow, short and expanded window | | |
| [QA-TEXT · Large text](../QA/Scenarios.md#qa-text) | PAD · short multitasking window | | |

### Conditional diagnostics

Use `DIAG`. Each row is required when its trigger applies. Otherwise enter `N/A` and document why. Record the actual dates and restoration of the device settings.

| Scenario | Trigger | Result | Notes / issue / retest |
| --- | --- | --- | --- |
| [QA-LOAD-ERROR · Startup recovery](../QA/Scenarios.md#qa-load-error) | Startup, asset preparation or archive loading or coverage changed | | |
| [QA-PREVIEW-ERROR · Preview error](../QA/Scenarios.md#qa-preview-error) | Preview, orbit coverage or preview error handling changed | | |
| [QA-FLIGHT-ERROR · Route start error](../QA/Scenarios.md#qa-flight-error) | Transfer playback, route failure handling or archive coverage changed | | |

## Automated checks and release review

Record the commands and results required by [AGENTS.md](../../AGENTS.md), including SwiftLint and the app build and test results. Include package test results when available. Link to the results that cover ephemeris and simulation accuracy and the review coordinator. Record environment blockers as such. Automated results and manual results have separate evidence.

| Check | Outcome | Evidence or blocker |
| --- | --- | --- |
| Strict SwiftLint | | |
| App build and tests | | |
| BaseModule tests | | |
| UniverseModule tests (including ephemeris) | | |
| Review coordinator tests | | |

Open a GitHub Issue for each defect. Include the scenario ID, candidate build, device and OS, display or window pose, reproduction steps, expected and actual results, and evidence. Link that issue from the affected run. Keep the report in the release PR and record the reviewer's decision in the Candidate section. [GitHub release tracking](https://docs.github.com/en/issues/tracking-your-work-with-issues/learning-about-issues/planning-and-tracking-work-for-your-team-or-project)

Every required row, including any triggered diagnostic, must have `PASS` for release sign-off. A required `FAIL`, `BLOCKED`, or blank result holds the candidate. `N/A` requires a reason and is reserved for an untriggered diagnostic. A build without the physical iPhone rendering result is still awaiting QA.
