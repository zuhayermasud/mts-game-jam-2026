extends Node2D
## The clinic: wires critters -> pot -> GIVE -> patient, runs the shift list and keeps score.

const BODY_ARTS: Array[String] = ["patient_body_a", "patient_body_b"]

var shift := 0
var score := 0
var cured := 0
var borrows := 0
var queue: Array[PatientInfo] = []
var game_over := false

@onready var cfg := Game.config
@onready var pot: Pot = $Pot
@onready var patient: Patient = $Patient
@onready var give_button: Button = $GiveButton
@onready var shift_label: Label = $HUD/Root/ShiftLabel
@onready var score_label: Label = $HUD/Root/ScoreLabel
@onready var toast_template: Label = $HUD/Root/Toast
@onready var game_over_panel: Control = $HUD/Root/GameOver
@onready var game_over_label: Label = $HUD/Root/GameOver/Box/Summary


func _ready() -> void:
	for critter: Critter in $Critters.get_children():
		critter.squeezed.connect(pot.pour)
	give_button.pressed.connect(_on_give)
	patient.resolved.connect(_on_patient_resolved)
	patient.gone.connect(_next_patient)
	$HUD/Root/GameOver/Box/Retry.pressed.connect(get_tree().reload_current_scene)
	game_over_panel.visible = false
	_add_score(0)
	_start_shift(1)


func _process(_delta: float) -> void:
	give_button.disabled = pot.is_empty() or not patient.active


func _start_shift(number: int) -> void:
	shift = number
	shift_label.text = "Shift %d" % shift
	queue.clear()
	for i in cfg.patients_in_shift(shift):
		var p := PatientInfo.new()
		var secondary := randf() < cfg.secondary_chance(shift)
		p.cure = (Potion.SECONDARIES if secondary else Potion.PRIMARIES).pick_random()
		p.clock = cfg.clock_for_shift(shift)
		p.ailment = cfg.ailments[randi() % cfg.ailments.size()]
		p.body_art = BODY_ARTS.pick_random()
		queue.append(p)
	Sfx.play("shift_start")
	_toast("Shift %d" % shift, Color.WHITE)
	_next_patient()


func _next_patient() -> void:
	if game_over:
		return
	if queue.is_empty():
		_start_shift(shift + 1)
		return
	patient.arrive(queue.pop_front())


func _on_give() -> void:
	if pot.is_empty() or not patient.active:
		return
	var brew := pot.take()
	Sfx.play("give")
	match patient.serve(brew.kind, brew.quality):
		Patient.Serve.BORROWED:
			borrows += 1
			_toast("+%d s borrowed time" % cfg.borrow_seconds, cfg.purple.lightened(0.3))
		Patient.Serve.REFUSED:
			_add_score(cfg.score_wrong)
			var why := "Overcooked!" if brew.quality == Potion.Quality.OVERCOOKED else "Wrong potion!"
			_toast("Ugh! %s −%d s" % [why, cfg.wrong_serve_penalty], cfg.red.lightened(0.3))
		Patient.Serve.ALREADY_BORROWED:
			_toast("Already borrowed — needs a perfect cure", cfg.orange.lightened(0.3))


func _on_patient_resolved(outcome: Patient.Outcome) -> void:
	match outcome:
		Patient.Outcome.CURED:
			cured += 1
			var base := cfg.score_after_borrow if patient.info.borrowed else cfg.score_perfect
			var points := base + int(patient.time_left) * cfg.score_per_second_left
			_add_score(points)
			_toast("Cured! +%d" % points, cfg.green.lightened(0.3))
		Patient.Outcome.BANDAGED:
			_rebook(patient.info)
			_toast("Out of borrowed time… they'll be back worse", cfg.orange.lightened(0.3))
		Patient.Outcome.DIED:
			_end_game()


## A patient who ran out of borrowed time comes back one tier harder.
func _rebook(p: PatientInfo) -> void:
	p.bandaged = true
	if Potion.is_primary(p.cure):
		p.cure = Potion.secondaries_with(p.cure).pick_random()
		p.clock = cfg.clock_for_shift(shift)
	else:
		# TODO: secondaries become bosses once bosses exist. Until then, a shorter clock.
		p.clock = maxf(cfg.min_clock, cfg.clock_for_shift(shift) * cfg.bandage_clock_multiplier)
	queue.insert(mini(cfg.bandage_return_after, queue.size()), p)


func _end_game() -> void:
	game_over = true
	Sfx.play("game_over")
	game_over_label.text = "You made it to Shift %d\n\nScore %d\nCured %d · Borrows %d" % [shift, score, cured, borrows]
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	create_tween().tween_property(game_over_panel, "modulate:a", 1.0, 0.4).set_delay(0.8)


func _add_score(points: int) -> void:
	score += points
	score_label.text = "Score %d" % score


func _toast(text: String, color: Color) -> void:
	var toast: Label = toast_template.duplicate()
	toast.text = text
	toast.modulate = color
	toast.visible = true
	toast_template.get_parent().add_child(toast)
	var t := toast.create_tween()
	t.tween_property(toast, "position:y", toast.position.y - 80, 1.2).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(toast, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(toast.queue_free)
