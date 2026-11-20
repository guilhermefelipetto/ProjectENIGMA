extends Node
## Antes de confirmar um pagamento, o Banco opina e pede para aceitar 14 termos

var api: ModAPI
var texts: Dictionary


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	texts = api.read_mod_json("textos.json")
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if app == GameData.App.PAYMENTINFORMATION:
		api.intercept_press(screen.confirm_button, _ask.bind(screen))


func _ask(proceed: Callable, screen: Control) -> void:
	var info: Dictionary = screen.codes_dict.get(screen.payment_code.code, {})
	var column := ModUI.dialog(screen)
	column.add_child(ModUI.title("Opinião sincera do Banco"))
	column.add_child(ModUI.label(_opinion(info)))
	var go_on := ModUI.button("Quero continuar mesmo assim", ModUI.WINE)
	var give_up := ModUI.button("Melhor não", ModUI.MINT, ModUI.INK)
	column.add_child(go_on)
	column.add_child(give_up)
	give_up.pressed.connect(ModUI.close.bind(column))
	go_on.pressed.connect(func() -> void:
		ModUI.close(column)
		_ask_terms(proceed, screen)
	)


func _opinion(info: Dictionary) -> String:
	var value := float(info.get("value", 0.0))
	var pool: Array = texts["opinions"]
	if value >= 5000:
		pool = texts["opinions_big"]
	elif value < 100:
		pool = texts["opinions_small"]
	return str(pool.pick_random()).replace("{valor}", GameData.format_brl(value))


func _ask_terms(proceed: Callable, screen: Control) -> void:
	var column := ModUI.dialog(screen, 320)
	column.add_child(ModUI.title("Termos da transferência"))
	column.add_child(ModUI.label("Para continuar, concorde com todos os termos.", 12, ModUI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var agree := ModUI.button("Concordo (0/%d)" % texts["terms"].size(), ModUI.TEAL)
	agree.disabled = true
	var boxes: Array[CheckBox] = []
	for term in texts["terms"]:
		var box := CheckBox.new()
		box.text = str(term)
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_theme_font_override("font", ModUI.REGULAR)
		box.add_theme_font_size_override("font_size", 12)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color"]:
			box.add_theme_color_override(state, ModUI.INK)
		box.toggled.connect(func(_on: bool) -> void:
			var checked := boxes.filter(func(other: CheckBox) -> bool: return other.button_pressed)
			agree.text = "Concordo (%d/%d)" % [checked.size(), boxes.size()]
			agree.disabled = checked.size() < boxes.size()
		)
		boxes.append(box)
		list.add_child(box)
	column.add_child(agree)
	var cancel := ModUI.button("Cancelar", ModUI.MINT, ModUI.INK)
	column.add_child(cancel)
	cancel.pressed.connect(ModUI.close.bind(column))
	agree.pressed.connect(func() -> void:
		ModUI.close(column)
		proceed.call()
	)
