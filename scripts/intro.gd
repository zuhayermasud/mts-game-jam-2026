class_name Intro
extends CanvasLayer
## First-launch intro: the cave parallax scrolls for a few seconds, fades to black, then the
## title menu appears. Click or press a key to skip. Emits finished once the screen is black.

signal finished

const DIR := "res://assets/intro/cave_%d.png"
const LAYERS := 8
const SIZE := Vector2(720, 900)
const SHOW_TIME := 3.0
const FADE_TIME := 0.6
## Texture pixels per second of the nearest layer. Farther layers crawl slower.
const FRONT_SPEED := 60.0

var _sprites: Array[Sprite2D] = []
var _black: ColorRect
var _time := 0.0
var _done := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(LAYERS - 1, -1, -1):  # 7 is the back wall, 0 the nearest
		var tex: Texture2D = load(DIR % i)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.region_enabled = true
		var k := SIZE.y / tex.get_height()
		s.scale = Vector2(k, k)
		s.region_rect = Rect2(Vector2.ZERO, Vector2(SIZE.x / k, tex.get_height()))
		add_child(s)
		_sprites.append(s)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = SIZE
	_black.modulate.a = 0.0
	add_child(_black)


func _process(delta: float) -> void:
	_time += delta
	for n in _sprites.size():
		var layer_index := LAYERS - 1 - n
		var speed := FRONT_SPEED * (1.0 - layer_index / float(LAYERS))
		var r := _sprites[n].region_rect
		r.position.x += speed * delta
		_sprites[n].region_rect = r
	_black.modulate.a = clampf((_time - SHOW_TIME) / FADE_TIME, 0.0, 1.0)
	if _time >= SHOW_TIME + FADE_TIME:
		_finish()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_time = maxf(_time, SHOW_TIME)  # skip straight to the fade
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	# Hold black for a beat so the menu can open underneath, then reveal it.
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
