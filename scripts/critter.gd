class_name Critter
extends Clickable
## A living ingredient. Click it and its colour lands in the pot right away;
## the squash is cosmetic and never blocks the next click.

signal squeezed(kind: int)

@export var kind: Potion.Kind = Potion.Kind.RED

var _squash_tween: Tween
var _time := randf() * TAU


func _ready() -> void:
	hit.art_name = "critter_" + Potion.art_suffix(kind)
	hit.placeholder_color = Game.config.potion_color(kind)
	clicked.connect(_on_clicked)


func _process(delta: float) -> void:
	_time += delta
	hit.position.y = sin(_time * 2.5) * 4.0


func _on_clicked(button: MouseButton) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	squeezed.emit(kind)
	_squash()


func _squash() -> void:
	if _squash_tween:
		_squash_tween.kill()
	hit.scale = Vector2(1.3, 0.7)
	_squash_tween = create_tween()
	_squash_tween.tween_property(hit, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
