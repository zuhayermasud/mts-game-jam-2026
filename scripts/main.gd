extends Node2D
## The clinic: wires critters -> pot -> click a patient, fills the chairs from
## the shift list, and keeps score, lives and the perfect streak.
## The pot lights itself after a pour; a left-click anywhere pulls it, and a click on a patient
## always means serve (pulling a boiling pot first if needed).

## Patient bodies: white 32x32 pixel creatures in assets/creatures/, tinted with the cure colour.
const CREATURE_COUNT := 64
## Which chairs (left, middle, right) open for 1, 2 or 3 chairs.
const CHAIR_LAYOUTS := [[1], [0, 2], [0, 1, 2]]
const HEART_SPACING := 44.0
## icon_heart.png is a strip from empty (frame 0) to full. Losing a life plays it full to empty.
const HEART_FRAMES := 5
const HEART_DRAIN_TIME := 0.6
## How long the potion flies from the pot to a patient. Cosmetic: the serve is decided on the click.
const FLIGHT_TIME := 0.25
const FLIGHT_ARC := 120.0
## Seconds a pulled brew takes to hop from the pot's mouth up to the cursor.
const LIFT_TIME := 0.12
const POT_MOUTH := Vector2(0, -50)
## A picked mushroom's flight into the stump: seconds, arc height and how small it ends up.
const PICK_TIME := 0.35
const PICK_ARC := 240.0
const PICK_SCALE := 0.55
const PICK_END_SCALE := 0.25
## Pitch the perfect chime rises per streak step, and the most steps it rises.
const STREAK_PITCH_STEP := 0.06
const STREAK_PITCH_MAX := 8
## Pixels of screen jitter at full danger.
const DANGER_JITTER := 6.0
## The "sound" item is the speaker icon; _with_sound() picks on or off.
const TITLE_ITEMS := [["play", "Play"], ["tutorial", "Tutorial"], ["sound", "Sound", {}]]
const PAUSE_ITEMS := [["continue", "Continue"], ["restart", "Restart"], ["sound", "Sound", {}], ["home", "Home"]]
const GAME_OVER_ITEMS := [["restart", "Retry"], ["home", "Back"]]
const TUTORIAL := "A patient's colour is their cure.\n" \
		+ "Click a critter (Z X C) to pour. Red + yellow = orange, yellow + blue = green, " \
		+ "red + blue = purple.\n" \
		+ "Click anywhere when the needle is in the gold, then click the patient.\n" \
		+ "Off the gold is a weak dose: it lends them time, less each loan. " \
		+ "Never pull in the red!\n" \
		+ "Wrong brew? Feed it to the slime (V) to empty the pot."

var shift := 0
var score := 0
var cured := 0
var borrows := 0
var lives := 0
var queue: Array[PatientInfo] = []
var game_over := false
## Shuffled creature art still to hand out, so nobody repeats until all have been seen.
var _creature_deck: Array[String] = []

var _open: Array[Patient] = []
var _arrival_timer := 0.0
var _hearts: Array[ArtSprite] = []
## The pulled brew, carried on the cursor until you click a patient.
var _held: ArtSprite
## Wrong serves still flying back to the cursor. The held blob hides until they land.
var _bouncing := 0
## 0 when the brew was just pulled (blob at the pot's mouth), 1 once it rides on the cursor.
var _lift := 1.0
## Perfect cures in a row. Any other serve or a boil-over resets it.
var _streak := 0
## The title screen and the pause menu (Esc or P).
var _menu: MenuPanel
## Offset from the screen-shake tween. The danger jitter is added on top every frame.
var _kick := Vector2.ZERO
## Red edges that swell as a patient runs out of time.
var _vignette: TextureRect
var _heartbeat := 0.0
## 1 on each heartbeat, fading to 0. Pulses the vignette.
var _beat_pulse := 0.0

@onready var cfg := Game.config
@onready var pot: Pot = $Pot
@onready var sink: Sink = $Sink
@onready var chairs: Array[Patient] = [$Chairs/Left, $Chairs/Middle, $Chairs/Right]
@onready var cards: Array[PatientCard] = [$HUD/Root/Cards/Left, $HUD/Root/Cards/Middle, $HUD/Root/Cards/Right]
@onready var shift_label: Label = $HUD/Root/ShiftLabel
@onready var score_label: Label = $HUD/Root/ScoreLabel
@onready var hearts_root: Control = $HUD/Root/Hearts
@onready var toast_template: Label = $HUD/Root/Toast
@onready var settings_button: TextureButton = $HUD/Root/Settings
@onready var sound_button: TextureButton = $HUD/Root/Sound


func _ready() -> void:
	for critter: Critter in $Critters.get_children():
		critter.squeezed.connect(_pour.bind(critter))
	pot.boiled_over.connect(_on_boiled_over)
	sink.used.connect(_on_sink_used)
	pot.pulled.connect(_on_pulled)
	for i in chairs.size():
		var p := chairs[i]
		p.clicked.connect(_on_patient_clicked.bind(p))
		p.resolved.connect(_on_patient_resolved.bind(p))
		p.gone.connect(_on_patient_gone)
		cards[i].patient = p
	settings_button.texture_normal = load("res://assets/ui/icon_settings.png")
	settings_button.pressed.connect(_on_settings_pressed)
	sound_button.pressed.connect(Sfx.toggle_mute)
	for b in [settings_button, sound_button]:
		b.mouse_entered.connect(_hover_icon.bind(b, true))
		b.mouse_exited.connect(_hover_icon.bind(b, false))
	lives = cfg.lives
	_build_hearts()
	_add_score(0)
	_held = _make_blob()
	_held.visible = false
	_build_vignette()
	_menu = MenuPanel.new()
	add_child(_menu)
	_menu.chosen.connect(_on_menu_chosen)
	Sfx.muted_changed.connect(_show_mute)
	_show_mute(Sfx.muted)
	if Game.show_title:
		get_tree().paused = true
		$HUD/Root.modulate.a = 0.0
		if Game.show_intro:
			Game.show_intro = false
			var intro := Intro.new()
			add_child(intro)
			intro.finished.connect(_open_title)
		else:
			_open_title()
	else:
		_start_shift(1)


func _open_title() -> void:
	_menu.open(_with_sound(TITLE_ITEMS), {heading = "logo", title = "Clinic Open"},
			MenuPanel.Style.UNROLL)


func _process(delta: float) -> void:
	_held.visible = pot.can_serve() and _bouncing == 0 and not game_over
	_lift = minf(1.0, _lift + delta / LIFT_TIME)
	var k := 1.0 - (1.0 - _lift) * (1.0 - _lift)  # ease out
	_held.global_position = _pot_mouth().lerp(get_global_mouse_position(), k)
	if _held.visible:
		_held.self_modulate = cfg.potion_color(pot.potion())
	_update_danger(delta)
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


## The most urgent open chair drives the vignette, the screen jitter and the heartbeat.
func _update_danger(delta: float) -> void:
	var danger := 0.0
	if not game_over:
		for p in _open:
			danger = maxf(danger, p.danger())
	_beat_pulse = maxf(0.0, _beat_pulse - delta * 4.0)
	if danger > 0.0:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			Sfx.play("heartbeat", 0.0, lerpf(1.0, 1.3, danger), lerpf(-8.0, 0.0, danger))
			_heartbeat = lerpf(cfg.heartbeat_slow, cfg.heartbeat_fast, danger)
			_beat_pulse = 1.0
	else:
		_heartbeat = 0.0  # the first beat lands as soon as danger starts
	_vignette.modulate.a = danger * (0.55 + 0.25 * _beat_pulse)
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * DANGER_JITTER * danger
	position = _kick + jitter


func _start_shift(number: int) -> void:
	shift = number
	Game.shift = number
	shift_label.text = "Shift %d" % shift
	queue.clear()
	for i in cfg.patients_in_shift(shift):
		var p := PatientInfo.new()
		p.emergency = randf() < cfg.emergency_for_shift(shift)
		# Emergencies always need a primary: one pour gets them a weak dose in time.
		var secondary := not p.emergency and randf() < cfg.secondary_chance(shift)
		p.cure = (Potion.SECONDARIES if secondary else Potion.PRIMARIES).pick_random()
		p.clock = cfg.emergency_clock if p.emergency else cfg.clock_for_shift(shift)
		p.ailment = cfg.ailments[randi() % cfg.ailments.size()]
		p.body_art = _next_creature()
		queue.append(p)
	_open.clear()
	for i in CHAIR_LAYOUTS[cfg.chairs_for_shift(shift) - 1]:
		_open.append(chairs[i])
	for i in chairs.size():
		cards[i].visible = chairs[i] in _open
	_arrival_timer = cfg.first_arrival_delay
	Sfx.play("shift_start")
	_toast("Shift %d" % shift, Color.WHITE)


func _next_creature() -> String:
	if _creature_deck.is_empty():
		for i in CREATURE_COUNT:
			_creature_deck.append("creatures/creature_%03d" % (i + 1))
		_creature_deck.shuffle()
	return _creature_deck.pop_back()


func _free_chair() -> Patient:
	for p in _open:
		if not p.occupied:
			return p
	return null


func _unhandled_key_input(event: InputEvent) -> void:
	if game_over or _menu.is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_P):
		get_viewport().set_input_as_handled()
		pause()


func pause() -> void:
	get_tree().paused = true
	_menu.open(_with_sound(PAUSE_ITEMS), {title_art = "menu_title_pause", cancel = "continue"})


func _on_menu_chosen(id: String) -> void:
	match id:
		"play", "continue":
			await _menu.close()
			get_tree().paused = false
			if id == "play":
				create_tween().tween_property($HUD/Root, "modulate:a", 1.0, 0.3)
				_start_shift(1)
		"restart":
			await _menu.close()
			_restart(false)
		"home":
			await _menu.close()
			_restart(true)
		"tutorial":
			_menu.show_page([["back", "Back", {small = true}]], {title = "How to Play", body = TUTORIAL, cancel = "back"})
		"back":
			_menu.show_page(_with_sound(TITLE_ITEMS), {title = "Clinic Open"})
		"sound":
			Sfx.toggle_mute()  # _show_mute() swaps the icon here and on the HUD


func _with_sound(items: Array) -> Array:
	var out := items.duplicate(true)
	for item in out:
		if item[0] == "sound":
			item[2].icon = _sound_icon(Sfx.muted)
	return out


func _sound_icon(muted: bool) -> String:
	return "icon_sound_off" if muted else "icon_sound_on"


func _on_settings_pressed() -> void:
	if not game_over and not _menu.is_open:
		Sfx.play("ui_click", 0.0)
		pause()


func _hover_icon(b: TextureButton, on: bool) -> void:
	b.create_tween().tween_property(b, "scale", Vector2.ONE * (1.15 if on else 1.0), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _restart(to_title: bool) -> void:
	Game.show_title = to_title
	get_tree().paused = false
	get_tree().reload_current_scene()


func _pour(kind: int, critter: Critter) -> void:
	if pot.pour(kind):
		_fly_mushroom(critter)


## A mushroom hops off the patch, spins along a curve and drops into the stump's hollow.
## Purely cosmetic: the colour is already in the pot.
func _fly_mushroom(critter: Critter) -> void:
	var m := critter.make_copy()
	m.z_index = 10
	add_child(m)
	var from := critter.hit.global_position + Vector2(0, -20)
	var to := _pot_mouth()
	# Lean the curve sideways toward the pot so it reads as a toss, not a straight hop.
	var control := from.lerp(to, 0.5) + Vector2((to.x - from.x) * 0.2, -PICK_ARC)
	var spin := signf(to.x - from.x if to.x != from.x else 1.0) * TAU
	var step := func(k: float):
		var a := from.lerp(control, k)
		var b := control.lerp(to, k)
		m.global_position = a.lerp(b, k)
		m.rotation = spin * k
		m.scale = Vector2.ONE * lerpf(PICK_SCALE, PICK_END_SCALE, k * k)
	step.call(0.0)
	var t := m.create_tween()
	t.tween_method(step, 0.0, 1.0, PICK_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_callback(pot.plop)
	t.tween_callback(m.queue_free)


## The sink empties the pot at any stage: heating, boiling or pulled.
func _on_sink_used() -> void:
	if game_over:
		return
	if pot.is_empty():
		sink.refuse()
		return
	sink.drain(cfg.potion_color(pot.potion()))
	pot.dump()


## A left click anywhere that nothing else took (not a critter or a button) pulls the pot,
## so you never have to move the mouse back to it.
func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pot.pull()


## Left-click a patient: always a serve.
func _on_patient_clicked(button: MouseButton, p: Patient) -> void:
	if game_over or not p.active or button != MOUSE_BUTTON_LEFT:
		return
	if pot.is_empty():
		_toast("The pot is empty", Color.WHITE)
		return
	# Clicking a patient while it boils pulls the brew right now and serves it.
	# Pulling in the red boils it over (the boiled_over toast covers that).
	# Still counting in, or raw: nothing to serve yet.
	if not pot.is_set() and not pot.pull():
		if not pot.is_empty():
			_toast("Still heating…", Color.WHITE)
		return
	_serve(p)


func _on_pulled(quality: int) -> void:
	_lift = 0.0
	if quality == Potion.Quality.PERFECT:
		Sfx.play("brew_perfect", 0.0, 1.0 + STREAK_PITCH_STEP * mini(_streak, STREAK_PITCH_MAX))


func _on_boiled_over() -> void:
	_streak = 0
	_toast("Boiled over! Brew it again", cfg.orange.lightened(0.3))


func _pot_mouth() -> Vector2:
	return pot.global_position + POT_MOUTH


## Gives the pot's brew to `p`. A wrong potion is refused and bounces back into the pot.
func _serve(p: Patient) -> void:
	var kind := pot.potion()
	var quality := pot.quality()
	var near_miss := pot.near_miss
	# Set before serving: a cure resolves (and scores the streak) inside p.serve().
	_streak = _streak + 1 if kind == p.info.cure and quality == Potion.Quality.PERFECT else 0
	var result := p.serve(kind, quality, FLIGHT_TIME)
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
		var text := "+%d s borrowed (next +%d s)" % [cfg.borrow_for(n - 1), cfg.borrow_for(n)]
		_toast(("So close! " + text) if near_miss else text, cfg.purple.lightened(0.3))


## The held blob arcs from where it is now to `p`: from the cursor, or from the pot when the
## brew was pulled by this very click. With `bounce` it arcs back to the cursor.
func _fly_potion(p: Patient, kind: int, bounce: bool) -> void:
	var blob := _make_blob()
	blob.self_modulate = cfg.potion_color(kind)
	var from := _pot_mouth() if _lift <= 0.0 else _held.global_position
	var to := p.global_position + Vector2(0, -60)
	blob.global_position = from
	var t := blob.create_tween()
	_tween_arc(t, blob, from, to)
	t.tween_callback(Sfx.play.bind("splash"))
	if bounce:
		_bouncing += 1
		_tween_arc(t, blob, to, get_global_mouse_position())
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
			if _streak >= 2:
				points += mini(cfg.streak_bonus * (_streak - 1), cfg.streak_bonus_max)
			_add_score(points)
			if _streak >= 2:
				_toast("Cured! +%d · Perfect ×%d" % [points, _streak], cfg.green.lightened(0.3))
			else:
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
	# Pops up, then drains from full to empty through every frame of the strip.
	heart.scale = Vector2.ONE * 1.6
	var t := heart.create_tween()
	t.tween_property(heart, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(heart, "frame", 0, HEART_DRAIN_TIME).from(HEART_FRAMES - 1)
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
	var summary := "You made it to Shift %d\n\nScore %d\nCured %d · Borrows %d" % [shift, score, cured, borrows]
	# A beat to see the last patient go before the menu slides in.
	await get_tree().create_timer(0.8).timeout
	_menu.open(GAME_OVER_ITEMS, {title = "Game Over", body = summary, center = true})


func _build_hearts() -> void:
	var left := -HEART_SPACING * (cfg.lives - 1) * 0.5
	for i in cfg.lives:
		var heart := ArtSprite.new()
		heart.art_name = "icon_heart"
		heart.size = Vector2(48, 48)
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.frames = HEART_FRAMES
		heart.autoplay = false
		heart.frame = HEART_FRAMES - 1
		heart.shape = ArtSprite.Shape.ELLIPSE
		heart.placeholder_color = cfg.red
		heart.show_name = false
		heart.position = Vector2(left + i * HEART_SPACING, 0)
		hearts_root.add_child(heart)
		_hearts.append(heart)


func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.55)
	gradient.set_color(0, Color(cfg.red, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, cfg.red)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_vignette = TextureRect.new()
	_vignette.texture = texture
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.modulate.a = 0.0
	# Above the cards, under the toasts and the game-over panel.
	toast_template.add_sibling(_vignette)
	toast_template.get_parent().move_child(_vignette, toast_template.get_index())


## Keeps the HUD speaker and the open menu's speaker in step, however sound was toggled.
func _show_mute(muted: bool) -> void:
	sound_button.texture_normal = load("res://assets/ui/%s.png" % _sound_icon(muted))
	sound_button.tooltip_text = "Unmute (M)" if muted else "Mute (M)"
	_menu.set_icon("sound", _sound_icon(muted))


func _shake_screen() -> void:
	var t := create_tween()
	for offset in [Vector2(12, -6), Vector2(-10, 8), Vector2(6, -4), Vector2.ZERO]:
		t.tween_property(self, "_kick", offset, 0.05)


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
