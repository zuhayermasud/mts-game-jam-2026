"""Cut the menu parts out of the Humble Gift UI pack (SpriteSheet.aseprite) into assets/ui/.

python3 -I tools/extract_ui.py "<path to SpriteSheet.aseprite>"

Each part is scaled up 3x with nearest neighbour, so the pixel art stays crisp at 1:1 in Godot
and nine-patch margins stay whole pixels.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ase_export  # noqa: E402

SCALE = 3
OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
# name: (x, y, w, h, pad_top) in sheet pixels. pad_top adds transparent rows so the pressed
# button (2 px shorter) lines up with the normal one and reads as pushed in.
PARTS = {
	"menu_panel": (32, 1120, 183, 280, 0),
	"menu_page_line": (268, 1133, 159, 251, 0),
	"menu_button": (52, 1557, 57, 22, 0),
	"menu_button_pressed": (132, 1557, 57, 20, 2),
	"menu_arrow": (57, 1496, 17, 31, 0),
	"menu_arrow_pressed": (105, 1496, 17, 31, 0),
	"menu_divider": (49, 1460, 96, 7, 0),
	"menu_title_pause": (160, 1504, 64, 16, 0),
}


def main():
	ase = ase_export.parse(sys.argv[1])
	sheet = ase_export.render(ase, 0)
	sw = ase["w"]
	OUT.mkdir(parents=True, exist_ok=True)
	for name, (x, y, w, h, pad) in PARTS.items():
		oh = h + pad
		out = bytearray(w * SCALE * oh * SCALE * 4)
		for py in range(oh * SCALE):
			sy = py // SCALE - pad
			if sy < 0:
				continue
			for px in range(w * SCALE):
				k = ((y + sy) * sw + x + px // SCALE) * 4
				t = (py * w * SCALE + px) * 4
				out[t:t + 4] = sheet[k:k + 4]
		ase_export._png(OUT / f"{name}.png", w * SCALE, oh * SCALE, out)
		print(f"{name}.png {w * SCALE}x{oh * SCALE}")


if __name__ == "__main__":
	main()
