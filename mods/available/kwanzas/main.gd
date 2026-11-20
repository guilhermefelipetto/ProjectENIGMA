extends Node
## A partir de um dia, os preços das lojas viram kwanzas, ainda escritos como reais

const SHOPS_PATH := "res://data/browser/shops_items.json"

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.patch_json(SHOPS_PATH, _to_kwanzas)


func _to_kwanzas(shops: Variant, _path: String) -> Variant:
	if not shops is Dictionary or GameData.current_day < int(api.config("from_day", 3)):
		return null
	var rate := float(api.config("rate", 158.27))
	for items in shops.values():
		for item in items:
			item["price"] = snappedf(float(item["price"]) * rate, 0.01)
	return null
