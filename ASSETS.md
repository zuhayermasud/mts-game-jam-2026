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
- [x] 🎨 Ingredient mushroom patch (`critter.png` + greyscale `critter_cap.png`, tinted red, yellow, blue in code). Squash and the fly-into-the-stump arc are ⚙️
- [x] 🎨 Pot as a hollow tree stump (`pot.png`); the brew colour is drawn in code in the hollow
- [ ] 🧪 Potion blob (`potion_blob.png`, 36×36, rides on the cursor once pulled and flies to a patient; the arc is ⚙️)
- [ ] ⚙️ Flame and bubbles
- [ ] ⚙️ Boil ring: grey weak arc, gold band (same spot for every brew), red arc (pull there = boils over), needle that bounces between the ends with a trail
- [ ] Potion name label under the pot ("Green Potion · Perfect!")
- [ ] 🎨 (on hold) BOTTLE button, shelf with 2 slots, bottle + 🧪 liquid
- [x] Sink: a green slime right of the pot (`slime.png`, 9-frame 32×32 idle strip drawn at 128×128 by `ArtSprite.frames`; click or V empties the pot, flashes the brew colour)
- [ ] 🎨 Recipe poster on the wall (R+Y=O, Y+B=G, R+B=P)
- [ ] 🎨 Recipe book: closed icon and open spread
- [ ] 🎨 Colour icons ×6 (shape per colour, for colour-blind players)

## 2. Patients
- [x] 🎨 Patient bodies: 64 creatures from Hexany's Monster Menagerie (CC0) in `assets/creatures/`, picked at random (🧪 tinted to the cure colour)
- [ ] 🎨 Boss patient (bigger silhouette)
- [ ] 🎨 "Came back worse" marker (a bandage or patch)
- [ ] Top status card per chair (drawn in code for now): cure icon, ailment, clock bar, status line, red outline for emergencies
- [ ] ⚙️ Lifespan clock bar on the card (green, purple after a borrow, flashing red near 0)
- [ ] ⚙️ Walk in and out, bobbing, cure pop, death fade

## 3. HUD
- [ ] Score
- [ ] Shift number
- [ ] 🧪 Heart icon for lives (×3)
- [x] Sound toggle (M key, HUD speaker top right, speaker button in the title and pause menus), saved between sessions. `assets/ui/icon_settings` / `icon_sound_on` / `icon_sound_off` are greyscale 3× copies from the Icons_Essential pack (`tools/extract_icons.py`)
- [ ] Patients cured counter
- [ ] 🎨 Custom cursor

## 4. Menus and screens (all use the shared `Theme`)
- [x] 🎨 Logo or title wordmark (`assets/ui/logo.png`, "Goblin Doctor", shown above the title scroll)
- [x] Title screen: Play, Tutorial, Music (Humble Gift scroll, `assets/ui/`)
- [ ] 🎨 Button style: normal, hover, pressed (9-slice)
- [ ] Panel or card style (9-slice)
- [ ] Shift intro card ("Shift 3" plus one line of story)
- [x] Pause menu (Esc): Continue, Music, Home (Humble Gift panel)
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
- [x] SFX, **placeholder** (synthesized by `tools/synth_sfx.py`, replace by saving a real sound under the same name in `audio/`): pour (`pour`), fire lit (`boil_start`), bubbling metronome (`bubble`, ticks on every beat of the needle), "in the gold" ding (`brew_ready`), boil-over warning rattle (`boil_warning`), boil over (`boil_over`), perfect pull chime (`brew_perfect`, pitch rises with the streak), weak pull pop (`pull`), give potion (`give`), potion splash (`splash`), wrong-potion buzz (`refuse`), heartbeat (`heartbeat`), sink drain (`dump`)
- [ ] SFX still missing: pot full (`pot_full`), cure jingle (`cure`), weak-cure "meh" (`borrow`), patient arrives (`patient_arrive`), emergency alarm (`emergency`), bandaged (`bandaged`), clock warning tick, death (`death`), shift start (`shift_start`), game over (`game_over`), button click
- [ ] Music: one loop that speeds up or gets more intense as danger rises
- [ ] Theme cue: a distinct "borrowed time" sound when you give a weak potion

## 7. Jam page (itch.io)
- [ ] Cover image 630×500
- [ ] 3–5 screenshots and a GIF
- [ ] Short description and controls
