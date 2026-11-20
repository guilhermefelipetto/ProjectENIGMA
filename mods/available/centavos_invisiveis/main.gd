extends Node
## Todo valor mostrado pelo jogo ganha centavos, um pouco a cada vez que aparece

const CHANCE := 0.4

var api: ModAPI
## valor -> centavos a mais
var _extra: Dictionary = {}
var _cents := RegEx.create_from_string(",(\\d{2})$")


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.filter("money_text", _drift)


func _drift(text: String, value: float) -> String:
	var key := "%.2f" % value
	if not _extra.has(key):
		# Na primeira vez aparece certo
		_extra[key] = 0
	elif randf() < CHANCE:
		_extra[key] += 1
	var found := _cents.search(text)
	if found == null or _extra[key] == 0:
		return text
	var cents := mini(int(found.get_string(1)) + _extra[key], 99)
	return text.substr(0, found.get_start()) + ",%02d" % cents
