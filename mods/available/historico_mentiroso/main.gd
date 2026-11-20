extends Node
## O histórico de Mensagens começa a mentir: nas conversas dos dias passados, as suas respostas
## viram coisas que você nunca disse, e algumas falas dos contatos também mudam. Só a tela mente:
## o que foi salvo continua igual, e desligar o mod devolve a verdade

const MY_MESSAGE := "res://scenes/apps/messages/my_message.tscn"

var api: ModAPI
var lies: Dictionary


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	lies = api.read_mod_json("mentiras.json")
	api.hook("screen_opened", _on_screen_opened)


func _on_screen_opened(app: int, screen: Control) -> void:
	if app != GameData.App.MESSAGESCHAT or not screen._is_archived():
		return
	for message in screen.messages_list.get_children():
		if not "label" in message or message.label == null:
			continue
		var is_mine: bool = message.scene_file_path == MY_MESSAGE
		var pool: Array = lies["mine"] if is_mine else lies["theirs"]
		# A mesma mensagem mente sempre do mesmo jeito; as dos contatos, só às vezes
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(message.label.text)
		if is_mine or rng.randf() < 0.3:
			message.label.text = str(pool[rng.randi_range(0, pool.size() - 1)])
