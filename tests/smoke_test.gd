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
	var pot: Pot = main.selected_pot
	var cfg := Game.config

	# Burner timeline and third-pour block.
	_check(pot.pour(Potion.Kind.RED) and pot.pour(Potion.Kind.YELLOW), "two pours accepted")
	_check(not pot.pour(Potion.Kind.BLUE), "third pour blocked")
	_check(pot.potion() == Potion.Kind.ORANGE, "pot mixes orange")
	_check(not pot.can_serve(), "raw brew can't be served")
	pot._process(5.0)
	_check(pot.heat == 0.0, "pot doesn't heat up with the burner off")
	_boil(pot, cfg.weak_from + 0.1)
	_check(pot.quality() == Potion.Quality.WEAK and pot.can_serve(), "short boil = weak")
	_boil(pot, cfg.perfect_from - cfg.weak_from)
	_check(pot.quality() == Potion.Quality.PERFECT, "boil to %ss = perfect" % cfg.perfect_from)
	var heat := pot.heat
	pot._process(5.0)
	_check(pot.heat == heat and pot.quality() == Potion.Quality.PERFECT, "burner off freezes heat and quality")
	pot.set_burner(true)
	pot._process(cfg.boil_over_at)
	_check(pot.is_empty() and not pot.burner_on, "boiling past perfect boils over, empties and switches off")
	pot.pour(Potion.Kind.RED)
	pot.dump()
	_check(pot.is_empty(), "dump empties pot")

	# Two pots: critters pour into the selected one, patients are served from it.
	var left: Pot = main.pots[0]
	var right: Pot = main.pots[1]
	_check(main.selected_pot == left and left.selected and not right.selected, "left pot starts selected")
	right.select_requested.emit()
	main._pour(Potion.Kind.BLUE)
	_check(right.potion() == Potion.Kind.BLUE and left.is_empty(), "pours go to the selected pot")
	right.dump()
	main._select(left)

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

	# Weak correct potion through the real serve path: +10 s, once.
	_weak(pot, cure)
	before = patient.time_left
	main._serve(patient)
	_check(patient.info.borrowed and patient.time_left > before + cfg.borrow_seconds - 0.1, "weak potion borrows time")
	_weak(pot, cure)
	main._serve(patient)
	_check(not pot.is_empty(), "second weak potion is refused and stays in the pot")
	pot.dump()

	# Run out of borrowed time -> bandaged and rebooked as a secondary.
	var info := patient.info
	var queued: int = main.queue.size()
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(main.queue.size() == queued + 1, "bandaged patient rejoins queue")
	var returning: PatientInfo = main.queue[mini(cfg.bandage_return_after, queued)]
	_check(returning.bandaged and returning.cure in Potion.SECONDARIES, "they come back bandaged and harder")
	_check(info.cure == cure, "leaving patient keeps their colour")

	# Next patient: a perfect cure from the selected (right) pot scores; the left pot is untouched.
	await patient.gone
	patient = await _next_seated(main)
	var score_before: int = main.score
	_weak(left, Potion.Kind.RED if patient.info.cure != Potion.Kind.RED else Potion.Kind.BLUE)
	right.pour(patient.info.cure)
	_boil(right, cfg.perfect_from + 0.1)
	main._select(right)
	main._serve(patient)
	_check(main.score >= score_before + cfg.score_perfect and right.is_empty() and not left.is_empty(),
			"serving uses the selected pot")
	left.dump()
	main._select(left)

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


## Turns the burner on for `seconds`, then off.
func _boil(pot: Pot, seconds: float) -> void:
	pot.set_burner(true)
	pot._process(seconds)
	pot.set_burner(false)


func _weak(pot: Pot, kind: int) -> void:
	pot.pour(kind)
	_boil(pot, Game.config.weak_from + 0.1)


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
