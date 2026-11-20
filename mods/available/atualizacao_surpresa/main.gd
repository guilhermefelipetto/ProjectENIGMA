extends Node
## A primeira confirmação de cada pagamento é cancelada por uma atualização, que embaralha a tela

var api: ModAPI
var changelog: Array
var version := 47
## Códigos que já foram "atualizados" hoje: a segunda tentativa passa
var _updated_codes: Dictionary = {}
var _day := -1


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	changelog = api.read_mod_json("novidades.json")
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if GameData.current_day != _day:
		_day = GameData.current_day
		_updated_codes.clear()
	if app == GameData.App.PAYMENTINFORMATION:
		api.intercept_press(screen.confirm_button, _maybe_update.bind(screen))
	# Depois de uma atualização, o Banco nunca mais é o mesmo
	if app == GameData.App.BANK and version > 47:
		_shuffle(screen.get_node_or_null("Screen/ScrollContainer/Margin/Column"))


func _maybe_update(proceed: Callable, screen: Control) -> void:
	var code: String = screen.payment_code.code
	if _updated_codes.has(code):
		proceed.call()
		return
	_updated_codes[code] = true
	version += 1
	var column := ModUI.dialog(screen)
	column.add_child(ModUI.title("Atualização obrigatória"))
	column.add_child(ModUI.label("Banco 2.%d está sendo instalado. Não feche o aplicativo." % version,
		13, ModUI.MUTED))
	var bar := ModUI.progress()
	column.add_child(bar)
	var news := ModUI.label("", 13)
	column.add_child(news)
	var items: Array = changelog.duplicate()
	items.shuffle()
	for step in 10:
		bar.value = (step + 1) * 10
		news.text = "• " + str(items[step % items.size()])
		await ModUI.wait(self, 0.6)
		if not is_instance_valid(column):
			return
	ModUI.close(column)
	_shuffle(screen.informations_container)
	_shuffle(screen.confirm_button.get_parent())
	var done := ModUI.dialog(screen)
	done.add_child(ModUI.title("Banco atualizado!"))
	done.add_child(ModUI.label("A transação foi cancelada pela atualização. Para sua comodidade, "
		+ "mudamos tudo de lugar. Tente de novo."))
	var ok := ModUI.button("Entendi")
	done.add_child(ok)
	ok.pressed.connect(ModUI.close.bind(done))


## Embaralha a ordem dos filhos de um container
func _shuffle(container: Node) -> void:
	if container == null:
		return
	var children := container.get_children()
	children.shuffle()
	for index in children.size():
		container.move_child(children[index], index)
