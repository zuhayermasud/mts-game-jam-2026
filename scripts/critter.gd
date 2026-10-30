class_name Critter
extends Clickable
## A mushroom patch. Click it and its colour lands in the pot right away; the squash and the
## mushroom flying into the stump are cosmetic and never block the next click.
## The art is an untinted base (outline and stems) with a greyscale cap tinted to the colour.
## Its hotkey (Z, X, C from left to right) does the same thing.

signal squeezed(kind: int)

@export var kind: Potion.Kind = Potion.Kind.RED
@export var key: Key = KEY_NONE

var _squash_tween: Tween

@onready var cap: ArtSprite = $Body/Cap


func _ready() -> void:
	hit.placeholder_color = Game.config.potion_color(kind)
	cap.self_modulate = Game.config.potion_color(kind)
	clicked.connect(_on_clicked)
	if key != KEY_NONE:
		_add_key_hint()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == key:
		get_viewport().set_input_as_handled()
		_squeeze()


func _on_clicked(button: MouseButton) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_squeeze()


func _squeeze() -> void:
	squeezed.emit(kind)
	_squash()


## A small keycap letter so the hotkey is discoverable.
func _add_key_hint() -> void:
	var hint := Label.new()
	hint.text = OS.get_keycode_string(key)
	hint.size = Vector2(40, 32)
	hint.position = Vector2(-20, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _squash() -> void:
	if _squash_tween:
		_squash_tween.kill()
	hit.scale = Vector2(1.3, 0.7)
	_squash_tween = create_tween()
	_squash_tween.tween_property(hit, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A tinted copy of the patch, for the mushroom that flies into the stump.
func make_copy() -> Node2D:
	var copy: Node2D = hit.duplicate()
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copy.scale = Vector2.ONE
	return copy
