extends Node
## Gira a tela do jogo inteira em volta do centro

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("day_started", _on_day_started)


func _on_day_started(_story: Node) -> void:
	var game := get_tree().current_scene as Control
	if game == null:
		return
	game.pivot_offset = game.size / 2
	game.rotation_degrees = float(api.config("degrees", 180))
	if not game.resized.is_connected(_center.bind(game)):
		game.resized.connect(_center.bind(game))


func _center(game: Control) -> void:
	game.pivot_offset = game.size / 2


func _exit_tree() -> void:
	var game := get_tree().current_scene as Control
	if game:
		game.rotation = 0
