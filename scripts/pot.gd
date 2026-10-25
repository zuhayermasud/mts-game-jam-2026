class_name Pot
extends Clickable
## The pot on the counter. Pours land instantly. Hold the left mouse button on the pot to
## stir: heat rises, the spoon circles and the needle goes round the ring. Let go to set
## the brew: inside the gold band it's perfect, before or after it's weak (after = overcooked).
## Hold to the end of the ring and it boils over and empties, after a rattling warning.
## The band rolls to a new spot on every pour. Right-click dumps the pot.

signal boiled_over

const STIR_SOUND_EVERY := 0.35
## Spoon turns per second while stirring.
const SPOON_SPEED := 1.6
const SPOON_ORBIT := Vector2(42, 10)
const SPOON_REST := Vector2(30, -62)

@export var ring_radius := 95.0
@export var ring_width := 14.0
@export var raw_color := Color(0.5, 0.5, 0.55)
@export var weak_color := Color(0.85, 0.85, 0.9)
@export var perfect_color := Color(1.0, 0.85, 0.3)
@export var warning_color := Color(1.0, 0.3, 0.25)
## Let go when the mouse button is up or the mouse leaves the pot. The smoke test turns
## this off and drives start_stir() / release_stir() itself.
@export var mouse_driven := true

var pours: Array[int] = []
## Seconds of stirring since the last pour.
var heat := 0.0
var stirring := false
## The quality locked in on letting go, or -1 while the brew isn't set.
var set_quality := -1
## Let go after the gold band.
var overcooked := false
var band_start := 0.0
var band_end := 0.0

var _zone := ""
var _stir_sound := 0.0
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


## True when the brew is set and can be served.
func can_serve() -> bool:
	return is_set()


func potion() -> int:
	return Potion.mix(pours)


## The set quality, or a live preview while stirring.
func quality() -> int:
	if set_quality != -1:
		return set_quality
	if heat < Game.config.weak_from:
		return Potion.Quality.RAW
	return Potion.Quality.PERFECT if _in_band() else Potion.Quality.WEAK


## Heat where the warning zone starts.
func warning_at() -> float:
	return Game.config.boil_over_at - Game.config.boil_warning


## Returns false (and shakes) if the pot is full.
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


## Starts stirring. Returns false if there's nothing to stir or the brew is already set.
func start_stir() -> bool:
	if is_empty() or is_set() or stirring:
		return false
	stirring = true
	_stir_sound = 0.0
	_zone = _zone_at(heat)
	_refresh()
	return true


## Lets go. Too early and nothing sets; otherwise the quality locks in.
func release_stir() -> void:
	if not stirring:
		return
	stirring = false
	hit.rotation = 0.0
	if heat >= Game.config.weak_from:
		set_quality = Potion.Quality.PERFECT if _in_band() else Potion.Quality.WEAK
		overcooked = heat > band_end
		_splash()
	_refresh()
	queue_redraw()


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
		start_stir()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_stir()


func _process(delta: float) -> void:
	_time += delta
	if not stirring:
		if is_set() and quality() == Potion.Quality.PERFECT:
			queue_redraw()  # keep the glow pulsing
		return
	if mouse_driven and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or not hit.contains_point(get_global_mouse_position())):
		release_stir()
		return
	heat += delta
	if heat >= Game.config.boil_over_at:
		_boil_over()
		return
	_stir_sound -= delta
	if _stir_sound <= 0.0:
		Sfx.play("stir", 0.15)
		_stir_sound = STIR_SOUND_EVERY
	_spoon_angle += TAU * SPOON_SPEED * delta
	spoon.position = Vector2(cos(_spoon_angle) * SPOON_ORBIT.x, -40.0 + sin(_spoon_angle) * SPOON_ORBIT.y)
	spoon.rotation = cos(_spoon_angle) * 0.35
	var zone := _zone_at(heat)
	if zone != _zone:
		_zone = zone
		match zone:
			"band":
				Sfx.play("brew_perfect")
				_splash()
			"warning":
				Sfx.play("boil_warning")
		_refresh()
	if zone == "warning":
		hit.rotation = sin(_time * 70.0) * 0.09
	else:
		hit.rotation = sin(_time * 22.0) * 0.03
	queue_redraw()


func _in_band() -> bool:
	return heat >= band_start and heat <= band_end


func _zone_at(h: float) -> String:
	if h >= warning_at():
		return "warning"
	if h >= band_start and h <= band_end:
		return "band"
	return "after" if h > band_end else "before"


## Rolls a new gold band, always ending before the warning zone.
func _roll_band() -> void:
	var cfg := Game.config
	var width := cfg.band_width(potion(), Game.shift)
	band_start = randf_range(cfg.band_start_min, cfg.band_start_max)
	band_start = clampf(band_start, cfg.weak_from, warning_at() - width)
	band_end = band_start + width


func _reset_brew() -> void:
	stirring = false
	heat = 0.0
	set_quality = -1
	overcooked = false
	_zone = ""
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
	if not stirring:
		spoon.position = SPOON_REST
		spoon.rotation = 0.3
	if is_empty():
		liquid.visible = false
		label.text = "Squeeze a critter"
		return
	liquid.visible = true
	var tint := Game.config.potion_color(potion())
	var potion_name := Potion.display_name(potion())
	if stirring:
		liquid.self_modulate = tint
		label.text = "Let go in the gold!"
	elif not is_set():
		liquid.self_modulate = tint.lightened(0.45)
		label.text = "Hold to stir"
	elif set_quality == Potion.Quality.PERFECT:
		liquid.self_modulate = tint
		label.text = "%s · Perfect!" % potion_name
	elif overcooked:
		liquid.self_modulate = tint.darkened(0.35)
		label.text = "%s · Overcooked" % potion_name
	else:
		liquid.self_modulate = tint.lightened(0.2)
		label.text = "%s · Weak" % potion_name


func _angle(h: float) -> float:
	return -PI / 2 + TAU * h / Game.config.boil_over_at


func _draw() -> void:
	var cfg := Game.config
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(0, 0, 0, 0.4), ring_width, true)
	if is_empty():
		return
	# Zones round the ring: weak (grey), the gold band, then red. Full circle = boils over.
	var warn := warning_at()
	var in_warning := stirring and heat >= warn
	var flash := in_warning and fmod(_time * 8.0, 2.0) < 1.0
	draw_arc(Vector2.ZERO, ring_radius, _angle(cfg.weak_from), _angle(warn), 48, Color(weak_color, 0.2), ring_width, true)
	draw_arc(Vector2.ZERO, ring_radius, _angle(band_start), _angle(band_end), 16, Color(perfect_color, 0.85), ring_width, true)
	var red := Color(warning_color, 0.9 if flash else 0.45)
	draw_arc(Vector2.ZERO, ring_radius, _angle(warn), _angle(cfg.boil_over_at), 16, red, ring_width, true)
	if in_warning:
		draw_arc(Vector2.ZERO, ring_radius + ring_width, 0.0, TAU, 64, Color(warning_color, 0.6 if flash else 0.2), 5.0, true)
	if quality() == Potion.Quality.PERFECT:
		var glow := 0.35 + 0.25 * sin(_time * 12.0)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(perfect_color, glow), ring_width * 2.2, true)
	if heat > 0.0:
		var fill := raw_color
		match quality():
			Potion.Quality.WEAK: fill = warning_color if in_warning or overcooked else weak_color
			Potion.Quality.PERFECT: fill = perfect_color
		draw_arc(Vector2.ZERO, ring_radius, _angle(0.0), _angle(heat), 48, fill, ring_width * 0.4, true)
		var needle := Vector2.from_angle(_angle(heat)) * ring_radius
		draw_circle(needle, ring_width * 0.75, Color(0.1, 0.08, 0.15))
		draw_circle(needle, ring_width * 0.5, fill.lightened(0.3))
	if stirring:
		# Steam puffs above the pot while it's stirred.
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
