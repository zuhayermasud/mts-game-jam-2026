class_name PatientCard
extends Control
## Status card at the top of the screen, one per chair: the cure colour, the ailment,
## the clock as a bar and whether they've borrowed time. Reads its patient every frame.
## The outline glows gold when the brew in the pot is this patient's cure.

const OUTLINE := Color(0.1, 0.08, 0.15)
const BG := Color(0.97, 0.96, 0.92)
const EMPTY_BG := Color(0.97, 0.96, 0.92, 0.25)
const MATCH := Color(1.0, 0.85, 0.3)
const BAR_BACK := Color(0.1, 0.08, 0.15, 0.25)
const CLOCK := Color(0.35, 0.8, 0.45)
const BORROWED := Color(0.62, 0.4, 0.95)
const CRITICAL := Color(1.0, 0.25, 0.25)
const BAR_RECT := Rect2(12, 98, 196, 14)
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
## The servable brew in the pot, or Potion.Kind.NONE.
var pot_kind := Potion.Kind.NONE
## More patients still to come this shift.
var waiting := false

var _time := 0.0
var _style := StyleBoxFlat.new()

@onready var icon: ArtSprite = $Icon
@onready var name_label: Label = $Name
@onready var ailment_label: Label = $Ailment
@onready var status_label: Label = $Status
@onready var time_label: Label = $Time


func _ready() -> void:
	_style.set_corner_radius_all(16)
	_style.set_border_width_all(4)
	_style.border_width_bottom = 7


func _process(delta: float) -> void:
	_time += delta
	var seated := patient != null and patient.occupied
	for child: CanvasItem in [icon, name_label, ailment_label, time_label]:
		child.visible = seated
	if not seated:
		status_label.text = "Next patient…" if waiting else ""
		status_label.modulate = Color(1, 1, 1, 0.6)
		queue_redraw()
		return
	var info := patient.info
	var tint := Game.config.potion_color(info.cure)
	var icon_art := "icon_" + Potion.art_suffix(info.cure)
	if icon.art_name != icon_art:
		icon.art_name = icon_art
	icon.self_modulate = tint
	name_label.text = Potion.NAMES[info.cure]
	ailment_label.text = info.ailment
	time_label.text = "%ds" % ceili(patient.time_left)
	if patient.outcome != -1:
		status_label.text = OUTCOME_TEXT[patient.outcome]
		status_label.modulate = OUTCOME_COLOR[patient.outcome]
	elif info.bandaged:
		status_label.text = "Bandaged · last chance"
		status_label.modulate = CRITICAL.lightened(0.3)
	elif info.borrowed:
		status_label.text = "Borrowed time"
		status_label.modulate = BORROWED.lightened(0.3)
	else:
		status_label.text = "Weak dose: +%ds" % Game.config.borrow_seconds
		status_label.modulate = Color.WHITE
	queue_redraw()


func _flash() -> bool:
	return fmod(_time * 6.0, 2.0) < 1.0


func _draw() -> void:
	var seated := patient != null and patient.occupied
	var matched := seated and patient.active and pot_kind == patient.info.cure
	_style.bg_color = BG if seated else EMPTY_BG
	_style.border_color = OUTLINE
	if matched:
		_style.border_color = MATCH
	elif seated and patient.is_critical() and _flash():
		_style.border_color = CRITICAL
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	if not seated:
		return
	# Clock bar: green, purple once they've borrowed, flashing red near zero.
	var fraction := clampf(patient.time_left / patient.clock_max, 0.0, 1.0)
	var color := BORROWED if patient.info.borrowed else CLOCK
	if patient.is_critical() and _flash():
		color = CRITICAL
	draw_rect(BAR_RECT, BAR_BACK)
	draw_rect(Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * fraction, BAR_RECT.size.y)), color)
	draw_rect(BAR_RECT, OUTLINE, false, 2.0)
