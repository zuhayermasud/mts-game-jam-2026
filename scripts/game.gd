extends Node
## Autoload. Gives every script the gameplay config (Game.config.boil_over_at) and the
## current shift number (main keeps it up to date).

var config: GameConfig = preload("res://config/game_config.tres")
var shift := 1
