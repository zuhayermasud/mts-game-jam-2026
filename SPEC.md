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
A doctor runs a busy potion clinic. Patients arrive with lifespan clocks ticking down. Up to three patients sit at once and all their clocks tick. You brew in **one pot**: pour colours in and it **boils by itself**; **left-click anywhere when the needle is inside the gold band** on the ring, then **right-click a patient** to give it to them. The band lands in a random spot every brew and gets smaller on later shifts. Pull it early or late and you get a weak potion, which buys a patient **borrowed time** (+10 s, then less each time: borrowing has interest). Forget it and it boils over. A patient who runs out of borrowed time comes back later, worse.

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
- **Right-click a patient to serve them** the brew in the pot. There is no GIVE button. If the pot is still boiling, the right-click pulls it at that moment and serves it, in one click. A left click on a patient just pulls the pot, like a left click anywhere else. Once pulled, the brew rides on the cursor as a tinted blob. Serving throws it from the cursor to the patient, who reacts when it lands (the outcome is decided on the click). A wrong potion bounces back to the cursor.
- **A patient's skin colour is their cure.** Bandaged patients show their bandage.
- **Top status bar:** one card per open chair, directly above it, showing the cure colour (icon and name), the ailment, a clock bar with seconds, and a status line (`Weak dose: +10s`, `EMERGENCY`, `Borrowed ×N · next +Xs`, `Bandaged · next +Xs`, then `Cured!` / `Back later, worse` / `Lost` as they leave). The bar is green, purple once they've borrowed, and flashes red under the critical threshold. A card's outline glows gold when the pot holds a set brew that's that patient's cure, and is red for an emergency patient. Empty chairs say "Next patient…".
- Tiers: **primary** (1 colour), **secondary** (2 primaries: orange, green, purple), **boss** (two potions served in order; the bubble shows both).
- Each shift has a **finite, hidden list** of patients. The total is never shown, and the queue just shrinks at the end.

### Brewing
- **One pot** on the counter. Critters pour into it and right-clicking a patient serves from it.
- **Ingredients are 3 living critters** (red, yellow, blue blobs) on the counter. Click one to squeeze it and it squirts its colour into the pot.
  - Fallback skins if the critters don't work: crystals or orbs, or plain potion bottles. The logic is identical, so only the art changes.
- **Pours are instant.** The colour lands in the pot on the click. Squeeze and squirt animations are cosmetic and **never block input**, so you can click twice in quick succession.
- **Auto boil.** Every pour starts the boil from zero: the spoon circles, the pot wobbles and steams, and a needle **sweeps** along the ring by itself (3.2 s from the start to the red end), **bounces back** off the red end, sweeps back to the start and bounces again, passing the same zones on every sweep. The ring has a gap at the top so you can see both ends. The needle is a dot with a short trail, not a clock filling up. **Left-click anywhere to pull the brew** and lock its quality in (anywhere except a critter, which pours instead). You never have to move the mouse back to the pot.
- **The gold band (perfect)** starts at a **random spot** between 0.8 s and 2.4 s along the sweep, **rolled fresh on every pour**, and the needle passes it again on every sweep. On shift 1 it's 0.5 s wide for primaries and 0.4 s for secondaries; it narrows 0.06 s per shift (never under 0.2 s). It always ends before the red section. Entering it plays a ding.
- Clicking **under 0.4 s** does nothing (still raw). Pulling on **grey before the band** (first sweep) gives a weak brew. On grey **after the band has gone by** (including on the way back) it's weak and marked *Overcooked*. A miss still buys time, or you can wait for the needle to come back through the gold.
- **Red section:** the far end of the ring (the last 0.6 s of the sweep) is red; the needle bounces off it. Entering it plays a warning sound, the pot rattles hard and the ring flashes. **Pulling in the red boils the pot over.**
- **Boil over:** left alone, the pot boils over at the end of **sweep 3** (out, back, out). Pips beside the ring count the sweeps left; on the last sweep they turn red and the pot rattles. Boiling over empties the pot with a shake and a "Boiled over!" toast. You lose the ingredients and the time, never the run.
- **Pouring resets the brew** (even a set one) and re-rolls the band.
- The ring shows a grey weak arc, the gold band, the red warning arc, and a needle dot with a short trail. A label under the pot reads "Squeeze a critter", "Heating…", "Pull in the gold!" / "Not in the red!" while boiling, then for example "Green Potion · Perfect!" / "· Weak" / "· Overcooked".
- Why: a timing skill on every brew (the band moves, so you have to watch the pot), while the pot keeps boiling when your attention is on the patients.
- Pour results: 1 pour = that primary. Same colour twice = that primary. Two different primaries = their secondary. A third pour is blocked, with a "full" sound.
- Two actions when a brew is ready:
  - **Right-click a patient** to serve it to them (this also pulls a boiling pot).
  - **BOTTLE** pours it into a bottle on the **2-slot shelf** beside the pot. Bottling stops the cooking and freezes the quality. Bottles never decay.
- Click a bottle on the shelf to serve it. This is how you brew ahead for waiting patients and bosses.
- **Dumping:** right-click the pot or a bottle, or click the sink (no toolbar).
- Bottles and the shelf are on hold.

### Borrowing time (the theme mechanic)
1. Serving a **weak** potion gives that patient **borrowed time**, and they stay in the chair. With several clocks running, a quick weak dose is how you stabilise one patient while you perfect another's cure. Borrowing also works as insurance: a patient who has borrowed doesn't die at 0, they get bandaged.
2. Cure them properly within that time and they leave happy, with no debt.
3. If the time runs out, they **don't die**. They leave with a **bandage** and rejoin the queue later, one tier harder (primary → secondary → boss; a boss gets a shorter clock instead).
4. **Borrowing has interest.** Every weak dose is accepted, but each buys less: **+10 s, then +6 s, then +3 s**, and +3 s after that (`borrow_steps`). The card shows the next loan. The count follows a bandaged patient back. A patient who never borrowed, or who is bandaged, **dies** at 0.
- A weak potion given to a boss buys time but doesn't count toward their two potions.
- No global debt meter. The cascade comes from bandaged patients filling up the queue.

### Mistakes
- **Wrong potion served:** the patient refuses (grimace and "ugh" sound) and their clock loses **2 s**. The potion bounces back to the cursor (it stays in the pot), so you can still give it to the right patient.

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
| Shift | Chairs | Patients | Clock | Emergencies | Mix |
|---|---|---|---|---|---|
| 1 | 1 | 4 | 22 s | 0% | primaries only |
| 2 | 2 | 6 | 18 s | 15% | + secondaries |
| 3 | 3 | 7 | 15 s | 25% | + 1 boss |
| 4 | 3 | 8 | 13 s | 30% | more secondaries, 2 bosses |
| 5+ | 3 | +1 each | −1 s each (floor 10 s) | 30% | weighted to bosses |

Patients sit down 1.5 s apart. Clocks are tight on purpose: perfecting every patient shouldn't be possible, so weak doses (+10 s, then less) are how you stay afloat.

### Emergencies
- Each patient in a shift has a chance (table above) to be an **emergency**: they arrive on a **7 s clock**, with a red card outline, an `EMERGENCY` status line, an "Emergency!" toast and the `emergency` sound.
- 7 s is tight for a perfect brew (up to ~3 s of boiling plus pouring), so an emergency usually needs a weak dose first.
- If an emergency patient runs out of borrowed time, they come back bandaged on a normal clock (no longer an emergency).
All of these live in one config resource.

### Story
- Light touch. The setting is undecided for now (the earlier alien sci-fi idea is shelved because the art would be too much work).
- Shift cards show one funny line each. Patients have silly ailments, shown on their status cards.

### Screens and controls
- **Mouse only.** Left click pours (on a critter) or pulls the pot (anywhere else). Right click serves (on a patient) or dumps (on the pot). No dragging.
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
- **Done (2026-10-24):** two pots on ON/OFF burner switches (click a pot to select it), longer perfect boil, tighter clocks, emergency patients.
- **Done (2026-10-25):** one pot again: hold to stir, let go in a gold band that moves every pour (narrower for secondaries), overcooked and boil-over warning, borrowing with interest (+10/+6/+3 s).
- **Done (2026-10-25):** hold-to-stir replaced by auto boil and click-to-pull; the gold band lands anywhere from 1–3 s, starts smaller (0.5 s / 0.4 s) and shrinks 0.06 s per shift. Waiting on a playtest: the band should feel readable, early/late pulls should land weak, and three chairs on shift 3 should be manageable with loans.
- **Done (2026-10-26):** handover polish: the potion flies from the pot to the patient, clicking a patient pulls a boiling pot and serves it in one click, and a wrong potion bounces back into the pot (−2 s).
- **Done (2026-10-26):** the needle loops (3.2 s a lap) instead of filling the ring like a clock: pulling in the red boils over, and the pot boils over by itself after 3 laps.
- **Done (2026-10-26):** left-click anywhere pulls the pot; right-click a patient serves them.
- **Done (2026-10-26):** the needle bounces back and forth between the start and the red end instead of looping (gap at the top of the ring). A pulled brew rides on the cursor.
- **Next:** sink, bosses, recipe poster and book, then title, pause and shift cards.
- Audio is waiting on the user to choose a sound-generator project.

## Nice to have (only once the MVP is done)
- Fancier overcooking effects (smoke, fire)
- More patient body silhouettes
- Patient-specific quirks (impatient, needs a double dose)
