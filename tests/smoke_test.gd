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

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var pot: Pot = main.pot
	var cfg := Game.config

	# Third pour blocked.
	_check(pot.pour(Potion.Kind.RED) and pot.pour(Potion.Kind.YELLOW), "two pours accepted")
	_check(not pot.pour(Potion.Kind.BLUE), "third pour blocked")
	_check(pot.potion() == Potion.Kind.ORANGE, "pot mixes orange")
	_check(pot.is_boiling() and not pot.can_serve(), "pouring starts the boil; unpulled brew can't be served")
	pot.dump()

	# Band rolls stay in bounds, land in random spots and end before the warning zone.
	var bands_ok := true
	var starts := {}
	for kind in [Potion.Kind.RED, Potion.Kind.GREEN]:
		for i in 50:
			pot.pours.clear()
			pot.pour(kind)
			var width := cfg.band_width(kind, Game.shift)
			bands_ok = bands_ok and pot.band_start >= cfg.weak_from \
					and pot.band_end <= pot.red_at() + 0.001 \
					and absf(pot.band_end - pot.band_start - width) < 0.001
			starts[snappedf(pot.band_start, 0.1)] = true
	_check(bands_ok, "band rolls stay in bounds and end before the red (primary and secondary)")
	_check(starts.size() >= 8, "band lands in random spots")
	_check(cfg.band_width(Potion.Kind.GREEN, 1) < cfg.band_width(Potion.Kind.RED, 1), "secondary band is narrower")
	_check(cfg.band_width(Potion.Kind.RED, 4) < cfg.band_width(Potion.Kind.RED, 1), "band narrows on later shifts")
	_check(cfg.band_width(Potion.Kind.GREEN, 99) == cfg.band_width_min, "band never narrower than the minimum")
	pot.dump()

	# The pot boils by itself; pulling while raw does nothing.
	pot.pour(Potion.Kind.RED)
	pot._process(cfg.weak_from * 0.5)
	_check(pot.heat > 0.0 and not pot.pull() and pot.is_boiling(), "pulling while raw does nothing, boil carries on")

	# Pull mid-band = perfect, before = weak, after = weak and overcooked.
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	_check(pot.can_serve() and pot.quality() == Potion.Quality.PERFECT and not pot.overcooked, "pull mid-band = perfect")
	var heat := pot.heat
	pot._process(5.0)
	_check(pot.heat == heat and not pot.pull(), "a pulled brew stops heating and can't be pulled again")
	pot.dump()
	pot.pour(Potion.Kind.BLUE)
	_boil_to(pot, pot.band_start - 0.15)
	_check(pot.quality() == Potion.Quality.WEAK and not pot.overcooked, "pull before the band = weak")
	pot.pour(Potion.Kind.BLUE)
	_check(pot.set_quality == -1 and pot.heat == 0.0 and pot.is_boiling(), "pouring resets the brew and boils again")
	_boil_to(pot, pot.band_end + 0.1)
	_check(pot.quality() == Potion.Quality.WEAK and pot.overcooked, "pull after the band = weak, overcooked")
	pot.dump()

	# The needle bounces off the red end and sweeps back through the band.
	pot.pour(Potion.Kind.RED)
	_boil_to(pot, cfg.sweep_time * 2.0 - (pot.band_start + pot.band_end) * 0.5)
	_check(pot.quality() == Potion.Quality.PERFECT, "the needle bounces back through the gold band")
	pot.dump()
	pot.pour(Potion.Kind.RED)
	_boil_to(pot, cfg.sweep_time * 2.0 - pot.band_start * 0.5)
	_check(pot.quality() == Potion.Quality.WEAK and pot.overcooked, "grey on the way back = weak, overcooked")
	pot.dump()

	# A left click anywhere pulls the pot.
	pot.pour(Potion.Kind.RED)
	pot._process((pot.band_start + pot.band_end) * 0.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._unhandled_input(click)
	_check(pot.is_set() and pot.quality() == Potion.Quality.PERFECT, "a left click anywhere pulls the pot")
	pot.dump()

	# Pulling in the red boils over.
	pot.pour(Potion.Kind.RED)
	pot._process(pot.red_at() + 0.05)
	_check(pot.is_boiling() and pot._zone == "red", "the needle reaches the red section")
	_check(not pot.pull() and pot.is_empty(), "pulling in the red boils the pot over")

	# Left alone it boils over at the end of the last sweep.
	pot.pour(Potion.Kind.RED)
	pot._process(pot.boil_over_at() - 0.05)
	_check(pot.is_boiling() and pot.is_last_sweep(), "still boiling on the last sweep")
	pot._process(0.1)
	_check(pot.is_empty(), "after %d sweeps the pot boils over and empties" % cfg.boil_over_sweeps)

	# Shift 1 opens one chair.
	var patient := await _next_seated(main)
	_check(patient != null and patient.active, "first patient sits down")
	_check(main._open.size() == cfg.chairs_for_shift(1), "shift 1 opens %d chair" % cfg.chairs_for_shift(1))
	var cure := patient.info.cure

	# Wrong potion: refused, -2 s.
	var before := patient.time_left
	var wrong := Potion.Kind.BLUE if cure != Potion.Kind.BLUE else Potion.Kind.RED
	_check(patient.serve(wrong, Potion.Quality.PERFECT) == Patient.Serve.REFUSED, "wrong potion refused")
	_check(patient.time_left <= before - cfg.wrong_serve_penalty + 0.01, "wrong potion costs time")

	# Served from the pot, a wrong potion bounces back: still in the pot, quality kept.
	pot.pour(wrong)
	_boil_to(pot, (pot.band_start + pot.band_end) * 0.5)
	var set_quality := pot.set_quality
	before = patient.time_left
	main._serve(patient)
	_check(patient.time_left <= before - cfg.wrong_serve_penalty + 0.01, "wrong serve from the pot costs time")
	_check(pot.potion() == wrong and pot.set_quality == set_quality, "wrong potion stays in the pot")
	pot.dump()

	# Clicking a patient while the pot is still raw does nothing.
	pot.pour(cure)
	pot._process(cfg.weak_from * 0.5)
	before = patient.time_left
	main._on_patient_clicked(MOUSE_BUTTON_RIGHT, patient)
	_check(pot.is_boiling() and patient.active and patient.time_left == before and patient.info.borrows == 0,
			"right-clicking a patient while raw does nothing")
	pot.dump()

	# Weak correct potions borrow with interest: +10, +6, +3, then +3.
	_weak(pot, cure)
	before = patient.time_left
	main._serve(patient)
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
	pot.pour(patient.info.cure)
	pot._process((pot.band_start + pot.band_end) * 0.5)
	_check(pot.is_boiling(), "pot still on the boil before the click")
	main._on_patient_clicked(MOUSE_BUTTON_RIGHT, patient)
	_check(patient.outcome == Patient.Outcome.CURED and pot.is_empty(), "right-clicking a patient pulls the boiling pot and serves it")
	_check(main.score >= score_before + cfg.score_perfect, "perfect brew cures and scores")

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
	cfg.emergency_chance = chances

	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(failures)


## Boils until `heat` seconds, then pulls.
func _boil_to(pot: Pot, heat: float) -> void:
	pot._process(heat - pot.heat)
	pot.pull()


func _weak(pot: Pot, kind: int) -> void:
	pot.pour(kind)
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
