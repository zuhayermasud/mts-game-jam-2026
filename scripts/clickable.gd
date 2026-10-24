class_name Clickable
extends Node2D
## A Node2D you can click. The `hit` sprite's shape is the click area.
## Scales up a little on hover. Controls (buttons, panels) get the click first.

signal clicked(button: MouseButton)

@export var hit: ArtSprite
@export var hover_scale := 1.08

var hovered := false
var _hover_tween: Tween


## Override to switch clicks off, e.g. for an empty chair.
func is_clickable() -> bool:
	return is_visible_in_tree()


func _unhandled_input(event: InputEvent) -> void:
	var over := is_clickable() and hit.contains_point(get_global_mouse_position())
	if event is InputEventMouseMotion:
		_set_hovered(over)
	elif event is InputEventMouseButton and event.pressed:
		if over:
			get_viewport().set_input_as_handled()
			clicked.emit(event.button_index)


func _set_hovered(value: bool) -> void:
	if value == hovered:
		return
	hovered = value
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	var target := Vector2.ONE * (hover_scale if hovered else 1.0)
	_hover_tween.tween_property(self, "scale", target, 0.12)
