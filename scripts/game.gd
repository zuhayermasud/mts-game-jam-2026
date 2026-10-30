extends Node
## Autoload. Gives every script the gameplay config (Game.config.sweep_time) and the
## current shift number (main keeps it up to date).

var config: GameConfig = preload("res://config/game_config.tres")
var shift := 1
## Show the title menu when main loads. Retry and Restart turn it off, Home and Back turn it back on.
var show_title := true
