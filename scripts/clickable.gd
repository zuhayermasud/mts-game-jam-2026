class_name Clickable
extends Node2D
## A Node2D you can click. The `hit` sprite's shape is the click area.
## Scales up a little on hover. Controls (buttons, panels) get the click first.

signal clicked(button: MouseButton)

@export var hit: ArtSprite
@export var hover_scale := 1.08

var hovered := false
var _hover_tween: Tween


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(hit.contains_point(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		if hit.contains_point(get_global_mouse_position()):
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
