extends Control
## MODS screen of the main menu: turns the mods on and off. Applied at once, as the game reads
## the data of the mods when a day starts

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const BACKGROUND := preload("res://assets/background.jpeg")
const TITLE_FONT := preload("res://assets/fonts/Droid 1997.otf")
const BOLD_FONT := preload("res://assets/fonts/IBMPlexSans-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/IBMPlexSans-Medium.ttf")
const ACCENT := Color(0.5882353, 0.078431375, 0.21960784)
const INK := Color(0.07, 0.09, 0.12)
const MUTED := Color(0.32, 0.36, 0.4)

## mod id -> CheckButton
var _toggles: Dictionary = {}
## mod id -> Label warning about missing dependencies
var _warnings: Dictionary = {}
var _apply_button: Button
var _status_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := _label("MODS", TITLE_FONT, 56, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if ModLoader.available_mods.is_empty():
		list.add_child(_wrapped_label("Nenhum mod encontrado.", BODY_FONT, 14, INK))
	for manifest in ModLoader.available_mods:
		list.add_child(_build_card(manifest))

	_status_label = _label("", BODY_FONT, 12, Color.WHITE)
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.clip_text = true
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	var back_button := _button("Voltar", false)
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)
	if OS.has_feature("pc"):
		var folder_button := _button("Pasta", false)
		folder_button.tooltip_text = "Abre a pasta onde ficam os mods instalados por você"
		folder_button.pressed.connect(_on_folder_pressed)
		buttons.add_child(folder_button)
	_apply_button = _button("Aplicar", true)
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)


func _build_card(manifest: ModManifest) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.88)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var name_label := _wrapped_label(manifest.display_name, BOLD_FONT, 16, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var toggle := CheckButton.new()
	toggle.button_pressed = ModLoader.is_enabled(manifest.id)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.tooltip_text = "Ativar ou desativar"
	toggle.toggled.connect(_on_toggled.unbind(1))
	header.add_child(toggle)
	_toggles[manifest.id] = toggle

	var details := "v%s" % manifest.version
	if not manifest.authors.is_empty():
		details += " · " + ", ".join(manifest.authors)
	if not manifest.is_builtin:
		details += " · instalado por você"
	content.add_child(_wrapped_label(details, BODY_FONT, 11, MUTED))
	if manifest.description != "":
		content.add_child(_wrapped_label(manifest.description, BODY_FONT, 13, INK))

	var warning := _wrapped_label("", BOLD_FONT, 12, ACCENT)
	warning.visible = false
	content.add_child(warning)
	_warnings[manifest.id] = warning
	return card


## Shows what is missing for each mod picked and whether there is anything to apply
func _refresh() -> void:
	var picked := _get_picked_ids()
	for mod_id in _warnings:
		var manifest: ModManifest = ModLoader.get_manifest(mod_id)
		var missing: Array = ModLoader.get_missing_dependencies(manifest, picked)
		var warning: Label = _warnings[mod_id]
		warning.visible = picked.has(mod_id) and not missing.is_empty()
		warning.text = "Precisa de: %s" % ", ".join(missing)

	var is_changed := Array(picked) != Array(_sorted(ModLoader.enabled_ids))
	_apply_button.disabled = not is_changed
	if is_changed:
		_status_label.text = "Toque em Aplicar para salvar"
	elif ModLoader.active_mods.is_empty():
		_status_label.text = "Nenhum mod ativo"
	else:
		_status_label.text = "%d ativo(s) · valem a partir do próximo dia" % (
			ModLoader.active_mods.size()
		)


func _get_picked_ids() -> PackedStringArray:
	var picked := PackedStringArray()
	for mod_id in _toggles:
		if _toggles[mod_id].button_pressed:
			picked.append(mod_id)
	return _sorted(picked)


func _sorted(ids: PackedStringArray) -> PackedStringArray:
	var copy := ids.duplicate()
	copy.sort()
	return copy


func _on_toggled() -> void:
	_refresh()


func _on_apply_pressed() -> void:
	ModLoader.apply_enabled(_get_picked_ids())
	_refresh()


func _on_folder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(ModLoader.USER_MODS_DIR))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _wrapped_label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := _label(text, font, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, is_primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = ACCENT if is_primary else Color(1, 1, 1, 0.9)
		if state == "hover" or state == "pressed":
			style.bg_color = style.bg_color.darkened(0.15)
		if state == "disabled":
			style.bg_color.a = 0.45
		button.add_theme_stylebox_override(state, style)
	var text_color := Color.WHITE if is_primary else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.6))
	return button
