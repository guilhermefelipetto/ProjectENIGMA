extends Node
## Uma maratona de autenticação, uma vez por dia, antes de usar o Banco

const PRODUCTS := "res://assets/icons/shops/products/"
const ICONS := {
	"martelos": "amazonia/martelo.png", "furadeiras": "amazonia/furadeira.png",
	"monitores": "amazonia/monitor.png", "barras de aço": "amazonia/aco.png",
	"frigobares": "amazonia/frigobar.png", "bolos": "emilia/bolo_decorado.png",
}

var api: ModAPI
var _authenticated_day := -1


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if app != GameData.App.BANK or _authenticated_day == GameData.current_day:
		return
	# A autenticação em andamento continua de onde parou
	if screen.has_meta("auth_dialog") and is_instance_valid(screen.get_meta("auth_dialog")):
		return
	var column := ModUI.dialog(screen, 320)
	screen.set_meta("auth_dialog", column)
	column.add_child(ModUI.label("BANCO • AUTENTICAÇÃO NÍVEL MÁXIMO", 10, ModUI.MUTED, ModUI.BOLD))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	_run(column, body)


func _run(column: VBoxContainer, body: VBoxContainer) -> void:
	for step in api.config("steps", []):
		await call("_step_" + str(step), body)
		if not is_instance_valid(body):
			return
	_clear(body)
	body.add_child(ModUI.title("Autenticação concluída"))
	body.add_child(ModUI.label("Bem-vindo ao seu Banco. Válida até o fim do dia."))
	var enter := ModUI.button("Entrar")
	body.add_child(enter)
	await enter.pressed
	_authenticated_day = GameData.current_day
	ModUI.close(column)


#region ETAPAS
func _step_cpf(body: VBoxContainer) -> void:
	_clear(body)
	body.add_child(ModUI.title("Login Nível Ouro"))
	body.add_child(ModUI.label("Digite seu CPF para continuar.", 13, ModUI.MUTED))
	var field := _field("000.000.000-00")
	body.add_child(field)
	var error := ModUI.label("", 12, ModUI.WINE)
	body.add_child(error)
	var go := ModUI.button("Continuar")
	body.add_child(go)
	var digit := RegEx.create_from_string("\\d")
	while true:
		await go.pressed
		var digits := digit.search_all(field.text).size()
		if digits == 11:
			return
		error.text = "CPF inválido: tem que ter 11 números (o seu tinha %d)." % digits


func _step_captcha(body: VBoxContainer) -> void:
	var rounds := int(api.config("captcha_rounds", 3))
	var round_index := 0
	while round_index < rounds:
		_clear(body)
		var names: Array = ICONS.keys()
		var target: String = names[round_index % names.size()]
		body.add_child(ModUI.title("Não sou um robô (%d/%d)" % [round_index + 1, rounds]))
		body.add_child(ModUI.label("Selecione todas as imagens com %s." % target.to_upper(), 13))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		body.add_child(grid)
		var verify := ModUI.button("Verificar")
		verify.disabled = true
		body.add_child(verify)
		# Pelo menos três certas; as imagens aparecem uma por uma, devagar
		var picks: Array = []
		for index in 9:
			picks.append(target if index < 3 else names.pick_random())
		picks.shuffle()
		var tiles: Array[Button] = []
		for pick in picks:
			var tile := Button.new()
			tile.toggle_mode = true
			tile.custom_minimum_size = Vector2(88, 72)
			tile.icon = load(PRODUCTS + ICONS[pick])
			tile.expand_icon = true
			tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.set_meta("is_target", pick == target)
			grid.add_child(tile)
			tiles.append(tile)
			await ModUI.wait(self, 0.45)
			if not is_instance_valid(grid):
				return
		verify.disabled = false
		await verify.pressed
		var right := tiles.all(func(tile: Button) -> bool:
			return tile.button_pressed == tile.get_meta("is_target")
		)
		if right:
			round_index += 1
		else:
			_clear(body)
			body.add_child(ModUI.title("Errou"))
			body.add_child(ModUI.label("Carregando novas imagens...", 13, ModUI.MUTED))
			await ModUI.wait(self, 2.0)


func _step_pesca(body: VBoxContainer) -> void:
	_clear(body)
	var needed := int(api.config("fish_catches", 3))
	var caught := 0
	body.add_child(ModUI.title("Prove que é humano"))
	var info := ModUI.label("Toque em Pescar quando o peixe estiver na faixa verde. 0/%d" % needed,
		13)
	body.add_child(info)
	var lake := ColorRect.new()
	lake.color = Color(0.2, 0.5, 0.75)
	lake.custom_minimum_size = Vector2(0, 64)
	lake.clip_contents = true
	body.add_child(lake)
	var zone := ColorRect.new()
	zone.color = Color(0.4, 0.85, 0.5, 0.75)
	zone.size = Vector2(64, 64)
	lake.add_child(zone)
	var fish := ModUI.label("><>", 22, ModUI.YELLOW, ModUI.BOLD)
	fish.autowrap_mode = TextServer.AUTOWRAP_OFF
	fish.position = Vector2(0, 16)
	lake.add_child(fish)
	var fish_button := ModUI.button("Pescar!", ModUI.WINE)
	body.add_child(fish_button)
	await get_tree().process_frame
	var width: float = maxf(lake.size.x, 280.0)
	zone.position.x = randf_range(20, width - 84)
	var swim := fish.create_tween().set_loops()
	swim.tween_property(fish, "position:x", width - 40, 1.4)
	swim.tween_property(fish, "position:x", 0.0, 1.4)
	while caught < needed:
		await fish_button.pressed
		if not is_instance_valid(fish):
			return
		var center := fish.position.x + fish.size.x / 2
		if center >= zone.position.x and center <= zone.position.x + zone.size.x:
			caught += 1
			zone.position.x = randf_range(20, width - 84)
			swim.set_speed_scale(1.0 + caught * 0.6)
			info.text = "Pegou! %d/%d" % [caught, needed]
		else:
			info.text = "Escapou! %d/%d" % [caught, needed]
	swim.kill()


func _step_assinatura(body: VBoxContainer) -> void:
	for attempt in 2:
		_clear(body)
		body.add_child(ModUI.title("Assinatura digital"))
		body.add_child(ModUI.label("Assine com o dedo no quadro abaixo." if attempt == 0 else
			"A assinatura não confere com a do cartório. Assine de novo, igualzinho.", 13,
			ModUI.MUTED if attempt == 0 else ModUI.WINE))
		var pad := ColorRect.new()
		pad.color = Color(0.97, 0.97, 0.94)
		pad.custom_minimum_size = Vector2(0, 120)
		pad.set_meta("ink", 0.0)
		pad.clip_contents = true
		body.add_child(pad)
		var line := Line2D.new()
		line.width = 3
		line.default_color = ModUI.INK
		pad.add_child(line)
		var sign := ModUI.button("Assinar")
		sign.disabled = true
		body.add_child(sign)
		pad.gui_input.connect(func(event: InputEvent) -> void:
			var drag := event as InputEventMouseMotion
			if drag and drag.button_mask & MOUSE_BUTTON_MASK_LEFT:
				if line.get_point_count() > 0:
					pad.set_meta("ink", pad.get_meta("ink") + line.points[-1].distance_to(drag.position))
				line.add_point(drag.position)
				sign.disabled = pad.get_meta("ink") < 120.0
			elif event is InputEventMouseButton and event.pressed:
				line.add_point(event.position)
		)
		await sign.pressed
		if not is_instance_valid(body):
			return


func _step_email(body: VBoxContainer) -> void:
	_clear(body)
	body.add_child(ModUI.title("Confirme seu email"))
	var info := ModUI.label("Enviamos um link de confirmação para estagiario@enigma.com.br. "
		+ "Abra o link e volte aqui.", 13)
	body.add_child(info)
	var done := ModUI.button("Já cliquei no link")
	body.add_child(done)
	await done.pressed
	if not is_instance_valid(body):
		return
	info.text = "Link expirado (validade: 3 segundos). Enviamos outro."
	info.add_theme_color_override("font_color", ModUI.WINE)
	done.disabled = true
	done.text = "Aguardando o novo email..."
	await ModUI.wait(self, 4.0)
	if not is_instance_valid(done):
		return
	info.text = "Novo link enviado. Esse vale 5 segundos, corre."
	info.add_theme_color_override("font_color", ModUI.INK)
	done.disabled = false
	done.text = "Já cliquei no link novo"
	await done.pressed


func _step_rosto(body: VBoxContainer) -> void:
	_clear(body)
	body.add_child(ModUI.title("Reconhecimento facial"))
	var frame := ModUI.card_panel(Color(0.1, 0.12, 0.16), 75, 10)
	frame.custom_minimum_size = Vector2(150, 150)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := ModUI.label(":|", 40, ModUI.WHITE, ModUI.BOLD)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(face)
	body.add_child(frame)
	var hint := ModUI.label("", 14, ModUI.INK, ModUI.SEMI)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	var bar := ModUI.progress()
	body.add_child(bar)
	var moves := [["Posicione o rosto no círculo", ":|"], ["Pisque duas vezes", ";|"],
		["Vire para a esquerda", ":|"], ["Sorria", ":)"], ["Mais", ":D"],
		["Agora faça cara de quem paga imposto", ":("], ["Não se mexa...", ":|"]]
	for index in moves.size():
		hint.text = moves[index][0]
		face.text = moves[index][1]
		bar.value = 100.0 * (index + 1) / moves.size()
		await ModUI.wait(self, 1.3)
		if not is_instance_valid(body):
			return


func _step_cartorio(body: VBoxContainer) -> void:
	_clear(body)
	body.add_child(ModUI.title("Prova de vida"))
	body.add_child(ModUI.label("Para continuar, comprove no cartório que você está vivo(a). "
		+ "Escolha uma data:", 13))
	var picked: Array = []
	for option in ["Daqui a 47 dias úteis", "Daqui a 89 dias úteis", "Março de 2031"]:
		var date := ModUI.button(option, ModUI.MINT, ModUI.INK, 13)
		date.pressed.connect(func() -> void: picked.append(option))
		body.add_child(date)
	while picked.is_empty():
		await get_tree().process_frame
		if not is_instance_valid(body):
			return
	_clear(body)
	body.add_child(ModUI.title("Agendado: " + str(picked[0])))
	body.add_child(ModUI.label("Até lá, liberamos um acesso provisório. Leve RG, CPF, comprovante "
		+ "de residência e você mesmo(a), vivo(a).", 13))
	var go := ModUI.button("Continuar")
	body.add_child(go)
	await go.pressed


func _step_pombo(body: VBoxContainer) -> void:
	var seconds := float(api.config("pigeon_seconds", 20))
	while true:
		_clear(body)
		body.add_child(ModUI.title("Código de segurança"))
		body.add_child(ModUI.label("Enviamos seu código por pombo-correio.", 13, ModUI.MUTED))
		var bar := ModUI.progress(ModUI.YELLOW)
		body.add_child(bar)
		var status := ModUI.label("", 13)
		body.add_child(status)
		var left := seconds
		while left > 0:
			bar.value = 100.0 * (1.0 - left / seconds)
			status.text = "Pombo a caminho... chega em %d s" % ceili(left)
			await ModUI.wait(self, 0.5)
			if not is_instance_valid(body):
				return
			left -= 0.5
		var code := str(randi_range(1000, 9999))
		_clear(body)
		body.add_child(ModUI.title("O pombo chegou!"))
		body.add_child(ModUI.label("No bilhete preso na pata: %s" % code, 14, ModUI.INK, ModUI.SEMI))
		var field := _field("Código")
		body.add_child(field)
		var go := ModUI.button("Confirmar código")
		body.add_child(go)
		await go.pressed
		if field.text.strip_edges() == code:
			return
		_clear(body)
		body.add_child(ModUI.title("Código errado"))
		body.add_child(ModUI.label("Enviando outro pombo...", 13, ModUI.MUTED))
		await ModUI.wait(self, 1.5)
		seconds = maxf(seconds / 2, 5)
#endregion ETAPAS


func _clear(body: Node) -> void:
	for child in body.get_children():
		child.queue_free()


func _field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 40
	field.add_theme_font_override("font", ModUI.REGULAR)
	field.add_theme_font_size_override("font_size", 16)
	return field
