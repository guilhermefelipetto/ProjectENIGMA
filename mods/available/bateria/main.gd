extends Node
## O celular tem bateria. Ela gasta com o relógio do jogo, carrega no carregador (que tem mau
## contato) e, se chegar a zero, o celular apaga e o jogo salvo é APAGADO

const SAVE_PATH := "user://saved_game.json"
const STATE_PATH := "user://mod_bateria.json"
const MAIN_MENU := "res://scenes/main_menu.tscn"

var api: ModAPI
var charge := 100.0
var plugged := false
var _warned_low := false
var _layer: CanvasLayer
var _pill: Button


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("day_started", _on_day_started)
	api.hook("clock_tick", _on_clock_tick)


func _on_day_started(_story: Node) -> void:
	# À noite o carregador fraco só devolve uma parte
	var saved := _read_state()
	charge = minf(100.0, saved + float(api.config("overnight_charge", 45)))
	plugged = false
	_warned_low = false
	_build()
	_refresh()


func _on_clock_tick(_minutes: int, _story: Node) -> void:
	if GameData.current_day == 0:
		return
	if plugged:
		charge = minf(100.0, charge + float(api.config("charge_per_minute", 0.8)))
		# Mau contato
		if randf() < float(api.config("bad_contact_chance", 0.04)):
			plugged = false
			_say("Mau contato", "O carregador desconectou sozinho. Tente de novo.")
	else:
		charge -= float(api.config("drain_per_minute", 0.25))
	_write_state()
	_refresh()
	if charge <= 15 and not _warned_low:
		_warned_low = true
		_say("Bateria fraca", "Restam %d%%. Toque na bateria, lá em cima, para ligar o carregador." % charge)
	if charge <= 0:
		_die()


func _build() -> void:
	var game := get_tree().current_scene
	if game == null or is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_pill = ModUI.button("", ModUI.INK, ModUI.WHITE, 11)
	_pill.custom_minimum_size = Vector2(0, 22)
	_pill.position = Vector2(100, 2)
	_pill.pressed.connect(func() -> void:
		plugged = not plugged
		_refresh()
	)
	_layer.add_child(_pill)
	# O dia começa enquanto a cena ainda está montando os filhos
	game.add_child.call_deferred(_layer)


func _refresh() -> void:
	if not is_instance_valid(_pill) or _pill.get_theme_stylebox("normal") == null:
		return
	_pill.text = "Bateria %d%%%s" % [ceili(charge), " • carregando" if plugged else ""]
	var color := ModUI.TEAL if plugged else (ModUI.WINE if charge <= 15 else ModUI.INK)
	for state in ["normal", "hover", "pressed"]:
		(_pill.get_theme_stylebox(state) as StyleBoxFlat).bg_color = color


func _die() -> void:
	set_process(false)
	var game := get_tree().current_scene as Control
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.add_child(black)
	game.add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.add_child(center)
	var text := ModUI.label("A bateria acabou.\n\nO jogo salvo foi apagado.", 18, ModUI.WHITE,
		ModUI.BOLD)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 300
	center.add_child(text)
	get_tree().paused = true
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if bool(api.config("delete_save", true)):
		DirAccess.remove_absolute(SAVE_PATH)
	charge = 100.0
	_write_state()
	await get_tree().create_timer(4.0, true).timeout
	get_tree().paused = false
	GameData.reset_to_defaults()
	get_tree().change_scene_to_file(MAIN_MENU)


func _say(title: String, message: String) -> void:
	var game := get_tree().current_scene as Control
	if game == null:
		return
	var column := ModUI.dialog(game, 280)
	column.add_child(ModUI.title(title))
	column.add_child(ModUI.label(message))
	var ok := ModUI.button("Ok")
	column.add_child(ok)
	ok.pressed.connect(ModUI.close.bind(column))


func _read_state() -> float:
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return 100.0
	return clampf(float(file.get_as_text()), 0.0, 100.0)


func _write_state() -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(charge))
