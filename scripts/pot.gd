class_name Pot
extends Clickable
## The pot on the counter (drawn as a hollow tree stump; the brew pools in the hollow). Pours land instantly and every pour resets the brew and puts the
## fire out. boil_delay seconds after the last pour the fire lights itself (a count-in, so a
## second pour in time keeps it off), and from then on the needle sweeps along the bar under the pot at a
## constant speed and bounces back and forth between the start and the red end, passing the
## same zones every sweep. A bubble ticks every `beat` of needle travel, so the gold can be
## timed by ear. Left-click anywhere to pull the brew: in the gold band it's perfect, on grey
## it's weak (overcooked once the needle has passed the band), and in the red section it boils
## over and empties. Left alone, it bounces forever.
## The band sits at the same spot for every brew (narrower for secondaries and on later shifts).
## Pulling has a little hidden grace around it, wider on the late side.
## Clicking the pot once the brew is pulled dumps it, and the sink dumps it any time.

signal boiled_over
## The brew was pulled and its quality locked in.
signal pulled(quality: int)

## Slack when checking beat crossings, so a needle landing exactly on a beat counts once.
const BEAT_EPSILON := 0.0001
## Seconds of needle trail drawn behind the dot.
const TRAIL := 0.12
const TRAIL_DOTS := 6
## The wooden bar under the pot (same frame as the patients' bars).
const BAR_FRAME := preload("res://assets/ui/bar_frame_wood.png")
## The frame's see-through window, in frame pixels.
const BAR_WINDOW := Rect2i(4, 3, 40, 5)
## Frame pixels to screen pixels. Whole numbers keep the pixel art crisp.
const BAR_PIXEL := 3.0
## The frame is stretched to this many frame pixels long by repeating its middle wood.
const BAR_LENGTH := 80
## The frame grows while the needle is in the gold and shrinks in the red.
const BAR_GOLD_SCALE := 1.12
const BAR_RED_SCALE := 0.92
const BAR_BACK := Color(0.1, 0.08, 0.15, 0.75)
## A click on the pot this soon after pulling doesn't dump, so a double-click is safe.
const DUMP_GUARD := 0.3

## Top of the bar, below the pot.
@export var bar_top := 84.0
@export var raw_color := Color(0.5, 0.5, 0.55)
@export var weak_color := Color(0.85, 0.85, 0.9)
@export var perfect_color := Color(1.0, 0.85, 0.3)
@export var warning_color := Color(1.0, 0.3, 0.25)

var pours: Array[int] = []
## The fire is on: it lights itself boil_delay seconds after the last pour.
var lit := false
## Seconds on the boil since the last pour (real time, used for the raw check).
var heat := 0.0
## Where the needle is along the sweep, in seconds (0 to sweep_time).
var needle := 0.0
## The quality locked in by pulling, or -1 while it's still boiling.
var set_quality := -1
## Pulled after the gold band.
var overcooked := false
## A weak pull that only just missed the gold.
var near_miss := false
var band_start := 0.0
var band_end := 0.0

var _dir := 1.0
var _sweeps := 0
## The needle has gone past the gold band at least once, so pulling now is overcooked.
var _passed_band := false
var _zone := ""
## Seconds left before a waiting pot lights itself.
var _count_in := 0.0
var _time := 0.0
var _pulled_at := -1.0
var _juice_tween: Tween
var _halo := StyleBoxFlat.new()
var _bar_scale := 1.0
var _bar_tween: Tween

@onready var liquid: ArtSprite = $Body/Liquid
@onready var label: Label = $Label


func _ready() -> void:
	clicked.connect(_on_clicked)
	_halo.set_corner_radius_all(6)
	_halo.draw_center = false
	_halo.set_border_width_all(3)
	_refresh()


func is_empty() -> bool:
	return pours.is_empty()


func is_set() -> bool:
	return not is_empty() and set_quality != -1


## Poured, but the fire isn't lit yet (the count-in is running).
func is_waiting() -> bool:
	return not is_empty() and not lit


## On the boil: lit and not pulled yet.
func is_boiling() -> bool:
	return not is_empty() and lit and set_quality == -1


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


## Point along the sweep where the red section starts.
func red_at() -> float:
	return Game.config.sweep_time - Game.config.red_width


## Sweeps the needle has finished.
func sweeps_done() -> int:
	return _sweeps


## Returns false (and shakes) if the pot is full. Resets the brew and restarts the count-in.
func pour(kind: int) -> bool:
	if pours.size() >= Game.config.max_pours:
		Sfx.play("pot_full")
		_shake()
		return false
	pours.append(kind)
	_reset_brew()
	_count_in = Game.config.boil_delay
	_place_band()
	Sfx.play("pour")
	_splash()
	_refresh()
	queue_redraw()
	return true


## Starts the boil from zero. Returns false if there's nothing waiting to be lit.
func light() -> bool:
	if not is_waiting():
		return false
	lit = true
	Sfx.play("boil_start")
	_splash()
	_refresh()
	queue_redraw()
	return true


## Takes the pot off the boil and locks the quality in. Returns false if there's nothing
## boiling or it's still raw. Pulling in the red section boils it over (also false).
func pull() -> bool:
	if not is_boiling() or heat < Game.config.weak_from:
		return false
	if needle >= red_at():
		_boil_over()
		return false
	var miss := _band_miss()
	set_quality = Potion.Quality.PERFECT if miss <= 0.0 else Potion.Quality.WEAK
	overcooked = _passed_band and miss > 0.0
	near_miss = miss > 0.0 and miss <= Game.config.near_miss
	_pulled_at = _time
	hit.rotation = 0.0
	_scale_bar(1.0)
	if set_quality != Potion.Quality.PERFECT:
		Sfx.play("pull")  # main plays the perfect chime, pitched by the streak
	_splash()
	_refresh()
	queue_redraw()
	pulled.emit(set_quality)
	return true


## Empties the pot and returns what was in it: {kind, quality}.
func take() -> Dictionary:
	var brew := {kind = potion(), quality = quality()}
	_clear()
	return brew


## A little squash when a picked mushroom lands in the hollow.
func plop() -> void:
	_splash()


func dump() -> void:
	if is_empty():
		return
	Sfx.play("dump")
	_clear()
	_shake()


## Pulls like a click anywhere; once the brew is pulled, a click on the pot dumps it.
func _on_clicked(button: MouseButton) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	if is_set():
		if _time - _pulled_at >= DUMP_GUARD:
			dump()
	else:
		pull()


func _process(delta: float) -> void:
	_time += delta
	if is_waiting():
		_count_in -= delta
		if _count_in <= 0.0:
			light()
		return
	if not is_boiling():
		if is_set() and quality() == Potion.Quality.PERFECT:
			queue_redraw()  # keep the glow pulsing
		return
	# Heat and the needle run in needle seconds: needle_speed above 1 is faster than real time.
	var step := delta * Game.config.needle_speed
	heat += step
	# The bubble is the metronome: it ticks on every beat the needle crosses, both ways.
	if _advance(step) > 0:
		Sfx.play("bubble", 0.0)
	var zone := _zone_at()
	if zone != _zone:
		_zone = zone
		match zone:
			"band":
				Sfx.play("brew_ready")
				_splash()
				_scale_bar(BAR_GOLD_SCALE)
			"red":
				Sfx.play("boil_warning")
				_scale_bar(BAR_RED_SCALE)
			_:
				_scale_bar(1.0)
		_refresh()
	if zone == "red":
		hit.rotation = sin(_time * 70.0) * 0.09
	else:
		hit.rotation = sin(_time * 22.0) * 0.03
	queue_redraw()


## Moves the needle `delta` seconds on: out to the red end, bounce, back to the start, bounce.
## Loops so one big delta still bounces correctly. Returns how many beats the needle crossed.
func _advance(delta: float) -> int:
	var sweep := Game.config.sweep_time
	var left := delta
	var beats := 0
	while left > 0.0:
		var from := needle
		var room := sweep - needle if _dir > 0.0 else needle
		if left < room:
			needle += _dir * left
			left = 0.0
		else:
			needle = sweep if _dir > 0.0 else 0.0
			left -= room
			_dir = -_dir
			_sweeps += 1
		beats += _beats_between(from, needle)
		if needle > band_end:
			_passed_band = true
	return beats


## Beats crossed moving from `from` to `to` in one direction. A beat the needle lands on counts
## on the way in, not again on the way out, so a bounce on a beat ticks once.
func _beats_between(from: float, to: float) -> int:
	var beat := Game.config.beat
	if to > from:
		return floori(to / beat + BEAT_EPSILON) - floori(from / beat + BEAT_EPSILON)
	return ceili(from / beat - BEAT_EPSILON) - ceili(to / beat - BEAT_EPSILON)


## Folds a point that ran off either end of the sweep back onto it, like the needle bouncing.
func _reflect(x: float) -> float:
	var sweep := Game.config.sweep_time
	var m := fposmod(x, sweep * 2.0)
	return m if m <= sweep else sweep * 2.0 - m


func _in_band() -> bool:
	return needle >= band_start and needle <= band_end


## How far the needle is outside the gold band plus its grace when pulled (0 or less is a hit).
## "Late" is the way the needle is travelling, so on the way back the late side is the low end.
func _band_miss() -> float:
	var cfg := Game.config
	var low_grace := cfg.band_grace_early if _dir > 0.0 else cfg.band_grace_late
	var high_grace := cfg.band_grace_late if _dir > 0.0 else cfg.band_grace_early
	return maxf(band_start - low_grace - needle, needle - band_end - high_grace)


func _zone_at() -> String:
	if needle >= red_at():
		return "red"
	if heat < Game.config.weak_from:
		return "raw"
	if _in_band():
		return "band"
	return "after" if _passed_band else "before"


## Puts the gold band at its fixed spot, always ending before the red section.
func _place_band() -> void:
	var cfg := Game.config
	var width := cfg.band_width(potion(), Game.shift)
	band_start = clampf(cfg.band_start, cfg.weak_from, red_at() - width)
	band_end = band_start + width


func _reset_brew() -> void:
	lit = false
	heat = 0.0
	needle = 0.0
	_dir = 1.0
	_sweeps = 0
	_passed_band = false
	set_quality = -1
	overcooked = false
	near_miss = false
	_zone = ""
	_count_in = 0.0
	hit.rotation = 0.0
	_scale_bar(1.0)


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
	if is_empty():
		liquid.visible = false
		label.text = "Pick a mushroom"
		return
	liquid.visible = true
	var tint := Game.config.potion_color(potion())
	var potion_name := Potion.display_name(potion())
	if is_waiting():
		liquid.self_modulate = tint.lightened(0.45)
		label.text = "Heating…"
	elif is_boiling():
		liquid.self_modulate = tint.lightened(0.45) if heat < Game.config.weak_from else tint
		if heat < Game.config.weak_from:
			label.text = "Heating…"
		elif _zone == "red":
			label.text = "Not in the red!"
		elif _zone == "band":
			label.text = "Pull now!"
		else:
			label.text = "Borrow some time"
	elif set_quality == Potion.Quality.PERFECT:
		liquid.self_modulate = tint
		label.text = "%s · Perfect!" % potion_name
	elif overcooked:
		liquid.self_modulate = tint.darkened(0.35)
		label.text = "%s · %s" % [potion_name, "So close! Overcooked" if near_miss else "Overcooked"]
	else:
		liquid.self_modulate = tint.lightened(0.2)
		label.text = "%s · %s" % [potion_name, "So close! Weak" if near_miss else "Weak"]


## The bar's see-through window on screen, in pot coordinates.
func _window() -> Rect2:
	var bar := _bar()
	var inner := Vector2(BAR_LENGTH - BAR_FRAME.get_width() + BAR_WINDOW.size.x, BAR_WINDOW.size.y)
	return Rect2(bar.position + Vector2(BAR_WINDOW.position) * _px(), inner * _px())


## Pixels per frame pixel right now, with the gold/red grow and shrink.
func _px() -> float:
	return BAR_PIXEL * _bar_scale


## The wooden frame on screen, centred under the pot. It scales about its own centre.
func _bar() -> Rect2:
	var size := Vector2(BAR_LENGTH, BAR_FRAME.get_height()) * _px()
	var centre_y := bar_top + BAR_FRAME.get_height() * BAR_PIXEL * 0.5
	return Rect2(Vector2(-size.x * 0.5, centre_y - size.y * 0.5), size)


## X on the bar for a point `h` along the sweep: the start on the left, the red end on the right.
func _bar_x(h: float) -> float:
	var window := _window()
	return window.position.x + window.size.x * clampf(h / Game.config.sweep_time, 0.0, 1.0)


## A slice of the bar's window from `a` to `b` along the sweep.
func _zone_rect(a: float, b: float) -> Rect2:
	var window := _window()
	var x := _bar_x(a)
	return Rect2(x, window.position.y, _bar_x(b) - x, window.size.y)


func _draw() -> void:
	var cfg := Game.config
	var bar := _bar()
	var window := _window()
	if is_empty():
		_draw_frame(bar, Color(1, 1, 1, 0.35))
		return
	# The same zones every sweep: grey (weak), the gold band, then red (boils over if pulled).
	var red := red_at()
	var in_red := is_boiling() and needle >= red and heat >= cfg.weak_from
	var flash := fmod(_time * 8.0, 2.0) < 1.0
	var halo := Color.TRANSPARENT
	if in_red:
		halo = Color(warning_color, 0.8 if flash else 0.3)
	elif quality() == Potion.Quality.PERFECT:
		halo = Color(perfect_color, 0.55 + 0.35 * sin(_time * 12.0))
	if halo.a > 0.0:
		_halo.border_color = halo
		draw_style_box(_halo, bar.grow(5))
	draw_rect(window, BAR_BACK)
	var grey_from := cfg.weak_from if sweeps_done() == 0 else 0.0
	draw_rect(_zone_rect(grey_from, red), Color(weak_color, 0.3))
	draw_rect(_zone_rect(band_start, band_end), Color(perfect_color, 0.9))
	var red_alpha := (0.95 if flash else 0.65) if in_red else 0.5
	draw_rect(_zone_rect(red, cfg.sweep_time), Color(warning_color, red_alpha))
	# Lit on top like the pack's bar textures.
	draw_rect(Rect2(window.position, Vector2(window.size.x, _px())), Color(1, 1, 1, 0.12))
	_draw_frame(bar, Color.WHITE)
	if is_waiting():
		# The needle waits at the start until the fire lights itself.
		_draw_needle(_bar_x(0.0), raw_color)
	elif heat > 0.0:
		var fill := raw_color
		match quality():
			Potion.Quality.WEAK: fill = warning_color if in_red or overcooked else weak_color
			Potion.Quality.PERFECT: fill = perfect_color
		# A short fading trail behind the needle so it reads as moving.
		if is_boiling():
			for i in range(TRAIL_DOTS, 0, -1):
				var back := TRAIL * i / TRAIL_DOTS
				if heat - back <= 0.0:
					continue
				var k := 1.0 - float(i) / (TRAIL_DOTS + 1)
				var x := _bar_x(_reflect(needle - _dir * back))
				draw_rect(Rect2(x - _px() * 0.5, window.position.y, _px(), window.size.y), Color(fill, 0.5 * k))
		_draw_needle(_bar_x(needle), fill.lightened(0.3))
	if is_boiling():
		# Steam puffs above the pot while it's on the boil.
		for i in 3:
			var t := fmod(_time * 1.5 + i / 3.0, 1.0)
			draw_circle(Vector2((i - 1) * 32.0, -70.0 - t * 30.0), 7.0 + t * 6.0, Color(1, 1, 1, 0.35 * (1.0 - t)))


## The needle: an outlined tick that pokes out past the frame so it's easy to follow.
func _draw_needle(x: float, color: Color) -> void:
	var window := _window()
	var px := _px()
	var tick := Rect2(x - px, window.position.y - px * 2, px * 2, window.size.y + px * 4)
	draw_rect(tick.grow(px * 0.67), Color(0.1, 0.08, 0.15))
	draw_rect(tick, color)


## Draws the frame BAR_LENGTH long: the end caps as they are, the middle wood repeated
## (not stretched, so the grain stays crisp).
func _draw_frame(bar: Rect2, tint: Color) -> void:
	var px := _px()
	var w := BAR_FRAME.get_width()
	var h := BAR_FRAME.get_height()
	var cap := BAR_WINDOW.position.x
	var mid := w - cap * 2
	draw_texture_rect_region(BAR_FRAME, Rect2(bar.position, Vector2(cap, h) * px), Rect2(0, 0, cap, h), tint)
	var x := cap
	while x < BAR_LENGTH - cap:
		var n := mini(mid, BAR_LENGTH - cap - x)
		draw_texture_rect_region(BAR_FRAME, Rect2(bar.position + Vector2(x * px, 0), Vector2(n, h) * px), Rect2(cap, 0, n, h), tint)
		x += n
	draw_texture_rect_region(BAR_FRAME, Rect2(bar.position + Vector2((BAR_LENGTH - cap) * px, 0), Vector2(cap, h) * px), Rect2(w - cap, 0, cap, h), tint)


## Eases the frame to `target` size, like the hover grow on clickable things.
func _scale_bar(target: float) -> void:
	if is_equal_approx(target, _bar_scale) and _bar_tween == null:
		return
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_method(_set_bar_scale, _bar_scale, target, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_callback(func() -> void: _bar_tween = null)


func _set_bar_scale(value: float) -> void:
	_bar_scale = value
	queue_redraw()


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
