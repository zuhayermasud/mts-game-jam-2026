"""Export Aseprite files to PNG frames. Stdlib only.

python3 -I tools/ase_export.py <file.aseprite> <out_dir> [--info] [--layers a,b] [--hide a,b]

Writes <out_dir>/frame_NN.png (all visible layers composited, normal blend)
and prints layers, tags and frame durations.
"""
import struct
import sys
import zlib
from pathlib import Path


def _png(path, w, h, rgba):
	raw = b"".join(b"\x00" + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))

	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

	data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
	data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
	Path(path).write_bytes(data)


def _string(b, o):
	n = struct.unpack_from("<H", b, o)[0]
	return b[o + 2:o + 2 + n].decode("utf-8", "replace"), o + 2 + n


def parse(path):
	b = Path(path).read_bytes()
	_, magic, nframes, w, h, depth, flags = struct.unpack_from("<IHHHHHI", b, 0)
	assert magic == 0xA5E0, "not an aseprite file"
	trans_idx = b[28]
	layers, frames, tags, palette = [], [], [], {}
	o = 128
	for _ in range(nframes):
		fsize, fmagic, old_n, dur = struct.unpack_from("<IHHH", b, o)
		new_n = struct.unpack_from("<I", b, o + 12)[0]
		n = new_n or old_n
		co = o + 16
		cels = []
		for _ in range(n):
			csize, ctype = struct.unpack_from("<IH", b, co)
			d = co + 6
			if ctype == 0x2004:
				lflags, ltype, child, _, _, blend, opacity = struct.unpack_from("<HHHHHHB", b, d)
				name, _ = _string(b, d + 16)
				layers.append(dict(name=name, flags=lflags, type=ltype, child=child, blend=blend, opacity=opacity))
			elif ctype == 0x2005:
				li, x, y, op, ct = struct.unpack_from("<HhhBH", b, d)
				p = d + 16
				if ct == 1:
					cels.append(dict(layer=li, link=struct.unpack_from("<H", b, p)[0]))
				elif ct in (0, 2):
					cw, ch = struct.unpack_from("<HH", b, p)
					px = b[p + 4:co + csize]
					if ct == 2:
						px = zlib.decompress(px)
					cels.append(dict(layer=li, x=x, y=y, op=op, w=cw, h=ch, px=px))
			elif ctype == 0x2019:
				_, first, last = struct.unpack_from("<III", b, d)
				p = d + 20
				for i in range(first, last + 1):
					ef, r, g, bb, a = struct.unpack_from("<HBBBB", b, p)
					p += 6
					if ef & 1:
						_, p = _string(b, p)
					palette[i] = (r, g, bb, a)
			elif ctype == 0x2018:
				nt = struct.unpack_from("<H", b, d)[0]
				p = d + 10
				for _ in range(nt):
					fr, to, direction = struct.unpack_from("<HHB", b, p)
					p += 17
					name, p = _string(b, p)
					tags.append(dict(name=name, frm=fr, to=to, dir=direction))
			co += csize
		frames.append(dict(dur=dur, cels=cels))
		o += fsize
	return dict(w=w, h=h, depth=depth, flags=flags, trans=trans_idx, layers=layers, frames=frames, tags=tags, palette=palette)


def _visible(ase, li, only, hide):
	layers = ase["layers"]
	if only and layers[li]["name"] not in only:
		return False
	if layers[li]["name"] in hide:
		return False
	# Walk up the group chain: every ancestor must be visible too.
	level = layers[li]["child"]
	i = li
	while i >= 0:
		if layers[i]["child"] <= level:
			if not layers[i]["flags"] & 1:
				return False
			if layers[i]["name"] in hide:
				return False
			level = layers[i]["child"] - 1
			if level < 0:
				break
		i -= 1
	return True


def render(ase, fi, only=(), hide=()):
	w, h, depth = ase["w"], ase["h"], ase["depth"]
	out = bytearray(w * h * 4)
	frame = ase["frames"][fi]
	cels = sorted(frame["cels"], key=lambda c: c["layer"])
	for cel in cels:
		if "link" in cel:
			linked = [c for c in ase["frames"][cel["link"]]["cels"] if c["layer"] == cel["layer"]]
			if not linked:
				continue
			cel = linked[0]
		li = cel["layer"]
		layer = ase["layers"][li]
		if layer["type"] != 0 or not _visible(ase, li, only, hide):
			continue
		lop = layer["opacity"] / 255 if ase["flags"] & 1 else 1.0
		op = cel["op"] / 255 * lop
		bpp = depth // 8
		px = cel["px"]
		for cy in range(cel["h"]):
			ty = cel["y"] + cy
			if ty < 0 or ty >= h:
				continue
			for cx in range(cel["w"]):
				tx = cel["x"] + cx
				if tx < 0 or tx >= w:
					continue
				k = (cy * cel["w"] + cx) * bpp
				if depth == 32:
					r, g, bb, a = px[k:k + 4]
				elif depth == 16:
					r = g = bb = px[k]
					a = px[k + 1]
				else:
					idx = px[k]
					if idx == ase["trans"]:
						continue
					r, g, bb, a = ase["palette"].get(idx, (0, 0, 0, 0))
				a = a * op / 255
				if a <= 0:
					continue
				t = (ty * w + tx) * 4
				da = out[t + 3] / 255
				oa = a + da * (1 - a)
				for c, s in enumerate((r, g, bb)):
					out[t + c] = int((s * a + out[t + c] * da * (1 - a)) / oa)
				out[t + 3] = int(oa * 255)
	return out


def main():
	args = sys.argv[1:]
	src, dst = Path(args[0]), Path(args[1])
	only = hide = ()
	if "--layers" in args:
		only = tuple(args[args.index("--layers") + 1].split(","))
	if "--hide" in args:
		hide = tuple(args[args.index("--hide") + 1].split(","))
	ase = parse(src)
	print(f"{src.name}: {ase['w']}x{ase['h']} depth {ase['depth']}, {len(ase['frames'])} frames")
	for i, l in enumerate(ase["layers"]):
		print(f"  layer {i}: {'  ' * l['child']}{l['name']!r} type={l['type']} visible={bool(l['flags'] & 1)} blend={l['blend']}")
	for t in ase["tags"]:
		print(f"  tag {t['name']!r}: frames {t['frm']}-{t['to']}")
	print("  durations:", [f["dur"] for f in ase["frames"]])
	if "--info" in args:
		return
	dst.mkdir(parents=True, exist_ok=True)
	for fi in range(len(ase["frames"])):
		_png(dst / f"frame_{fi:02d}.png", ase["w"], ase["h"], render(ase, fi, only, hide))


if __name__ == "__main__":
	main()
