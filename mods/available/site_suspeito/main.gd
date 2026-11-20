extends Node
## Um site de filmes "grátis" no Navegador. Abrir já basta: popups, um player para instalar e
## o celular hackeado, com vírus de brinde. No fim, como reconhecer esse tipo de site.
##
## Nada de conteúdo impróprio: a graça é o endereço suspeito e tudo o que vem junto.

const SITES_PATH := "Screen/ScrollContainer/Margin/Column/SitesSection/SitesCard/SitesList"
const ADDRESS := "xfilmes-gratis.biz.ru"
const NIGHT := Color(0.05, 0.04, 0.08)
const RED := Color(0.92, 0.1, 0.2)
const HACKER_GREEN := Color(0.3, 1.0, 0.45)

const MOVIES := [
	["O Estagiário 2: A Vingança do Boleto", Color(0.55, 0.12, 0.2)],
	["Capivara Assassina 4K", Color(0.2, 0.35, 0.6)],
	["Velozes e Parcelados 12x", Color(0.85, 0.45, 0.1)],
	["Titanic 2: O Iceberg Volta", Color(0.15, 0.5, 0.55)],
	["Vingadores do Condomínio", Color(0.35, 0.2, 0.55)],
	["Procurando o Pix", Color(0.1, 0.55, 0.3)],
]
const POPUPS := [
	"PARABÉNS!!! Você é o visitante nº 1.000.000",
	"Seu celular está com 37 VÍRUS! Limpe agora",
	"Ganhe R$ 5.000 por dia sem sair de casa",
	"Atualize seu player para continuar",
	"Você ganhou um celular novo! Toque aqui",
	"Sua conta do Banco foi bloqueada. Clique",
]
const STEPS := [
	"> conectando a xfilmes-gratis.biz.ru... OK",
	"> instalando PlayerHD_2026.apk... OK",
	"> lendo contatos... 248 encontrados",
	"> copiando senhas salvas... OK",
	"> abrindo o app do Banco... OK",
	"> instalando %d vírus de brinde... OK",
]
const TIPS := [
	"Site de filme, série ou jogo \"grátis\" que ninguém conhece vive de anúncio malicioso.",
	"Endereço estranho (.biz, .ru, cheio de hífen) é sinal de alerta antes mesmo de abrir.",
	"Nenhum site precisa que você instale um \"player\" para ver vídeo.",
	"\"Você ganhou um prêmio\" e \"seu celular tem vírus\" em popup são sempre mentira.",
	"Agora: rode o Antivírus nas Configurações e troque as senhas.",
]

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if app != GameData.App.BROWSER:
		return
	var sites := screen.get_node_or_null(SITES_PATH) as VBoxContainer
	if sites == null or sites.has_meta("xfilmes"):
		return
	sites.set_meta("xfilmes", true)
	sites.add_child(_site_row(screen))


#region LINHA NA LISTA DE SITES
func _site_row(screen: Control) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var line := ColorRect.new()
	line.color = Color(ModUI.INK, 0.08)
	line.custom_minimum_size.y = 1
	column.add_child(line)

	var row_button := Button.new()
	row_button.flat = true
	row_button.custom_minimum_size.y = 54
	row_button.pressed.connect(_open_site.bind(screen))
	column.add_child(row_button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	row_button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var logo := ModUI.card_panel(RED, 10, 0)
	logo.custom_minimum_size = Vector2(38, 38)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := ModUI.label("X", 24, ModUI.WHITE, ModUI.BOLD)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_child(letter)
	row.add_child(logo)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_child(ModUI.label("XFilmes Grátis", 15, ModUI.INK, ModUI.SEMI))
	texts.add_child(ModUI.label(ADDRESS, 11, ModUI.MUTED))
	row.add_child(texts)

	var badge := ModUI.card_panel(ModUI.YELLOW, 100, 4)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var free := ModUI.label("GRÁTIS", 10, ModUI.INK, ModUI.BOLD)
	free.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.add_child(free)
	row.add_child(badge)
	for node in [letter, texts, badge] + texts.get_children() + badge.get_children():
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column
#endregion LINHA NA LISTA DE SITES


#region O SITE
func _open_site(screen: Control) -> void:
	var page := _full_page(screen, NIGHT)
	var column: VBoxContainer = page.get_meta("column")

	var title := ModUI.label("XFILMES GRÁTIS", 30, RED, ModUI.BOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := ModUI.label("Filmes que nem estrearam • sem cadastro • 100% seguro", 12,
		ModUI.YELLOW, ModUI.SEMI)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for movie in MOVIES:
		grid.add_child(_movie_card(page, movie[0], movie[1]))

	# Os popups vão chegando, e qualquer toque leva ao "player"
	_spawn_popups(page)
	await ModUI.wait(self, 4.5)
	if is_instance_valid(page) and not page.has_meta("installing"):
		_ask_install(page)


func _movie_card(page: Control, movie_title: String, color: Color) -> Control:
	var card := ModUI.card_panel(color, 8, 8)
	card.custom_minimum_size = Vector2(150, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	card.add_child(box)
	var name_label := ModUI.label(movie_title, 12, ModUI.WHITE, ModUI.BOLD)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)
	var watch := ModUI.button("▶ ASSISTIR", RED, ModUI.WHITE, 12)
	watch.custom_minimum_size.y = 30
	watch.pressed.connect(_ask_install.bind(page))
	box.add_child(watch)
	return card


func _spawn_popups(page: Control) -> void:
	var rng := RandomNumberGenerator.new()
	for text in POPUPS:
		await ModUI.wait(self, 0.7)
		if not is_instance_valid(page) or page.has_meta("installing"):
			return
		var popup := ModUI.card_panel(ModUI.WHITE, 6, 10)
		popup.custom_minimum_size.x = 230
		var box := VBoxContainer.new()
		popup.add_child(box)
		box.add_child(ModUI.label("Anúncio", 9, ModUI.MUTED))
		box.add_child(ModUI.label(text, 14, RED, ModUI.BOLD))
		var claim := ModUI.button("CLIQUE AQUI", ModUI.TEAL, ModUI.WHITE, 13)
		claim.custom_minimum_size.y = 32
		claim.pressed.connect(_ask_install.bind(page))
		box.add_child(claim)
		# O anúncio inteiro é clicável, não só o botão
		popup.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_ask_install(page)
		)
		page.add_child(popup)
		popup.size = Vector2(230, 0)
		popup.reset_size.call_deferred()
		popup.position = Vector2(rng.randf_range(4, maxf(page.size.x - 240, 5)),
			rng.randf_range(90, maxf(page.size.y - 160, 91)))


func _ask_install(page: Control) -> void:
	if not is_instance_valid(page) or page.has_meta("installing"):
		return
	page.set_meta("installing", true)
	var column := ModUI.dialog(page, 280)
	column.add_child(ModUI.title("Player desatualizado"))
	column.add_child(ModUI.label("Para assistir em HD, instale o PlayerHD_2026.apk (é rapidinho!)."))
	var install := ModUI.button("Instalar")
	column.add_child(install)
	var cancel := ModUI.button("Cancelar", ModUI.MINT, ModUI.INK)
	column.add_child(cancel)
	# Cancelar também instala, claro
	for button in [install, cancel]:
		button.pressed.connect(_install.bind(page, column))


func _install(page: Control, column: VBoxContainer) -> void:
	for child in column.get_children():
		child.queue_free()
	column.add_child(ModUI.title("Instalando..."))
	var bar := ModUI.progress(RED)
	column.add_child(bar)
	for step in 20:
		await ModUI.wait(self, 0.07)
		if not is_instance_valid(bar):
			return
		bar.value = (step + 1) * 5
	_hacked(page)
#endregion O SITE


#region HACKEADO
func _hacked(page: Control) -> void:
	var screen := page.get_parent() as Control
	page.queue_free()
	var hacked := _full_page(screen, Color.BLACK)
	var column: VBoxContainer = hacked.get_meta("column")
	var viruses := int(api.config("viruses", 12))
	for step in STEPS:
		await ModUI.wait(self, 0.45)
		if not is_instance_valid(column):
			return
		var text: String = step % viruses if step.contains("%d") else step
		column.add_child(ModUI.label(text, 13, HACKER_GREEN, ModUI.SEMI))

	GameData.number_of_viruses += viruses
	var game := get_tree().current_scene
	if game and game.get("event_handler"):
		game.event_handler.hack_handler.force_hack()

	await ModUI.wait(self, 0.6)
	if not is_instance_valid(column):
		return
	var alert := ModUI.label("CELULAR HACKEADO", 30, RED, ModUI.BOLD)
	alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(alert)

	var card := ModUI.card_panel(ModUI.WHITE, 12, 14)
	var tips := VBoxContainer.new()
	tips.add_theme_constant_override("separation", 6)
	card.add_child(tips)
	tips.add_child(ModUI.title("O que aconteceu?"))
	for tip in TIPS:
		tips.add_child(ModUI.label("• " + tip, 13))
	var close := ModUI.button("Fechar")
	close.pressed.connect(hacked.queue_free)
	tips.add_child(close)
	column.add_child(card)
#endregion HACKEADO


## Página que cobre a tela do app inteira, com rolagem. A coluna do conteúdo fica na meta "column"
func _full_page(screen: Control, color: Color) -> Control:
	var page := ColorRect.new()
	page.color = color
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	page.set_meta("column", column)
	return page
