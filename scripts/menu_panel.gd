class_name MenuPanel
extends CanvasLayer
## A paper menu from the Humble Gift UI pack, used by the title screen, the pause menu and
## the game-over screen.
## open() builds a page of buttons and animates it in, chosen(id) fires on a click and
## close() animates it out. Runs while the tree is paused.
##
## Two entrances:
## - SLIDE (pause): the screen flashes and dims, the panel slides in from the left, the
##   divider grows and the buttons pop in from the bottom up. It leaves to the right.
## - UNROLL (title): the panel opens from a thin strip like a scroll, then the same divider
##   and buttons. It rolls back up to leave.
## The focused button gets an arrow on each side that bobs; they turn red while it's held.

signal chosen(id: String)

enum Style { SLIDE, UNROLL }

const UI := "res://assets/ui/"
## Sizes are the pack's pixels ×3 (assets/ui/ is exported at 3×).
const PANEL_WIDTH := 549.0
const PANEL_MARGIN := 18
const PAGE_INSET := Vector2(36, 39)
const PAGE_INSET_BOTTOM := 48.0
const PAGE_MARGIN := 45
## The page line's top edge has a gap in the middle where the title sits.
const TITLE_Y := 47.0
const DIVIDER_Y := 112.0
const CONTENT_Y := 160.0
const BUTTON_SIZE := Vector2(270, 66)
## A `small` button (the tutorial's Back) and an `icon` button (the speaker).
const SMALL_BUTTON_SIZE := Vector2(168, 54)
const SMALL_FONT_SIZE := 24
const ICON_BUTTON_SIZE := Vector2(96, 66)
const BUTTON_GAP := 22.0
const BODY_WIDTH := 420.0
const BODY_FONT_SIZE := 22
const BOTTOM_SPACE := 84.0
## The logo above the panel is scaled to fit this height.
const HEADING_HEIGHT := 190.0
## Height of the closed scroll in the UNROLL style.
const ROLLED_HEIGHT := 2.0 * PANEL_MARGIN
const ARROW_GAP := 4.0
## The arrows are drawn at 2/3 of the pack's 3x art, so they stay on whole pixels.
const ARROW_SCALE := 2.0 / 3.0
const ARROW_BOB := 6.0
const DIM := Color(0.04, 0.03, 0.08, 0.6)
const FLASH := Color(1, 0.95, 0.85, 0.55)

var style := Style.SLIDE
var is_open := false
## The id chosen() fires with when Esc is pressed. Empty means Esc does nothing.
var cancel_id := ""

var _overlay: ColorRect
var _panel: NinePatchRect
var _content: Control
var _heading: TextureRect
var _heading_name := ""
var _divider: TextureRect
var _buttons: Array[Button] = []
var _arrows: Array[TextureRect] = []
var _arrow_tex: Texture2D
var _arrow_pressed_tex: Texture2D
var _focused: Button
var _full_height := 0.0
var _time := 0.0
## Hover sounds stay quiet while the buttons pop in.
var _quiet := true


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_arrow_tex = load(UI + "menu_arrow.png")
	_arrow_pressed_tex = load(UI + "menu_arrow_pressed.png")

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_heading = TextureRect.new()
	_heading.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heading.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)

	_panel = NinePatchRect.new()
	_panel.texture = load(UI + "menu_panel.png")
	_set_patch(_panel, PANEL_MARGIN)
	_panel.clip_contents = true
	add_child(_panel)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)


## items: [["play", "Play"], ...]. An item can carry a third entry, a dictionary with icon (a
## texture name in assets/ui/, shown instead of the text) or small (a shorter button). opts: title (text in the gap of the top line), title_art
## (a texture name in assets/ui/ instead), heading (a texture name in assets/ui/, the logo above the panel), body (text
## above the buttons), center (centre the body text), cancel (the id Esc chooses).
func open(items: Array, opts := {}, how := Style.SLIDE) -> void:
	style = how
	is_open = true
	visible = true
	_quiet = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_build(items, opts)
	var target := _panel_target()
	_panel.size = Vector2(PANEL_WIDTH, _full_height)
	_panel.scale = Vector2.ONE

	var t := create_tween()
	match style:
		Style.SLIDE:
			Sfx.play("ui_open", 0.0)
			_overlay.color = FLASH
			t.tween_property(_overlay, "color", DIM, 0.25)
			_panel.position = Vector2(-PANEL_WIDTH - 20.0, target.y)
			t.parallel().tween_property(_panel, "position:x", target.x, 0.35) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Style.UNROLL:
			Sfx.play("ui_open", 0.0, 0.9)
			_overlay.color = Color(DIM, 0.0)
			t.tween_property(_overlay, "color", Color(DIM, 0.4), 0.4)
			_panel.position = target
			_set_unroll(0.0)
			t.parallel().tween_method(_set_unroll, 0.0, 1.0, 0.5) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			# A little bounce as the scroll snaps open.
			t.tween_property(_panel, "scale", Vector2(1.03, 0.97), 0.07)
			t.tween_property(_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	if _heading.texture != null:
		var y := _heading.position.y
		_heading.position.y = -_heading.size.y - 20.0
		_heading.modulate.a = 1.0
		create_tween().tween_property(_heading, "position:y", y, 0.6) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	t.tween_callback(_pop_in)
	_panel.pivot_offset = Vector2(PANEL_WIDTH, _full_height) * 0.5
	_heading.pivot_offset = _heading.size * 0.5


## Swaps the page in place (the tutorial and back): old buttons fold away, the panel resizes
## and the new ones pop in.
func show_page(items: Array, opts := {}) -> void:
	_quiet = true
	_hide_arrows()
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 0.0, 0.12)
	await t.finished
	var page_opts := opts.duplicate()
	page_opts.heading = _heading_name
	var heading_y := _heading.position.y
	_build(items, page_opts)
	create_tween().tween_property(_heading, "position:y", _heading.position.y, 0.2).from(heading_y)
	_content.modulate.a = 1.0
	var target := _panel_target()
	_panel.pivot_offset = Vector2(PANEL_WIDTH, _full_height) * 0.5
	var r := create_tween().set_parallel()
	r.tween_property(_panel, "size:y", _full_height, 0.2).set_trans(Tween.TRANS_CUBIC)
	r.tween_property(_panel, "position:y", target.y, 0.2).set_trans(Tween.TRANS_CUBIC)
	Sfx.play("ui_open", 0.0, 1.2, -6.0)
	_pop_in()


## Animates the menu away. Await it: it returns once the menu is gone.
func close() -> void:
	if not is_open:
		return
	is_open = false
	_quiet = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_arrows()
	Sfx.play("ui_close", 0.0)
	var t := create_tween()
	# Buttons fold away top first, the reverse of how they came in.
	for i in _buttons.size():
		var b := _buttons[i]
		t.parallel().tween_property(b, "scale:x", 0.3, 0.1).set_delay(i * 0.04)
		t.parallel().tween_property(b, "modulate:a", 0.0, 0.1).set_delay(i * 0.04)
	t.parallel().tween_property(_divider, "scale:x", 0.0, 0.12)
	t.tween_interval(0.02)
	match style:
		Style.SLIDE:
			t.tween_property(_panel, "position:x", _viewport_size().x + 20.0, 0.22) \
					.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		Style.UNROLL:
			t.tween_method(_set_unroll, 1.0, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_property(_panel, "scale", Vector2(0.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_overlay, "color:a", 0.0, 0.25)
	if _heading.texture != null:
		create_tween().tween_property(_heading, "modulate:a", 0.0, 0.25)
	await t.finished
	visible = false


func set_icon(id: String, icon: String) -> void:
	for b in _buttons:
		if b.name == id:
			b.icon = load(UI + icon + ".png")


func _process(delta: float) -> void:
	_time += delta
	if _heading.texture != null:
		_heading.rotation = sin(_time * 1.6) * 0.015
	if _focused == null or not is_instance_valid(_focused):
		return
	var bob := (sin(_time * TAU * 1.5) * 0.5 + 0.5) * ARROW_BOB
	var mid := _focused.position.y + _focused.size.y * 0.5 - _arrows[0].size.y * 0.5
	var left := _focused.position.x - _arrows[0].size.x - ARROW_GAP - bob
	var right := _focused.position.x + _focused.size.x + ARROW_GAP + bob
	var k := minf(1.0, delta * 25.0)
	_arrows[0].position = _arrows[0].position.lerp(Vector2(left, mid), k)
	_arrows[1].position = _arrows[1].position.lerp(Vector2(right, mid), k)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open or cancel_id == "":
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_P):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_click", 0.0)
		chosen.emit(cancel_id)


func _build(items: Array, opts: Dictionary) -> void:
	for child in _content.get_children():
		child.free()
	_buttons.clear()
	_arrows.clear()
	_focused = null
	_content.position = Vector2.ZERO
	cancel_id = opts.get("cancel", "")
	_heading_name = opts.get("heading", "")
	_heading.texture = load(UI + _heading_name + ".png") if _heading_name != "" else null

	var page := NinePatchRect.new()
	page.texture = load(UI + "menu_page_line.png")
	_set_patch(page, PAGE_MARGIN)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(page)

	if opts.has("title_art"):
		var art := TextureRect.new()
		art.texture = load(UI + opts.title_art + ".png")
		art.position = Vector2((PANEL_WIDTH - art.texture.get_width()) * 0.5, TITLE_Y - art.texture.get_height() * 0.5)
		_content.add_child(art)
	elif opts.has("title"):
		var title := Label.new()
		title.theme_type_variation = &"PaperLabel"
		title.text = opts.title
		title.add_theme_font_size_override("font_size", 28)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(PANEL_WIDTH, 40)
		title.position = Vector2(0, TITLE_Y - 21)
		_content.add_child(title)

	_divider = TextureRect.new()
	_divider.texture = load(UI + "menu_divider.png")
	_divider.position = Vector2((PANEL_WIDTH - _divider.texture.get_width()) * 0.5, DIVIDER_Y)
	_divider.pivot_offset = _divider.texture.get_size() * 0.5
	_divider.scale.x = 0.0  # grows in with _pop_in()
	_content.add_child(_divider)

	var y := CONTENT_Y
	if opts.has("body"):
		var body := Label.new()
		body.theme_type_variation = &"PaperLabel"
		body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		body.text = opts.body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if opts.get("center", false):
			body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.position = Vector2((PANEL_WIDTH - BODY_WIDTH) * 0.5, y - 40.0)
		body.size = Vector2(BODY_WIDTH, 0)
		_content.add_child(body)
		var h := body.get_line_count() * body.get_line_height()
		body.size.y = h
		y += h + 14.0
		# Text pages have no OPTIONS divider; the body starts right under the title.
		_divider.visible = false

	for item in items:
		var extra: Dictionary = item[2] if item.size() > 2 else {}
		var size := BUTTON_SIZE
		var b := Button.new()
		b.name = item[0]
		b.theme_type_variation = &"PaperButton"
		if extra.has("icon"):
			size = ICON_BUTTON_SIZE
			b.icon = load(UI + extra.icon + ".png")
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.tooltip_text = item[1]
		else:
			b.text = item[1]
		if extra.get("small", false):
			size = SMALL_BUTTON_SIZE
			b.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
		b.size = size
		b.position = Vector2((PANEL_WIDTH - size.x) * 0.5, y)
		b.pivot_offset = size * 0.5
		b.modulate.a = 0.0
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_on_focus.bind(b))
		b.button_down.connect(_set_arrows_pressed.bind(true))
		b.button_up.connect(_set_arrows_pressed.bind(false))
		b.pressed.connect(_on_pressed.bind(b))
		_content.add_child(b)
		_buttons.append(b)
		y += size.y + BUTTON_GAP
	_full_height = y - BUTTON_GAP + BOTTOM_SPACE

	for flip in [false, true]:
		var arrow := TextureRect.new()
		arrow.texture = _arrow_tex
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_SCALE
		arrow.size = _arrow_tex.get_size() * ARROW_SCALE
		arrow.flip_h = flip
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.visible = false
		_content.add_child(arrow)
		_arrows.append(arrow)

	_content.size = Vector2(PANEL_WIDTH, _full_height)
	page.position = PAGE_INSET
	page.size = Vector2(PANEL_WIDTH - PAGE_INSET.x * 2.0, _full_height - PAGE_INSET.y - PAGE_INSET_BOTTOM)
	var vp := _viewport_size()
	_heading.size = Vector2(vp.x, HEADING_HEIGHT)
	_heading.position = Vector2(0, maxf(_panel_target().y - HEADING_HEIGHT - 8.0, 0.0))


## The divider grows out from the middle, then the buttons pop in from the bottom up.
func _pop_in() -> void:
	_divider.scale.x = 0.0
	var t := create_tween()
	t.tween_property(_divider, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC)
	for i in range(_buttons.size() - 1, -1, -1):
		var b := _buttons[i]
		b.scale = Vector2(0.4, 1.0)
		t.tween_property(b, "modulate:a", 1.0, 0.05)
		t.parallel().tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_callback(Sfx.play.bind("ui_hover", 0.0, 1.0 + (_buttons.size() - i) * 0.1, -8.0))
		t.tween_interval(0.03)
	t.tween_callback(func():
		if not _buttons.is_empty() and is_open:
			_buttons[0].grab_focus()
		_quiet = false)


func _on_focus(b: Button) -> void:
	var first := _focused == null
	_focused = b
	for arrow in _arrows:
		arrow.visible = true
	if first:
		# Snap in place instead of flying in from the corner.
		var mid := b.position.y + (b.size.y - _arrows[0].size.y) * 0.5
		_arrows[0].position = Vector2(b.position.x - _arrows[0].size.x - ARROW_GAP, mid)
		_arrows[1].position = Vector2(b.position.x + b.size.x + ARROW_GAP, mid)
	if not _quiet:
		Sfx.play("ui_hover", 0.04, 1.0, -4.0)


func _on_pressed(b: Button) -> void:
	if not is_open:
		return
	Sfx.play("ui_click", 0.0)
	# A quick squash so the click reads even if the menu closes right away.
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(1.08, 0.9), 0.05)
	t.tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	chosen.emit(b.name)


func _set_arrows_pressed(down: bool) -> void:
	for arrow in _arrows:
		arrow.texture = _arrow_pressed_tex if down else _arrow_tex


func _hide_arrows() -> void:
	_focused = null
	for arrow in _arrows:
		if is_instance_valid(arrow):
			arrow.visible = false
	_set_arrows_pressed(false)


## 0 = rolled up to a thin strip, 1 = fully open. The content stays put and the panel
## reveals it from the middle outwards, like a scroll opening.
func _set_unroll(k: float) -> void:
	var h := lerpf(ROLLED_HEIGHT, _full_height, k)
	var target := _panel_target()
	_panel.size.y = h
	_panel.position.y = target.y + (_full_height - h) * 0.5
	_content.position.y = -(_full_height - h) * 0.5


func _panel_target() -> Vector2:
	var vp := _viewport_size()
	var y := (vp.y - _full_height) * 0.5
	if _heading.texture != null:
		y += 50.0
	return Vector2((vp.x - PANEL_WIDTH) * 0.5, y)


func _viewport_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))


func _set_patch(rect: NinePatchRect, margin: int) -> void:
	rect.patch_margin_left = margin
	rect.patch_margin_top = margin
	rect.patch_margin_right = margin
	rect.patch_margin_bottom = margin
