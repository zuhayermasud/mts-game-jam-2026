"""Slice the SpeechBubble1.png sheet (5x4 cells of 32 px) into assets/ui/bubble_<name>.png at 3x.

python3 -I tools/extract_bubbles.py "<path to SpeechBubble1.png>" [--sheet out.png]

The sheet is an indexed PNG, so this has its own reader. Cells are named in CELLS below
(row, col). `--sheet` writes a labelled-grid zoom for checking which cell is which.
"""
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ase_export  # noqa: E402

CELL = 32
SCALE = 3
OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
# name: (row, col). bubble_sad_* show on arrival, bubble_alert when time is nearly up,
# bubble_happy_* as a cured patient leaves.
CELLS = {
	"sad_sad": (3, 2),
	"sad_meh": (2, 4),
	"sad_worried": (2, 2),
	"alert": (0, 1),
	"happy_smile": (3, 3),
	"happy_grin": (3, 1),
	"happy_wink": (2, 1),
	"happy_cat": (3, 0),
	"happy_tongue": (2, 0),
	"happy_heart": (1, 4),
}


def read_indexed_png(path):
	data = Path(path).read_bytes()
	pos, idat, pal, trns = 8, b"", b"", b""
	while pos < len(data):
		n, kind = struct.unpack(">I4s", data[pos:pos + 8])
		body = data[pos + 8:pos + 8 + n]
		if kind == b"IHDR":
			w, h, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
			assert depth == 8 and color == 3 and interlace == 0, f"{path}: unsupported PNG"
		elif kind == b"PLTE":
			pal = body
		elif kind == b"tRNS":
			trns = body
		elif kind == b"IDAT":
			idat += body
		pos += 12 + n
	raw = zlib.decompress(idat)
	out = bytearray(w * h * 4)
	prev = bytearray(w)
	for y in range(h):
		f = raw[y * (w + 1)]
		line = bytearray(raw[y * (w + 1) + 1:(y + 1) * (w + 1)])
		for i in range(w):
			a = line[i - 1] if i >= 1 else 0
			b = prev[i]
			c = prev[i - 1] if i >= 1 else 0
			if f == 1:
				line[i] = (line[i] + a) & 255
			elif f == 2:
				line[i] = (line[i] + b) & 255
			elif f == 3:
				line[i] = (line[i] + (a + b) // 2) & 255
			elif f == 4:
				p = a + b - c
				pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
				line[i] = (line[i] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
		prev = line
		for x in range(w):
			i = line[x]
			alpha = trns[i] if i < len(trns) else 255
			out[(y * w + x) * 4:(y * w + x) * 4 + 4] = bytes((pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2], alpha))
	return w, h, out


def crop(px, w, row, col):
	cell = bytearray(CELL * CELL * 4)
	for y in range(CELL):
		s = ((row * CELL + y) * w + col * CELL) * 4
		cell[y * CELL * 4:(y + 1) * CELL * 4] = px[s:s + CELL * 4]
	return cell


def scale(px, w, h, s):
	out = bytearray(w * s * h * s * 4)
	for y in range(h * s):
		for x in range(w * s):
			k = ((y // s) * w + x // s) * 4
			out[(y * w * s + x) * 4:(y * w * s + x) * 4 + 4] = px[k:k + 4]
	return out


def main():
	w, h, px = read_indexed_png(sys.argv[1])
	if "--sheet" in sys.argv:
		s = 6
		big = scale(px, w, h, s)
		for y in range(h * s):
			for x in range(w * s):
				k = (y * w * s + x) * 4
				if big[k + 3] < 255:
					big[k:k + 4] = bytes((90, 90, 110, 255))
				if x % (CELL * s) == 0 or y % (CELL * s) == 0:
					big[k:k + 4] = bytes((255, 0, 0, 255))
		ase_export._png(sys.argv[sys.argv.index("--sheet") + 1], w * s, h * s, big)
	for name, (row, col) in CELLS.items():
		ase_export._png(OUT / f"bubble_{name}.png", CELL * SCALE, CELL * SCALE,
				scale(crop(px, w, row, col), CELL, CELL, SCALE))
		print(f"bubble_{name}.png")


main()
