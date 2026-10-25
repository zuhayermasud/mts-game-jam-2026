# ASSETS.md — Art and audio checklist

The quality comes from **consistency**, not from detail. Lock the style guide first, then make every asset to match it.

Legend: 🎨 draw it · 🧪 one greyscale or white sprite, tinted in code · ⚙️ done in code (tween, particles, shader), no art needed

## 0. Style guide (finish this first, day 1)
- [ ] Palette: 4–5 UI and environment colours plus 6 potion colours (R, Y, B, O, G, P). Write down the hex codes.
- [ ] Outline rule: one stroke width and one outline colour, used everywhere.
- [ ] Corner radius and shape language (for example, everything rounded and blobby).
- [ ] Fonts: one display font (logo and titles) and one readable body font. Both free for commercial use.
- [ ] Canvas: 4:5, 720×900, drawn at that size (or at 2× and scaled down evenly).
- [ ] A one-page mockup of the game screen, before any final art.

## 1. Game screen
- [ ] 🎨 Clinic background (kept muted so patients and potions stand out)
- [ ] 🎨 Counter or workbench
- [ ] 🎨 Ingredient critters ×3 (red, yellow, blue blobs). Reuse the face set: idle, squeezed, sweating, cheering. Squash and squirt are ⚙️
- [ ] 🎨 Pot + 🧪 liquid layer, and a burner or flame base under it
- [ ] 🎨 Spoon (circles in the pot while it boils)
- [ ] ⚙️ Flame and bubbles
- [ ] ⚙️ Boil ring: grey weak arc, moving gold band, red warning arc, needle (full circle = boils over)
- [ ] Potion name label under the pot ("Green Potion · Perfect!")
- [ ] 🎨 (on hold) BOTTLE button, shelf with 2 slots, bottle + 🧪 liquid
- [ ] 🎨 Sink built into the workbench
- [ ] 🎨 Recipe poster on the wall (R+Y=O, Y+B=G, R+B=P)
- [ ] 🎨 Recipe book: closed icon and open spread
- [ ] 🎨 Colour icons ×6 (shape per colour, for colour-blind players)

## 2. Patients
- [ ] 🎨 Patient body base ×2–3 silhouettes (🧪 skin tinted to the cure colour)
- [ ] 🎨 Faces: calm, worried, critical, cured (happy), dead
- [ ] 🎨 Boss patient (bigger silhouette)
- [ ] 🎨 "Came back worse" marker (a bandage or patch)
- [ ] Top status card per chair (drawn in code for now): cure icon, ailment, clock bar, status line, red outline for emergencies
- [ ] ⚙️ Lifespan clock bar on the card (green, purple after a borrow, flashing red near 0)
- [ ] ⚙️ Walk in and out, bobbing, cure pop, death fade

## 3. HUD
- [ ] Score
- [ ] Shift number
- [ ] 🧪 Heart icon for lives (×3)
- [ ] Patients cured counter
- [ ] 🎨 Custom cursor

## 4. Menus and screens (all use the shared `Theme`)
- [ ] 🎨 Logo or title wordmark
- [ ] Title screen: Play, Volume, Credits
- [ ] 🎨 Button style: normal, hover, pressed (9-slice)
- [ ] Panel or card style (9-slice)
- [ ] Shift intro card ("Shift 3" plus one line of story)
- [ ] Pause menu (Esc): music and SFX sliders, Resume, Quit
- [ ] 🎨 Star icons: filled and empty
- [ ] Game-over screen: shift reached, cured count, best, Retry
- [ ] Shift 1 hints in the world (arrows or highlights, not text walls)

## 5. Juice (all ⚙️)
- [ ] Screen shake when a patient dies or gets close
- [ ] Bubbles and steam particles on the pot
- [ ] Sparkle burst when a patient is cured
- [ ] Red vignette when any patient drops under 3 s
- [ ] Hover scale-up on everything you can click

## 6. Audio
- [ ] SFX: jar pour, flask clear, bubbling (repeats while boiling), "in the gold" ding, boil-over warning rattle, perfect pull chime, overcooked hiss, pull potion, give potion, cure jingle, weak-cure "meh", patient arrives, emergency alarm, clock warning tick, death, shift start, game over, button click
- [ ] Music: one loop that speeds up or gets more intense as danger rises
- [ ] Theme cue: a distinct "borrowed time" sound when you give a weak potion

## 7. Jam page (itch.io)
- [ ] Cover image 630×500
- [ ] 3–5 screenshots and a GIF
- [ ] Short description and controls
