extends Node
## Um app novo na tela inicial: Blocolândia, um mundinho de blocos para colocar e quebrar.
## O relógio do jogo não para enquanto você constrói.

const Textures := preload("res://mods/available/blocolandia/textures.gd")
const World := preload("res://mods/available/blocolandia/world.gd")

const HOTBAR := [
	Textures.GRASS, Textures.DIRT, Textures.STONE, Textures.LOG, Textures.PLANKS,
	Textures.LEAVES, Textures.SAND, Textures.GLASS, Textures.BRICK,
]

var api: ModAPI
var textures: Textures
## O mundo fica aqui, não no app: fechar e abrir de novo mantém o que foi construído
var _blocks: Array = []
var _backdrop: Array = []
var _stats := {"placed": 0, "broken": 0}
var _app: Control
var _world: World
var _clock: Label
var _counts: Label


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	textures = Textures.new()
	_blocks = World.generate(randi())
	_backdrop = _blocks.duplicate()
	api.watch_nodes(func(node: Node) -> bool: return node is GridContainer and node.name == "AppsUI",
		_add_icon)
	api.hook("clock_tick", _on_clock_tick)


func _exit_tree() -> void:
	_close()


#region ÍCONE
func _add_icon(apps: GridContainer) -> void:
	var button := VBoxContainer.new()
	button.custom_minimum_size = Vector2(80, 80)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.texture = textures.icon()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var name_label := Label.new()
	name_label.text = "Blocolândia"
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	button.gui_input.connect(_on_icon_input.bind(apps))
	apps.add_child.call_deferred(button)


func _on_icon_input(event: InputEvent, apps: GridContainer) -> void:
	if not api.is_on():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if apps.get("touch_sound_player"):
			apps.touch_sound_player.play_touch_sound()
		_open()
#endregion ÍCONE


#region APP
func _open() -> void:
	var game := get_tree().current_scene
	if game == null or game.get("ui") == null or is_instance_valid(_app):
		return
	_app = ColorRect.new()
	_app.color = ModUI.INK
	_app.mouse_filter = Control.MOUSE_FILTER_STOP
	_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui.add_child(_app)
	# No fim do dia o jogo fecha os apps: este também
	if not game.event_handler.day_ended.is_connected(_close):
		api.connect_signal(game.event_handler.day_ended, _close)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	_app.add_child(column)
	column.add_child(_header())

	_world = World.new()
	_world.blocks = _blocks
	_world.backdrop = _backdrop
	_world.stats = _stats
	_world.textures = textures
	_world.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world.counts_changed.connect(_update_counts)
	column.add_child(_world)
	column.add_child(_hotbar())
	_update_counts()


func _close() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null


func _header() -> Control:
	var panel := ModUI.card_panel(ModUI.INK, 0, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := ModUI.label("Blocolândia", 18, ModUI.WHITE, ModUI.BOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_clock = ModUI.label("", 13, ModUI.MINT, ModUI.SEMI)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock)
	_update_clock()
	var close := ModUI.button("×", ModUI.WINE, ModUI.WHITE, 18)
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(_close)
	row.add_child(close)
	return panel


func _hotbar() -> Control:
	var panel := ModUI.card_panel(Color(0.16, 0.18, 0.26), 0, 8)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_counts = ModUI.label("", 11, ModUI.WHITE)
	_counts.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_counts)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	column.add_child(row)
	var group := ButtonGroup.new()
	for block in HOTBAR:
		var slot := Button.new()
		slot.toggle_mode = true
		slot.button_group = group
		slot.button_pressed = block == _world.selected
		slot.icon = textures.textures[block]
		slot.expand_icon = true
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.custom_minimum_size = Vector2(35, 35)
		slot.tooltip_text = Textures.NAMES[block]
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0.35)
			style.set_content_margin_all(4)
			style.set_corner_radius_all(4)
			if state in ["pressed", "hover_pressed"]:
				style.set_border_width_all(3)
				style.border_color = ModUI.YELLOW
			if state == "focus":
				style.draw_center = false
			slot.add_theme_stylebox_override(state, style)
		slot.pressed.connect(func() -> void:
			_world.selected = block
			_update_counts()
		)
		row.add_child(slot)
	return panel


func _update_counts() -> void:
	if not is_instance_valid(_counts):
		return
	_counts.text = "%s • toque no ar para colocar, segure para quebrar\nColocados: %d • Quebrados: %d" % [
		Textures.NAMES[_world.selected], _stats["placed"], _stats["broken"]]


func _on_clock_tick(_minutes: int, _story: Node) -> void:
	if is_instance_valid(_app):
		_update_clock()
		_world.queue_redraw()


func _update_clock() -> void:
	if is_instance_valid(_clock):
		_clock.text = "%02d:%02d" % [GameData.hours_minutes / 60, GameData.hours_minutes % 60]
#endregion APP
