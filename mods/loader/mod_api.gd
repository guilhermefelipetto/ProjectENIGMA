class_name ModAPI
extends RefCounted
## What the script of a mod gets in _on_mod_load() to talk to the game, see mods/README.md

## Hooks the game emits: "day_started" (story_director) once the data of a day is set up,
## "clock_tick" (current_minutes, story_director) every minute of the game clock and
## "screen_opened" (app: GameData.App, screen: Control) whenever a screen of the phone opens
const HOOKS := ["day_started", "clock_tick", "screen_opened"]
## Filters the game runs what it shows through: "money_text" (text, value: float), every amount of
## money written by the game (GameData.format_brl()), "R$ 1.480,00"
const FILTERS := ["money_text"]

var manifest: ModManifest
var _loader: Node
## False once the mod is turned off, so what it left behind (on labels, say) stops working
var _is_on := true
var _watch_count := 0


func _init(loader: Node, mod_manifest: ModManifest) -> void:
	_loader = loader
	manifest = mod_manifest


## Whether the mod is still on: false once the player turns it off and applies
func is_on() -> bool:
	return _is_on


## Connects to a signal of the game, cut when the mod is turned off
func connect_signal(game_signal: Signal, callable: Callable) -> void:
	game_signal.connect(callable)
	_loader._connections.append([game_signal, callable])


#region LOG
func info(message: String) -> void:
	print("[mod:%s] %s" % [manifest.id, message])


func warn(message: String) -> void:
	push_warning("[mod:%s] %s" % [manifest.id, message])
#endregion LOG


#region FILES
## A value of the "config" of the mod.json, so a mod can be tuned without touching its script
func config(key: String, default: Variant = null) -> Variant:
	return manifest.config.get(key, default)


## Path of a file of the mod ("assets/icon.png"), to load() or read it
func path(relative_path: String = "") -> String:
	return manifest.mod_path.path_join(relative_path)


## Reads a JSON file of the mod itself, null when it is missing or broken
func read_mod_json(relative_path: String) -> Variant:
	return _loader.JsonOverlay.read_file(path(relative_path))


## Reads a JSON file of the game ("res://data/news.json") as every active mod leaves it
func read_json(res_path: String) -> Variant:
	return _loader.read_json(res_path)
#endregion FILES


#region PATCHES
## Changes a JSON file of the game every time it is read, after the data of the mods was merged
##
## pattern: The res:// path of the file, "*" and "?" standing for anything ("res://data/emails/*")
## callable: func(data: Variant, res_path: String), changing data in place or returning another
func patch_json(pattern: String, callable: Callable) -> void:
	_loader._register_json_patch(pattern, callable)


## Rewrites every text the player reads in a chat or an email: the messages and the answers of
## the conversations, the subject, the content and the reply of the emails
##
## rewrite: func(text: String) -> String
func patch_story_text(rewrite: Callable) -> void:
	patch_json("res://data/messages/*", func(root: Variant, _path: String) -> Variant:
		for conversation in _get_conversations(root):
			for nodes in conversation.get("branches", {}).values():
				for node in nodes:
					_rewrite_key(node, "text", rewrite)
					for choice in node.get("choices", []):
						_rewrite_key(choice, "player_text", rewrite)
		return null
	)
	patch_json("res://data/emails/*", func(root: Variant, _path: String) -> Variant:
		if root is Array:
			for email in root:
				for key in ["subject", "content", "reply"]:
					_rewrite_key(email, key, rewrite)
		return null
	)


## Conversations of a file of res://data/messages, which holds one or a list of them
func _get_conversations(root: Variant) -> Array:
	if not root is Dictionary:
		return []
	return root["conversations"] if root.has("conversations") else [root]


func _rewrite_key(holder: Variant, key: String, rewrite: Callable) -> void:
	if holder is Dictionary and holder.get(key) is String:
		holder[key] = rewrite.call(holder[key])
#endregion PATCHES


#region GAME
## Runs a callable whenever the game emits a hook, see HOOKS
func hook(hook_name: String, callable: Callable) -> void:
	if not HOOKS.has(hook_name):
		warn("hook desconhecido: '%s' (existem: %s)" % [hook_name, ", ".join(HOOKS)])
		return
	_loader._register_hook(hook_name, callable)


## Changes what the game is about to show, see FILTERS
##
## callable: Gets the value and the arguments of the filter, returns the value to show
func filter(filter_name: String, callable: Callable) -> void:
	if not FILTERS.has(filter_name):
		warn("filtro desconhecido: '%s' (existem: %s)" % [filter_name, ", ".join(FILTERS)])
		return
	_loader._register_filter(filter_name, callable)


## Has a contact send messages one after another, outside of the story: they hold no other chat
## and nothing waits for an answer. The conversation must exist in res://data/messages
##
## story: The story director, as the hooks give it
## texts: Each message, sent in order: a text, or {"text", "typing_seconds"} to say how long
## the contact stays "typing..." before it
## typing: Whether the contact shows as typing first, as long as the text asks for (see
## GameData.get_human_typing_time()), or else the messages come one second apart
func send_messages(story: Node, conversation_id: String, texts: Array, typing := true) -> void:
	var messages: Node = story.messages_director
	if not messages.conversations_by_id.has(conversation_id):
		warn("conversa desconhecida: '%s'" % conversation_id)
		return
	var contact: Dictionary = messages._get_contact(conversation_id)
	var setup_at_start: int = messages.setup_count
	for item in texts:
		var text := str(item["text"]) if item is Dictionary else str(item)
		if typing:
			messages.npc_message_created.emit(contact)
		var wait: float = GameData.get_human_typing_time(text) if typing else 1.0
		if item is Dictionary and item.has("typing_seconds"):
			wait = float(item["typing_seconds"])
		await story.get_tree().create_timer(wait).timeout
		# The day ended meanwhile
		if not is_instance_valid(messages) or messages.setup_count != setup_at_start:
			return
		messages.npc_message_sent.emit(
			contact, text, {}, GameData.Sender.NPC, GameData.hours_minutes
		)


## Has a contact send messages (see send_messages()) once a day, at a time of the game clock
##
## day: Day of the game they come on, -1 for every day but the tutorial (day 0)
## minutes: Game minutes after the start of the workday (08:00) they come at
func schedule_messages(
	day: int, minutes: int, conversation_id: String, texts: Array, typing := true
) -> void:
	var state := {"sent_on": -1}
	hook("clock_tick", func(current_minutes: int, story: Node) -> void:
		var is_day: bool = GameData.current_day == day or (day == -1 and GameData.current_day > 0)
		if not is_day or state["sent_on"] == GameData.current_day:
			return
		if current_minutes < GameData.starting_hours_minutes + minutes:
			return
		state["sent_on"] = GameData.current_day
		send_messages(story, conversation_id, texts, typing)
	)
	# Playing the day again sends them again
	hook("day_started", func(_story: Node) -> void: state["sent_on"] = -1)
## Runs a callable for every node of the game that matches, the ones in the tree now and the
## ones added later, each once
##
## matches: func(node: Node) -> bool
## callable: func(node: Node)
func watch_nodes(matches: Callable, callable: Callable) -> void:
	# A node taken out of the tree and put back is added again. A metadata name must be an
	# identifier, the id of a mod may have dots or dashes
	var seen_key := "mod_seen_%d_" % _watch_count + _identifier(manifest.id)
	_watch_count += 1
	var visit := func(node: Node) -> void:
		if _is_on and not node.has_meta(seen_key) and matches.call(node):
			node.set_meta(seen_key, true)
			callable.call(node)
	var tree := _loader.get_tree()
	connect_signal(tree.node_added, visit)
	for node in tree.root.find_children("*", "", true, false):
		visit.call(node)


## Makes every label of the game showing a text that matches wrap to more lines, instead of
## overflowing its box or being cut, for mods writing texts longer than the game expects
##
## matches: func(text: String) -> bool
func wrap_labels(matches: Callable) -> void:
	watch_nodes(func(node: Node) -> bool: return node is Label, func(label: Label) -> void:
		# A label is drawn again whenever its text changes
		label.draw.connect(_wrap_label.bind(label, matches), CONNECT_DEFERRED)
	)


## Holds a button of the game: when it is pressed the gate runs first, and what the game does
## on that press only happens if the gate calls proceed (a confirmation, a delay...). Several
## mods may hold the same button, one after another. Calling it again replaces the gate
##
## gate: func(proceed: Callable)
func intercept_press(button: BaseButton, gate: Callable) -> void:
	_loader.intercept_press(button, self, gate)


static func _identifier(text: String) -> String:
	return RegEx.create_from_string("[^A-Za-z0-9_]").sub(text, "_", true)


## label sem tipo: pode chegar já liberado, numa chamada adiada
func _wrap_label(label, matches: Callable) -> void:
	if not _is_on or not is_instance_valid(label):
		return
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF or not matches.call(label.text):
		return
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	# Wrapped, a label asks for no width: in a row it would be squeezed to nothing
	if label.get_parent() is HBoxContainer:
		label.size_flags_horizontal |= Control.SIZE_EXPAND
#endregion GAME
