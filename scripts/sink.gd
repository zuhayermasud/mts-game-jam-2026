class_name Sink
extends Clickable
## The slime beside the pot (the "sink"). Click it (or press its hotkey, V) to pour the pot away at any
## stage, so a wrong brew never blocks you. Main decides what happens; the sink only animates.

signal used

@export var key: Key = KEY_V

var _tween: Tween


func _ready() -> void:
	clicked.connect(_on_clicked)
	_add_key_hint()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == key:
		get_viewport().set_input_as_handled()
		used.emit()


func _on_clicked(button: MouseButton) -> void:
	if button == MOUSE_BUTTON_LEFT:
		used.emit()


## The slime gulps the brew: a squash and a flash of its colour.
func drain(color: Color) -> void:
	_reset_tween()
	hit.scale = Vector2(1.15, 0.85)
	hit.self_modulate = color.lightened(0.3)
	_tween = create_tween()
	_tween.tween_property(hit, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(hit, "self_modulate", Color.WHITE, 0.4)


## Nothing to pour away: a little shake.
func refuse() -> void:
	_reset_tween()
	Sfx.play("pot_full")
	_tween = create_tween()
	for x in [-6.0, 6.0, -3.0, 0.0]:
		_tween.tween_property(hit, "position:x", x, 0.04)


func _reset_tween() -> void:
	if _tween:
		_tween.kill()
	hit.position.x = 0.0
	hit.scale = Vector2.ONE
	hit.self_modulate = Color.WHITE


## A small keycap letter so the hotkey is discoverable, like the critters'.
func _add_key_hint() -> void:
	var hint := Label.new()
	hint.text = OS.get_keycode_string(key)
	hint.size = Vector2(40, 32)
	hint.position = Vector2(-20, 58)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
