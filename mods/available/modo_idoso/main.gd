extends Node
## Aumenta a escala de toda a interface enquanto a tela do jogo está aberta

var api: ModAPI
var _normal_scale := 1.0


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("day_started", _on_day_started)


func _on_day_started(story: Node) -> void:
	var root := get_tree().root
	var game := get_tree().current_scene
	if root.content_scale_factor == 1.0:
		_normal_scale = root.content_scale_factor
	root.content_scale_factor = float(api.config("scale", 1.8))
	# Saindo do jogo (menu, tela MODS) volta ao normal
	if game and not game.tree_exiting.is_connected(_restore):
		game.tree_exiting.connect(_restore)


func _restore() -> void:
	get_tree().root.content_scale_factor = _normal_scale


func _exit_tree() -> void:
	_restore()
