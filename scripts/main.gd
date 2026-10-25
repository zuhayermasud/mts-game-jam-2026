extends Node2D
## The clinic: wires critters -> pot -> right-click a patient, fills the chairs from
## the shift list, and keeps score and lives.

const BODY_ARTS: Array[String] = ["patient_body_a", "patient_body_b"]
## Which chairs (left, middle, right) open for 1, 2 or 3 chairs.
const CHAIR_LAYOUTS := [[1], [0, 2], [0, 1, 2]]
const HEART_SPACING := 40.0
## How long the potion flies from the pot to a patient. Cosmetic: the serve is decided on the click.
const FLIGHT_TIME := 0.25
const FLIGHT_ARC := 120.0

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
## The pulled brew, carried on the cursor until you right-click a patient.
var _held: ArtSprite
## Wrong serves still flying back to the cursor. The held blob hides until they land.
var _bouncing := 0

@onready var cfg := Game.config
@onready var pot: Pot = $Pot
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
	pot.boiled_over.connect(func(): _toast("Boiled over! Brew it again", cfg.orange.lightened(0.3)))
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
	_held = _make_blob()
	_held.visible = false
	_start_shift(1)


func _process(delta: float) -> void:
	_held.visible = pot.can_serve() and _bouncing == 0 and not game_over
	if _held.visible:
		_held.global_position = get_global_mouse_position()
		_held.self_modulate = cfg.potion_color(pot.potion())
	if game_over:
		return
	var brews: Array[int] = []
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
	Game.shift = number
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


func _pour(kind: int) -> void:
	pot.pour(kind)


## A left click anywhere that nothing else took (not a critter or a button) pulls the pot,
## so you never have to move the mouse back to the pot to stop the needle.
func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pot.pull()


## Left-click a patient = pull, like anywhere else. Right-click = give them the pot.
func _on_patient_clicked(button: MouseButton, p: Patient) -> void:
	if game_over or not p.active:
		return
	if button == MOUSE_BUTTON_LEFT:
		pot.pull()
		return
	if button != MOUSE_BUTTON_RIGHT:
		return
	if pot.is_empty():
		_toast("The pot is empty", Color.WHITE)
		return
	# Right-clicking a patient while it boils pulls the brew right now and serves it.
	# Pulling in the red boils it over (the boiled_over toast covers that).
	if pot.is_boiling() and not pot.pull():
		if not pot.is_empty():
			_toast("Still heating…", Color.WHITE)
		return
	_serve(p)


## Gives the pot's brew to `p`. A wrong potion is refused and bounces back into the pot.
func _serve(p: Patient) -> void:
	var kind := pot.potion()
	var result := p.serve(kind, pot.quality(), FLIGHT_TIME)
	Sfx.play("give")
	if result == Patient.Serve.REFUSED:
		_fly_potion(p, kind, true)
		_add_score(cfg.score_wrong)
		_toast("Wrong potion −%d s · it bounces back" % cfg.wrong_serve_penalty, cfg.red.lightened(0.3))
		return
	pot.take()
	_fly_potion(p, kind, false)
	if result == Patient.Serve.BORROWED:
		borrows += 1
		var n := p.info.borrows
		_toast("+%d s borrowed (next +%d s)" % [cfg.borrow_for(n - 1), cfg.borrow_for(n)], cfg.purple.lightened(0.3))


## The held blob arcs from the cursor to `p`. With `bounce` it arcs back to the cursor.
func _fly_potion(p: Patient, kind: int, bounce: bool) -> void:
	var blob := _make_blob()
	blob.self_modulate = cfg.potion_color(kind)
	var from := get_global_mouse_position()
	var to := p.global_position + Vector2(0, -60)
	blob.global_position = from
	var t := blob.create_tween()
	_tween_arc(t, blob, from, to)
	t.tween_callback(Sfx.play.bind("splash"))
	if bounce:
		_bouncing += 1
		_tween_arc(t, blob, to, from)
		t.tween_callback(func():
			_bouncing -= 1
			_held.scale = Vector2(1.3, 0.75)
			_held.create_tween().tween_property(_held, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC))
	t.tween_callback(blob.queue_free)


func _make_blob() -> ArtSprite:
	var blob := ArtSprite.new()
	blob.art_name = "potion_blob"
	blob.shape = ArtSprite.Shape.ELLIPSE
	blob.size = Vector2(36, 36)
	blob.placeholder_color = Color.WHITE
	blob.show_name = false
	blob.z_index = 10
	add_child(blob)
	return blob


func _tween_arc(t: Tween, blob: Node2D, from: Vector2, to: Vector2) -> void:
	var step := func(k: float):
		blob.global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * FLIGHT_ARC)
		# A little stretch at the top of the arc, back to round as it lands.
		var s := 1.0 + 0.25 * sin(k * PI)
		blob.scale = Vector2(2.0 - s, s)
	t.tween_method(step, 0.0, 1.0, FLIGHT_TIME)


func _on_patient_resolved(outcome: Patient.Outcome, p: Patient) -> void:
	if game_over:
		return
	match outcome:
		Patient.Outcome.CURED:
			cured += 1
			var base := cfg.score_after_borrow if p.info.has_borrowed() else cfg.score_perfect
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
