extends Node
## Autoload. Sfx.play("pour") plays res://audio/pour.ogg (or .wav) if the file exists.
## Missing sounds stay silent, so gameplay code can call them before the audio is made.

const AUDIO_DIR := "res://audio/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

var _cache := {}


func play(sound: String, pitch_jitter := 0.05) -> void:
	var stream := _find(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _find(sound: String) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = null
		for ext in EXTENSIONS:
			var path := "%s%s.%s" % [AUDIO_DIR, sound, ext]
			if ResourceLoader.exists(path):
				_cache[sound] = load(path)
				break
	return _cache[sound]
