extends Node
## Deixa as mensagens e os emails VERDADEIROS com cara de golpe: português estranho, urgência,
## exclamações e emoji demais. Os golpes de verdade ficam como estão, e as regras também: quem
## julgar pela cara vai denunciar coisa certa.
##
## Nomes, códigos e valores não mudam, porque as regras do jogo comparam isso.

const EVENTS_PATH := "res://data/events/events.json"
const SHOP_NAMES := {
	"amazonia": "AMAZÔNIA OFICIAL DEFINITIVA LTDA", "libre_mercado": "LIBRE MERCADO 100% REAL",
	"emilia_bolos": "EMÍLIA BOLOS (NÃO É GOLPE)", "emporio_bolos": "EMPÓRIO DOS BOLOS ORIGINAL",
	"aec": "A&C MODA OFICIAL VERIFICADA", "zora": "ZORA LOJA CONFIÁVEL",
}

var api: ModAPI
var style: Dictionary
## Conversas e emails que são golpes de verdade, esses não mudam
var _scam_conversations: Dictionary = {}
var _scam_emails: Dictionary = {}
var _original_shop_names: Dictionary = {}
var _sentence_end := RegEx.create_from_string("\\.(?=\\s|$)")
var _code_like := RegEx.create_from_string("[0-9@]")


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	style = api.read_mod_json("estilo.json")
	api.patch_json("res://data/messages/*", _patch_conversation)
	api.patch_json("res://data/emails/*", _patch_emails)
	_original_shop_names = GameData.shops_names.duplicate()
	for app in GameData.shops_names:
		for shop_id in GameData.shop_string_to_enum:
			if GameData.shop_string_to_enum[shop_id] == app and SHOP_NAMES.has(shop_id):
				GameData.shops_names[app] = SHOP_NAMES[shop_id]
	# O nome da loja escrito no topo do site
	var renames: Dictionary = {}
	for app in _original_shop_names:
		renames[_original_shop_names[app]] = GameData.shops_names[app]
	api.watch_nodes(func(node: Node) -> bool: return node is Label, func(label: Label) -> void:
		# Agora (já pode estar na tela) e sempre que o texto mudar
		_rename.call_deferred(label, renames)
		label.draw.connect(_rename.bind(label, renames), CONNECT_DEFERRED)
	)


## label sem tipo: pode chegar já liberado, numa chamada adiada
func _rename(label, renames: Dictionary) -> void:
	if api.is_on() and is_instance_valid(label) and renames.has(label.text):
		label.text = renames[label.text]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _exit_tree() -> void:
	GameData.shops_names = _original_shop_names


func _patch_conversation(root: Variant, _path: String) -> Variant:
	_find_scams()
	var conversations: Array = []
	if root is Dictionary:
		conversations = root["conversations"] if root.has("conversations") else [root]
	for conversation in conversations:
		if _scam_conversations.has(str(conversation.get("conversation_id", ""))):
			continue
		for nodes in conversation.get("branches", {}).values():
			for node in nodes:
				if node is Dictionary and node.get("text") is String:
					node["text"] = _scammify(node["text"])
	return null


func _patch_emails(root: Variant, _path: String) -> Variant:
	_find_scams()
	if not root is Array:
		return null
	for email in root:
		if not email is Dictionary or _scam_emails.has(str(email.get("email_id", ""))):
			continue
		for key in ["subject", "content"]:
			if email.get(key) is String:
				email[key] = _scammify(email[key])
	return null


## As conversas e os emails em que algum evento aponta uma discrepância são golpes
func _find_scams() -> void:
	if not _scam_conversations.is_empty():
		return
	var events = api.read_json(EVENTS_PATH)
	if not events is Dictionary:
		return
	for event in events.values():
		for discrepancy in event.get("discrepancies", []):
			for place in discrepancy.get("found_at", []):
				if place.has("conversation"):
					_scam_conversations[str(place["conversation"])] = true
				if place.has("email_id"):
					_scam_emails[str(place["email_id"])] = true


## O mesmo texto vira sempre o mesmo texto estranho
func _scammify(text: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var words := text.split(" ")
	for index in words.size():
		var word := words[index]
		var key := word.to_lower().rstrip(",.!?")
		# Palavras com números ou @ são códigos, valores e endereços: ficam como estão
		if _code_like.search(word):
			continue
		if style["swaps"].has(key) and rng.randf() < 0.8:
			words[index] = word.replace(word.rstrip(",.!?"), style["swaps"][key])
		elif rng.randf() < 0.07:
			words[index] = word.to_upper()
	var result := " ".join(words)
	if rng.randf() < 0.45:
		result = _pick(style["openers"], rng) + " " + result
	# Só o ponto final de frase: "1.480,00" fica como está
	if rng.randf() < 0.4:
		result = _sentence_end.sub(result, "!!!", true)
	if rng.randf() < 0.55:
		result += " " + _pick(style["closers"], rng)
	return result


func _pick(options: Array, rng: RandomNumberGenerator) -> String:
	return str(options[rng.randi_range(0, options.size() - 1)])
