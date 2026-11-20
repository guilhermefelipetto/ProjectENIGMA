extends Node
## Agenda cada rajada de roteiro.json no dia e no minuto dela

var api: ModAPI


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	for burst in api.read_mod_json("roteiro.json"):
		api.schedule_messages(
			int(burst["day"]), int(burst["minutes_after_start"]), burst["conversation_id"],
			burst["messages"]
		)
