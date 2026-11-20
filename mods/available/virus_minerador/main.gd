extends Node
## Cada vírus derruba os quadros por segundo e "minera" bitcoin num aviso no canto

const FULL_FPS := 0
const FPS_PER_VIRUS := 9
const MIN_FPS := 5

var api: ModAPI
var _normal_fps := 0
var _mined := 0.0
var _layer: CanvasLayer
var _label: Label


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	_normal_fps = Engine.max_fps
	api.hook("clock_tick", _on_clock_tick)


func _on_clock_tick(_minutes: int, _story: Node) -> void:
	var viruses: int = GameData.number_of_viruses
	if viruses <= 0:
		Engine.max_fps = _normal_fps
		if _layer:
			_layer.visible = false
		return
	Engine.max_fps = maxi(60 - FPS_PER_VIRUS * viruses, MIN_FPS)
	_mined += 0.0000047 * viruses
	_show("%d vírus minerando · ₿ %.7f enviados" % [viruses, _mined])


func _show(content: String) -> void:
	if not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 90
		var panel := ModUI.card_panel(Color(0.06, 0.08, 0.12, 0.85), 8, 6)
		panel.position = Vector2(8, 600)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = ModUI.label("", 11, ModUI.YELLOW, ModUI.SEMI)
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		panel.add_child(_label)
		_layer.add_child(panel)
		get_tree().current_scene.add_child(_layer)
	_layer.visible = true
	_label.text = content


func _exit_tree() -> void:
	Engine.max_fps = _normal_fps
