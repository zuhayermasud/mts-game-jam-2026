# assets/

Drop a PNG here with one of these names and it replaces the grey-box placeholder of the same name. You don't need to change any code. Each placeholder in the game has its file name written on it.

- Export at **2×** the on-screen size. The art is stretched to fit that box, so keep the same proportions.
- **Tinted** files are coloured in code. Draw them white or greyscale.

| File | On screen | Export (2×) | Tinted |
|---|---|---|---|
| `background.png` (back wall, behind the patients) | 720×468 | 120×78 pixel art, nearest filtering | |
| `counter.png` (table, in front of the patients) | 720×432 | 120×72 pixel art | |
| `counter_trim.png` (fairy ring strip at the bottom of the table) | 720×180 | 120×30 pixel art | |
| `frame.png` (border and bottles, drawn over everything in the world) | 720×540 | 120×90 pixel art | |
| `pot.png` (hollow tree stump, 32×32 pixel art; the brew colour is drawn in code inside the hollow) | 128×128 | as is | |
| `slime.png` (the sink) | 128×128 | 32×32 per frame, 9 frames in a row | pixel art strip; `frames` on its ArtSprite plays it |
| `critter.png` (mushroom patch outline and stems, 32×32 pixel art) | 128×128 | as is | |
| `critter_cap.png` (just the caps, greyscale, same canvas as `critter.png`) | 128×128 | as is | yes |
| `creatures/creature_001.png` … `creature_064.png` (patients, 32×32 pixel art, nearest filtering) | 224×224 | as is | yes |
| `bandage.png` | 84×28 | 168×56 | |
| `icon_red.png` … `icon_purple.png` (6) | 48×48 (status card) | 96×96 (or larger, same proportions) | yes |
| `icon_heart.png` | 48×48 | 5 frames of 64×64 in a row, empty to full | no, coloured; losing a life plays it full to empty |
| `potion_blob.png` (held / flying potion) | 36×36 | 72×72 | yes |

Sizes and positions can be changed in the Godot editor: select the node and edit `size` in the Inspector.

Sounds work the same way: put `res://audio/<name>.ogg` (or `.wav`) in `audio/` and `Sfx.play("<name>")` picks it up. These names are already called: `pour`, `pot_full`, `dump` (the sink), `bubble`, `brew_ready`, `brew_perfect`, `boil_warning`, `boil_over`, `give`, `refuse`, `splash`, `borrow`, `cure`, `bandaged`, `death`, `patient_arrive`, `emergency`, `shift_start`, `game_over`.
