class_name Patient
extends Node2D
## The active patient. Only their clock ticks.
## `resolved` fires the moment the outcome is decided (for score and game over),
## `gone` fires after the walk-out animation (to bring in the next patient).

signal resolved(outcome: Outcome)
signal gone

enum Outcome { CURED, BANDAGED, DIED }
enum Serve { CURED, BORROWED, REFUSED, ALREADY_BORROWED }

@export var clock_color := Color(0.95, 0.95, 1.0)
@export var borrowed_clock_color := Color(0.75, 0.55, 1.0)
@export var critical_clock_color := Color(1.0, 0.25, 0.25)

var info: PatientInfo
var time_left := 0.0
## Clock length the ring is measured against. Grows when time is borrowed.
var clock_max := 1.0
var active := false

var _home: Vector2
var _time := 0.0
var _move_tween: Tween
var _shake_tween: Tween

@onready var body: ArtSprite = $Body
@onready var face: ArtSprite = $Body/Face
@onready var bandage: ArtSprite = $Body/Bandage
@onready var bubble: Node2D = $Bubble
@onready var clock_ring: RingGauge = $Bubble/ClockRing
@onready var icon: ArtSprite = $Bubble/Icon
@onready var time_label: Label = $Bubble/Time
@onready var ailment_label: Label = $Bubble/Ailment


func _ready() -> void:
	_home = position
	visible = false


func arrive(patient: PatientInfo) -> void:
	info = patient
	time_left = patient.clock
	clock_max = patient.clock
	active = false
	var tint := Game.config.potion_color(patient.cure)
	body.art_name = patient.body_art
	body.self_modulate = tint
	icon.art_name = "icon_" + Potion.art_suffix(patient.cure)
	icon.self_modulate = tint
	bandage.visible = patient.bandaged
	ailment_label.text = patient.ailment
	_update_clock()
	Sfx.play("patient_arrive")

	visible = true
	position = _home + Vector2(520, 0)
	modulate.a = 0.0
	scale = Vector2.ONE
	bubble.scale = Vector2.ZERO
	_move(func(t: Tween):
		t.tween_property(self, "position", _home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
		t.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): active = true))


func serve(kind: int, quality: int) -> Serve:
	if kind != info.cure or quality == Potion.Quality.OVERCOOKED:
		time_left = maxf(time_left - Game.config.wrong_serve_penalty, 0.0)
		Sfx.play("refuse")
		_shake()
		return Serve.REFUSED
	if quality == Potion.Quality.PERFECT:
		_resolve(Outcome.CURED)
		return Serve.CURED
	if info.borrowed:
		Sfx.play("refuse")
		_shake()
		return Serve.ALREADY_BORROWED
	info.borrowed = true
	time_left += Game.config.borrow_seconds
	clock_max = maxf(clock_max, time_left)
	Sfx.play("borrow")
	clock_ring.scale = Vector2.ONE * 1.25
	create_tween().tween_property(clock_ring, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
	return Serve.BORROWED


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	body.position.y = sin(_time * 2.0) * 5.0
	if not active:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		# Out of borrowed time -> bandage and come back worse. Otherwise -> dead.
		_resolve(Outcome.BANDAGED if info.borrowed and not info.bandaged else Outcome.DIED)
	_update_clock()


func _update_clock() -> void:
	clock_ring.fraction = time_left / clock_max
	time_label.text = str(ceili(time_left))
	var critical := time_left <= Game.config.critical_seconds
	if critical:
		var flash := fmod(_time * 6.0, 2.0) < 1.0
		clock_ring.color = critical_clock_color if flash else clock_color
	else:
		clock_ring.color = borrowed_clock_color if info.borrowed else clock_color
	if active:
		if critical:
			_set_face("face_critical")
		elif time_left / clock_max <= Game.config.worried_fraction:
			_set_face("face_worried")
		else:
			_set_face("face_calm")


func _set_face(art: String) -> void:
	if face.art_name != art:
		face.art_name = art


func _resolve(outcome: Outcome) -> void:
	active = false
	resolved.emit(outcome)
	match outcome:
		Outcome.CURED:
			_set_face("face_cured")
			Sfx.play("cure")
			_move(func(t: Tween):
				t.tween_property(self, "scale", Vector2.ONE * 1.15, 0.12)
				t.tween_property(self, "scale", Vector2.ONE, 0.15)
				t.tween_interval(0.25)
				t.tween_property(self, "position", _home + Vector2(-520, 0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN))
		Outcome.BANDAGED:
			bandage.visible = true
			_set_face("face_worried")
			Sfx.play("bandaged")
			_move(func(t: Tween):
				t.tween_interval(0.5)
				t.tween_property(self, "position", _home + Vector2(-520, 0), 0.6).set_trans(Tween.TRANS_SINE))
		Outcome.DIED:
			_set_face("face_dead")
			Sfx.play("death")
			_move(func(t: Tween):
				t.tween_interval(0.4)
				t.tween_property(self, "modulate:a", 0.0, 0.8)
				t.parallel().tween_property(self, "position", _home + Vector2(0, 60), 0.8))
	_move_tween.tween_callback(func():
		visible = false
		gone.emit())


func _move(build: Callable) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	build.call(_move_tween)


func _shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for x in [-14.0, 14.0, -8.0, 8.0, 0.0]:
		_shake_tween.tween_property(body, "position:x", x, 0.05)
