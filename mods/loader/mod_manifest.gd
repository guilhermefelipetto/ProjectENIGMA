class_name ModManifest
extends RefCounted
## A mod as its mod.json describes it, see mods/README.md

const MANIFEST_FILE := "mod.json"
## Folder of a mod mirroring res://data, laid over the data of the game
const DATA_DIR := "data"

var id: String
var display_name: String
var version: String
var authors: PackedStringArray
var description: String
## Higher loads first, so a lower one is laid over it and has the last word
var priority: int
var depends: PackedStringArray
## Script with the hooks of the mod, relative to its folder
var script_path: String
## .pck replacing files of the game, relative to its folder
var pack_path: String
## Data files the mod replaces whole instead of merging ("data/news.json")
var replaces: PackedStringArray
## Free values for the script of the mod, see ModAPI.config()
var config: Dictionary
## Folder of the mod, res:// for the ones shipped with the game and user:// for the others
var mod_path: String
var is_builtin: bool


## Reads the mod.json of a mod folder, null (with a warning) when it is not a valid one
static func load_from(mod_dir: String, builtin: bool) -> ModManifest:
	var manifest_path := mod_dir.path_join(MANIFEST_FILE)
	var data = preload("res://mods/loader/json_overlay.gd").read_file(manifest_path)
	if not data is Dictionary:
		push_warning("[ModLoader] %s não é um objeto JSON" % manifest_path)
		return null
	var mod_id := str(data.get("id", "")).strip_edges()
	if mod_id == "":
		push_warning("[ModLoader] %s não tem \"id\"" % manifest_path)
		return null

	var manifest := ModManifest.new()
	manifest.id = mod_id
	manifest.display_name = str(data.get("name", mod_id))
	manifest.version = str(data.get("version", "0.0.0"))
	manifest.authors = _to_strings(data.get("authors", []))
	manifest.description = str(data.get("description", ""))
	manifest.priority = int(data.get("priority", 0))
	manifest.depends = _to_strings(data.get("depends", []))
	manifest.script_path = str(data.get("main_script", ""))
	manifest.pack_path = str(data.get("pack", ""))
	manifest.replaces = _to_strings(data.get("replace", []))
	var config_data = data.get("config", {})
	manifest.config = config_data if config_data is Dictionary else {}
	manifest.mod_path = mod_dir
	manifest.is_builtin = builtin
	return manifest


## Where the mod keeps its version of a data file of the game ("res://data/news.json")
func get_overlay_path(res_path: String) -> String:
	return mod_path.path_join(DATA_DIR).path_join(res_path.trim_prefix("res://data/"))


## Whether the mod replaces a data file of the game whole instead of merging into it
func replaces_file(res_path: String) -> bool:
	return replaces.has(res_path.trim_prefix("res://"))


static func _to_strings(values: Variant) -> PackedStringArray:
	var strings := PackedStringArray()
	if values is Array:
		for value in values:
			strings.append(str(value))
	return strings
