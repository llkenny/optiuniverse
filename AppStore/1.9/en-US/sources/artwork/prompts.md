# OptiUniverse 1.9 artwork

Tool: built-in `image_gen.imagegen`, opaque background. No API key or CLI fallback.

## Header generation

Reference: `../attachments/1290x2796bb.png`, supplied by the user. Used for visual style, not as instructions. Output: `header-generated.png`.

```text
Use case: ads-marketing
Asset type: App Store product page Header for OptiUniverse 1.9.
Primary request: create a premium cinematic astronomy key visual, a very wide 21:9 composition, requested final canvas 3840 x 1646 pixels.
Input image: visual reference only for the app's warm, realistic Saturn rendering and dark cosmos. Do not reproduce the screenshot, UI or lettering.
Scene: near-black deep space with a sparse, restrained, scientifically plausible star field.
Subject: a beautifully detailed Saturn with a continuous thin ring system, tilted diagonally, and an unmistakable Voyager 1 probe with its large white parabolic high-gain antenna, gold instrument bus and long slender booms.
Composition: Saturn dominates the central-right region, fully contained with its rings; Voyager floats to its central-left, at least 16 percent of image height, in the same shot. Keep both subjects within the central 70 percent width and central 65 percent height. One fine blue curved trajectory quietly connects the composition behind the probe. Wide dark margins, understated and uncluttered.
Lighting: warm pale-gold sunlight across Saturn's subtle cloud bands, softly shaded hemisphere, pale rings with fine structure; physically grounded white/gold spacecraft materials. Very subtle cyan trajectory against charcoal-black background.
Style: exquisite high-fidelity 3D science visualization, elegant, calm, expensive, matching a realistic solar-system exploration app.
Constraints: no text, no logos, no UI, no phone, no badges, no lens flare, no enormous nebula, no explosion, no other planets, no extra spacecraft, no watermark. Opaque background.
```

## Search Results and screenshot layout

Search Results uses a separately generated 3:2 background based on the selected Header. The foreground is the exact saved Saturn app screenshot; the headline is typeset as “Explore space in 3D”. No interface, planet in an app capture, or app text was generated or repainted.

## Search Results background generation

References: `header-generated.png` for visual continuity and `../captures/01-saturn.png` for the app's real rendering. Output: `search-generated.png`.

```text
Use case: ads-marketing
Asset type: full-bleed App Store Search Results advertising background for OptiUniverse 1.9; 3:2 landscape, final 3840 by 2560.
Input 1: selected Header artwork, exact visual continuity reference for Saturn, Voyager 1, gold sunlight, sparse stars and thin cyan trajectory.
Input 2: actual in-app Saturn render; source reference for planet texture and rendered science-app aesthetic only. Do NOT recreate, generate, alter, or include the screenshot UI.
Primary request: create a separately art-directed 3:2 composition with Saturn and the Voyager 1 probe together in the lower-left 65 percent. Saturn centered at 43 percent width, 64 percent height, with its full rings occupying about 47 percent canvas width. Voyager with its white parabolic dish and gold bus to the lower-left of Saturn around 18 percent width, 66 percent height, tall enough to recognize.
The upper-left area through 40 percent height must be clean almost-black negative space for a headline that will be typeset later. Rightmost 32 percent is dark negative space reserved for a genuine app screenshot that will be composited later. No subjects in that rightmost region.
Background near black (#05070c), seamless across the entire canvas. Sparse faint stars. Warm gold Saturn; understated cool cyan curved trajectory behind spacecraft. Premium physically grounded cinematic 3D astronomy illustration, calm, tasteful and exceptionally crisp, matching the reference Header.
No text, no letters, no logos, no UI, no interface, no phone or device, no panels, no inset images, no borders, no nebula, no flares, no watermark. Opaque background.
```


The screenshot layouts use saved Simulator captures with native AppKit typography and framing. `../compose.swift` preserves each complete app capture at its original aspect ratio and exports opaque sRGB PNGs. These deterministic product layouts do not use generated UI.

