@tool
class_name ArtSprite
extends Node2D
## Draws res://assets/<art_name>.png, centred and fitted to `size`, if that file exists.
## Otherwise it draws a grey-box placeholder with the file name written on it.
## To swap in real art, drop a 2x PNG with that name into assets/. No code changes needed.
## Tint with self_modulate (draw tinted art white or greyscale) so children keep their colours.
## A horizontal strip of equal frames plays on loop when `frames` > 1, or holds `frame` when
## `autoplay` is off.

enum Shape { RECT, ROUNDED, ELLIPSE }

const ASSET_DIR := "res://assets/"
const OUTLINE := Color(0.1, 0.08, 0.15)

@export var art_name := "":
	set(value):
		art_name = value
		_load_texture()
## Size on the 720x900 screen. The PNG is exported at twice this.
@export var size := Vector2(100, 100):
	set(value):
		size = value
		queue_redraw()
## Frames side by side in the PNG, played left to right at `fps`.
@export var frames := 1:
	set(value):
		frames = maxi(value, 1)
		queue_redraw()
@export var fps := 10.0
@export var autoplay := true
@export var frame := 0:
	set(value):
		value = clampi(value, 0, frames - 1)
		if value != frame:
			frame = value
			queue_redraw()
@export var shape := Shape.ROUNDED:
	set(value):
		shape = value
		queue_redraw()
@export var placeholder_color := Color(0.6, 0.6, 0.65):
	set(value):
		placeholder_color = value
		queue_redraw()
## Write art_name on the placeholder so you know which file replaces it.
@export var show_name := true:
	set(value):
		show_name = value
		queue_redraw()

var _texture: Texture2D
var _time := 0.0


func has_art() -> bool:
	return _texture != null


func contains_point(global_point: Vector2) -> bool:
	var p := to_local(global_point)
	if shape == Shape.ELLIPSE:
		return (p / (size * 0.5)).length_squared() <= 1.0
	return Rect2(-size * 0.5, size).has_point(p)


func _process(delta: float) -> void:
	if frames <= 1 or not autoplay or _texture == null:
		return
	_time += delta
	frame = int(_time * fps) % frames


func _load_texture() -> void:
	var path := ASSET_DIR + art_name + ".png"
	_texture = load(path) if art_name != "" and ResourceLoader.exists(path) else null
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	if _texture:
		if frames > 1:
			var w := _texture.get_width() / float(frames)
			var src := Rect2(w * frame, 0, w, _texture.get_height())
			draw_texture_rect_region(_texture, rect, src)
		else:
			draw_texture_rect(_texture, rect, false)
		return
	match shape:
		Shape.RECT:
			draw_rect(rect, placeholder_color)
		Shape.ROUNDED:
			var box := StyleBoxFlat.new()
			box.bg_color = placeholder_color
			box.border_color = OUTLINE
			box.set_border_width_all(3)
			box.set_corner_radius_all(int(minf(size.x, size.y) * 0.2))
			draw_style_box(box, rect)
		Shape.ELLIPSE:
			var points := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				points.append(Vector2(cos(a) * size.x, sin(a) * size.y) * 0.5)
			draw_colored_polygon(points, placeholder_color)
			points.append(points[0])
			draw_polyline(points, OUTLINE, 3.0, true)
	if show_name and art_name != "":
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, 5), art_name,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0, 0, 0, 0.5))
