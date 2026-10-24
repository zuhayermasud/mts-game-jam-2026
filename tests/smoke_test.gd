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
	var patient: Patient = main.patient
	var cfg := Game.config

	# Brew timeline and third-pour block.
	_check(pot.pour(Potion.Kind.RED) and pot.pour(Potion.Kind.YELLOW), "two pours accepted")
	_check(not pot.pour(Potion.Kind.BLUE), "third pour blocked")
	_check(pot.potion() == Potion.Kind.ORANGE, "pot mixes orange")
	_brew(pot, cfg.weak_until - 0.5)
	_check(pot.quality() == Potion.Quality.WEAK, "weak before %ss" % cfg.weak_until)
	_brew(pot, 1.0)
	_check(pot.quality() == Potion.Quality.PERFECT, "perfect after %ss" % cfg.weak_until)
	_brew(pot, cfg.perfect_until)
	_check(pot.quality() == Potion.Quality.OVERCOOKED, "overcooked after %ss" % cfg.perfect_until)
	pot.dump()
	_check(pot.is_empty(), "dump empties pot")

	await get_tree().create_timer(1.0).timeout
	_check(patient.active, "first patient is active after walking in")
	var cure := patient.info.cure

	# Wrong potion: refused, -2 s.
	var before := patient.time_left
	var wrong := Potion.Kind.BLUE if cure != Potion.Kind.BLUE else Potion.Kind.RED
	_check(patient.serve(wrong, Potion.Quality.PERFECT) == Patient.Serve.REFUSED, "wrong potion refused")
	_check(patient.time_left <= before - cfg.wrong_serve_penalty + 0.01, "wrong potion costs time")

	# Weak correct potion through the real GIVE path: +10 s, once.
	pot.pour(cure)
	before = patient.time_left
	main._on_give()
	_check(patient.info.borrowed and patient.time_left > before + cfg.borrow_seconds - 0.1, "weak potion borrows time")
	_check(patient.serve(cure, Potion.Quality.WEAK) == Patient.Serve.ALREADY_BORROWED, "borrow only once")

	# Run out of borrowed time -> bandaged and rebooked as a secondary.
	var info := patient.info
	var queued: int = main.queue.size()
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(info.bandaged and info.cure in Potion.SECONDARIES, "timeout after borrow -> bandaged, harder")
	_check(main.queue.size() == queued + 1, "bandaged patient rejoins queue")

	# Next patient: perfect cure scores.
	await patient.gone
	await get_tree().create_timer(1.0).timeout
	var score_before: int = main.score
	pot.pour(patient.info.cure)
	_brew(pot, cfg.weak_until + 0.5)
	main._on_give()
	_check(main.score > score_before + cfg.score_perfect - 1 or patient.info.borrowed, "perfect cure scores")

	# Timeout without a borrow -> death -> game over.
	await patient.gone
	await get_tree().create_timer(1.0).timeout
	patient.time_left = 0.05
	await get_tree().create_timer(0.2).timeout
	_check(main.game_over, "timeout without borrow -> game over")

	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(failures)


func _brew(pot: Pot, seconds: float) -> void:
	pot._process(seconds)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + what)
