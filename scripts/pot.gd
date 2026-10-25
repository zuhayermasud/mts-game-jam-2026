class_name Pot
extends Clickable
## The pot on the counter. Pours land instantly and every pour starts the boil from zero:
## the needle laps the ring by itself, passing the same zones every lap. Click the pot to
## pull the brew: in the gold band it's perfect, on grey it's weak (overcooked once the
## needle has passed the band), and in the red section it boils over and empties.
## Left alone, it boils over at the end of the last lap (pips count the laps left).
## The band rolls to a random spot on every pour and narrows on later shifts.
## Right-click dumps the pot.

signal boiled_over

const BUBBLE_SOUND_EVERY := 0.35
## Spoon turns per second while boiling.
const SPOON_SPEED := 0.8
const SPOON_ORBIT := Vector2(42, 10)
const SPOON_REST := Vector2(30, -62)
## Seconds of needle trail drawn behind the dot.
const TRAIL := 0.25
const TRAIL_DOTS := 6

@export var ring_radius := 95.0
@export var ring_width := 14.0
@export var raw_color := Color(0.5, 0.5, 0.55)
@export var weak_color := Color(0.85, 0.85, 0.9)
@export var perfect_color := Color(1.0, 0.85, 0.3)
@export var warning_color := Color(1.0, 0.3, 0.25)

var pours: Array[int] = []
## Seconds on the boil since the last pour.
var heat := 0.0
## The quality locked in by pulling, or -1 while it's still boiling.
var set_quality := -1
## Pulled after the gold band.
var overcooked := false
var band_start := 0.0
var band_end := 0.0

var _zone := ""
var _bubble_sound := 0.0
var _spoon_angle := 0.0
var _time := 0.0
var _juice_tween: Tween

@onready var liquid: ArtSprite = $Body/Liquid
@onready var spoon: ArtSprite = $Body/Spoon
@onready var label: Label = $Label


func _ready() -> void:
	clicked.connect(_on_clicked)
	_refresh()


func is_empty() -> bool:
	return pours.is_empty()


func is_set() -> bool:
	return not is_empty() and set_quality != -1


## On the boil: poured and not pulled yet.
func is_boiling() -> bool:
	return not is_empty() and set_quality == -1


## True when the brew has been pulled and can be served.
func can_serve() -> bool:
	return is_set()


func potion() -> int:
	return Potion.mix(pours)


## The pulled quality, or a live preview while boiling.
func quality() -> int:
	if set_quality != -1:
		return set_quality
	if heat < Game.config.weak_from:
		return Potion.Quality.RAW
	return Potion.Quality.PERFECT if _in_band() else Potion.Quality.WEAK


## Point in each lap where the red section starts.
func red_at() -> float:
	return Game.config.lap_time - Game.config.red_width


## Heat at which a pot left alone boils over: the end of the last lap.
func boil_over_at() -> float:
	return Game.config.lap_time * Game.config.boil_over_laps


## Laps the needle has finished.
func laps_done() -> int:
	return int(heat / Game.config.lap_time)


func is_last_lap() -> bool:
	return laps_done() >= Game.config.boil_over_laps - 1


## Returns false (and shakes) if the pot is full. Starts the boil again from zero.
func pour(kind: int) -> bool:
	if pours.size() >= Game.config.max_pours:
		Sfx.play("pot_full")
		_shake()
		return false
	pours.append(kind)
	_reset_brew()
	_roll_band()
	Sfx.play("pour")
	_splash()
	_refresh()
	return true


## Takes the pot off the boil and locks the quality in. Returns false if there's nothing
## boiling or it's still raw. Pulling in the red section boils it over (also false).
func pull() -> bool:
	if not is_boiling() or heat < Game.config.weak_from:
		return false
	if _phase(heat) >= red_at():
		_boil_over()
		return false
	set_quality = Potion.Quality.PERFECT if _in_band() else Potion.Quality.WEAK
	overcooked = heat > band_end
	hit.rotation = 0.0
	if set_quality == Potion.Quality.PERFECT:
		Sfx.play("brew_perfect")
	_splash()
	_refresh()
	queue_redraw()
	return true


## Empties the pot and returns what was in it: {kind, quality}.
func take() -> Dictionary:
	var brew := {kind = potion(), quality = quality()}
	_clear()
	return brew


func dump() -> void:
	if is_empty():
		return
	Sfx.play("dump")
	_clear()
	_shake()


func _on_clicked(button: MouseButton) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		dump()
	elif button == MOUSE_BUTTON_LEFT:
		pull()


func _process(delta: float) -> void:
	_time += delta
	if not is_boiling():
		if is_set() and quality() == Potion.Quality.PERFECT:
			queue_redraw()  # keep the glow pulsing
		return
	heat += delta
	if heat >= boil_over_at():
		_boil_over()
		return
	_bubble_sound -= delta
	if _bubble_sound <= 0.0:
		Sfx.play("bubble", 0.15)
		_bubble_sound = BUBBLE_SOUND_EVERY
	_spoon_angle += TAU * SPOON_SPEED * delta
	spoon.position = Vector2(cos(_spoon_angle) * SPOON_ORBIT.x, -40.0 + sin(_spoon_angle) * SPOON_ORBIT.y)
	spoon.rotation = cos(_spoon_angle) * 0.35
	var zone := _zone_at(heat)
	if zone != _zone:
		_zone = zone
		match zone:
			"band":
				Sfx.play("brew_ready")
				_splash()
			"red":
				Sfx.play("boil_warning")
		_refresh()
	if zone == "red":
		hit.rotation = sin(_time * 70.0) * 0.09
	elif is_last_lap():
		hit.rotation = sin(_time * 40.0) * 0.05
	else:
		hit.rotation = sin(_time * 22.0) * 0.03
	queue_redraw()


## Where `h` falls in the current lap.
func _phase(h: float) -> float:
	return fmod(h, Game.config.lap_time)


func _in_band() -> bool:
	var p := _phase(heat)
	return p >= band_start and p <= band_end


func _zone_at(h: float) -> String:
	var p := _phase(h)
	if p >= red_at():
		return "red"
	if h < Game.config.weak_from:
		return "raw"
	if p >= band_start and p <= band_end:
		return "band"
	return "after" if h > band_end else "before"


## Rolls a new gold band at a random spot in the lap, always ending before the red section.
func _roll_band() -> void:
	var cfg := Game.config
	var width := cfg.band_width(potion(), Game.shift)
	band_start = randf_range(cfg.band_start_min, cfg.band_start_max)
	band_start = clampf(band_start, cfg.weak_from, red_at() - width)
	band_end = band_start + width


func _reset_brew() -> void:
	heat = 0.0
	set_quality = -1
	overcooked = false
	_zone = ""
	_bubble_sound = 0.0
	hit.rotation = 0.0


func _boil_over() -> void:
	Sfx.play("boil_over")
	_clear()
	_shake()
	boiled_over.emit()


func _clear() -> void:
	pours.clear()
	_reset_brew()
	_refresh()
	queue_redraw()


func _refresh() -> void:
	spoon.visible = not is_empty()
	if not is_boiling():
		spoon.position = SPOON_REST
		spoon.rotation = 0.3
	if is_empty():
		liquid.visible = false
		label.text = "Squeeze a critter"
		return
	liquid.visible = true
	var tint := Game.config.potion_color(potion())
	var potion_name := Potion.display_name(potion())
	if is_boiling():
		liquid.self_modulate = tint.lightened(0.45) if heat < Game.config.weak_from else tint
		if heat < Game.config.weak_from:
			label.text = "Heating…"
		elif _zone == "red":
			label.text = "Not in the red!"
		else:
			label.text = "Pull in the gold!"
	elif set_quality == Potion.Quality.PERFECT:
		liquid.self_modulate = tint
		label.text = "%s · Perfect!" % potion_name
	elif overcooked:
		liquid.self_modulate = tint.darkened(0.35)
		label.text = "%s · Overcooked" % potion_name
	else:
		liquid.self_modulate = tint.lightened(0.2)
		label.text = "%s · Weak" % potion_name


## Angle on the ring for a point `h` in the lap. Lap start is at the top.
func _angle(h: float) -> float:
	return -PI / 2 + TAU * h / Game.config.lap_time


func _draw() -> void:
	var cfg := Game.config
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(0, 0, 0, 0.4), ring_width, true)
	if is_empty():
		return
	# The same zones every lap: grey (weak), the gold band, then red (boils over if pulled).
	var red := red_at()
	var phase := _phase(heat)
	var in_red := is_boiling() and phase >= red and heat >= cfg.weak_from
	var flash := fmod(_time * 8.0, 2.0) < 1.0
	var grey_from := cfg.weak_from if laps_done() == 0 else 0.0
	draw_arc(Vector2.ZERO, ring_radius, _angle(grey_from), _angle(red), 48, Color(weak_color, 0.2), ring_width, true)
	draw_arc(Vector2.ZERO, ring_radius, _angle(band_start), _angle(band_end), 16, Color(perfect_color, 0.85), ring_width, true)
	var red_alpha := (0.9 if flash else 0.6) if in_red else 0.45
	draw_arc(Vector2.ZERO, ring_radius, _angle(red), _angle(cfg.lap_time), 16, Color(warning_color, red_alpha), ring_width, true)
	if is_boiling() and (in_red or is_last_lap()):
		var alpha := 0.6 if flash else 0.2
		if not in_red:
			alpha *= 0.5
		draw_arc(Vector2.ZERO, ring_radius + ring_width, 0.0, TAU, 64, Color(warning_color, alpha), 5.0, true)
	if quality() == Potion.Quality.PERFECT:
		var glow := 0.35 + 0.25 * sin(_time * 12.0)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(perfect_color, glow), ring_width * 2.2, true)
	if heat > 0.0:
		var fill := raw_color
		match quality():
			Potion.Quality.WEAK: fill = warning_color if in_red or overcooked else weak_color
			Potion.Quality.PERFECT: fill = perfect_color
		# A short fading trail behind the needle so it reads as spinning, not filling up.
		if is_boiling():
			for i in range(TRAIL_DOTS, 0, -1):
				var back := heat - TRAIL * i / TRAIL_DOTS
				if back <= 0.0:
					continue
				var k := 1.0 - float(i) / (TRAIL_DOTS + 1)
				var at := Vector2.from_angle(_angle(_phase(back))) * ring_radius
				draw_circle(at, ring_width * 0.45 * k, Color(fill, 0.5 * k))
		var needle := Vector2.from_angle(_angle(phase)) * ring_radius
		draw_circle(needle, ring_width * 0.75, Color(0.1, 0.08, 0.15))
		draw_circle(needle, ring_width * 0.5, fill.lightened(0.3))
	if is_boiling():
		# Lap pips beside the ring: one goes dark per finished lap.
		for i in cfg.boil_over_laps:
			var left := i >= laps_done()
			var color := (warning_color if is_last_lap() else Color.WHITE) if left else Color(0, 0, 0, 0.35)
			draw_circle(Vector2(ring_radius + 22.0, -16.0 + i * 16.0), 5.0, color)
		# Steam puffs above the pot while it's on the boil.
		for i in 3:
			var t := fmod(_time * 1.5 + i / 3.0, 1.0)
			draw_circle(Vector2((i - 1) * 32.0, -85.0 - t * 50.0), 8.0 + t * 7.0, Color(1, 1, 1, 0.35 * (1.0 - t)))


func _splash() -> void:
	_juice(Vector2(1.12, 0.9))


func _shake() -> void:
	if _juice_tween:
		_juice_tween.kill()
	hit.position.x = 0.0
	_juice_tween = create_tween()
	for x in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		_juice_tween.tween_property(hit, "position:x", x, 0.04)


func _juice(squash: Vector2) -> void:
	if _juice_tween:
		_juice_tween.kill()
	hit.position.x = 0.0
	hit.scale = squash
	_juice_tween = create_tween()
	_juice_tween.tween_property(hit, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
