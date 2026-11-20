extends Node
## Tocafunk: uma rádio de funk-forró no celular. Uma vez ligada, não desliga mais (até você
## desligar o mod no menu)

const Synth := preload("res://mods/available/tocafunk/synth.gd")
const EXCUSES := [
	"Pausar é exclusivo do Tocafunk Premium (R$ 47,90/mês).",
	"Não foi possível pausar. Tente de novo depois do refrão.",
	"O Tocafunk detectou que você está curtindo e ignorou o pedido.",
	"Botão de pausa em manutenção. Previsão: nunca.",
]

var api: ModAPI
var playing := false
var _synth := Synth.new()
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _layer: CanvasLayer
var _status: Label
var _volume := -10.0


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	# Toca até com o jogo pausado e entre uma tela e outra
	process_mode = Node.PROCESS_MODE_ALWAYS
	api.hook("day_started", _on_day_started)


func _on_day_started(_story: Node) -> void:
	_build_bar.call_deferred()


func _build_bar() -> void:
	var game := get_tree().current_scene
	if game == null or is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 94
	var bar := ModUI.card_panel(Color(0.08, 0.09, 0.12, 0.92), 10, 6)
	bar.position = Vector2(8, 598)
	bar.custom_minimum_size = Vector2(344, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(ModUI.label("Tocafunk", 11, ModUI.TEAL, ModUI.BOLD))
	_status = ModUI.label("Funk-forró 24h • toque para ouvir", 10, ModUI.WHITE)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	info.add_child(_status)
	var louder := ModUI.button("-", ModUI.INK, ModUI.WHITE, 13)
	louder.custom_minimum_size = Vector2(30, 28)
	louder.tooltip_text = "Diminuir volume"
	louder.pressed.connect(_on_volume_down)
	row.add_child(louder)
	var toggle := ModUI.button("Ouvir", ModUI.TEAL, ModUI.WHITE, 12)
	toggle.custom_minimum_size = Vector2(64, 28)
	toggle.pressed.connect(_on_toggle.bind(toggle))
	row.add_child(toggle)
	if playing:
		toggle.text = "Pausar"
		_status.text = "Forró do Tamborzão (ao vivo)"
	_layer.add_child(bar)
	game.add_child(_layer)


func _on_toggle(toggle: Button) -> void:
	if not playing:
		_start()
		toggle.text = "Pausar"
		_status.text = "Forró do Tamborzão (ao vivo)"
		return
	_status.text = EXCUSES.pick_random()


## O "-" aumenta o volume, como em todo rádio de vizinho
func _on_volume_down() -> void:
	if not playing:
		return
	_volume = minf(_volume + 3.0, 0.0)
	_player.volume_db = _volume
	_status.text = "Volume: %d%%" % roundi(db_to_linear(_volume) * 100)


func _start() -> void:
	playing = true
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = Synth.MIX_RATE
	stream.buffer_length = 0.4
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = _volume
	# No Master: mutar a música do jogo não adianta
	_player.bus = &"Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames > 0:
		_playback.push_buffer(_synth.render(frames))
