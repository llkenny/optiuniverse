# Third-Party Notices

This file tracks attribution and release-review source material for assets bundled with OptiUniverse. Keep it in sync with the in-app Legal & Credits screen before each release.

## N1 Loading Scene

- Original asset: `OptiUniverse/Resources/LaunchScene/n1-original.jpg` (916 × 1500, unmodified download).
- Title: N1 1M1 mockup on the launch pad at the Baikonur Cosmodrome in late 1967.
- Credit: National Reconnaissance Office, via NASA and Wikimedia Commons, as identified by those sources.
- File/source and usage information: https://commons.wikimedia.org/wiki/File:N1_1M1_mockup_on_the_launch_pad_at_the_Baikonur_Cosmodrome_in_late_1967.jpg
- Historical context: https://www.nasa.gov/history/50-years-ago-soviets-moon-rockets-rollout-to-pad-affects-apollo-plans/
- Status: Wikimedia Commons identifies this specific file as released into the public domain in the United States under its PD-US-NRO notice. This records the source's statement, not a blanket claim about Soviet imagery or worldwide status.
- Changes: `n1-rocket.png` is a transparent photo-derived cutout with AI-assisted extraction and removal of people at the base. `vfx_scripts/n1_launch_reference/n1-clean-pad.png` reconstructs the area behind the rocket; `n1-surroundings.png` extends that plate into the single continuous runtime background. The source photograph remains unmodified; the derived layers are retouched interpretations. The derived images are not newly recovered historical detail. `n1-vapor.png` and `n1-exhaust.png` are generated transparent textures, downsampled for runtime use.
- Generation: Built-in ImageGen; prompts are saved in `vfx_scripts/n1_launch_prompts.json`. No runtime network access or generated machine-specific paths are required.
- App use: Illustrative startup animation of the test vehicle lifting off; not footage or a factual reconstruction of a historical flight. No endorsement is implied.

## Solar System Textures

- Asset: `Modules/UniverseModule/Sources/UniverseModule/Assets/Models/*.usdz`
- Title: "Solar Textures"
- Creator: solarsystemscope
- Source: https://www.solarsystemscope.com/textures/
- License: Creative Commons Attribution 4.0 International
- License URL: https://creativecommons.org/licenses/by/4.0/
- App use: Converted and optimized for use in OptiUniverse.

## Milky Way Environment Texture

- Asset: `Modules/UniverseModule/Sources/UniverseModule/Assets/Environment/milky_way_environment.jpg`
- Title: The Milky Way panorama
- Credit: ESO/S. Brunier
- Source: https://www.eso.org/public/images/eso0932a/
- License: Creative Commons Attribution 4.0 International
- License URL: https://creativecommons.org/licenses/by/4.0/
- App use: Equirectangular deep-space background for the live RealityKit scene.

## NASA, ESA, STScI, and JPL Imagery

NASA content is generally available for educational or informational uses when used factually and without implying endorsement. NASA should be acknowledged as a source, and NASA logos, insignia, identifiers, or protected third-party materials should not be used unless separately cleared.

- NASA media guidelines: https://www.nasa.gov/nasa-brand-center/images-and-media/
- ESA/Hubble image use information: https://esahubble.org/copyright/
- ESA/Hubble image archive: https://esahubble.org/images/
- NASA/JPL image archive: https://www.jpl.nasa.gov/images/

### Bundled Featured Images

- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Mars/Mars_1.imageset/opo0124a.jpg`
  - Source: https://esahubble.org/images/opo0124a/
  - Credit: NASA/ESA and The Hubble Heritage Team STScI/AURA
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Neptune/Neptune_1.imageset/opo1622b.jpg`
  - Source: https://esahubble.org/images/opo1622b/
  - Credit: NASA, ESA, and source parties listed on the source page
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Neptune/Neptune_2.imageset/opo2059a.jpg`
  - Source: https://esahubble.org/images/opo2059a/
  - Credit: NASA, ESA, STScI, and source parties listed on the source page
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Saturn/Saturn_1.imageset/heic0904e.jpg`
  - Source: https://esahubble.org/images/heic0904e/
  - Credit: NASA, ESA and the Hubble Heritage Team (STScI/AURA)
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Saturn/Saturn_2.imageset/opo0418a.jpg`
  - Source: https://esahubble.org/images/opo0418a/
  - Credit: NASA, ESA and E. Karkoschka (University of Arizona)
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Saturn/Saturn_3.imageset/heic1917a.jpg`
  - Source: https://esahubble.org/images/heic1917a/
  - Credit: NASA, ESA, A. Simon (GSFC), M.H. Wong (University of California, Berkeley), and the OPAL Team
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Saturn/Jupiter_1.imageset/PIA03451.jpg`
  - Source: https://science.nasa.gov/image-detail/amf-f99593ed-7430-4b17-bad5-9245cc073ac9/
  - Credit: NASA

### Bundled Destination Thumbnails

- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Sun.imageset/dst-Sun.jpg`
  - Title: Pulses from the Sun
  - Source: https://science.nasa.gov/photojournal/pulses-from-the-sun/
  - Credit: NASA/SDO/AIA
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Mercury.imageset/dst-Mercury.jpg`
  - Title: Outgoing Hemisphere
  - Source: https://science.nasa.gov/photojournal/outgoing-hemisphere/
  - Credit: NASA/JPL/Northwestern University
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Venus.imageset/dst-Venus.jpg`
  - Title: Venus Cloud Tops Viewed by Hubble
  - Source: https://science.nasa.gov/resource/venus-cloud-tops-viewed-by-hubble/
  - Credit: L. Esposito (University of Colorado, Boulder), and NASA/ESA
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Earth.imageset/dst-Earth.jpg`
  - Title: Earth from Space
  - Source: https://commons.wikimedia.org/wiki/File:Earth_from_Space.jpg
  - Original source: http://earthobservatory.nasa.gov/IOTD/view.php?id=885
  - Credit: NASA/GSFC/Reto Stockli, Nazmi El Saleous, and Marit Jentoft-Nilsen
  - License: Public domain in the United States as a NASA-created work, per the Wikimedia Commons file page
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Moon.imageset/dst-Moon.jpg`
  - Title: Full moon
  - Source: https://commons.wikimedia.org/wiki/File:Full_moon.jpeg
  - Original source: http://photojournal.jpl.nasa.gov/catalog/PIA00405
  - Credit: NASA/JPL/USGS
  - License: Public domain in the United States as a NASA-created work, per the Wikimedia Commons file page
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Mars.imageset/dst-Mars.jpg`
  - Title: The best Earth-based view of Mars ever
  - Source: https://esahubble.org/images/opo0124a/
  - Credit: NASA/ESA and The Hubble Heritage Team STScI/AURA
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Jupiter.imageset/dst-Jupiter.jpg`
  - Title: Hubble's View of Jupiter and Europa in August 2020
  - Source: https://esahubble.org/images/heic2017a/
  - Credit: NASA, ESA, A. Simon (Goddard Space Flight Center), M. H. Wong (University of California, Berkeley), and the OPAL team
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Saturn.imageset/dst-Saturn.jpg`
  - Title: Latest Saturn Portrait
  - Source: https://esahubble.org/images/heic1917a/
  - Credit: NASA, ESA, A. Simon (Goddard Space Flight Center), and M.H. Wong (University of California, Berkeley)
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Uranus.imageset/dst-Uranus.jpg`
  - Title: Adding to Uranus's legacy
  - Source: https://esahubble.org/images/potw1906a/
  - Credit: NASA, ESA, A.A. Simon (NASA Goddard), and M.H. Wong and A.I. Hsu (University of California, Berkeley)
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Neptune.imageset/dst-Neptune.jpg`
  - Title: Neptune's Curious Dark Spots
  - Source: https://esahubble.org/images/opo2059a/
  - Credit: NASA, ESA, STScI, M.H. Wong (University of California, Berkeley), L.A. Sromovsky, and P.M. Fry (University of Wisconsin-Madison)
- `OptiUniverse/Resources/Resources.xcassets/Destination Objects/dst-Pluto.imageset/dst-Pluto.jpg`
  - Title: Pluto Facts
  - Source: https://science.nasa.gov/dwarf-planets/pluto/facts/
  - Credit: NASA/JHUAPL/SwRI
  
  
## Moon Base images
NASA media resources related to the Moon Base
https://www.nasa.gov/moonbase-media-resources/

- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Moon Base/Moon_Base_3.imageset/Moon_Base_3.png`
  - Title: Concept for Sustained Lunar Surface Operations at the Moon Base
  - Source: https://www.nasa.gov/image-detail/stmd-exteriorlunarbase-hdlandscapeversion-2026-0521/
  - Credit: NASA
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Moon Base/Moon_Base_4.imageset/dst-Moon_Base.png`
  - Title: Lunar South Pole Region
  - Source: https://www.nasa.gov/image-detail/moon-background/
  - Credit: NASA
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Moon Base/Moon_Base_1.imageset/Moon_Base_1.png`
  - Title: Concept for Base at the Lunar South Pole
  - Source: https://www.nasa.gov/image-detail/liveenable-im4-craterlogistics-1/
  - Credit: NASA
- `OptiUniverse/Resources/Resources.xcassets/Featured Objects/Moon Base/Moon_Base_2.imageset/Moon_Base_2.png`
  - Title: Concept for Lunar Surface Logistics and Infrastructure
  - Source: https://www.nasa.gov/image-detail/liveenable-im3-sustainabilitylogistics-withastros-3/
  - Credit: NASA

## In-App Disclaimer

OptiUniverse includes this disclaimer in Legal & Credits:

> Planet imagery is courtesy of NASA, ESA, STScI, JPL, and listed source agencies. NASA does not endorse this app.
