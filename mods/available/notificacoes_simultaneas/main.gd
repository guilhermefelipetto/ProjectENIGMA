extends Node
## Agenda as conversas de roteiro.json para o mesmo minuto, todas ao mesmo tempo

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	var day := int(api.config("day", 2))
	var minutes := int(api.config("minutes_after_start", 20))
	for burst in api.read_mod_json("roteiro.json"):
		api.schedule_messages(day, minutes, burst["conversation_id"], burst["messages"])
