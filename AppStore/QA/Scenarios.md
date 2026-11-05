# OptiUniverse manual release QA scenarios

Generate the release QA issue using the [Release QA instructions](../../README.md#release-qa) to assign and record runs. The [release checklist template](ReleaseChecklist.template.md) supplies its configuration matrix and remains available for a file-based report. Scenario IDs are stable. Update the scenario and its checklist rows together when a feature or supported configuration changes.

## Run conventions

- Use the release candidate from TestFlight where available. For a simulator, use a Release build from the same source commit with the same version and build number. Record the install source. Xcode development builds are reserved for the review prompt and debugger diagnostics.
- Start each scenario from its stated screen. On the 3D scene, use the toolbar action named **Home** to return to discovery. To open a preview from Home, select the named destination, open **Object details** (binoculars), then tap **Route**. To start a mission from Home, bring its card into view and tap the card. These are setup actions when the scenario evaluates a later state.
- Run at default text size and with automatic date and time unless the scenario says otherwise. Read times in UTC. Measure playback from the running state, counting foreground time only and allowing for rounding and the completion transition. A recording helps capture brief phases and arrivals.
- For any failed step, record the last successful step and the actual result. A setup failure blocks the dependent run. Link to the original defect so the same failure can be tracked in one issue.

## Installation and discovery

<a name="qa-install"></a>

### QA-INSTALL · Clean offline launch

**Start** with the candidate installed but never launched on a disposable device or simulator. Turn on Airplane Mode and explicitly turn Wi-Fi off.

1. Open the app and let preparation finish. Verify the loading presentation gives way to Home with Missions and destinations. The app remains responsive and shows no network or loading error.
2. Force-quit and reopen while still offline. Verify Home loads again.

**Reset** by restoring the previous network settings and leaving the app on Home.

<a name="qa-update"></a>

### QA-UPDATE · Update from the previous public version

**Start** on a device with the previous public version installed. Open it once, select Earth, then close the app. Record both version/build numbers.

1. Install the candidate over the existing app. Use the same app identity and keep the existing installation data. Launch the updated app and verify Home loads without a crash or preparation error.
2. Select Mars, open its details, then return Home. Verify the upgraded installation can use the bundled scene and destination data. The selected object from the old session is allowed to reset at launch.

**Reset** on Home. Use a separate disposable install for clean-install and rating checks.

<a name="qa-discovery"></a>

### QA-DISCOVERY · Mission browser, destination catalog and filters

**Start** on Home in a compact portrait layout with no category selected.

1. Swipe from the first mission to the last. Verify five distinct cards in this order: Crew 13, Starship Flight 14, Artemis II, Voyager 1, Vostok 1. Each card shows a name, launch date, goal and description. Verify the selected dot follows the swipe. Tap the second and fifth dots and verify they select the corresponding cards. Leave the cards unopened.
2. Scroll the unfiltered destination row end to end. Verify one card per object listed below, including separate Moon and Moon Base cards, with readable names and thumbnails.
3. Select each category and verify the visible cards exactly match its row below. Switch directly from one active category to another and verify only the new category remains selected. Tap the active chip again and verify all 12 cards return.

| Category | Cards |
| --- | --- |
| Hot | Mercury, Venus, Sun |
| Inhabited | Earth |
| Satellite | Moon |
| Popular | Mars, Jupiter |
| Rings | Saturn, Uranus |
| Cold | Neptune, Pluto |
| Base | Moon Base |

**Reset** by clearing the filter and selecting the first mission dot.

## Scene, details and navigation

<a name="qa-camera"></a>

### QA-CAMERA · Object selection, camera transitions and gestures

**Start** on Home with the catalog unfiltered.

1. Open Earth, return Home, then open Saturn and Moon Base in turn. Verify the breadcrumb updates to the card's name and the camera settles on the corresponding body. Moon Base focuses on the Moon's designated surface location while keeping the Moon Base identity in the breadcrumb. Use **Home** between selections and verify it remains usable after each transition.
2. With Earth selected and overlays closed, drag horizontally and vertically with one finger, then pinch in and out. Verify dragging rotates the view continuously around the object and pinching changes the camera distance. At the near and far zoom limits, keep pinching, then reverse. Verify the camera stays controllable, recovers from both limits, and avoids clipping through the body or losing its target.

**Reset** by returning Home.

<a name="qa-render"></a>

### QA-RENDER · Body assets and rendering stability on hardware

**Start** on Home on a physical iPhone. Keep the default graphics behavior of the candidate. Use the same traversal as QA-CAMERA if both run on that iPhone, while recording each scenario's own result.

1. Open Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn, Uranus, Neptune and Pluto. Wait for each camera transition. Verify the body is visible, textured and distinct, with no placeholder, blank mesh or persistent rendering artifact.
2. Inspect the lit and shaded sides of a body, the Sun's glow, Earth and Venus atmosphere layers, the rings of Saturn and Uranus, and the star field and Milky Way when zoomed out. Verify layers stay attached, with no obvious z-fighting, holes or disappearing rings or background during movement.
3. On Earth and then Venus, perform five cycles per body. Drag to change the viewing angle, pinch toward the limb, then zoom back out. Go from Earth to Moon and back to Earth, then from Venus to Mars and back to Venus, using Home between selections. Repeat the five cycles on both bodies. Verify the surface, atmosphere and whole body remain visible throughout, with no intermittent flashing, black frames or repeatable stalls. Record the affected layer and a timestamp or clip if anything flickers.

**Reset** on Home. For deeper atmosphere investigation, use the [existing A/B procedure](../../README.md#atmosphere-rendering-diagnostics).

<a name="qa-details"></a>

### QA-DETAILS · Object information and Route eligibility

**Start** on Home with no filter. Use compact portrait. Shorten the window or rotate to a shorter pose if necessary to make the content scroll.

1. Select Saturn and open **Object details**. Verify the panel shows Saturn's title, subtitle, statistics with units, description and orbit section with illustration and properties. Scroll from the top to the end. Verify content and the **Route** action are reachable. Scroll back toward the top from within the content and verify the panel remains open during ordinary reading.
2. Tap the scene outside the panel. Reopen the panel, start a new downward pull at the very top, and release. Verify each dismissal reveals the same selected object and returns the **Object details** button.
3. Open details for the other destinations using Home between them. Verify each shows its own title. **Route** is present for Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune and Pluto. **Route** is absent for Sun, Earth, Moon and Moon Base. Check that the Moon and Moon Base details remain distinct and that Moon Base has no orbit section.

**Reset** by closing details and returning Home.

<a name="qa-preview"></a>

### QA-PREVIEW · Transfer preview, orbit guides and close

**Start** on Home with no active route and the device clock set normally.

1. Open a Mars preview. If calculation text appears, verify it resolves. Verify the scene frames the orbital overview, displays Earth and destination orbit guides and a transfer path, and shows a positive transfer duration in days alongside **30 s playback**. Verify **Start navigation** is available.
2. Tap **Close transfer preview**. Verify the preview lines and controls disappear and Mars remains the selected destination. Open another preview promptly and verify it contains only the new destination's guides and controls.
3. Open a Neptune preview and then a Pluto preview, closing each before opening the next. Verify each labels its incomplete guide **Orbit arc · 1961–2100** and produces a usable transfer for the current release date when departure and arrival fall within coverage.

**Reset** by closing the preview and returning Home.

<a name="qa-flight"></a>

### QA-FLIGHT · Transfer playback, arrival and cancellation

**Start** on Home. Open a Mars preview and wait for it to be ready.

1. Tap **Start navigation**. Verify the Earth-to-Mars title, flight duration, countdown and advancing UTC date. Observe the route and its moving navigation marker. Drag with two fingers while in flight. Verify the viewpoint responds and playback continues.
2. Allow about 30 active seconds for arrival. Verify **Arrived** and **Route complete** appear briefly, then route UI and accelerated UTC disappear automatically. Verify the camera follows Mars and ordinary scene controls work.
3. Return Home, start a Jupiter transfer, wait for its countdown, then tap **Cancel navigation**. Verify route UI, marker and accelerated UTC clear promptly. Remain in the scene long enough to verify the cancelled route does not resume or report a late arrival.

**Reset** on Home. QA-LIFECYCLE covers the clock behind the restored scene.

<a name="qa-lifecycle"></a>

### QA-LIFECYCLE · Live time and playback across backgrounding

**Start** on Home with automatic time and a second UTC clock for reference.

1. Start a Mars transfer. Once it is running, record the ETA and UTC, leave for the iOS Home Screen for 10 seconds and return. Verify the route and destination remain the same. On return, the displayed ETA and epoch continue from the prior position, allowing for time in the foreground and display rounding. Cancel the transfer.
2. Start Crew 13 and repeat while it is running. Verify the mission remains in its current phase or advances only by elapsed foreground time. Its historical UTC and ETA must not jump by the background interval. Cancel the mission.
3. Verify exact Live UTC in an Xcode development build from the same commit. Set a source breakpoint at `let modeOrErrorChanged` in `UniverseSceneCoordinator.publishSimulationTime`. On the 3D scene with no active playback, note the reference UTC at the stop, inspect the local `snapshot` with `frame variable snapshot`, and read the date with `po snapshot.dateUTC`. Disable the breakpoint, resume, background for 10 seconds and return. Enable the breakpoint and inspect a fresh snapshot. Repeat after cancelling an active replay. Verify `.live` and a UTC date within two seconds of the reference at each stop. The candidate's iOS UI displays UTC during accelerated playback and hides that readout in Live. Use the debugger only for the exact Live check, outside the playback timing steps.

**Reset** by removing the breakpoint, stopping the development build, and returning the candidate to Home.

## Mission replays

Start each replay from Home with no active route and the app in the foreground. The times below are approximate active playback times unless marked UTC.

<a name="qa-mission"></a>

### QA-MISSION · Shared mission controls and cancellation

**Start** on Home with the Starship Flight 14 card in view.

1. Open the card. Verify the title identifies Starship Flight 14, the phase and ETA become readable, and the UTC date switches to the historical flight date.
2. Drag or pinch the scene while playing. Verify the viewpoint responds and the ETA continues. Tap **Cancel mission**. Verify the mission overlay, vehicles and historical UTC clear and the scene returns to an Earth view. Wait briefly to check that playback stays cancelled.

**Reset** on Home.

<a name="qa-artemis"></a>

### QA-ARTEMIS · Artemis II lunar flyby and return

**Start** on Home with Artemis II in view.

1. Play the roughly 16-second replay without touching the camera. Verify the Earth → Moon → Earth route departs Earth, passes close to the Moon, then follows Earth's limb into atmospheric descent and ends at Earth without a full orbit on the return.
2. Verify the encounter occurs around April 6, 2026 UTC, between the April 1 departure and April 11 return. Verify the final camera handoff leaves Earth in view without route geometry.

**Reset** on Home after completion.

<a name="qa-starship"></a>

### QA-STARSHIP · Starship Flight 14 staging, deployment and splashdown

**Start** on Home with Starship Flight 14 in view.

1. Play the roughly 60-second replay. Observe launch, separation and the Super Heavy splashdown cutaway. Verify playback returns to Starship after the cutaway.
2. Verify the replay depicts two Earth orbits. During deployment (about 19–28 seconds), observe satellite release and a counter that advances to 26. Verify the UTC display stays on September 28, 2026 through the later reentry and controlled ocean splashdown.
3. Verify the replay clears automatically and the camera returns to an Earth overview.

**Reset** on Home after completion.

<a name="qa-crew"></a>

### QA-CREW · Crew 13 staging and ISS docking

**Start** on Home with Crew 13 in view.

1. Play the roughly 60-second replay. Observe Falcon 9 ascent, stage separation and second-stage burn, then Dragon separation around 16–18 seconds. Verify the camera follows Dragon after separation.
2. During rendezvous around 36–48 seconds, verify the camera frames both Dragon and the ISS. Observe the nose cone open, the docking ports align and the vehicles meet without an obvious jump or pass-through. Verify **Docked at ISS** holds at the October 1, 2026 docking epoch for the last two seconds.
3. Verify completion returns to an Earth overview.

**Reset** on Home after completion.

<a name="qa-voyager"></a>

### QA-VOYAGER · Voyager 1 flybys and heliopause epilogue

**Start** on Home with Voyager 1 in view.

1. Play the roughly 90-second replay. Observe launch and probe release, then Jupiter near 30 seconds and Saturn near 52 seconds. Verify flybys are framed clearly, the probe passes clear of each body and Saturn's rings, and UTC advances through the 1979 and 1980 encounters.
2. At about 82 seconds, verify UTC holds on August 25, 2012 and the caption reads “Voyager 1 has left the heliosphere and continues its journey through interstellar space.” Verify the caption remains through completion, then clears automatically with the accelerated UTC as the camera returns to a Sun-centered overview.

**Reset** on Home after completion.

<a name="qa-vostok"></a>

### QA-VOSTOK · Vostok 1 orbit, separate landings and Done

**Start** on Home with Vostok 1 in view.

1. Play the roughly 60-second replay. Observe launch from Earth, booster/fairing/core separation, one orbit, retrofire, reentry and ejection. Verify capsule and pilot descend under separate parachutes and land in that order.
2. Verify UTC holds at approximately 07:55 on April 12, 1961. The final Gagarin caption and **Done** remain visible after the ETA ends. Wait at least five foreground seconds, then tap **Done**. Verify the caption and replay UI clear and the camera returns to an Earth overview.

**Reset** on Home.

## Accessibility and system surfaces

<a name="qa-text"></a>

### QA-TEXT · Large text and short-window scrolling

**Start** on Home in the configuration assigned in the checklist. Enable the largest accessibility text size. Use a short window or landscape where specified.

1. On Home, scroll through the content. Verify long mission descriptions, the page indicator, category chips and the last destination are readable and reachable even when the whole page must scroll. Check that the grid or row can be scrolled without losing access to the other section.
2. Open Mars details. Verify statistics use one column, the orbit illustration stacks above the text, and **Route** is reachable by scrolling. Open the preview and verify its text and **Start navigation** and **Close transfer preview** remain reachable within the safe area.

**Reset** by closing the preview, restoring the original text size, and returning Home.

<a name="qa-voiceover"></a>

### QA-VOICEOVER · Screen-reader navigation and details escape

**Start** on Home at default text size with VoiceOver enabled.

1. Navigate by swiping focus. Verify a mission card and a destination card announce their identities. Activate Mars and verify the **Home**, **Legal and credits** and **Object details** actions have understandable announcements.
2. Open details. Verify focus can reach the title, content and **Route** in a sensible order. With focus inside the panel, perform the two-finger scrub escape. Verify the panel closes and the scene controls are reachable again. Reopen details, activate **Route**, and verify **Start navigation** and **Close transfer preview** each announce their purpose. Activate **Close transfer preview** with VoiceOver.

**Reset** by returning Home and restoring the original VoiceOver setting.

<a name="qa-credits"></a>

### QA-CREDITS · Legal credits and external links

**Start** on Home with a working network connection.

1. Open **Legal and credits**. Verify the sheet scrolls from the solar-system textures attribution to the destination thumbnails and each section names its sources.
2. Open the Solar System Textures **License** and one source or usage-terms link from each section. Verify each opens the corresponding external source or license. Return to the app after each link and verify the sheet remains usable. Record the URL and response for a failing link.
3. Dismiss the sheet with the system gesture and verify Home is usable.

**Reset** on Home.

<a name="qa-review"></a>

### QA-REVIEW · Native rating prompt in an Xcode development build

**Start** with a clean development install from the candidate commit. Use two independent clean installs for the two paths, or delete and reinstall on a disposable device between them. Dismiss the system prompt without submitting a rating. [StoreKit test behavior](https://developer.apple.com/documentation/storekit/appstore/requestreview%28in%3A%29)

1. On the first install, let Home settle on the first session. Go to the iOS Home Screen and back, then wait at least three seconds. Verify no prompt in the first two sessions. Open **Legal and credits**, go to the iOS Home Screen and back again, then wait at least three seconds. Verify the third session does not interrupt the sheet. Dismiss it and verify the native prompt appears after about two seconds of stable UI.
2. On the second install, stay in a single foreground session. Start and cancel a mission after it begins running. Verify no prompt after waiting three seconds. Start a second mission and let it run for at least three seconds. Verify no prompt while it is running. Cancel it and verify the native prompt appears after the interface settles.
3. Cross-check automated results for persistence across launches, distinct successful starts, interrupted sessions, failed routes, same-version suppression and the 120-day cooldown in [ReviewRequestCoordinatorTests](../../OptiUniverseTests/ReviewRequestCoordinatorTests.swift). Record that evidence separately in the report's automated checks section.

**Reset** by stopping the development build and restoring the candidate installation if needed. TestFlight suppresses this system UI, so the development build supplies the manual result for this row.

## Device configurations and resizing

Use the iOS 27.1 SDK or later and iOS 27.1 or later on iPhone Duo. Change its display, fold pose and orientation on the device or in Simulator Device Hub. On iPad, use an 11-inch iPad (A16) or an equivalent resizable iPad. Note actual sizes and poses in the report, especially when a native toolbar is vertical or safe areas are asymmetric.

<a name="qa-min-os"></a>

### QA-MIN-OS · iOS 26.0 compatibility smoke

**Start** with the candidate installed on an iPhone or simulator running iOS 26.0.

1. Launch and verify Home is usable. Select Mars and verify the scene renders. Open its details and tap **Route**.
2. Verify the transfer preview becomes usable, **Start navigation** is reachable, and **Close transfer preview** returns to the scene without a crash.

**Reset** on Home.

<a name="qa-pose"></a>

### QA-POSE · Static layout and scene framing

**Start** on Home in the device, display and orientation specified by the checklist row. Test an already configured pose here. Use the resize scenarios for changes while an interaction is in progress.

1. Check that the mission area, page indicator, category chips and first destination row fit or are reachable by scrolling. The layout uses a carousel and horizontal destination row in compact windows, and multiple mission cards and a grid in qualifying wide windows. Check that mission text and destination names remain legible.
2. Select Saturn and wait for the camera to settle. Verify the scene fills the viewport behind the transparent bars and Saturn is centered with details closed. Open details and verify the readable panel and **Route** are within the safe area. Dismiss the panel and verify the scene controls are still reachable. In a Duo pose with asymmetric insets, look for clipped controls on the side with less space.

**Reset** on Home before changing to the next pose.

<a name="qa-resize-home"></a>

### QA-RESIZE-HOME · Discovery state through a layout change

**Start** on Home in a compact window at default text size. Select the Voyager 1 card using the page indicator without starting playback, and select **Rings**.

1. Change to a window wide enough for expanded discovery, then back to compact. On Duo, open to the inner display, rotate and return to the outer display. On iPad, resize from tall or square to wider than tall with at least 600 points of content width, then back.
2. After each change, verify the selected mission and highlighted dot still point to Voyager 1 and the Rings filter still shows Saturn and Uranus. Verify both sections remain reachable and the arrangement changes with the available space. On iPad, a tall or square window uses the compact layout even when its width alone would allow the grid.

**Reset** by clearing the filter, selecting the first mission dot and restoring the original pose.

<a name="qa-resize-info"></a>

### QA-RESIZE-INFO · Object identity and reading position

**Start** on Home in a compact window. Open Saturn details. Make the window short enough to scroll, then scroll into the description and note a visible passage.

1. Keep the panel open and change to a size that uses the trailing panel (at least 700 × 400 points of content, and a wider-than-tall window on iPad). On Duo, include a fold or unfold and a rotation. On iPad, resize across both sides of the breakpoint.
2. Verify the panel moves from bottom to trailing and back, without replacing Saturn or jumping back to the beginning of the text. Allow the scroll position to clamp if the larger panel fits the remaining content. Check the background scene does not restart, and **Route** and dismissal are reachable in each presentation.

**Reset** by dismissing the panel and returning Home in the original pose.

<a name="qa-resize-preview"></a>

### QA-RESIZE-PREVIEW · Transfer preview and toolbar placement

**Start** on Home. Open a ready Mars preview. Adjust the view slightly with a camera gesture so a reset is easy to spot.

1. On Duo, rotate or fold through a pose with the native vertical toolbar and back to a horizontal toolbar. Repeat with the app in both supported Split View positions. On iPad, shrink and expand the window while the preview is open.
2. Verify the same destination, orbital lines and camera viewpoint survive. Expect the projection to adapt to the viewport. Verify **Start navigation** moves into the native bar before **Close transfer preview** when the bar is vertical and returns to the bottom when horizontal. Check each position keeps duration and controls readable and reachable, including beside asymmetric safe-area insets. Tap **Close transfer preview** after resizing.

**Reset** on Home in the original pose.

<a name="qa-resize-mission"></a>

### QA-RESIZE-MISSION · Playback continuity during a display or window change

**Start** on Home in the assigned initial pose. Start Voyager 1 for the longer playback window and wait for its ETA to begin counting down.

1. Note the ETA and displayed phase, then change poses while the replay is still running. On Duo, change between outer and inner, rotate and move between the two Split View positions. If moving between positions requires leaving the app, restart from Home for the second position and test a live resize within each position. On iPad, narrow, shorten and expand the window while the mission plays.
2. Verify the title and scene remain on Voyager 1, the ETA and epoch do not reset, and camera gestures and **Cancel mission** still work. Verify the status and controls stay within the safe area. If the OS backgrounds the app during a transition, allow the same pause as in QA-LIFECYCLE. Cancel before completion.
3. Return Home and start a Mars transfer. Make one display change on Duo or one substantial window resize on iPad while it is running. Verify the destination, moving route marker and ETA survive the change, and **Cancel navigation** is still reachable. Cancel before arrival.

**Reset** on Home in the original pose.

## Conditional diagnostics

Use a disposable device. Before changing its time, record the original time zone, automatic time setting and network state. Install the candidate first, then set the time zone to UTC and disable **Set Automatically** in iOS **Settings → General → Date & Time**. Restore all settings at the end, including after a failure. Record the dates used.

If the device or install source prevents the clock change, use a disposable Xcode development build from the candidate commit. In a scratch copy of `UniverseModuleFactory.swift`, import Foundation and pass a clock through the existing `now` initializer argument. Use `4_134_024_000` for January 1, 2101 or `4_132_987_200` for December 20, 2100.

```swift
UniverseModuleResources(now: {
    UserDefaults.standard.bool(forKey: "OptiQAUseCurrentTime")
        ? Date() : Date(timeIntervalSince1970: 4_134_024_000)
})
```

When the steps call for restoring the current date, pause in the debugger and run `expression -l Swift -- Foundation.UserDefaults.standard.set(true, forKey: "OptiQAUseCurrentTime")`, then resume. Use a fresh diagnostic install for each initial date. Record the clock override as the install type and delete the diagnostic build and scratch copy after the run. If neither setup is available, record `BLOCKED` for a required diagnostic.

<a name="qa-load-error"></a>

### QA-LOAD-ERROR · Startup error and Try Again

**Run when** startup, asset preparation or ephemeris archive loading or coverage changes.

**Start** with the app force-quit. Set the clock to January 1, 2101 at 12:00 UTC, beyond the bundled archive.

1. Open the app. Verify **Unable to Load Universe** with a readable reason and **Try Again**. Tap **Try Again** while still out of range. Verify the error returns and the app remains usable.
2. Restore the clock to the current date in Settings, then return without force-quitting the app. Tap **Try Again**. Verify preparation completes and Home appears.

**Reset** by restoring the original time and network settings and reopening at the current date. Revisit the test date if archive coverage changes.

<a name="qa-preview-error"></a>

### QA-PREVIEW-ERROR · Unsupported arrival date, Retry and Close

**Run when** transfer preview, orbit coverage or preview error handling changes.

**Start** with the app force-quit. Set the clock to December 20, 2100 at 12:00 UTC. The date is inside the archive, but a Mars transfer arrives beyond it.

1. Launch, select Mars and open the preview. Verify the ephemeris coverage error appears with **Retry** and **Close transfer preview**. Verify no successful transfer path or duration is presented. Tap **Retry** and verify the same error returns for Mars.
2. Tap **Close transfer preview**. Verify the error and guide lines clear and the Mars scene is usable. Restore the current date, then open a fresh Mars preview to verify the valid route calculates.

**Reset** by restoring the original time and network settings, closing the preview and returning Home. Revisit the test date if archive coverage changes.

<a name="qa-flight-error"></a>

### QA-FLIGHT-ERROR · Failed start, Retry and Cancel

**Run when** transfer playback, route failure handling or ephemeris coverage changes.

**Start** with the app force-quit. Set the clock to December 20, 2100 at 12:00 UTC, launch, then open the failed Mars preview as setup.

1. Use **Start navigation** from the preview. Verify the route fails with an ephemeris error and **Retry**. Verify no playback countdown or arrival starts. Tap **Retry** and verify the error is still associated with Mars while the clock remains unchanged.
2. Tap **Cancel navigation**. Verify the error and playback controls clear and the scene is usable. Restore the current date, open a fresh Mars preview and verify navigation can reach the running state.

**Reset** by cancelling any running navigation, restoring the original time and network settings, and returning Home. Revisit the test date if archive coverage changes.
