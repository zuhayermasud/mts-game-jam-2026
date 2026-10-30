extends Node
## Autoload. Sfx.play("pour") plays res://audio/pour.ogg (or .wav) if the file exists.
## Missing sounds stay silent, so gameplay code can call them before the audio is made.
## Also owns the one sound switch (the M key, the HUD speaker and the menus' speaker button),
## saved between sessions. Music plays res://audio/music.* on loop once that file exists.
## Keeps running while the game is paused so the menus have sound.

signal muted_changed(muted: bool)

const AUDIO_DIR := "res://audio/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const SETTINGS_PATH := "user://settings.cfg"

var muted := false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(0, muted)
		muted_changed.emit(muted)

var _cache := {}
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus()
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		muted = settings.get_value("audio", "muted", false)
	_start_music()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		get_viewport().set_input_as_handled()
		toggle_mute()


func toggle_mute() -> void:
	muted = not muted
	_save("muted", muted)


func _save(key: String, value: bool) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", key, value)
	settings.save(SETTINGS_PATH)


func _start_music() -> void:
	var stream := _find("music")
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	_music.play()


## A Music bus under Master, made on first use, so music can be mixed on its own.
func _music_bus() -> int:
	var index := AudioServer.get_bus_index("Music")
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Music")
		AudioServer.set_bus_send(index, "Master")
	return index


func play(sound: String, pitch_jitter := 0.05, pitch := 1.0, volume_db := 0.0) -> void:
	var stream := _find(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = volume_db
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
