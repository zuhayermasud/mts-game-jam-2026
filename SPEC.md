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
A doctor runs a busy potion clinic. Patients arrive with lifespan clocks ticking down. Up to three patients sit at once and all their clocks tick. You brew in **one pot**: pour colours in and it **lights itself and boils by itself**; **left-click anywhere when the needle is inside the gold band** on the bar under the pot, then **click a patient** to give it to them. Everything is left-click. The needle keeps a steady beat you can hear, the band sits in the same spot for every brew, and it gets smaller for secondaries and on later shifts. A **sink** beside the pot empties it at any time. Pull it early or late and you get a weak potion, which buys a patient **borrowed time** (+10 s, then less each time: borrowing has interest). Pull it in the red and it boils over. A patient who runs out of borrowed time comes back later, worse.

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
- **Click a patient to serve them** the brew in the pot. There is no GIVE button. If the pot is still boiling, the click pulls it at that moment and serves it, in one click. If it's still heating (the count-in, or raw), the click just says "Still heating…": a click on a patient always means serve. Once pulled, the brew hops out of the pot's mouth up to the cursor (0.12 s) and rides there as a tinted blob. Serving throws it from wherever it is to the patient, so a one-click serve visibly throws from the pot. The patient reacts when it lands (the outcome is decided on the click). A wrong potion bounces back to the cursor.
- **A patient's skin colour is their cure.** Bandaged patients show their bandage.
- **Status bar:** one wooden progress bar per open chair, directly under the patient (`assets/ui/bar_frame_wood.png`, from the Pixel ProgressBars pack, 3× pixels). The fill is the cure colour, which is how the player reads the need. It starts **half full** and drains with the clock; a cure fills it to full as they leave. Under it are the seconds left and a status line (`Weak dose: +10s`, `EMERGENCY`, `Borrowed ×N · next +Xs`, `Bandaged · next +Xs`, then `Cured!` / `Back later, worse` / `Lost` as they leave). A halo glows gold around the bar when the pot holds a set brew that's that patient's cure, is red for an emergency patient, and flashes red under the critical threshold. Empty chairs show a faded empty frame and "Next patient…".
- Tiers: **primary** (1 colour), **secondary** (2 primaries: orange, green, purple), **boss** (two potions served in order; the bubble shows both).
- Each shift has a **finite, hidden list** of patients. The total is never shown, and the queue just shrinks at the end.

### Brewing
- **One pot** on the counter, drawn as a hollow tree stump (160 px); the brew colour shows in the hollow. Critters pour into it and clicking a patient serves from it.
- **Ingredients are 3 mushroom patches** (red, yellow, blue caps, one greyscale sprite tinted in code) on the counter. Click one to pick it: the colour lands in the pot instantly, and a mushroom spins along a curve into the stump as cosmetic juice.
  - Fallback skins if the critters don't work: crystals or orbs, or plain potion bottles. The logic is identical, so only the art changes.
- **Pours are instant.** The colour lands in the pot on the click. Squeeze and squirt animations are cosmetic and **never block input**, so you can click twice in quick succession.
- **Auto count-in, then auto boil.** Every pour resets the brew and puts the fire out: the needle sits at the start and the label says "Heating…". **0.4 s after the last pour the fire lights itself** (`boil_delay`), with the `boil_start` whoosh. A second pour inside that window restarts the count-in, so two-colour brews are safe. There is no light click. Once lit, the boil runs from zero: the pot wobbles and steams, and a needle **sweeps** along the bar under the pot by itself at a **constant speed** (**1.6 s** from the start to the red end), **bounces back** off the red end, sweeps back to the start and bounces again, passing the same zones on every sweep at the same timing.
- **Needle speed.** All the brewing times here are in needle seconds; `needle_speed` (1.15) runs the needle that much faster than real time, so a sweep takes about 1.4 s.
- **The bubble is the metronome.** The `bubble` sound ticks every time the needle crosses a 0.4 s beat (`beat`), in both directions: 4 ticks a sweep. The boil starting is beat 1, and the primary gold band starts on beat 3, so the perfect pull can be learned by ear. The bar runs left (start) to right (red end), so both ends are visible. The needle is a tick with a short trail, not a bar filling up. **Left-click anywhere to pull the brew** and lock its quality in (anywhere except a critter, which pours instead). You never have to move the mouse back to the pot.
- **The gold band (perfect)** sits at **one fixed spot for every brew**: 0.8 s along the sweep (`band_start`, the third beat), so adding a second colour never moves it. The needle passes it again on every sweep. On shift 1 it's 0.25 s wide for primaries and 0.2 s for secondaries; it narrows 0.03 s per shift (never under 0.1 s). It always ends before the red section. Entering it plays a ding.
- **Hidden grace.** A pull counts as perfect a little outside the drawn band: 0.03 s early (`band_grace_early`) and 0.07 s late (`band_grace_late`), "late" being the way the needle is travelling. It's wider late because browser audio lags, so players timing by ear pull late. A weak pull within 0.08 s past the grace (`near_miss`) reads "So close!" on the pot label and the borrow toast, so a miss reads as your timing, not the game's.
- Clicking **under 0.2 s** does nothing (still raw). Pulling on **grey before the band** (first sweep) gives a weak brew. On grey **after the band has gone by** (including on the way back) it's weak and marked *Overcooked*. A miss still buys time, or you can wait for the needle to come back through the gold (costing patient time).
- **Red section:** the right end of the bar (the last 0.3 s of the sweep) is red; the needle bounces off it. Entering it plays a warning sound, the pot rattles hard and the bar flashes red. **Pulling in the red boils the pot over.**
- **Boil over:** only from pulling in the red. Left alone, the needle keeps bouncing forever. Boiling over empties the pot with a shake and a "Boiled over!" toast. You lose the ingredients and the time, never the run.
- **Pouring resets the brew** (even a set one) and restarts the count-in.
- **Perfect streak.** Perfect cures in a row build a streak. The perfect pull chime rises in pitch with it (+6% a step, up to 8 steps). From the second perfect cure in a row, the cure toast reads "Cured! +X · Perfect ×N" and adds +25 per step after the first (`streak_bonus`, capped at +100 `streak_bonus_max`). A weak or wrong serve, or a boil-over, resets it.
- The bar is the same wooden frame as the patients' bars (`assets/ui/bar_frame_wood.png`, 3× pixels), lengthened to 80 frame pixels (240 px) by repeating its middle wood, centred under the pot. The frame grows (×1.12) while the needle is in the gold and shrinks (×0.92) in the red. It shows a grey weak section, the gold band, the red section, and a needle tick with a short trail; it glows gold on a perfect pull. Empty, it's a faded frame. A label under the pot reads "Pick a mushroom", "Heating…" (count-in and raw), "Borrow some time" (grey), "Pull now!" (gold) / "Not in the red!" while boiling, then for example "Green Potion · Perfect!" / "· Weak" / "· Overcooked".
- Why: a timing skill on every brew that you can learn (steady speed, fixed band, an audible beat), so mistakes come from split attention between the pot and the patients, not from a new reaction test every brew.
- Pour results: 1 pour = that primary. Same colour twice = that primary. Two different primaries = their secondary. A third pour is blocked, with a "full" sound.
- Two actions when a brew is ready:
  - **Click a patient** to serve it to them (this also pulls a boiling pot).
  - **BOTTLE** pours it into a bottle on the **2-slot shelf** beside the pot. Bottling stops the cooking and freezes the quality. Bottles never decay.
- Click a bottle on the shelf to serve it. This is how you brew ahead for waiting patients and bosses.
- **The sink:** click the sink right of the pot (or press **V**) to empty the pot at any stage: heating, boiling or pulled. It flashes the brew's colour with a drain sound; on an empty pot it just shakes. This is how you switch brews when an emergency arrives.
- **Dumping from the pot:** clicking the pot once the brew is pulled also empties it (not within 0.3 s of the pull, so a double-click doesn't dump it).
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
- Each patient in a shift has a chance (table above) to be an **emergency**: they always need a **primary** (one pour), and they arrive on a **7 s clock**, with a red card outline, an `EMERGENCY` status line, an "Emergency!" toast and the `emergency` sound.
- 7 s is tight for a perfect brew (up to ~3 s of boiling plus pouring), so an emergency usually needs a weak dose first: sink, one pour, and a weak pull is about 0.6 s later.
- If an emergency patient runs out of borrowed time, they come back bandaged on a normal clock (no longer an emergency).
- **Danger ramp:** in any patient's last **2.5 s** the screen edges glow red (a vignette that pulses with each heartbeat), the screen jitters, and their card and body tremble. A `heartbeat` sound speeds up from one beat every 0.6 s to every 0.22 s, rising in pitch and volume. It ramps up steeply, and emergencies get the full effect; normal patients get 60% of it. The most urgent open chair drives it. Nothing blocks clicks.
All of these live in one config resource.

### Story
- Light touch. The setting is undecided for now (the earlier alien sci-fi idea is shelved because the art would be too much work).
- Shift cards show one funny line each. Patients have silly ailments, shown on their status cards.

### Screens and controls
- **Mouse only, left button only**, plus the **Z, X, C keys** as pour hotkeys for the red, yellow and blue critters (left to right; a keycap letter shows on each), and **V** for the sink. Click a critter to pour, anywhere to pull the pot, a patient to serve, and the sink (or the pot, once pulled) to empty it. No right-click, no dragging.
- Title screen: the game paused behind a paper scroll that unrolls (Humble Gift UI pack), with Play, Tutorial (a how-to-play page with Back) and Music on/off.
- **Esc (or P) pauses the game.** The pause panel slides in over a flash and a dim, with Continue, Restart, Music on/off and Home (back to the title). Esc again continues.
- **Game over** slides in the same paper panel ("Game Over", shift reached, score, cures and borrows) with Retry (a new run, no title) and Back (to the title).
- All text uses **Pixelify Sans** (`assets/fonts/`, SIL OFL 1.1, set as the theme's default font).
- Menu buttons pop in from the bottom up; the selected one has a bobbing arrow on each side (red while held). Menu art is cut from the pack by `python3 -I tools/extract_ui.py <SpriteSheet.aseprite>` into `assets/ui/` at 3×. The menu sounds are from Witchy UI Sounds (free, royalty-free).
- Shift intro card: shift number, stars from the last shift, one flavour line.

## Art pipeline (user draws in Illustrator)
- **Three levels of detail.** The static background gets the most detail. Hero objects (active patient, pot, critters) get medium detail with strong silhouettes. Repeated things and UI (bubbles, bottles, icons, buttons) stay simple and bold.
- **Colour hierarchy.** Only gameplay objects use the 6 saturated potion colours. The background is a dark, desaturated palette (muted purples and teal-greys).
- **Export.** One 720×900 artboard, exported as **2× PNG**. Each moving part is its own file. Anything tinted in code is drawn white or greyscale.
- **Naming.** Use snake_case, for example `critter_red.png`, `bandage.png`. Files go in `assets/` and replace grey-box placeholders with the same name.
- **Patients.** Random white 32×32 creatures from Hexany's Monster Menagerie (CC0, `assets/creatures/`), tinted to the cure colour and drawn with nearest-neighbour filtering. Each shift draws from a shuffled deck, so a creature only repeats after all 64 have appeared. No faces. A cure fades the creature back to its healthy gray (`cured_color`) as it leaves.
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
- **Done (2026-10-26):** the needle is twice as fast (1.6 s a sweep, every zone halved) and the boil-over after 3 sweeps is gone: only a pull in the red boils over.
- **Done (2026-10-26):** playtest fixes: the needle speeds up ×1.2 every sweep (capped at ×2), so waiting for the gold again is a gamble; a danger ramp (red vignette, screen jitter, card and patient tremble, speeding heartbeat) over a patient's last 2.5 s, strongest for emergencies.
- **Done (2026-10-26):** the pot no longer boils as soon as you pour: the first left-click anywhere lights it, then it runs by itself and the next click pulls. Pouring again puts the fire out.
- **Done (2026-10-26):** right-click removed, everything is left-click: click a patient to serve (or light an unlit pot), click the pot to dump a pulled brew.
- **Done (2026-10-26):** brewing is a learnable beat: the fire lights itself 0.4 s after the last pour (no light click, so a patient click always serves), constant needle speed (the ×1.2 speedup is gone), the gold band at a fixed spot per tier, and the bubble ticks on every 0.4 s beat of the needle. A pulled brew hops from the pot's mouth to the cursor, and a one-click serve throws from the pot. Perfect streak with a rising chime and a score bonus. Placeholder SFX synthesized by `tools/synth_sfx.py`.
- **Done (2026-10-27):** layout pulled inside the CRT frame (HUD, cards, chairs and critters inset so nothing is lost to the curved corners). Mute button top right (or the M key) mutes the master bus and is saved between sessions.
- **Done (2026-10-29):** game-over screen on the paper panel (Retry, Back), Restart in the pause menu, Pixelify Sans everywhere.
- **Done (2026-10-28):** title and pause menus (`scripts/menu_panel.gd`). Music on/off is saved and mutes a Music bus; `audio/music.*` plays on loop once it exists.
- **Done (2026-10-30):** the patients' status bars moved from the top of the screen to just under each patient (patients lifted so the bar and its text sit above the doorway border), and the stump is bigger (128 → 160 px).
- **Done (2026-10-30):** the timing ring around the pot is now a straight wooden bar under it (same frame as the patients' bars), easier to read at a glance, then lengthened, with the needle 15% faster (`needle_speed`) and the frame growing in the gold and shrinking in the red. Same bounce and zones.
- **Done (2026-10-30):** one sound switch instead of separate mute and music toggles, so they can't drift apart. HUD has a gear (opens pause) top left and a speaker top right; the menus show a speaker icon button instead of "Music: On/Off". Tutorial Back button and the menu arrows made smaller.
- **Done (2026-10-29):** playtest fairness fixes: the sink (V) empties the pot at any stage, the gold band no longer moves when you add a second colour, a hidden grace around the band (wider late) with "So close!" feedback, and emergencies always need a primary. A cure-all potion was considered and cut (past the feature freeze).
- **Next:** bosses, recipe poster and book, then title, pause and shift cards.
- Audio: the SFX in `audio/` are **placeholders** synthesized by `python3 -I tools/synth_sfx.py` (stdlib only). A real generator can overwrite them by saving under the same names (`.ogg`, `.wav` or `.mp3`); `ASSETS.md` lists which ones exist. Music is still to do.

## Nice to have (only once the MVP is done)
- Fancier overcooking effects (smoke, fire)
- Patient-specific quirks (impatient, needs a double dose)
