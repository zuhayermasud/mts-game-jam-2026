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
	pot.mouse_driven = false
	var cfg := Game.config

	# Third pour blocked.
	_check(pot.pour(Potion.Kind.RED) and pot.pour(Potion.Kind.YELLOW), "two pours accepted")
	_check(not pot.pour(Potion.Kind.BLUE), "third pour blocked")
	_check(pot.potion() == Potion.Kind.ORANGE, "pot mixes orange")
	_check(not pot.can_serve(), "unstirred brew can't be served")
	pot.dump()

	# Band rolls stay in bounds and end before the warning zone.
	var bands_ok := true
	for kind in [Potion.Kind.RED, Potion.Kind.GREEN]:
		for i in 50:
			pot.pours.clear()
			pot.pour(kind)
			var width := cfg.band_width(kind, Game.shift)
			bands_ok = bands_ok and pot.band_start >= cfg.weak_from \
					and pot.band_end <= pot.warning_at() + 0.001 \
					and absf(pot.band_end - pot.band_start - width) < 0.001
	_check(bands_ok, "band rolls stay in bounds and end before the warning (primary and secondary)")
	_check(cfg.band_width(Potion.Kind.GREEN, 1) < cfg.band_width(Potion.Kind.RED, 1), "secondary band is narrower")
	pot.dump()

	# Letting go too early sets nothing; you can stir again.
	pot.pour(Potion.Kind.RED)
	_check(pot.start_stir(), "hold starts stirring")
	pot._process(cfg.weak_from * 0.5)
	pot.release_stir()
	_check(not pot.can_serve() and pot.quality() == Potion.Quality.RAW, "letting go before weak_from leaves it unset")
	_check(pot.start_stir(), "can stir again after an early let-go")
	pot.release_stir()

	# Let go mid-band = perfect, before = weak, after = weak and overcooked.
	_stir_to(pot, (pot.band_start + pot.band_end) * 0.5)
	_check(pot.can_serve() and pot.quality() == Potion.Quality.PERFECT and not pot.overcooked, "let go mid-band = perfect")
	_check(not pot.start_stir(), "a set brew refuses another stir")
	var old_band := pot.band_start
	pot.dump()
	pot.pour(Potion.Kind.BLUE)
	_check(pot.set_quality == -1 and pot.heat == 0.0, "pouring resets the brew")
	var rerolled := pot.band_start != old_band
	for i in 5:
		pot.pour(Potion.Kind.BLUE) if pot.pours.size() < 2 else pot.dump()
		rerolled = rerolled or pot.band_start != old_band
	_check(rerolled, "pouring re-rolls the band")
	pot.dump()
	pot.pour(Potion.Kind.BLUE)
	_stir_to(pot, pot.band_start - 0.2)
	_check(pot.quality() == Potion.Quality.WEAK and not pot.overcooked, "let go before the band = weak")
	pot.dump()
	pot.pour(Potion.Kind.BLUE)
	_stir_to(pot, pot.band_end + 0.1)
	_check(pot.quality() == Potion.Quality.WEAK and pot.overcooked, "let go after the band = weak, overcooked")
	pot.dump()

	# Holding to the end boils over.
	pot.pour(Potion.Kind.RED)
	pot.start_stir()
	pot._process(pot.warning_at() + 0.05)
	_check(pot.stirring and pot._zone == "warning", "warning zone before boiling over")
	pot._process(cfg.boil_warning)
	_check(pot.is_empty() and not pot.stirring, "holding to boil_over_at boils over and empties the pot")

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
	_stir_to(pot, (pot.band_start + pot.band_end) * 0.5)
	main._serve(patient)
	_check(main.score >= score_before + cfg.score_perfect and pot.is_empty(), "perfect brew cures and scores")

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


## Stirs from scratch to `heat` seconds, then lets go.
func _stir_to(pot: Pot, heat: float) -> void:
	pot.start_stir()
	pot._process(heat - pot.heat)
	pot.release_stir()


func _weak(pot: Pot, kind: int) -> void:
	pot.pour(kind)
	_stir_to(pot, Game.config.weak_from + 0.1)


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
