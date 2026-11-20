class_name ModUI
extends RefCounted
## Peças de interface com a cara do jogo, para os mods montarem telas, avisos e janelas
##
## Tudo é criado por código: um mod não precisa de cena (.tscn) para mostrar algo.

const BOLD := preload("res://assets/fonts/IBMPlexSans-Bold.ttf")
const SEMI := preload("res://assets/fonts/IBMPlexSans-SemiBold.ttf")
const REGULAR := preload("res://assets/fonts/IBMPlexSans-Regular.ttf")

const INK := Color(0.10, 0.125, 0.2)
const MUTED := Color(0.43, 0.44, 0.5)
const TEAL := Color(0.2745, 0.7098, 0.6902)
const MINT := Color(0.796, 0.9216, 0.8275)
const WINE := Color(0.5608, 0.102, 0.2275)
const YELLOW := Color(0.949, 0.784, 0.294)
const WHITE := Color.WHITE
const SHADE := Color(0.06, 0.08, 0.12, 0.55)


## Fundo escuro que cobre o pai inteiro e segura todo toque, com um cartão no meio. Devolve a
## coluna do cartão, onde vai o conteúdo; o fundo é column.get_meta("overlay")
##
## parent: Onde cobrir: a tela de um app (cobre só ela) ou a raiz do jogo (cobre tudo)
static func dialog(parent: Control, width := 300.0) -> VBoxContainer:
	# Um container organizaria o fundo como mais uma linha: cobre o primeiro pai que não é um
	while parent is Container and parent.get_parent() is Control:
		parent = parent.get_parent()
	var overlay := ColorRect.new()
	overlay.color = SHADE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := card_panel(WHITE)
	card.custom_minimum_size.x = width
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.set_meta("overlay", overlay)
	return column


## Fecha o diálogo de uma coluna feita por dialog()
static func close(column: Control) -> void:
	if is_instance_valid(column) and column.has_meta("overlay"):
		var overlay: Node = column.get_meta("overlay")
		if is_instance_valid(overlay):
			overlay.queue_free()


static func card_panel(color: Color, radius := 14, padding := 16) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0.118, 0.188, 0.278, 0.18)
	style.shadow_size = 6
	card.add_theme_stylebox_override("panel", style)
	return card


static func label(content: String, size := 14, color := INK, font: Font = REGULAR) -> Label:
	var new_label := Label.new()
	new_label.text = content
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_label.add_theme_font_override("font", font)
	new_label.add_theme_font_size_override("font_size", size)
	new_label.add_theme_color_override("font_color", color)
	return new_label


static func title(content: String, color := INK) -> Label:
	return label(content, 18, color, BOLD)


static func button(content: String, color := TEAL, text_color := WHITE, size := 15) -> Button:
	var new_button := Button.new()
	new_button.text = content
	new_button.custom_minimum_size.y = 40
	new_button.add_theme_font_override("font", BOLD)
	new_button.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		style.bg_color = color
		if state == "hover" or state == "pressed":
			style.bg_color = color.darkened(0.12)
		if state == "disabled":
			style.bg_color = Color(color, 0.4)
		if state == "focus":
			style.draw_center = false
		new_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		new_button.add_theme_color_override(state, text_color)
	new_button.add_theme_color_override("font_disabled_color", Color(text_color, 0.6))
	return new_button


## Barra de progresso fina, de 0 a 100
static func progress(color := TEAL) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 14
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.08)
	background.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Espera alguns segundos, em jogo pausado também não (como os timers do jogo)
static func wait(node: Node, seconds: float) -> void:
	await node.get_tree().create_timer(seconds).timeout
