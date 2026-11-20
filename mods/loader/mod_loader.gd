extends Node
## Finds the mods, turns the enabled ones on and lays their data over the data of the game
##
## Autoload "ModLoader". The game reads its JSON through read_json(), list_json_files() and
## list_subdirectories(), and tells the mods what happens through emit_hook(). With no mod enabled
## all of them give exactly what the game files hold. See mods/README.md.

## Emitted after the mods were turned on again, see apply_enabled()
signal mods_reloaded

const JsonOverlay := preload("res://mods/loader/json_overlay.gd")

const BUILTIN_MODS_DIR := "res://mods/available"
const USER_MODS_DIR := "user://mods"
const ENABLED_MODS_FILE := "user://mods_enabled.json"
## Only what is under it can be laid over by the "data" folder of a mod
const DATA_ROOT := "res://data/"

## Every mod found, enabled or not, by name
var available_mods: Array[ModManifest] = []
## Mods turned on, in the order they are applied: the last one has the last word
var active_mods: Array[ModManifest] = []
var enabled_ids: PackedStringArray = PackedStringArray()

## mod id -> node running its main_script
var _instances: Dictionary = {}
## hook name -> Array[Callable]
var _hooks: Dictionary = {}
## filter name -> Array[Callable], see apply_filter()
var _filters: Dictionary = {}
## {"pattern": String, "callable": Callable} in the order the mods registered them
var _json_patches: Array[Dictionary] = []
## API of every mod on, told when it is turned off, see ModAPI.is_on()
var _apis: Array[ModAPI] = []
## [Signal, Callable] the mods connected through ModAPI.connect_signal(), cut on reload()
var _connections: Array = []
## Packs already loaded: a pack cannot be unloaded, nor loaded twice
var _loaded_packs: Dictionary = {}


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(USER_MODS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MODS_DIR)
	reload()


#region ACTIVATION
## Finds the mods again and turns the enabled ones on, dropping what the mods on before registered
func reload() -> void:
	for instance in _instances.values():
		instance.queue_free()
	for api in _apis:
		api._is_on = false
	_apis.clear()
	for connection in _connections:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])
	_connections.clear()
	_instances.clear()
	_hooks.clear()
	_filters.clear()
	_json_patches.clear()
	active_mods.clear()

	available_mods = _discover()
	enabled_ids = _read_enabled_ids()
	for manifest in _get_load_order():
		_activate(manifest)
	if not active_mods.is_empty():
		print("[ModLoader] %d de %d mods ativos" % [active_mods.size(), available_mods.size()])
	mods_reloaded.emit()


## Enables exactly these mods from now on, without restarting the game
func apply_enabled(mod_ids: PackedStringArray) -> void:
	var file := FileAccess.open(ENABLED_MODS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("[ModLoader] não foi possível gravar %s" % ENABLED_MODS_FILE)
		return
	file.store_string(JSON.stringify(Array(mod_ids)))
	file.close()
	reload()


func is_enabled(mod_id: String) -> bool:
	return enabled_ids.has(mod_id)


func is_active(mod_id: String) -> bool:
	return active_mods.any(func(manifest: ModManifest) -> bool: return manifest.id == mod_id)


func get_manifest(mod_id: String) -> ModManifest:
	for manifest in available_mods:
		if manifest.id == mod_id:
			return manifest
	return null


## Dependencies of a mod that are not enabled, or do not exist
func get_missing_dependencies(manifest: ModManifest, mod_ids: PackedStringArray) -> Array:
	var missing: Array = []
	for dependency in manifest.depends:
		if not mod_ids.has(dependency) or get_manifest(dependency) == null:
			missing.append(dependency)
	return missing


func _discover() -> Array[ModManifest]:
	var found: Array[ModManifest] = []
	var seen: Dictionary = {}
	for source in [[BUILTIN_MODS_DIR, true], [USER_MODS_DIR, false]]:
		for mod_dir in _list_directory(source[0], true):
			var mod_path: String = source[0].path_join(mod_dir)
			if not FileAccess.file_exists(mod_path.path_join(ModManifest.MANIFEST_FILE)):
				continue
			var manifest := ModManifest.load_from(mod_path, source[1])
			if manifest == null:
				continue
			if seen.has(manifest.id):
				push_warning("[ModLoader] id repetido '%s' em %s, ignorado" % [
					manifest.id, mod_path
				])
				continue
			seen[manifest.id] = true
			found.append(manifest)
	found.sort_custom(func(a: ModManifest, b: ModManifest) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return found


func _read_enabled_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var saved = JsonOverlay.read_file(ENABLED_MODS_FILE)
	if saved is Array:
		for mod_id in saved:
			ids.append(str(mod_id))
	return ids


## Enabled mods whose dependencies are all there, lower priority first: a higher one is applied
## after it and so has the last word. A mod is always applied after the mods it depends on
func _get_load_order() -> Array[ModManifest]:
	var enabled: Array[ModManifest] = []
	for manifest in available_mods:
		if is_enabled(manifest.id):
			enabled.append(manifest)
	enabled.sort_custom(func(a: ModManifest, b: ModManifest) -> bool:
		return a.priority < b.priority if a.priority != b.priority else a.id < b.id
	)

	var ordered: Array[ModManifest] = []
	var placed: Dictionary = {}
	var is_progressing := true
	while is_progressing:
		is_progressing = false
		for manifest in enabled:
			if placed.has(manifest.id):
				continue
			if Array(manifest.depends).all(func(dependency): return placed.has(dependency)):
				placed[manifest.id] = true
				ordered.append(manifest)
				is_progressing = true
	for manifest in enabled:
		if not placed.has(manifest.id):
			push_warning("[ModLoader] '%s' ignorado, falta dependência: %s" % [
				manifest.id, ", ".join(manifest.depends)
			])
	return ordered


func _activate(manifest: ModManifest) -> void:
	if manifest.pack_path != "":
		_load_pack(manifest)
	active_mods.append(manifest)
	if manifest.script_path != "":
		_run_script(manifest)
	print("[ModLoader] ativo: %s v%s (%s)" % [manifest.display_name, manifest.version, manifest.id])


func _load_pack(manifest: ModManifest) -> void:
	var pack_path := manifest.mod_path.path_join(manifest.pack_path)
	if _loaded_packs.has(pack_path):
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_warning("[ModLoader] '%s': não foi possível carregar %s" % [manifest.id, pack_path])
		return
	_loaded_packs[pack_path] = true


func _run_script(manifest: ModManifest) -> void:
	var script := _load_script(manifest)
	if script == null:
		return
	if script.get_instance_base_type() != &"Node":
		push_warning("[ModLoader] '%s': o main_script precisa de 'extends Node'" % manifest.id)
		return
	var instance: Node = script.new()
	instance.name = manifest.id.validate_node_name()
	_instances[manifest.id] = instance
	add_child(instance)
	if instance.has_method("_on_mod_load"):
		var api := ModAPI.new(self, manifest)
		_apis.append(api)
		instance.call("_on_mod_load", api)


## The script of a mod. The mods shipped with the game are loaded as any script, the ones in
## user:// are compiled from their source
func _load_script(manifest: ModManifest) -> GDScript:
	var script_path := manifest.mod_path.path_join(manifest.script_path)
	if manifest.is_builtin:
		if not ResourceLoader.exists(script_path):
			push_warning("[ModLoader] '%s': script não encontrado: %s" % [
				manifest.id, script_path
			])
			return null
		return load(script_path) as GDScript

	if not FileAccess.file_exists(script_path):
		push_warning("[ModLoader] '%s': script não encontrado: %s" % [manifest.id, script_path])
		return null
	push_warning(
		"[ModLoader] '%s' roda um script de fora do jogo, com acesso total ao sistema" % manifest.id
	)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(script_path)
	if script.reload() != OK:
		push_warning("[ModLoader] '%s': erro ao compilar %s" % [manifest.id, script_path])
		return null
	return script
#endregion ACTIVATION


#region DATA
## Reads a JSON file of the game as the active mods leave it, null when nobody has it
##
## A file under res://data is merged with the file each mod keeps at the same place of its "data"
## folder (see JsonOverlay.merge(), or replaced whole when the mod lists it in "replace"). Then
## the scripts that asked for it change the result, see ModAPI.patch_json()
func read_json(res_path: String) -> Variant:
	var data: Variant = JsonOverlay.read_file(res_path)
	if res_path.begins_with(DATA_ROOT):
		for manifest in active_mods:
			var overlay: Variant = JsonOverlay.read_file(manifest.get_overlay_path(res_path))
			if overlay == null:
				continue
			data = overlay if manifest.replaces_file(res_path) else JsonOverlay.merge(data, overlay)

	for patch in _json_patches:
		var callable: Callable = patch["callable"]
		if not callable.is_valid() or not res_path.match(patch["pattern"]):
			continue
		var patched: Variant = callable.call(data, res_path)
		if patched != null:
			data = patched
	return data


## Paths of the JSON files of a folder of the game, the ones the mods add to it included
func list_json_files(res_dir: String) -> Array[String]:
	var file_paths: Array[String] = []
	for file_name in _list_overlaid(res_dir, false):
		if file_name.get_extension().to_lower() == "json":
			file_paths.append(res_dir.path_join(file_name))
	return file_paths


## Paths of the folders inside a folder of the game, the ones the mods add to it included
func list_subdirectories(res_dir: String) -> Array[String]:
	var directory_paths: Array[String] = []
	for directory_name in _list_overlaid(res_dir, true):
		directory_paths.append(res_dir.path_join(directory_name))
	return directory_paths


func _register_json_patch(pattern: String, callable: Callable) -> void:
	_json_patches.append({"pattern": pattern, "callable": callable})


## Names in a folder of the game and in the same folder of every active mod, sorted, each once
func _list_overlaid(res_dir: String, directories: bool) -> Array[String]:
	var names: Array[String] = _list_directory(res_dir, directories)
	if res_dir.begins_with(DATA_ROOT):
		for manifest in active_mods:
			for entry in _list_directory(manifest.get_overlay_path(res_dir), directories):
				if not names.has(entry):
					names.append(entry)
	names.sort()
	return names


## Names of the files (or the folders) of a folder, hidden ones left out
func _list_directory(dir_path: String, directories: bool) -> Array[String]:
	var names: Array[String] = []
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return names
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry == "":
			break
		if directory.current_is_dir() == directories and not entry.begins_with("."):
			names.append(entry)
	directory.list_dir_end()
	return names
#endregion DATA


#region HOOKS
## Tells the mods something happened in the game, see the hooks in mods/README.md
func emit_hook(hook_name: String, arguments: Array = []) -> void:
	for callable in _hooks.get(hook_name, []):
		if callable.is_valid():
			callable.callv(arguments)


func _register_hook(hook_name: String, callable: Callable) -> void:
	_hooks.get_or_add(hook_name, []).append(callable)


## Lets the mods change something the game is about to show, see the filters in mods/README.md.
## Each mod gets what the one before returned, followed by the arguments
func apply_filter(filter_name: String, value: Variant, arguments: Array = []) -> Variant:
	for callable in _filters.get(filter_name, []):
		if callable.is_valid():
			value = callable.callv([value] + arguments)
	return value


func _register_filter(filter_name: String, callable: Callable) -> void:
	_filters.get_or_add(filter_name, []).append(callable)
#endregion HOOKS
