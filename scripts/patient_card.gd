class_name PatientCard
extends Control
## Status bar just under each chair's patient: a wooden progress bar filled with
## the cure colour, plus the seconds left and whether they've borrowed time.
## Reads its patient every frame. The bar starts half full and drains with the clock;
## a cure fills it all the way. A halo glows gold when the pot holds a set brew that's
## this patient's cure, and is red for emergencies.

const FRAME := preload("res://assets/ui/bar_frame_wood.png")
## The frame's see-through window, in frame pixels.
const WINDOW := Rect2i(4, 3, 40, 5)
## Frame pixels to screen pixels. Whole numbers keep the pixel art crisp.
const PIXEL := 3.0
## Where the frame sits on the card.
const BAR_POS := Vector2(38, 6)
## A full clock shows this much of the bar, so a cure has room to fill it.
const START_FILL := 0.5
const BAR_BACK := Color(0.1, 0.08, 0.15, 0.6)
const MATCH := Color(1.0, 0.85, 0.3)
const BORROWED := Color(0.62, 0.4, 0.95)
const CRITICAL := Color(1.0, 0.25, 0.25)
const OUTCOME_TEXT := {
	Patient.Outcome.CURED: "Cured!",
	Patient.Outcome.BANDAGED: "Back later, worse",
	Patient.Outcome.DIED: "Lost",
}
const OUTCOME_COLOR := {
	Patient.Outcome.CURED: Color(0.6, 1.0, 0.65),
	Patient.Outcome.BANDAGED: Color(1.0, 0.75, 0.45),
	Patient.Outcome.DIED: Color(1.0, 0.5, 0.5),
}

var patient: Patient
## The servable brew in the pot (0 or 1 kinds).
var pot_kinds: Array[int] = []
## More patients still to come this shift.
var waiting := false

var _time := 0.0
## Shown bar fill, eased toward the patient's real value.
var _fill := 0.0
## The visit the bar is showing, so a new patient snaps it instead of easing.
var _info: PatientInfo
var _halo := StyleBoxFlat.new()

@onready var status_label: Label = $Status
@onready var time_label: Label = $Time


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_halo.set_corner_radius_all(10)
	_halo.draw_center = false
	_halo.set_border_width_all(4)


func _process(delta: float) -> void:
	_time += delta
	var seated := patient != null and patient.occupied
	# Trembles as the patient runs out of time.
	pivot_offset = size / 2
	rotation = sin(_time * 45.0) * 0.04 * patient.danger() if seated else 0.0
	time_label.visible = seated
	if not seated:
		status_label.text = "Next patient…" if waiting else ""
		status_label.modulate = Color(1, 1, 1, 0.6)
		queue_redraw()
		return
	var info := patient.info
	var target := 1.0 if patient.outcome == Patient.Outcome.CURED \
		else START_FILL * clampf(patient.time_left / patient.clock_max, 0.0, 1.0)
	if info != _info:
		_info = info
		_fill = target
	_fill = lerpf(_fill, target, 1.0 - exp(-delta * 8.0))
	time_label.text = "%ds" % ceili(patient.time_left)
	if patient.outcome != -1:
		status_label.text = OUTCOME_TEXT[patient.outcome]
		status_label.modulate = OUTCOME_COLOR[patient.outcome]
	elif info.bandaged:
		status_label.text = "Bandaged · next +%ds" % Game.config.borrow_for(info.borrows)
		status_label.modulate = CRITICAL.lightened(0.3)
	elif info.has_borrowed():
		status_label.text = "Borrowed ×%d · next +%ds" % [info.borrows, Game.config.borrow_for(info.borrows)]
		status_label.modulate = BORROWED.lightened(0.3)
	elif info.emergency:
		status_label.text = "EMERGENCY"
		status_label.modulate = CRITICAL.lightened(0.3)
	else:
		status_label.text = "Weak dose: +%ds" % Game.config.borrow_for(0)
		status_label.modulate = Color.WHITE
	queue_redraw()


func _flash() -> bool:
	return fmod(_time * 6.0, 2.0) < 1.0


func _draw() -> void:
	var seated := patient != null and patient.occupied
	var bar := Rect2(BAR_POS, Vector2(FRAME.get_size()) * PIXEL)
	var window := Rect2(BAR_POS + Vector2(WINDOW.position) * PIXEL, Vector2(WINDOW.size) * PIXEL)
	if not seated:
		draw_texture_rect(FRAME, bar, false, Color(1, 1, 1, 0.35))
		return
	var matched := patient.active and patient.info.cure in pot_kinds
	var halo := CRITICAL if patient.info.emergency else Color.TRANSPARENT
	if matched:
		halo = MATCH
	elif patient.is_critical() and _flash():
		halo = Color.TRANSPARENT if halo == CRITICAL else CRITICAL
	if halo.a > 0.0:
		_halo.border_color = halo
		draw_style_box(_halo, bar.grow(6))
	# Fill in the cure colour, lit on top like the pack's bar textures.
	var tint := Game.config.potion_color(patient.info.cure)
	draw_rect(window, BAR_BACK)
	var fill := Rect2(window.position, Vector2(roundf(window.size.x * _fill / PIXEL) * PIXEL, window.size.y))
	draw_rect(fill, tint)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2 * PIXEL)), tint.lightened(0.35))
	draw_texture_rect(FRAME, bar, false)
