extends RefCounted
## Reads JSON files and merges what the mods lay over them, see ModLoader.read_json()


## Reads and parses a JSON file, null when it is missing or broken
static func read_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		push_error("[ModLoader] JSON inválido em %s (linha %d): %s" % [
			file_path, parser.get_error_line(), parser.get_error_message()
		])
		return null
	return parser.data


## Lays a JSON value over another, returning the merge. Neither is changed
##
## Objects are merged key by key. Arrays are joined, unless their items are objects with an "id":
## then an item of the overlay is merged into the item of the base with the same id, and joined
## when there is none. Anything else is replaced by the overlay
static func merge(base: Variant, overlay: Variant) -> Variant:
	if overlay == null:
		return base
	if base is Dictionary and overlay is Dictionary:
		var merged: Dictionary = base.duplicate()
		for key in overlay:
			merged[key] = merge(merged[key], overlay[key]) if merged.has(key) \
				else _copy(overlay[key])
		return merged
	if base is Array and overlay is Array:
		return _merge_arrays(base, overlay)
	return _copy(overlay)


static func _merge_arrays(base: Array, overlay: Array) -> Array:
	var merged: Array = base.duplicate()
	if not (_has_ids(base) and _has_ids(overlay)):
		merged.append_array(overlay.duplicate(true))
		return merged

	var index_by_id: Dictionary = {}
	for index in merged.size():
		index_by_id[str(merged[index]["id"])] = index
	for item in overlay:
		var item_id := str(item["id"])
		if index_by_id.has(item_id):
			merged[index_by_id[item_id]] = merge(merged[index_by_id[item_id]], item)
		else:
			index_by_id[item_id] = merged.size()
			merged.append(item.duplicate(true))
	return merged


## Whether every item is an object with an "id", an empty array has none to tell
static func _has_ids(items: Array) -> bool:
	if items.is_empty():
		return false
	for item in items:
		if not (item is Dictionary and item.has("id")):
			return false
	return true


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
