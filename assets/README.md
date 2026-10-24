# assets/

Drop a PNG here with one of these names and it replaces the grey-box placeholder of the same name. You don't need to change any code. Each placeholder in the game has its file name written on it.

- Export at **2×** the on-screen size. The art is stretched to fit that box, so keep the same proportions.
- **Tinted** files are coloured in code. Draw them white or greyscale.

| File | On screen | Export (2×) | Tinted |
|---|---|---|---|
| `background.png` | 720×900 | 1440×1800 | |
| `counter.png` | 720×430 | 1440×860 | |
| `pot.png` | 190×170 | 380×340 | |
| `pot_liquid.png` | 140×46 | 280×92 | yes |
| `critter_red.png`, `critter_yellow.png`, `critter_blue.png` | 130×115 | 260×230 | |
| `patient_body_a.png`, `patient_body_b.png` | 280×360 | 560×720 | yes |
| `face_calm.png`, `face_worried.png`, `face_critical.png`, `face_cured.png`, `face_dead.png` | 160×100 | 320×200 | |
| `bandage.png` | 120×40 | 240×80 | |
| `bubble.png` | 160×160 | 320×320 | |
| `icon_red.png` … `icon_purple.png` (6) | 76×76 | 152×152 | yes |

Sizes and positions can be changed in the Godot editor: select the node and edit `size` in the Inspector.

Sounds work the same way: put `res://audio/<name>.ogg` (or `.wav`) in `audio/` and `Sfx.play("<name>")` picks it up. These names are already called: `pour`, `pot_full`, `dump`, `brew_perfect`, `brew_overcooked`, `give`, `refuse`, `borrow`, `cure`, `bandaged`, `death`, `patient_arrive`, `shift_start`, `game_over`.
