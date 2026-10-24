# SPEC.md — Borrowed Medicine (working title)

The full game design spec. Read it before working on gameplay, UI or art.

Jam entry for MTS Game Jam 2026, theme **"Borrowed Time"**. The brief and judging criteria are in `README.md`. The art and audio checklist is in `ASSETS.md`.

## Roles
- **User:** graphic designer (Illustrator). Owns all visual art. Third-party assets are allowed.
- **Claude:** all GDScript code. Audio comes later, from a generator project the user will pick.

## Constraints
- Solo dev with Claude. **Deadline: 2026-10-30.** We started on 2026-10-23.
- **Godot 4, 2D, GDScript only** (C# can't export to web). Target: **HTML5 on itch.io**, played with a mouse. **4:5, 720×900** (itch embed 640×800 with a fullscreen button). Chosen over 9:16 phone portrait so the whole game fits on a laptop screen with the page description visible below it.
- Godot isn't installed on this machine yet. Install the standard Godot 4.x build, not .NET.

## Pitch
A doctor runs a busy potion clinic. Patients arrive with lifespan clocks ticking down. Up to three patients sit at once and all their clocks tick. You pour colours into the pot and **hold it to boil**. Boil it a moment and you get a weak potion, which buys a patient **+10 s of borrowed time**. Boil it longer for the perfect cure, but don't overdo it or it boils over. A patient who runs out of borrowed time comes back later, worse.

## Visual reference
- Heavily inspired by **Miracle Merchant** (Tiny Touch Tales):
  - a single large customer framed in a detailed, illustrated shop
  - symbol speech bubbles
  - one hero bottle in the middle of the counter, with a name label under it
  - ingredients as cards along the bottom
  - thick outlines and saturated colours
  - small HUD in the corners
- We differ by being **real-time**, with brewing and borrowing time. Miracle Merchant is turn-based cards.

## Core rules (locked)

### Patients
- **Up to 3 chairs, all clocks tick at once.** Chairs open per shift (1, then 2, then 3). Patients sit down one at a time, a short gap apart, whenever a chair is free.
- **Click a patient to serve them** the brew in the pot. There is no GIVE button.
- **A patient's skin colour is their cure.** Bandaged patients show their bandage.
- **Top status bar:** one card per open chair, directly above it, showing the cure colour (icon and name), the ailment, a clock bar with seconds, and a status line (`Weak dose: +10s`, `Borrowed time`, `Bandaged · last chance`, then `Cured!` / `Back later, worse` / `Lost` as they leave). The bar is green, purple once they've borrowed, and flashes red under the critical threshold. A card's outline glows gold when the pot holds a servable brew that's that patient's cure. Empty chairs say "Next patient…".
- Tiers: **primary** (1 colour), **secondary** (2 primaries: orange, green, purple), **boss** (two potions served in order; the bubble shows both).
- Each shift has a **finite, hidden list** of patients. The total is never shown, and the queue just shrinks at the end.

### Brewing
- **One hero pot** in the middle of the counter. There is no second burner.
- **Ingredients are 3 living critters** (red, yellow, blue blobs) on the counter. Click one to squeeze it and it squirts its colour into the pot.
  - Fallback skins if the critters don't work: crystals or orbs, or plain potion bottles. The logic is identical, so only the art changes.
- **Pours are instant.** The colour lands in the pot on the click. Squeeze and squirt animations are cosmetic and **never block input**, so you can click twice in quick succession.
- **Hold the pot to boil it** (left button down on the pot; let go anywhere to stop). Heat only rises while you hold, so a released pot waits safely while you deal with patients. **Pouring resets the heat.**
- Heat timeline (seconds held): **under 0.25 s raw** (can't be served), **0.25–1.2 s weak**, **1.2–1.8 s perfect**, **1.8 s boils over**: the pot empties itself with a shake and a "Boiled over!" toast. You can tap to creep into the perfect band safely, or hold it in one go to save time.
- A ring around the pot fills with heat: raw, weak (grey), perfect (gold, glowing), and a full circle means it boils over. The pot wobbles and steams while boiling. A label under the pot names the brew (for example "Green Potion · Perfect!").
- Pour results: 1 pour = that primary. Same colour twice = that primary. Two different primaries = their secondary. A third pour is blocked, with a "full" sound.
- Two actions when a brew is ready:
  - **Click a patient** to serve it to them.
  - **BOTTLE** pours it into a bottle on the **2-slot shelf** beside the pot. Bottling stops the cooking and freezes the quality. Bottles never decay.
- Click a bottle on the shelf to serve it. This is how you brew ahead for waiting patients and bosses.
- **Dumping:** right-click the pot or a bottle, or click the sink (no toolbar).

### Borrowing time (the theme mechanic)
1. Serving a **weak** potion gives that patient **+10 s**, and they stay in the chair. With several clocks running, a quick weak dose is how you stabilise one patient while you perfect another's cure. Borrowing also works as insurance: a patient who has borrowed doesn't die at 0, they get bandaged.
2. Cure them properly within that time and they leave happy, with no debt.
3. If the time runs out, they **don't die**. They leave with a **bandage** and rejoin the queue later, one tier harder (primary → secondary → boss; a boss gets a shorter clock instead).
4. **Borrow once per patient.** A second weak potion is refused and **stays in the pot** (nothing lost). A patient who never borrowed, or who is bandaged, **dies** at 0.
- A weak potion given to a boss buys time but doesn't count toward their two potions.
- No global debt meter. The cascade comes from bandaged patients filling up the queue.

### Mistakes
- **Wrong potion served:** the patient refuses (grimace and "ugh" sound), the potion is wasted, and their clock loses **2 s**.

### Teaching
- A **recipe poster on the clinic wall** (R+Y=O, Y+B=G, R+B=P, with icons), plus a **recipe book you can open** for the full chart. Time keeps running while it's open.
- Shift 1 teaches through play: primaries only, generous clocks.

### Run structure and scoring
- **Endless shifts.** A shift ends when its list is cleared. There's no shift timer.
- **3 lives** (hearts at the top). A patient dying costs one heart, with a screen shake. **The run ends when the last heart goes.**
- Score per cure: **perfect +100**, **cured after a borrow +50**, plus a bonus for clock time left. A wrong serve costs −25.
- **Stars per shift** (shown on the next shift card): ★★★ no borrows and no wrong serves, ★★ no more than 2 borrows, ★ survived.
- Game-over screen: **"You made it to Shift N"**, score, patients cured, borrows, and your best (saved locally). Retry is one click.

### Difficulty (starting values, tune after the prototype)
| Shift | Chairs | Patients | Clock | Mix |
|---|---|---|---|---|
| 1 | 1 | 4 | 25 s | primaries only |
| 2 | 2 | 6 | 24 s | + secondaries |
| 3 | 3 | 7 | 22 s | + 1 boss |
| 4 | 3 | 8 | 20 s | more secondaries, 2 bosses |
| 5+ | 3 | +1 each | −1 s each (floor 12 s) | weighted to bosses |

Clocks are longer than a one-at-a-time design would need because every seated clock ticks at once.
All of these live in one config resource.

### Story
- Light touch. The setting is undecided for now (the earlier alien sci-fi idea is shelved because the art would be too much work).
- Shift cards show one funny line each. Patients have silly ailments, shown on their status cards.

### Screens and controls
- **Mouse only**, left click (plus right-click as a dump shortcut). No dragging.
- Title screen: Play, Volume, Credits.
- **Esc pauses the game.** The pause menu has music and SFX volume, Resume, and Quit to title.
- Shift intro card: shift number, stars from the last shift, one flavour line.

## Art pipeline (user draws in Illustrator)
- **Three levels of detail.** The static background gets the most detail. Hero objects (active patient, pot, critters) get medium detail with strong silhouettes. Repeated things and UI (bubbles, bottles, icons, buttons) stay simple and bold.
- **Colour hierarchy.** Only gameplay objects use the 6 saturated potion colours. The background is a dark, desaturated palette (muted purples and teal-greys).
- **Export.** One 720×900 artboard, exported as **2× PNG**. Each moving part is its own file. Anything tinted in code is drawn white or greyscale.
- **Naming.** Use snake_case, for example `patient_body_a.png`, `face_worried.png`, `critter_red.png`. Files go in `assets/` and replace grey-box placeholders with the same name.
- **Patients.** 2 body silhouettes + 1 boss body, plus one shared set of faces: calm, worried, critical, cured, dead.
- Outside assets are fine for fonts, filler icons and background props. Patients, critters and the pot are drawn by the user.

## Status and next step
- The design is complete as of 2026-10-23. The day-by-day checklist lives in the user's Obsidian note `2026 Mts Gamejam.md`.
- **Done (2026-10-23):** the Godot 4 project and the grey-box core loop (critter pour → pot boil and quality ring → GIVE → active patient clock, borrow, bandage and rebook, death and game over, shifts and score). Numbers are in `config/game_config.tres`, and art swaps by file name (`assets/README.md`). Smoke test: `godot --headless res://tests/smoke_test.tscn`.
- **Done (2026-10-24):** redesign: hold-to-boil pot with boil-over, 3 chairs whose clocks all tick, click a patient to serve, top status cards, 3 lives.
- **Next:** BOTTLE and the 2-slot shelf, sink, bosses, recipe poster and book, then title, pause and shift cards.
- Audio is waiting on the user to choose a sound-generator project.

## Nice to have (only once the MVP is done)
- Fancier overcooking effects (smoke, fire)
- More patient body silhouettes
- Patient-specific quirks (impatient, needs a double dose)
