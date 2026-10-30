extends Node
## Headless check of the core loop. Run from the project folder:
##   godot --headless res://tests/smoke_test.tscn

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Potion.mix([Potion.Kind.RED]) == Potion.Kind.RED, "1 pour = primary")
	_check(Potion.mix([Potion.Kind.BLUE, Potion.Kind.BLUE]) == Potion.Kind.BLUE, "same twice = primary")
	_check(Potion.mix([Potion.Kind.BLUE, Potion.Kind.YELLOW]) == Potion.Kind.GREEN, "Y+B = green")
	_check(Potion.mix([Potion.Kind.RED, Potion.Kind.BLUE]) == Potion.Kind.PURPLE, "R+B = purple")

	Game.show_title = false  # straight into the game, no title menu
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var pot: Pot = main.pot
	var cfg := Game.config
	# needle_speed scales the needle against real time; the checks below step in needle seconds.
	cfg.needle_speed = 2.0
	_pour(pot, Potion.Kind.RED)
	pot._process(0.1)
	_check(is_equal_approx(pot.needle, 0.2), "needle_speed speeds the needle up")
	pot.dump()
	cfg.needle_speed = 1.0

	# Third pour blocked.
	_check(pot.pour(Potion.Kind.RED) and pot.pour(Potion.Kind.YELLOW), "two pours accepted")
	_check(not pot.pour(Potion.Kind.BLUE), "third pour blocked")
	_check(pot.potion() == Potion.Kind.ORANGE, "pot mixes orange")
	_check(pot.is_waiting() and not pot.is_boiling() and not pot.can_serve(), "pouring starts the count-in; unpulled brew can't be served")
	pot.dump()

	# The fire lights itself boil_delay after the last pour; a second pour restarts the count-in.
	pot.pour(Potion.Kind.RED)
	pot._process(cfg.boil_delay * 0.6)
	_check(pot.is_waiting() and pot.heat == 0.0 and pot.needle == 0.0, "still unlit halfway through the count-in")
	pot.pour(Potion.Kind.BLUE)
	pot._process(cfg.boil_delay * 0.6)
	_check(pot.is_waiting(), "a second pour restarts the count-in")
	_check(not pot.pull() and pot.is_waiting(), "pulling during the count-in does nothing")
	pot._process(cfg.boil_delay * 0.6)
	_check(pot.is_boiling() and not pot.is_set(), "the fire lights itself after the count-in")
	pot._process(cfg.weak_from * 0.5)
	_check(pot.heat > 0.0, "a lit pot boils by itself")
	pot.dump()

	# The band sits at the same spot for every brew and ends before the red.
	var bands_ok := true
	for kind in [Potion.Kind.RED, Potion.Kind.GREEN]:
		for i in 5:
			pot.pours.clear()
			pot.pour(kind)
			var width := cfg.band_width(kind, Game.shift)
			bands_ok = bands_ok and is_equal_approx(pot.band_start, cfg.band_start) \
					and pot.band_end <= pot.red_at() + 0.001 \
					and absf(pot.band_end - pot.band_start - width) < 0.001
	_check(bands_ok, "the band starts at the same spot for every brew and ends before the red")
	pot.pours.clear()
	pot.pour(Potion.Kind.BLUE)
	var primary_start := pot.band_start
	pot.pour(Potion.Kind.YELLOW)
	_check(is_equal_approx(pot.band_start, primary_start), "adding a second colour doesn't move the band")
	_check(cfg.band_width(Potion.Kind.GREEN, 1) < cfg.band_width(Potion.Kind.RED, 1), "secondary band is narrower")
	_check(cfg.band_width(Potion.Kind.RED, 4) < cfg.band_width(Potion.Kind.RED, 1), "band narrows on later shifts")
	_check(cfg.band_width(Potion.Kind.GREEN, 99) == cfg.band_width_min, "band never narrower than the minimum")
	pot.dump()

	# The pot boils by itself; pulling while raw does nothing.
	_pour(pot, Potion.Kind.RED)
	pot._process(cfg.weak_from * 0.5)
	_check(pot.heat > 0.0 and not pot.pull() and pot.is_boiling(), "pulling while raw does nothing, boil carries on")

	# Pull mid-band = perfect, before = weak, after = weak and overcooked.
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	_check(pot.can_serve() and pot.quality() == Potion.Quality.PERFECT and not pot.overcooked, "pull mid-band = perfect")
	var heat := pot.heat
	pot._process(5.0)
	_check(pot.heat == heat and not pot.pull(), "a pulled brew stops heating and can't be pulled again")
	pot.dump()
	_pour(pot, Potion.Kind.BLUE)
	_boil_to(pot, (pot.band_start + cfg.weak_from) * 0.5)
	_check(pot.quality() == Potion.Quality.WEAK and not pot.overcooked, "pull before the band = weak")
	pot.pour(Potion.Kind.BLUE)
	_check(pot.set_quality == -1 and pot.heat == 0.0 and pot.is_waiting(), "pouring resets the brew and restarts the count-in")
	pot.light()
	_boil_to(pot, cfg.sweep_time * 2.0 - (pot.band_start + cfg.weak_from) * 0.5)
	_check(pot.quality() == Potion.Quality.WEAK and pot.overcooked, "pull after the band = weak, overcooked")
	pot.dump()

	# Hidden grace around the band, wider on the late side (the way the needle is going).
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, pot.band_end + cfg.band_grace_late * 0.5)
	_check(pot.quality() == Potion.Quality.PERFECT and not pot.overcooked, "a hair late is still perfect")
	pot.dump()
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, pot.band_start - cfg.band_grace_early * 0.5)
	_check(pot.quality() == Potion.Quality.PERFECT, "a hair early is still perfect")
	pot.dump()
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, cfg.sweep_time * 2.0 - (pot.band_start - cfg.band_grace_late * 0.5))
	_check(pot.quality() == Potion.Quality.PERFECT, "on the way back, late is the low end")
	pot.dump()
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, pot.band_start - cfg.band_grace_early - cfg.near_miss * 0.5)
	_check(pot.quality() == Potion.Quality.WEAK and pot.near_miss, "just outside the grace = weak, so close")
	pot.dump()
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, cfg.weak_from + 0.01)
	_check(pot.quality() == Potion.Quality.WEAK and not pot.near_miss, "far off the gold isn't a near miss")
	pot.dump()

	# The sink (V) empties the pot at any stage; an empty pot stays empty.
	var drain := InputEventKey.new()
	drain.physical_keycode = KEY_V
	drain.pressed = true
	pot.pour(Potion.Kind.RED)
	main.sink._unhandled_key_input(drain)
	_check(pot.is_empty(), "the sink empties a heating pot")
	_pour(pot, Potion.Kind.RED)
	pot._process(cfg.weak_from + 0.1)
	main.sink._unhandled_key_input(drain)
	_check(pot.is_empty(), "the sink empties a boiling pot")
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	main.sink._unhandled_key_input(drain)
	_check(pot.is_empty(), "the sink empties a pulled brew")
	main.sink._unhandled_key_input(drain)
	_check(pot.is_empty(), "the sink on an empty pot does nothing")

	# The needle bounces off the red end and sweeps back through the band.
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, cfg.sweep_time * 2.0 - (pot.band_start + pot.band_end) * 0.5)
	_check(pot.quality() == Potion.Quality.PERFECT, "the needle bounces back through the gold band")
	pot.dump()
	_pour(pot, Potion.Kind.RED)
	_boil_to(pot, cfg.sweep_time * 2.0 - pot.band_start * 0.5)
	_check(pot.quality() == Potion.Quality.WEAK and pot.overcooked, "grey on the way back = weak, overcooked")
	pot.dump()

	# Constant speed: after a sweep the needle is back on the same timing.
	_pour(pot, Potion.Kind.RED)
	pot._process(cfg.sweep_time + 0.01)
	_check(pot.sweeps_done() == 1 and is_equal_approx(pot.needle, cfg.sweep_time - 0.01), "the needle keeps a constant speed")
	_check(pot.overcooked == false and pot._passed_band, "after a sweep the band has been passed")
	pot._process(cfg.sweep_time * 30.0 + 0.3)
	_check(pot.needle >= 0.0 and pot.needle <= cfg.sweep_time, "one big step keeps the needle on the ring")
	pot.dump()

	# The bubble ticks on every beat the needle crosses, once per beat, both ways.
	_check(pot._beats_between(0.0, cfg.sweep_time) == roundi(cfg.sweep_time / cfg.beat), "a sweep out crosses every beat once")
	_check(pot._beats_between(cfg.sweep_time, 0.0) == roundi(cfg.sweep_time / cfg.beat), "a sweep back crosses every beat once")
	_check(pot._beats_between(cfg.beat * 0.2, cfg.beat * 0.8) == 0, "no tick between beats")
	_pour(pot, Potion.Kind.RED)
	var ticks := 0
	for i in 160:
		ticks += pot._advance(cfg.sweep_time * 2.0 / 160.0)
	_check(ticks == 2 * roundi(cfg.sweep_time / cfg.beat), "small steps over a round trip tick once per beat")
	pot.dump()

	_pour(pot, Potion.Kind.RED)
	pot._process(cfg.sweep_time + 0.01)
	pot._process(pot.needle - pot.band_start * 0.5)
	_check(pot.needle < pot.band_start and pot.pull() and pot.overcooked, "pulling after passing the band = overcooked")
	pot.dump()

	# Z, X, C pour red, yellow, blue.
	for pair in [[KEY_Z, Potion.Kind.RED], [KEY_X, Potion.Kind.YELLOW], [KEY_C, Potion.Kind.BLUE]]:
		pot.pours.clear()
		var press := InputEventKey.new()
		press.physical_keycode = pair[0]
		press.pressed = true
		for critter: Critter in main.get_node("Critters").get_children():
			critter._unhandled_key_input(press)
		_check(pot.pours == [pair[1]], "%s pours %s" % [OS.get_keycode_string(pair[0]), Potion.NAMES[pair[1]]])
	pot.pours.clear()

	# A left click anywhere pulls the pot.
	pot.pour(Potion.Kind.RED)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._unhandled_input(click)
	_check(pot.is_waiting(), "a left click during the count-in doesn't light or pull")
	pot.light()
	pot._process((pot.band_start + pot.band_end) * 0.5)
	main._unhandled_input(click)
	_check(pot.is_set() and pot.quality() == Potion.Quality.PERFECT, "a left click anywhere pulls the pot")
	_check(main._lift == 0.0, "a pulled brew starts at the pot's mouth")
	pot.dump()

	# Clicking the pot right after pulling keeps the brew; a later click dumps it.
	_pour(pot, Potion.Kind.RED)
	pot._process((pot.band_start + pot.band_end) * 0.5)
	pot._on_clicked(MOUSE_BUTTON_LEFT)
	pot._on_clicked(MOUSE_BUTTON_LEFT)
	_check(pot.is_set(), "a double-click on the pot pulls without dumping")
	pot._process(Pot.DUMP_GUARD + 0.01)
	pot._on_clicked(MOUSE_BUTTON_LEFT)
	_check(pot.is_empty(), "clicking the pot with a pulled brew dumps it")

	# Pulling in the red boils over.
	_pour(pot, Potion.Kind.RED)
	pot._process(pot.red_at() + 0.05)
	_check(pot.is_boiling() and pot._zone == "red", "the needle reaches the red section")
	_check(not pot.pull() and pot.is_empty(), "pulling in the red boils the pot over")

	# Left alone it never boils over: the needle keeps bouncing.
	_pour(pot, Potion.Kind.RED)
	pot._process(cfg.sweep_time * 20.0)
	_check(pot.is_boiling(), "left alone, the pot keeps boiling")
	pot.dump()

	# Shift 1 opens one chair.
	var patient := await _next_seated(main)
	_check(patient != null and patient.active, "first patient sits down")
	_check(main._open.size() == cfg.chairs_for_shift(1), "shift 1 opens %d chair" % cfg.chairs_for_shift(1))
	var cure := patient.info.cure

	# Danger ramps up in the last seconds, harder for emergencies.
	var clock := patient.time_left
	var emergency := patient.info.emergency
	patient.info.emergency = true
	patient.time_left = cfg.danger_seconds + 1.0
	var calm := patient.danger()
	patient.time_left = cfg.danger_seconds * 0.5
	var mid := patient.danger()
	patient.time_left = 0.01
	var near := patient.danger()
	patient.info.emergency = false
	var normal := patient.danger()
	_check(calm == 0.0 and mid > 0.0 and near > mid and near > 0.95, "danger is 0 early and rises toward 1 near the end")
	_check(normal < near and normal > 0.0, "danger is lower for non-emergencies")
	patient.info.emergency = emergency
	patient.time_left = clock

	# Wrong potion: refused, -2 s.
	var before := patient.time_left
	var wrong := Potion.Kind.BLUE if cure != Potion.Kind.BLUE else Potion.Kind.RED
	_check(patient.serve(wrong, Potion.Quality.PERFECT) == Patient.Serve.REFUSED, "wrong potion refused")
	_check(patient.time_left <= before - cfg.wrong_serve_penalty + 0.01, "wrong potion costs time")

	# Served from the pot, a wrong potion bounces back: still in the pot, quality kept.
	_pour(pot, wrong)
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	var set_quality := pot.set_quality
	before = patient.time_left
	main._serve(patient)
	_check(patient.time_left <= before - cfg.wrong_serve_penalty + 0.01, "wrong serve from the pot costs time")
	_check(pot.potion() == wrong and pot.set_quality == set_quality, "wrong potion stays in the pot")
	pot.dump()

	# Clicking a patient during the count-in serves nothing and doesn't light the pot.
	pot.pour(cure)
	before = patient.time_left
	main._on_patient_clicked(MOUSE_BUTTON_LEFT, patient)
	_check(pot.is_waiting() and patient.time_left == before and patient.info.borrows == 0,
			"clicking a patient during the count-in serves nothing")
	pot.dump()

	# Clicking a patient while the pot is still raw does nothing.
	_pour(pot, cure)
	pot._process(cfg.weak_from * 0.5)
	before = patient.time_left
	main._on_patient_clicked(MOUSE_BUTTON_LEFT, patient)
	_check(pot.is_boiling() and patient.active and patient.time_left == before and patient.info.borrows == 0,
			"clicking a patient while raw does nothing")
	pot.dump()

	# Weak correct potions borrow with interest: +10, +6, +3, then +3. A weak serve ends the streak.
	_weak(pot, cure)
	before = patient.time_left
	main._streak = 3
	main._serve(patient)
	_check(main._streak == 0, "a weak serve resets the perfect streak")
	_check(pot.is_empty() and patient.info.borrows == 1 and is_equal_approx(patient.time_left - before, cfg.borrow_for(0)),
			"first weak potion borrows +%ds" % cfg.borrow_for(0))
	var expected := [cfg.borrow_steps[1], cfg.borrow_steps[2], cfg.borrow_steps[2]]
	for i in expected.size():
		before = patient.time_left
		_check(patient.serve(cure, Potion.Quality.WEAK) == Patient.Serve.BORROWED
				and is_equal_approx(patient.time_left - before, expected[i]), "loan %d adds +%ds" % [i + 2, expected[i]])

	# Run out of borrowed time -> bandaged and rebooked as a secondary.
	var info := patient.info
	var queued: int = main.queue.size()
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(main.queue.size() == queued + 1, "bandaged patient rejoins queue")
	var returning: PatientInfo = main.queue[mini(cfg.bandage_return_after, queued)]
	_check(returning.bandaged and returning.cure in Potion.SECONDARIES, "they come back bandaged and harder")
	_check(info.cure == cure, "leaving patient keeps their colour")
	_check(returning.borrows == 4, "the debt follows them back")

	# Next patient: a perfect cure scores.
	await patient.gone
	patient = await _next_seated(main)
	var score_before: int = main.score
	_pour(pot, patient.info.cure)
	pot._process((pot.band_start + pot.band_end) * 0.5)
	_check(pot.is_boiling(), "pot still on the boil before the click")
	main._on_patient_clicked(MOUSE_BUTTON_LEFT, patient)
	_check(patient.outcome == Patient.Outcome.CURED and pot.is_empty(), "clicking a patient pulls the boiling pot and serves it")
	_check(main.score >= score_before + cfg.score_perfect and main._streak == 1, "perfect brew cures, scores and starts a streak")

	# A second perfect cure in a row earns the streak bonus.
	await patient.gone
	patient = await _next_seated(main)
	score_before = main.score
	_pour(pot, patient.info.cure)
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	main._serve(patient)
	var base_points: int = cfg.score_perfect + int(patient.time_left) * cfg.score_per_second_left
	_check(main._streak == 2 and main.score - score_before == base_points + cfg.streak_bonus,
			"two perfect cures in a row add the streak bonus")

	# Timeout without a borrow -> a life lost, but the run goes on.
	await patient.gone
	patient = await _next_seated(main)
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(main.lives == cfg.lives - 1 and not main.game_over, "death costs a life, not the run")

	# Last life -> game over.
	main.lives = 1
	await patient.gone
	patient = await _next_seated(main)
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(main.game_over, "losing the last life ends the run")

	# Later shifts: three chairs, every clock ticks at once.
	main.game_over = false
	main._start_shift(3)
	await get_tree().create_timer(cfg.first_arrival_delay + cfg.arrival_gap * 2 + 1.0).timeout
	var seated: Array = main.chairs.filter(func(p: Patient): return p.active)
	_check(seated.size() == 3, "shift 3 fills three chairs")
	var clocks: Array = seated.map(func(p: Patient): return p.time_left)
	await get_tree().create_timer(0.3).timeout
	var all_ticked := true
	for i in seated.size():
		all_ticked = all_ticked and seated[i].time_left < clocks[i]
	_check(all_ticked, "all seated clocks tick together")

	# Emergencies arrive on the short clock.
	var chances := cfg.emergency_chance
	cfg.emergency_chance = PackedFloat32Array([1.0])
	main._start_shift(4)
	_check(main.queue.all(func(p: PatientInfo): return p.emergency and p.clock == cfg.emergency_clock),
			"emergency patients get the emergency clock")
	_check(main.queue.all(func(p: PatientInfo): return p.cure in Potion.PRIMARIES), "emergencies always need a primary")
	cfg.emergency_chance = chances

	# Pause menu: Esc pauses, Continue closes it and resumes.
	if not main.game_over:
		main.pause()
		_check(get_tree().paused and main._menu.is_open, "pause opens the menu and pauses the game")
		main._menu.chosen.emit("continue")
		await get_tree().create_timer(1.0).timeout
		_check(not get_tree().paused and not main._menu.is_open, "continue closes the menu and resumes")

	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(failures)


## Boils until `heat` seconds, then pulls.
func _boil_to(pot: Pot, heat: float) -> void:
	pot._process(heat - pot.heat)
	pot.pull()


## Pours and lights the fire without waiting for the count-in.
func _pour(pot: Pot, kind: int) -> void:
	pot.pour(kind)
	pot.light()


func _weak(pot: Pot, kind: int) -> void:
	_pour(pot, kind)
	_boil_to(pot, Game.config.weak_from + 0.1)


## Waits until a patient is sitting with their clock ticking.
func _next_seated(main: Node) -> Patient:
	for i in 100:
		for p: Patient in main.chairs:
			if p.active:
				return p
		await get_tree().create_timer(0.1).timeout
	return null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + what)
