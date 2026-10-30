"""Copy icons from the Icons_Essential pack into assets/ui/ as greyscale 3x PNGs.

python3 -I tools/extract_icons.py "<path to Icons_Essential/v1.2/Icons>"

Greyscale so they sit with the paper menus (and can be tinted with modulate). Scaled 3x with
nearest neighbour to match the rest of assets/ui/.
"""
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ase_export  # noqa: E402

SCALE = 3
OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
# Our name: the pack's file name.
ICONS = {
	"icon_settings": "Gear",
	"icon_sound_on": "SpeakerOn",
	"icon_sound_off": "SpeakerMute",
}


def read_png(path):
	"""8-bit RGBA, non-interlaced PNGs only (all the pack uses)."""
	data = Path(path).read_bytes()
	pos, idat = 8, b""
	while pos < len(data):
		n, kind = struct.unpack(">I4s", data[pos:pos + 8])
		body = data[pos + 8:pos + 8 + n]
		if kind == b"IHDR":
			w, h, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
			assert depth == 8 and color == 6 and interlace == 0, f"{path}: unsupported PNG"
		elif kind == b"IDAT":
			idat += body
		pos += 12 + n
	raw = zlib.decompress(idat)
	stride = w * 4
	out = bytearray(h * stride)
	prev = bytearray(stride)
	for y in range(h):
		f = raw[y * (stride + 1)]
		line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
		for i in range(stride):
			a = line[i - 4] if i >= 4 else 0
			b = prev[i]
			c = prev[i - 4] if i >= 4 else 0
			if f == 1:
				line[i] = (line[i] + a) & 255
			elif f == 2:
				line[i] = (line[i] + b) & 255
			elif f == 3:
				line[i] = (line[i] + (a + b) // 2) & 255
			elif f == 4:
				p = a + b - c
				pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
				pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
				line[i] = (line[i] + pr) & 255
		out[y * stride:(y + 1) * stride] = line
		prev = line
	return w, h, out


def main():
	src = Path(sys.argv[1])
	for name, pack_name in ICONS.items():
		w, h, px = read_png(src / f"{pack_name}.png")
		out = bytearray(w * SCALE * h * SCALE * 4)
		for py in range(h * SCALE):
			for qx in range(w * SCALE):
				k = ((py // SCALE) * w + qx // SCALE) * 4
				r, g, b, a = px[k:k + 4]
				grey = round(0.299 * r + 0.587 * g + 0.114 * b)
				t = (py * w * SCALE + qx) * 4
				out[t:t + 4] = bytes((grey, grey, grey, a))
		ase_export._png(OUT / f"{name}.png", w * SCALE, h * SCALE, out)
		print(f"{name}.png {w * SCALE}x{h * SCALE}")


if __name__ == "__main__":
	main()
