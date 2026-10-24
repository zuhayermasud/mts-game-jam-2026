@tool
class_name RingGauge
extends Node2D
## A circular progress ring drawn in code. Fills clockwise from 12 o'clock.

@export var radius := 90.0:
	set(value):
		radius = value
		queue_redraw()
@export var width := 10.0:
	set(value):
		width = value
		queue_redraw()
@export_range(0.0, 1.0) var fraction := 1.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var back_color := Color(0, 0, 0, 0.35):
	set(value):
		back_color = value
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, back_color, width, true)
	if fraction > 0.0:
		draw_arc(Vector2.ZERO, radius, -PI / 2, -PI / 2 + TAU * fraction, 64, color, width, true)
