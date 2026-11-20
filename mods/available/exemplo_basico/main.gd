extends Node
## Exemplo de main_script: recebe a API no _on_mod_load() e se registra nos hooks

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.info("carregado")
	api.hook("day_started", _on_day_started)


func _on_day_started(story: Node) -> void:
	api.info("dia %d começou com %d conversas" % [
		GameData.current_day, story.messages_director.conversations_by_id.size()
	])
