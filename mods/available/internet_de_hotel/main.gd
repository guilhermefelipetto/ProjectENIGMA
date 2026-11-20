extends Node
## Cada site do Navegador carrega devagar e às vezes falha

const SITES := [
	"BROWSERNEWS", "REVIEWSSITE", "BROWSERFAKESHOP", "BROWSERAMAZONIASHOP",
	"BROWSERLIBREMERCADOSHOP", "BROWSEREMILIASHOP", "BROWSEREMPORIOBOLOSSHOP", "BROWSERAECSHOP",
	"BROWSERZORASHOP", "BROWSERPAYMENTSCREEN",
]
const ERRORS := [
	"Erro desconhecido (ERR_WIFI_DO_HOTEL)", "Erro 418: o servidor é um bule de chá",
	"Tempo esgotado. O roteador está no quarto 47.", "Erro desconhecido. Tente desligar e ligar.",
]

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	for site in SITES:
		if app == GameData.App[site]:
			_load(screen)
			return


func _load(screen: Control) -> void:
	var column := ModUI.dialog(screen, 280)
	column.add_child(ModUI.title("Carregando..."))
	var status := ModUI.label("Conectando ao Wi-Fi do hotel", 13, ModUI.MUTED)
	column.add_child(status)
	var bar := ModUI.progress()
	column.add_child(bar)
	var seconds := randf_range(float(api.config("min_seconds", 4)), float(api.config("max_seconds", 14)))
	var elapsed := 0.0
	var steps := ["Conectando ao Wi-Fi do hotel", "Aceitando os termos do Wi-Fi do hotel",
		"Digitando o número do quarto", "Baixando a internet", "Quase lá", "Quase lá mesmo"]
	while elapsed < seconds:
		await ModUI.wait(self, 0.25)
		if not is_instance_valid(column) or not screen.is_visible_in_tree():
			ModUI.close(column)
			return
		elapsed += 0.25
		# Corre no começo e trava em 99%
		bar.value = minf(99.0, 100.0 * sqrt(elapsed / seconds) * 1.1)
		status.text = steps[mini(int(elapsed / seconds * steps.size()), steps.size() - 1)]
	ModUI.close(column)
	if randf() < float(api.config("error_chance", 0.3)):
		var failed := ModUI.dialog(screen, 280)
		failed.add_child(ModUI.title("Ops"))
		failed.add_child(ModUI.label(ERRORS.pick_random()))
		var retry := ModUI.button("Tentar de novo")
		failed.add_child(retry)
		retry.pressed.connect(func() -> void:
			ModUI.close(failed)
			_load(screen)
		)
