extends Node2D
## The clinic: wires critters -> selected pot -> click a patient, fills the chairs from
## the shift list, and keeps score and lives.

const BODY_ARTS: Array[String] = ["patient_body_a", "patient_body_b"]
## Which chairs (left, middle, right) open for 1, 2 or 3 chairs.
const CHAIR_LAYOUTS := [[1], [0, 2], [0, 1, 2]]
const HEART_SPACING := 40.0

var shift := 0
var score := 0
var cured := 0
var borrows := 0
var lives := 0
var queue: Array[PatientInfo] = []
var game_over := false

var _open: Array[Patient] = []
var _arrival_timer := 0.0
var _hearts: Array[ArtSprite] = []

@onready var cfg := Game.config
@onready var pots: Array[Pot] = [$Pots/Left, $Pots/Right]
@onready var selected_pot: Pot = pots[0]
@onready var chairs: Array[Patient] = [$Chairs/Left, $Chairs/Middle, $Chairs/Right]
@onready var cards: Array[PatientCard] = [$HUD/Root/Cards/Left, $HUD/Root/Cards/Middle, $HUD/Root/Cards/Right]
@onready var shift_label: Label = $HUD/Root/ShiftLabel
@onready var score_label: Label = $HUD/Root/ScoreLabel
@onready var hearts_root: Control = $HUD/Root/Hearts
@onready var toast_template: Label = $HUD/Root/Toast
@onready var game_over_panel: Control = $HUD/Root/GameOver
@onready var game_over_label: Label = $HUD/Root/GameOver/Box/Summary


func _ready() -> void:
	for critter: Critter in $Critters.get_children():
		critter.squeezed.connect(_pour)
	for pot in pots:
		pot.select_requested.connect(_select.bind(pot))
		pot.boiled_over.connect(func(): _toast("Boiled over! Brew it again", cfg.orange.lightened(0.3)))
	_select(selected_pot)
	for i in chairs.size():
		var p := chairs[i]
		p.clicked.connect(_on_patient_clicked.bind(p))
		p.resolved.connect(_on_patient_resolved.bind(p))
		p.gone.connect(_on_patient_gone)
		cards[i].patient = p
	$HUD/Root/GameOver/Box/Retry.pressed.connect(get_tree().reload_current_scene)
	game_over_panel.visible = false
	lives = cfg.lives
	_build_hearts()
	_add_score(0)
	_start_shift(1)


func _process(delta: float) -> void:
	if game_over:
		return
	var brews: Array[int] = []
	for pot in pots:
		if pot.can_serve():
			brews.append(pot.potion())
	for card in cards:
		card.pot_kinds = brews
		card.waiting = not queue.is_empty()
	_arrival_timer -= delta
	if _arrival_timer <= 0.0 and not queue.is_empty():
		var chair := _free_chair()
		if chair:
			var info: PatientInfo = queue.pop_front()
			chair.arrive(info)
			_arrival_timer = cfg.arrival_gap
			if info.emergency:
				Sfx.play("emergency")
				_toast("Emergency! Only %d s" % cfg.emergency_clock, cfg.red.lightened(0.3))


func _start_shift(number: int) -> void:
	shift = number
	shift_label.text = "Shift %d" % shift
	queue.clear()
	for i in cfg.patients_in_shift(shift):
		var p := PatientInfo.new()
		var secondary := randf() < cfg.secondary_chance(shift)
		p.cure = (Potion.SECONDARIES if secondary else Potion.PRIMARIES).pick_random()
		p.clock = cfg.clock_for_shift(shift)
		if randf() < cfg.emergency_for_shift(shift):
			p.emergency = true
			p.clock = cfg.emergency_clock
		p.ailment = cfg.ailments[randi() % cfg.ailments.size()]
		p.body_art = BODY_ARTS.pick_random()
		queue.append(p)
	_open.clear()
	for i in CHAIR_LAYOUTS[cfg.chairs_for_shift(shift) - 1]:
		_open.append(chairs[i])
	for i in chairs.size():
		cards[i].visible = chairs[i] in _open
	_arrival_timer = cfg.first_arrival_delay
	Sfx.play("shift_start")
	_toast("Shift %d" % shift, Color.WHITE)


func _free_chair() -> Patient:
	for p in _open:
		if not p.occupied:
			return p
	return null


func _select(pot: Pot) -> void:
	selected_pot = pot
	for other in pots:
		other.selected = other == pot


func _pour(kind: int) -> void:
	selected_pot.pour(kind)


func _on_patient_clicked(button: MouseButton, p: Patient) -> void:
	if button != MOUSE_BUTTON_LEFT or game_over or not p.active:
		return
	if selected_pot.is_empty():
		_toast("This pot is empty", Color.WHITE)
		return
	if not selected_pot.can_serve():
		_toast("Still raw: let it boil" if selected_pot.burner_on else "Turn the burner on", Color.WHITE)
		return
	_serve(p)


## Gives the selected pot's brew to `p`. A weak potion for someone who already borrowed
## stays in the pot.
func _serve(p: Patient) -> void:
	var pot := selected_pot
	var kind := pot.potion()
	var quality := pot.quality()
	var result := p.serve(kind, quality)
	if result == Patient.Serve.ALREADY_BORROWED:
		_toast("Already borrowed: needs a perfect cure", cfg.orange.lightened(0.3))
		return
	pot.take()
	Sfx.play("give")
	match result:
		Patient.Serve.BORROWED:
			borrows += 1
			_toast("+%d s borrowed time" % cfg.borrow_seconds, cfg.purple.lightened(0.3))
		Patient.Serve.REFUSED:
			_add_score(cfg.score_wrong)
			_toast("Ugh! Wrong potion −%d s" % cfg.wrong_serve_penalty, cfg.red.lightened(0.3))


func _on_patient_resolved(outcome: Patient.Outcome, p: Patient) -> void:
	if game_over:
		return
	match outcome:
		Patient.Outcome.CURED:
			cured += 1
			var base := cfg.score_after_borrow if p.info.borrowed else cfg.score_perfect
			var points := base + int(p.time_left) * cfg.score_per_second_left
			_add_score(points)
			_toast("Cured! +%d" % points, cfg.green.lightened(0.3))
		Patient.Outcome.BANDAGED:
			_rebook(p.info)
			_toast("Out of borrowed time… they'll be back worse", cfg.orange.lightened(0.3))
		Patient.Outcome.DIED:
			_lose_life()


func _on_patient_gone() -> void:
	if game_over or not queue.is_empty():
		return
	for p in chairs:
		if p.occupied:
			return
	_start_shift(shift + 1)


## A patient who ran out of borrowed time comes back one tier harder.
## They come back as a copy so the leaving patient's card doesn't change colour.
func _rebook(old: PatientInfo) -> void:
	var p := old.duplicate_info()
	p.bandaged = true
	p.emergency = false  # they come back bandaged instead, on a normal clock
	if Potion.is_primary(p.cure):
		p.cure = Potion.secondaries_with(p.cure).pick_random()
		p.clock = cfg.clock_for_shift(shift)
	else:
		# TODO: secondaries become bosses once bosses exist. Until then, a shorter clock.
		p.clock = maxf(cfg.min_clock, cfg.clock_for_shift(shift) * cfg.bandage_clock_multiplier)
	queue.insert(mini(cfg.bandage_return_after, queue.size()), p)


func _lose_life() -> void:
	lives -= 1
	var heart := _hearts[lives]
	heart.self_modulate = Color(0.3, 0.27, 0.35)
	heart.scale = Vector2.ONE * 1.6
	heart.create_tween().tween_property(heart, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	_shake_screen()
	if lives <= 0:
		_end_game()
	else:
		_toast("Lost a patient! %d %s left" % [lives, "life" if lives == 1 else "lives"], cfg.red.lightened(0.3))


func _end_game() -> void:
	game_over = true
	for p in chairs:
		p.freeze()
	Sfx.play("game_over")
	game_over_label.text = "You made it to Shift %d\n\nScore %d\nCured %d · Borrows %d" % [shift, score, cured, borrows]
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	create_tween().tween_property(game_over_panel, "modulate:a", 1.0, 0.4).set_delay(0.8)


func _build_hearts() -> void:
	var left := -HEART_SPACING * (cfg.lives - 1) * 0.5
	for i in cfg.lives:
		var heart := ArtSprite.new()
		heart.art_name = "icon_heart"
		heart.size = Vector2(30, 28)
		heart.shape = ArtSprite.Shape.ELLIPSE
		heart.placeholder_color = Color.WHITE
		heart.self_modulate = cfg.red
		heart.show_name = false
		heart.position = Vector2(left + i * HEART_SPACING, 0)
		hearts_root.add_child(heart)
		_hearts.append(heart)


func _shake_screen() -> void:
	var t := create_tween()
	for offset in [Vector2(12, -6), Vector2(-10, 8), Vector2(6, -4), Vector2.ZERO]:
		t.tween_property(self, "position", offset, 0.05)


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
