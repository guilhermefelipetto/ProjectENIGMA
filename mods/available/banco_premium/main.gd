extends Node
## Anúncios, passe de batalha e popups no Banco

const COLUMN_PATH := "Screen/ScrollContainer/Margin/Column"
const AD_PRICE := 99.99
const PREMIUM_PRICE := 49.90

var api: ModAPI
var content: Dictionary
var _ads_bought := 0
var _premium := false
var _last_popup := -999
var _popup_open := false


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	content = api.read_mod_json("anuncios.json")
	api.hook("screen_opened", _on_screen_opened)
	api.hook("clock_tick", _on_clock_tick)


#region BANCO
func _on_screen_opened(app: int, screen: Control) -> void:
	if app != GameData.App.BANK:
		return
	var column := screen.get_node_or_null(COLUMN_PATH) as VBoxContainer
	if column == null:
		return
	if not column.has_meta("premium"):
		column.set_meta("premium", true)
		_add_ad(screen, column, content["ads"][0])
	# O passe é refeito a cada abertura, com o nível de agora
	if column.has_meta("pass_card") and is_instance_valid(column.get_meta("pass_card")):
		column.get_meta("pass_card").queue_free()
	var pass_card := _pass_card(screen)
	column.add_child(pass_card)
	var balance := column.get_node_or_null("BalanceCard")
	column.move_child(pass_card, balance.get_index() + 1 if balance else 1)
	column.set_meta("pass_card", pass_card)


func _add_ad(screen: Control, column: VBoxContainer, ad: Dictionary) -> void:
	var card := ModUI.card_panel(ModUI.YELLOW, 12, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(ModUI.label("PUBLICIDADE", 10, ModUI.MUTED, ModUI.BOLD))
	box.add_child(ModUI.title(ad["title"]))
	box.add_child(ModUI.label(ad["text"], 13))
	var row := HBoxContainer.new()
	box.add_child(row)
	var invest := ModUI.button(ad.get("action", "Investir já"), ModUI.WINE, ModUI.WHITE, 13)
	invest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invest.pressed.connect(_say.bind(screen, "Que pena!", ad.get("result", "Oferta esgotada.")))
	row.add_child(invest)
	var remove := ModUI.button("Remover anúncios\n%s" % GameData.format_brl(AD_PRICE), ModUI.INK,
		ModUI.WHITE, 11)
	remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove.pressed.connect(_buy_no_ads.bind(screen, column))
	row.add_child(remove)
	column.add_child(card)
	column.move_child(card, 0)


## Cobra para remover os anúncios e, para manter o app gratuito, coloca mais
func _buy_no_ads(screen: Control, column: VBoxContainer) -> void:
	GameData.bank_balance -= AD_PRICE
	_ads_bought += 1
	_say(screen, "Pagamento aprovado!", "Anúncios removidos com sucesso.*\n\n*Para manter o app "
		+ "gratuito, adicionamos mais %d anúncios." % (_ads_bought + 1))
	var ads: Array = content["ads"]
	for index in _ads_bought + 1:
		_add_ad(screen, column, ads[(_ads_bought + index) % ads.size()])


func _pass_card(screen: Control) -> Control:
	var payments: int = GameData.completed_payments.size()
	var level := clampi(1 + payments * 7 + GameData.current_day * 3, 1, 100)
	var rewards: Array = content["pass_rewards"]
	var card := ModUI.card_panel(ModUI.INK, 12, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(ModUI.label("PASSE BANCÁRIO • TEMPORADA 1", 10, ModUI.YELLOW, ModUI.BOLD))
	box.add_child(ModUI.label("Nível %d/100%s" % [level, " • PREMIUM" if _premium else ""], 18,
		ModUI.WHITE, ModUI.BOLD))
	var bar := ModUI.progress(ModUI.YELLOW)
	bar.value = (payments * 37 + 13) % 100
	box.add_child(bar)
	box.add_child(ModUI.label("Próxima recompensa: " + str(rewards[level % rewards.size()]), 12,
		ModUI.MINT))
	box.add_child(ModUI.label("Faça mais pagamentos para subir de nível!", 11, ModUI.WHITE))
	if not _premium:
		var buy := ModUI.button("Passe Premium • %s" % GameData.format_brl(PREMIUM_PRICE),
			ModUI.YELLOW, ModUI.INK, 13)
		buy.pressed.connect(func() -> void:
			GameData.bank_balance -= PREMIUM_PRICE
			_premium = true
			_say(screen, "Passe Premium liberado!", "Recompensa desbloqueada: Taxa Dourada. Suas "
				+ "transferências agora custam o mesmo, mas você se sente melhor.")
			buy.queue_free()
		)
		box.add_child(buy)
	return card


func _say(screen: Control, title: String, message: String) -> void:
	var column := ModUI.dialog(screen)
	column.add_child(ModUI.title(title))
	column.add_child(ModUI.label(message))
	var ok := ModUI.button("Ok")
	column.add_child(ok)
	ok.pressed.connect(ModUI.close.bind(column))
#endregion BANCO


#region POPUPS
func _on_clock_tick(minutes: int, _story: Node) -> void:
	var every := int(api.config("popup_every_minutes", 40))
	if _popup_open or minutes - _last_popup < every / 2.0 or randf() > 2.0 / every:
		return
	var game := get_tree().current_scene as Control
	if game == null:
		return
	_last_popup = minutes
	_popup(game, content["popups"].pick_random(), 0)


func _popup(game: Control, popup: Dictionary, depth: int) -> void:
	_popup_open = true
	var column := ModUI.dialog(game, 290)
	var top := HBoxContainer.new()
	column.add_child(top)
	var ad_label := ModUI.label("Anúncio", 10, ModUI.MUTED)
	ad_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ad_label)
	# O X de fechar, minúsculo como manda a tradição
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.custom_minimum_size = Vector2(12, 12)
	close.add_theme_font_size_override("font_size", 9)
	close.add_theme_color_override("font_color", Color(ModUI.MUTED, 0.5))
	top.add_child(close)
	column.add_child(ModUI.title(popup["title"], ModUI.WINE))
	column.add_child(ModUI.label(popup["text"]))
	var yes := ModUI.button(popup.get("yes", "QUERO!"), ModUI.WINE, ModUI.WHITE, 18)
	yes.custom_minimum_size.y = 56
	column.add_child(yes)
	var cancel := ModUI.button("CANCELAR", ModUI.MINT, ModUI.INK, 16)
	cancel.custom_minimum_size.y = 48
	column.add_child(cancel)

	close.pressed.connect(func() -> void:
		ModUI.close(column)
		_popup_open = false
	)
	# Cancelar (ou aceitar) leva a mais uma pergunta, umas três vezes
	var next := func() -> void:
		ModUI.close(column)
		var chain: Array = content["cancel_chain"]
		if depth < chain.size():
			_popup(game, chain[depth], depth + 1)
		else:
			_popup_open = false
	cancel.pressed.connect(next)
	yes.pressed.connect(next)
#endregion POPUPS
