class_name Pot
extends Clickable
## The hero pot. Pours land instantly. Hold the left button on the pot to boil it:
## heat only rises while you hold, so a released pot waits safely. Raw, then weak,
## then perfect; hold past perfect and it boils over and empties. Pouring resets the heat.
## Right-click dumps it.

signal boiled_over

@export var ring_radius := 120.0
@export var ring_width := 14.0
@export var raw_color := Color(0.5, 0.5, 0.55)
@export var weak_color := Color(0.85, 0.85, 0.9)
@export var perfect_color := Color(1.0, 0.85, 0.3)

var pours: Array[int] = []
## Seconds held on the boil since the last pour.
var heat := 0.0
var boiling := false
var _last_quality := -1
var _time := 0.0
var _juice_tween: Tween

@onready var liquid: ArtSprite = $Body/Liquid
@onready var label: Label = $Label


func _ready() -> void:
	clicked.connect(_on_clicked)
	_refresh()


func is_empty() -> bool:
	return pours.is_empty()


## True when there's something boiled enough to serve.
func can_serve() -> bool:
	return not is_empty() and quality() != Potion.Quality.RAW


func potion() -> int:
	return Potion.mix(pours)


func quality() -> int:
	if heat < Game.config.weak_from:
		return Potion.Quality.RAW
	if heat < Game.config.perfect_from:
		return Potion.Quality.WEAK
	return Potion.Quality.PERFECT


## Returns false (and shakes) if the pot is full.
func pour(kind: int) -> bool:
	if pours.size() >= Game.config.max_pours:
		Sfx.play("pot_full")
		_shake()
		return false
	pours.append(kind)
	heat = 0.0
	Sfx.play("pour")
	_splash()
	_refresh()
	return true


func start_boil() -> void:
	if is_empty() or boiling:
		return
	boiling = true
	Sfx.play("boil_start")


func stop_boil() -> void:
	boiling = false
	hit.rotation = 0.0
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
		start_boil()


## Let go anywhere on screen to stop boiling.
func _input(event: InputEvent) -> void:
	if boiling and event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		stop_boil()


func _process(delta: float) -> void:
	_time += delta
	if is_empty():
		return
	if boiling:
		heat += delta
		hit.rotation = sin(_time * 45.0) * 0.03
		if heat >= Game.config.boil_over_at:
			_boil_over()
			return
		queue_redraw()
	var q := quality()
	if q != _last_quality:
		_refresh()
		if q == Potion.Quality.PERFECT:
			Sfx.play("brew_perfect")
			_splash()
	elif q == Potion.Quality.PERFECT:
		queue_redraw()  # keep the glow pulsing


func _boil_over() -> void:
	Sfx.play("boil_over")
	_clear()
	_shake()
	boiled_over.emit()


func _clear() -> void:
	stop_boil()
	pours.clear()
	heat = 0.0
	_refresh()
	queue_redraw()


func _refresh() -> void:
	if is_empty():
		_last_quality = -1
		liquid.visible = false
		label.text = "Squeeze a critter"
		return
	_last_quality = quality()
	liquid.visible = true
	var tint := Game.config.potion_color(potion())
	liquid.self_modulate = tint.lightened(0.45) if _last_quality == Potion.Quality.RAW else tint
	var potion_name := Potion.display_name(potion())
	match _last_quality:
		Potion.Quality.RAW: label.text = "%s · Hold the pot to boil" % potion_name
		Potion.Quality.WEAK: label.text = "%s · Weak (buys time)" % potion_name
		Potion.Quality.PERFECT: label.text = "%s · Perfect!" % potion_name


func _draw() -> void:
	var cfg := Game.config
	var start := -PI / 2
	var raw_end := start + TAU * cfg.weak_from / cfg.boil_over_at
	var weak_end := start + TAU * cfg.perfect_from / cfg.boil_over_at
	# Zones round the ring: raw, weak, then perfect. Full circle = boils over.
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(0, 0, 0, 0.4), ring_width, true)
	draw_arc(Vector2.ZERO, ring_radius, raw_end, weak_end, 48, Color(weak_color, 0.15), ring_width, true)
	draw_arc(Vector2.ZERO, ring_radius, weak_end, start + TAU, 24, Color(perfect_color, 0.3), ring_width, true)
	if is_empty() or heat <= 0.0:
		return
	var end := start + TAU * heat / cfg.boil_over_at
	match quality():
		Potion.Quality.RAW:
			draw_arc(Vector2.ZERO, ring_radius, start, end, 16, raw_color, ring_width, true)
		Potion.Quality.WEAK:
			draw_arc(Vector2.ZERO, ring_radius, start, end, 64, weak_color, ring_width, true)
		Potion.Quality.PERFECT:
			var glow := 0.35 + 0.25 * sin(_time * 12.0)
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(perfect_color, glow), ring_width * 2.2, true)
			draw_arc(Vector2.ZERO, ring_radius, start, end, 64, perfect_color, ring_width, true)
	if boiling:
		# Steam puffs above the pot while it's on the boil.
		for i in 3:
			var t := fmod(_time * 1.5 + i / 3.0, 1.0)
			draw_circle(Vector2((i - 1) * 40.0, -110.0 - t * 60.0), 10.0 + t * 8.0, Color(1, 1, 1, 0.35 * (1.0 - t)))


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
