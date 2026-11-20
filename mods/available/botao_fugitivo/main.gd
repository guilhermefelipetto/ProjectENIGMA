extends Node
## Botões de confirmar fogem algumas vezes antes de aceitar o toque

const GAME_SCENE := "res://scenes/game_screen.tscn"

var api: ModAPI
var flees: int
var texts: Array


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	flees = int(api.config("flees", 3))
	texts = api.config("buttons", ["Confirmar"])
	api.watch_nodes(func(node: Node) -> bool: return node is Button, _watch)


func _watch(button: Button) -> void:
	button.mouse_entered.connect(_flee.bind(button))
	button.button_down.connect(_flee.bind(button))
	button.pressed.connect(func() -> void: button.set_meta("fugas", 0))


func _flee(button: Button) -> void:
	if not api.is_on() or not texts.has(button.text.strip_edges()) or button.disabled:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != GAME_SCENE:
		return
	var count: int = button.get_meta("fugas", 0)
	if count >= flees:
		return
	button.set_meta("fugas", count + 1)
	# Ignorando o mouse durante a fuga, o toque não dispara ao soltar. Não usa disabled: o
	# container reorganizaria os filhos e o botão voltaria para o lugar
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Foge para um lugar qualquer da tela visível, abaixo da barra do topo
	var visible_rect := button.get_viewport_rect()
	var room := visible_rect.size - button.size - Vector2(16, 96)
	var global_target := Vector2(8 + randf() * maxf(room.x, 0), 88 + randf() * maxf(room.y, 0))
	var target := button.position + (global_target - button.global_position)
	var tween := button.create_tween()
	tween.tween_property(button, "position", target, 0.18).set_trans(Tween.TRANS_BACK)
	await tween.finished
	if is_instance_valid(button):
		button.mouse_filter = Control.MOUSE_FILTER_STOP
