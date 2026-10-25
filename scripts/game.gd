extends Node
## Autoload. Gives every script the gameplay config (Game.config.lap_time) and the
## current shift number (main keeps it up to date).

var config: GameConfig = preload("res://config/game_config.tres")
var shift := 1
