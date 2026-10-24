class_name Patient
extends Clickable
## A patient in one of the chairs. Every seated patient's clock ticks at the same time.
## Click them to serve the pot. Their status card at the top of the screen reads from here.
## `resolved` fires the moment the outcome is decided (for score and lives),
## `gone` fires after the leave animation (the chair is free again).

signal resolved(outcome: Outcome)
signal gone

enum Outcome { CURED, BANDAGED, DIED }
enum Serve { CURED, BORROWED, REFUSED, ALREADY_BORROWED }

var info: PatientInfo
var time_left := 0.0
## Clock length the timer bar is measured against. Grows when time is borrowed.
var clock_max := 1.0
## Clock is ticking and they accept potions.
var active := false
## Someone is in this chair (including walking in and out).
var occupied := false
## How this visit ended, or -1 while it's still going. Shown on the card as they leave.
var outcome := -1

var _home: Vector2
var _time := randf() * TAU
var _move_tween: Tween
var _shake_tween: Tween

@onready var body: ArtSprite = $Body
@onready var face: ArtSprite = $Body/Face
@onready var bandage: ArtSprite = $Body/Bandage


func _ready() -> void:
	_home = position
	visible = false


func is_clickable() -> bool:
	return active and super()


func is_critical() -> bool:
	return active and time_left <= Game.config.critical_seconds


func arrive(patient: PatientInfo) -> void:
	info = patient
	time_left = patient.clock
	clock_max = patient.clock
	active = false
	occupied = true
	outcome = -1
	body.art_name = patient.body_art
	body.self_modulate = Game.config.potion_color(patient.cure)
	bandage.visible = patient.bandaged
	_set_face("face_calm")
	Sfx.play("patient_arrive")

	# Pop up from behind the counter.
	visible = true
	position = _home + Vector2(0, 260)
	modulate.a = 1.0
	scale = Vector2.ONE
	_move(func(t: Tween):
		t.tween_property(self, "position", _home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): active = true))


func serve(kind: int, quality: int) -> Serve:
	if kind != info.cure:
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
	body.scale = Vector2(1.15, 0.9)
	create_tween().tween_property(body, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
	return Serve.BORROWED


## Stops the clock for good, e.g. on game over.
func freeze() -> void:
	active = false


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
		return
	if is_critical():
		_set_face("face_critical")
	elif time_left / clock_max <= Game.config.worried_fraction:
		_set_face("face_worried")
	else:
		_set_face("face_calm")


func _set_face(art: String) -> void:
	if face.art_name != art:
		face.art_name = art


func _resolve(result: Outcome) -> void:
	active = false
	outcome = result
	resolved.emit(result)
	var down := _home + Vector2(0, 260)
	match result:
		Outcome.CURED:
			_set_face("face_cured")
			Sfx.play("cure")
			_move(func(t: Tween):
				t.tween_property(self, "scale", Vector2.ONE * 1.15, 0.12)
				t.tween_property(self, "scale", Vector2.ONE, 0.15)
				t.tween_interval(0.25)
				t.tween_property(self, "position", down, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN))
		Outcome.BANDAGED:
			bandage.visible = true
			_set_face("face_worried")
			Sfx.play("bandaged")
			_move(func(t: Tween):
				t.tween_interval(0.5)
				t.tween_property(self, "position", down, 0.6).set_trans(Tween.TRANS_SINE))
		Outcome.DIED:
			_set_face("face_dead")
			Sfx.play("death")
			_move(func(t: Tween):
				t.tween_interval(0.4)
				t.tween_property(self, "modulate:a", 0.0, 0.8)
				t.parallel().tween_property(self, "position", _home + Vector2(0, 60), 0.8))
	_move_tween.tween_callback(func():
		visible = false
		occupied = false
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
