extends Node
## Alonga todo código de Pix e de boleto do jogo, em todo lugar onde aparece: no banco, nas
## mensagens, nos emails, nos eventos e nas notas. O começo do código continua sendo o código
## original, então a regra "2 letras e 3 números" ainda serve para pegar os golpes: ela passa a
## valer para os 5 primeiros caracteres, e as notas e o livro de regras dizem isso

const PIX_CODES_PATH := "res://data/bank/pix_codes_data.json"
const TICKET_CODES_PATH := "res://data/bank/ticket_codes_data.json"
const BOARD_PATH := "res://data/notes/board.json"
const RULES_PATH := "res://data/rules/rules.json"
## Sem O, que se confunde com zero, como os códigos do jogo
const LETTERS_AND_DIGITS := "ABCDEFGHIJKLMNPQRSTUVWXYZ0123456789"
const DIGITS := "0123456789"

var api: ModAPI
var target_length: int
## código original -> código alongado
var _long_codes: Dictionary = {}
var _code_regex: RegEx
var _is_reading_codes := false


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	target_length = maxi(int(api.config("target_length", 120)), 8)
	api.patch_json("res://data/*", _lengthen_codes)
	api.patch_json(BOARD_PATH, _explain_on_board)
	api.patch_json(RULES_PATH, _explain_in_rules)
	# Um código de 120 caracteres não cabe em lugar nenhum: quebra linha
	api.wrap_labels(func(text: String) -> bool:
		return Array(text.split(" ")).any(func(word: String) -> bool:
			return word.length() >= target_length
		)
	)


func _lengthen_codes(data: Variant, _res_path: String) -> Variant:
	# Reading the codes below goes through this patch too
	if _is_reading_codes:
		return null
	if _code_regex == null:
		_build_long_codes()
	if _long_codes.is_empty():
		return null
	return _rewrite(data)


## Reads every code once, from the game and from the other mods
func _build_long_codes() -> void:
	_is_reading_codes = true
	for code_path in [PIX_CODES_PATH, TICKET_CODES_PATH]:
		var codes = api.read_json(code_path)
		if codes is Dictionary:
			for code in codes:
				_long_codes[code] = _make_long_code(str(code))
	_is_reading_codes = false

	var alternatives: Array = _long_codes.keys()
	alternatives.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var escaped: PackedStringArray = []
	for code in alternatives:
		escaped.append(_escape(code))
	_code_regex = RegEx.create_from_string(
		"(?<![A-Za-z0-9])(%s)(?![A-Za-z0-9])" % "|".join(escaped)
	)
	api.info("%d códigos alongados para %d caracteres" % [_long_codes.size(), target_length])


## The same code is always lengthened the same way, so a saved game keeps working
func _make_long_code(code: String) -> String:
	var charset := DIGITS if code.is_valid_int() else LETTERS_AND_DIGITS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(code)
	var long_code := code
	while long_code.length() < target_length:
		long_code += charset[rng.randi_range(0, charset.length() - 1)]
	return long_code


func _rewrite(value: Variant) -> Variant:
	if value is String:
		return _replace_codes(value) if _code_regex.search(value) else value
	if value is Array:
		for index in value.size():
			value[index] = _rewrite(value[index])
		return value
	if value is Dictionary:
		var rewritten := {}
		for key in value:
			rewritten[_rewrite(key) if key is String else key] = _rewrite(value[key])
		return rewritten
	return value


func _replace_codes(text: String) -> String:
	var result := ""
	var last := 0
	for found in _code_regex.search_all(text):
		result += text.substr(last, found.get_start() - last) + _long_codes[found.get_string()]
		last = found.get_end()
	return result + text.substr(last)


func _explain_on_board(board: Variant, _res_path: String) -> Variant:
	if board is Dictionary:
		board["payment_patterns"] = [
			"Código Pix: começa com 2 letras seguidas de 3 números (ex.: PX482…). "
			+ "O resto é verificação, mas confira tudo: um golpe também pode trocar o fim.",
			"Cuidado com a letra O no lugar do zero e com começos de 4 ou 6 caracteres.",
			"Código de boleto: começa com 6 números, seguidos só de números.",
			"Sim, você tem que digitar tudo. Boa sorte.",
		]
	return null


func _explain_in_rules(rules: Variant, _res_path: String) -> Variant:
	if rules is Array:
		for rule in rules:
			if rule is Dictionary and rule.get("id") == "pix_code_format":
				rule["description"] = "O código Pix não começa com 2 letras seguidas de 3 " \
					+ "números, ou o código do boleto não começa com 6 números."
	return null


func _escape(text: String) -> String:
	var escaped := ""
	for character in text:
		escaped += "\\" + character if "\\^$.|?*+()[]{}-/".contains(character) else character
	return escaped
