extends Node
## Troca as frases do minigame de digitação por frases enormes e difíceis

var api: ModAPI
var phrases: Array = []


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	phrases = api.read_mod_json("frases.json")
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if app != GameData.App.FASTTYPING or phrases.is_empty():
		return
	_replace_phrases(screen)
	# Quando o tempo acaba o jogo sorteia frases novas: troca de novo
	if not screen.minigame_timer.timer_finished.is_connected(_replace_phrases.bind(screen)):
		screen.minigame_timer.timer_finished.connect(
			_replace_phrases.bind(screen), CONNECT_DEFERRED
		)


func _replace_phrases(screen: Control) -> void:
	if not api.is_on():
		return
	var picked: Array = phrases.duplicate()
	picked.shuffle()
	screen.current_phrases.clear()
	for phrase in picked.slice(0, randi_range(1, 3)):
		screen.current_phrases.append(str(phrase).to_lower().split(" ", false))
	screen.completed_phrases = 0
	screen.line_edit.text = ""
	screen.update_display()
