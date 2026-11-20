## Teste de integração dos mods: ativa todos, confere os dados e roda os dias 1 a 6.
## flatpak run org.godotengine.Godot --headless --path . -s res://mods/tests/mods_test.gd
## Restaura a lista de mods ativos ao terminar. Sai com código 1 se algo falhar.
extends SceneTree

var failures := 0

func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1

## Avalia uma conta do Cálculo II traduzindo os símbolos para a Expression do Godot
func evaluate(text: String) -> Variant:
	var rules := [
		["∫ 2x dx de 0 a (\\d+)", "($1*$1)"],
		["∫ dx de (\\d+) a (\\d+)", "($2-$1)"],
		["Σ 1, de k=(\\d+) a (\\d+)", "($2-$1+1)"],
		["Σ k, de k=1 a (\\d+)", "($1*($1+1)/2)"],
		["√(\\d+)", "int(sqrt($1))"],
		["cos\\(π/2\\) × 47", "0"],
	]
	for rule in rules:
		text = RegEx.create_from_string(rule[0]).sub(text, rule[1], true)
	text = text.replace("×", "*").replace("÷", "/").replace("−", "-")
	text = text.replace("²", "**2")
	var expression := Expression.new()
	if expression.parse(text) != OK:
		return "parse: " + text
	var result = expression.execute()
	return int(round(result)) if result is float or result is int else result

func _initialize() -> void:
	call_deferred("_run")
	# Um erro de script no meio do teste não pode deixá-lo preso
	create_timer(300.0).timeout.connect(func():
		print("FALHAS: tempo esgotado")
		quit(1)
	)

func _run() -> void:
	var loader = root.get_node("ModLoader")
	var gd = root.get_node("GameData")
	gd.start_date_dict = Time.get_date_dict_from_system()
	var previous: PackedStringArray = loader.enabled_ids.duplicate()
	print("mods:", loader.available_mods.map(func(m): return m.id))
	check(loader.available_mods.size() >= 7, "%d mods descobertos" % loader.available_mods.size())

	# --- sem mods: dados idênticos aos arquivos
	loader.apply_enabled(PackedStringArray())
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/events.json"))
	check(loader.read_json("res://data/events/events.json") == raw, "sem mods: events.json intacto")
	var plain_dirs = loader.list_subdirectories("res://data/messages")
	check(not plain_dirs.has("res://data/messages/presidente"), "sem mods: sem pasta presidente")

	# --- todos os mods
	var all := PackedStringArray()
	for m in loader.available_mods: all.append(m.id)
	loader.apply_enabled(all)
	check(loader.active_mods.size() == loader.available_mods.size(), "todos os mods ativos")
	var dirs = loader.list_subdirectories("res://data/messages")
	for d in ["presidente", "modsbot", "tia_cleuza", "mae_aflita"]:
		check(dirs.has("res://data/messages/" + d), "pasta de mensagens do mod: " + d)
	var events = loader.read_json("res://data/events/events.json")
	check(events.has("presidente_golpe"), "evento do presidente mesclado")
	check(events.size() == raw.size() + 1, "eventos do jogo preservados")
	var shops = loader.read_json("res://data/browser/shops_items.json")
	check(shops["amazonia"].size() == 26 and shops["amazonia"][0]["id"] == 11, "produtos: base + 20 novos")
	var pix = loader.read_json("res://data/bank/pix_codes_data.json")
	var long_pr := ""
	for code in pix:
		if code.begins_with("PR3S1"): long_pr = code
	check(long_pr.length() == 120, "código PR3S1 alongado para 120: " + long_pr.left(20))
	check(not pix.has("ANVNB"), "código original sumiu do banco")
	var pres = events["presidente_golpe"]
	check(pres["requires"][0]["payment_id"] == long_pr, "evento aponta pro código longo")
	var presidente = loader.read_json("res://data/messages/presidente/presidente_1.json")
	var all_text := JSON.stringify(presidente)
	check(all_text.contains(long_pr), "mensagem do presidente usa o código longo")
	check(not all_text.contains("R$ 5.000"), "valor do presidente virou conta")
	print("    ex.: ", presidente["branches"]["d2_emergencia"][4]["text"].left(110))

	# payment_value: o 'contains' do evento continua batendo com a mensagem
	var d3g10 = events["d3g10_carolina"]
	var contains := ""
	for disc in d3g10["discrepancies"]:
		for place in disc["found_at"]:
			if place.has("contains") and disc["rule"] == "payment_value": contains = place["contains"]
	check(contains.begins_with("R$ (") , "contains do evento virou conta: " + contains)
	var found_in_chat := false
	for path in loader.list_json_files("res://data/messages/carolina"):
		if JSON.stringify(loader.read_json(path)).contains(contains.json_escape()): found_in_chat = true
	check(found_in_chat, "a mesma conta está na mensagem da Carolina")
	var board = loader.read_json("res://data/notes/board.json")
	check(str(board["payment_patterns"]).contains("digitar tudo"), "notas explicam códigos longos")

	# --- Cálculo II: contas geradas avaliadas por fora, e o filtro do format_brl
	var calc = loader._instances["felipetto.calculo_2_pagamentos"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var amounts: Array = range(0, 3001)
	for i in 3000:
		amounts.append(rng.randi_range(3001, 10000000))
	var wrong: Array = []
	var showing := 0
	var longest := ""
	for amount in amounts:
		var text: String = calc.express(amount)
		var got = evaluate(text)
		if not (got is int and got == amount):
			wrong.append("%d = %s -> %s" % [amount, text, evaluate(text)])
		if amount > 0 and calc._shows_amount(text, amount):
			showing += 1
		if text.length() > longest.length():
			longest = text
	check(wrong.is_empty(), "%d contas avaliadas, erradas: %d %s" % [amounts.size(), wrong.size(), wrong.slice(0, 3)])
	check(showing == 0, "nenhuma conta mostra o próprio número")
	print("    maior conta: ", longest)
	for amount in [58, 1480, 150000]:
		print("    %d -> %s" % [amount, calc.express(amount)])
	check(calc.express(1480) == calc.express(1480), "mesma quantia, mesma conta")
	var formatted: String = gd.format_brl(1480.0)
	check(formatted == "R$ %s,00" % calc.express(1480), "format_brl usa a mesma conta: " + formatted)
	check(contains == "R$ %s,00" % calc.express(1480), "chat e Banco mostram a mesma conta para R$ 1.480")
	check(gd.format_brl(-58.9).begins_with("-R$ ("), "valor negativo: " + gd.format_brl(-58.9))

	# wrap_labels: um rótulo que sai e volta para a árvore não é conectado duas vezes
	var label := Label.new()
	root.add_child(label)
	root.remove_child(label)
	root.add_child(label)
	label.text = "R$ (1 + 2),00"
	await process_frame
	await process_frame
	check(label.autowrap_mode != TextServer.AUTOWRAP_OFF, "rótulo com conta passou a quebrar linha")
	label.free()

	# --- jogo de verdade, dias 1 a 6
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	for day in range(1, 7):
		gd.current_day = day
		gd.downloaded_apps.assign([gd.App.MESSAGESHOME, gd.App.NOTES, gd.App.BANK, gd.App.EMAIL, gd.App.BROWSER])
		var game = scene.instantiate()
		root.add_child(game)
		await process_frame
		var story = game.story_director
		var convs = story.messages_director.conversations_by_id
		check(convs.has("presidente_1") and convs.has("tia_cleuza"), "dia %d: conversas dos mods registradas" % day)
		var received := []
		story.messages_director.npc_message_sent.connect(func(c, m, _a, _s, _t): received.append(c["id"]))
		for minute in range(480, 540):
			gd.hours_minutes = minute
			story.on_clock_tick(minute)
		await create_timer(6.0).timeout
		var ids := {}
		for r in received: ids[r] = ids.get(r, 0) + 1
		print("    dia %d mensagens: %s" % [day, ids])
		if day == 2:
			check(ids.has("mae_aflita") and ids.has("agiota_sereno") and ids.has("banco_seguranca") and ids.has("tutorial_sarcastico"), "dia 2: os 4 contatos ao mesmo tempo")
			check(story.events_director.initiated_events.has("presidente_golpe") or ids.has("presidente_1") or story.main_queue.any(func(e): return e["owner"] == "messages:presidente_1"), "dia 2: presidente agendado/entregue")
		if day == 1:
			check(ids.has("tia_cleuza") or story.messages_director.setup_count > 0, "dia 1: tia cleuza começou")
		game.queue_free()
		await process_frame

	loader.apply_enabled(previous)
	print("FALHAS: %d" % failures)
	print("FIM DO TESTE")
	quit(1 if failures else 0)
