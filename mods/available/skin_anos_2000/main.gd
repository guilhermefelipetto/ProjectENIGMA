extends Node
## Skin "anos 2000": barras de título azuis em degradê, janelas bege-cinza e uma barra de tarefas
## com botão "iniciar" que abre os aplicativos instalados

const BLUE_TOP := Color(0.24, 0.52, 0.95)
const BLUE_BOTTOM := Color(0.0, 0.29, 0.78)
const STATUS := Color(0.0, 0.18, 0.55)
const WINDOW := Color(0.925, 0.914, 0.847)
const GREEN_TOP := Color(0.35, 0.72, 0.31)
const GREEN_BOTTOM := Color(0.16, 0.5, 0.15)
const TASKBAR_HEIGHT := 30.0

var api: ModAPI
var _menu: Control


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("day_started", func(_story: Node) -> void: _apply.call_deferred())


func _apply() -> void:
	var game := get_tree().current_scene
	if game == null or not "ui" in game or game.has_meta("skin_2000"):
		return
	game.set_meta("skin_2000", true)
	var base: Control = game.ui.base_app
	var top_bar := base.get_node_or_null("TopBar") as ColorRect
	if top_bar:
		top_bar.color = BLUE_BOTTOM
		var gradient := _gradient_rect(BLUE_TOP, BLUE_BOTTOM)
		top_bar.add_child(gradient)
		top_bar.move_child(gradient, 0)
		var strip := top_bar.get_node_or_null("StatusStrip") as ColorRect
		if strip:
			strip.color = STATUS
	var background := base.get_node_or_null("BaseBackgroundColor") as ColorRect
	if background:
		background.color = WINDOW
	var title := base.get_node_or_null(
		"TopBar/HeaderRow/HeaderContent/TitleArea/AppTitle/TitleColumn/TitleLabel"
	) as Label
	if title:
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0.3, 0.8))
		title.add_theme_constant_override("shadow_offset_x", 1)
		title.add_theme_constant_override("shadow_offset_y", 1)
	_add_taskbar(game)


func _add_taskbar(game: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var bar := _gradient_rect(BLUE_TOP, BLUE_BOTTOM, false)
	bar.position = Vector2(0, 640 - TASKBAR_HEIGHT)
	bar.size = Vector2(360, TASKBAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bar)

	var start := Button.new()
	start.text = "iniciar"
	start.position = Vector2(0, 0)
	start.size = Vector2(92, TASKBAR_HEIGHT)
	start.add_theme_font_override("font", ModUI.BOLD)
	start.add_theme_font_size_override("font_size", 16)
	start.add_theme_color_override("font_color", Color.WHITE)
	start.add_theme_color_override("font_hover_color", Color.WHITE)
	start.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = _gradient_texture(GREEN_TOP if state != "pressed" else GREEN_BOTTOM,
			GREEN_BOTTOM if state != "pressed" else GREEN_TOP)
		style.set_content_margin_all(2)
		start.add_theme_stylebox_override(state, style)
	start.pressed.connect(_toggle_menu.bind(game, layer))
	bar.add_child(start)

	var tray := ColorRect.new()
	tray.color = Color(0.05, 0.55, 0.9)
	tray.position = Vector2(290, 0)
	tray.size = Vector2(70, TASKBAR_HEIGHT)
	bar.add_child(tray)
	var clock := ModUI.label("", 12, Color.WHITE, ModUI.SEMI)
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.position = Vector2(16, 6)
	tray.add_child(clock)
	api.hook("clock_tick", func(minutes: int, _story: Node) -> void:
		if is_instance_valid(clock):
			clock.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	)
	clock.text = "%02d:%02d" % [GameData.hours_minutes / 60, GameData.hours_minutes % 60]
	game.add_child(layer)


func _toggle_menu(game: Node, layer: CanvasLayer) -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
		return
	_menu = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = BLUE_BOTTOM
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	_menu.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_menu.add_child(column)

	var header := _gradient_rect(BLUE_TOP, BLUE_BOTTOM, false)
	header.custom_minimum_size = Vector2(220, 44)
	var user := ModUI.label("Estagiário", 16, Color.WHITE, ModUI.BOLD)
	user.autowrap_mode = TextServer.AUTOWRAP_OFF
	user.position = Vector2(12, 10)
	header.add_child(user)
	column.add_child(header)

	for app in GameData.downloaded_apps:
		var data: Dictionary = GameData.apps_data.get(app, {})
		if data.is_empty():
			continue
		var item := Button.new()
		item.text = "  " + str(data.get("name", ""))
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.flat = true
		item.custom_minimum_size.y = 32
		item.icon = load(data.get("icon_path", "")) if ResourceLoader.exists(data.get("icon_path", "")) else null
		item.expand_icon = false
		item.add_theme_constant_override("icon_max_width", 22)
		item.add_theme_font_override("font", ModUI.SEMI)
		item.add_theme_font_size_override("font_size", 13)
		item.add_theme_color_override("font_color", ModUI.INK)
		item.pressed.connect(func() -> void:
			_menu.queue_free()
			game.ui.base_app._on_app_opened(app)
		)
		column.add_child(item)

	var shutdown := ModUI.button("Desligar", Color(0.85, 0.3, 0.15), Color.WHITE, 12)
	shutdown.pressed.connect(func() -> void:
		shutdown.text = "47 atualizações pendentes"
		shutdown.disabled = true
	)
	column.add_child(shutdown)
	layer.add_child(_menu)
	await get_tree().process_frame
	if is_instance_valid(_menu):
		_menu.position = Vector2(0, 640 - TASKBAR_HEIGHT - _menu.size.y)


## fill: Cobre o pai inteiro; sem isso, o tamanho é definido por quem chama
func _gradient_rect(top: Color, bottom: Color, fill := true) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _gradient_texture(top, bottom)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if fill:
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _gradient_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 32
	return texture
