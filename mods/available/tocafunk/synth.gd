extends RefCounted
## Sintetiza um funk-forró em loop: tamborzão (bumbo e palma), zabumba, triângulo e sanfona

const MIX_RATE := 22050.0
const BPM := 128.0
const STEPS := 32
## Uma linha por instrumento, 32 semicolcheias (dois compassos)
const KICK := [1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,0,0, 1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,1,0]
const CLAP := [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,1,1]
const ZABUMBA := [0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,1,0]
const TRIANGLE := [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]
## Sanfona em sol mixolídio, uma nota a cada colcheia (0 é pausa), em semitons acima de sol
const MELODY := [0,2,4,5, 7,5,4,2, 4,0,-3,0, 2,0,0,0, 7,9,10,9, 7,5,4,5, 7,4,2,0, -1,0,0,0]

var _time := 0.0
var _step := -1
var _kick_age := 99.0
var _clap_age := 99.0
var _zabumba_age := 99.0
var _triangle_age := 99.0
var _kick_phase := 0.0
var _note := 0.0
var _note_phase := 0.0
var _rng := RandomNumberGenerator.new()


## Os próximos frames estéreo
func render(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	var step_length := 60.0 / BPM / 4.0
	var dt := 1.0 / MIX_RATE
	for index in frames:
		var step := int(_time / step_length) % STEPS
		if step != _step:
			_on_step(step)
		var sample := _kick(dt) + _clap() + _zabumba() + _triangle() + _accordion(dt)
		# Saturação suave em vez de corte seco
		out[index] = Vector2.ONE * tanh(sample * 0.55)
		_time += dt
		_kick_age += dt
		_clap_age += dt
		_zabumba_age += dt
		_triangle_age += dt
	return out


func _on_step(step: int) -> void:
	_step = step
	if KICK[step]:
		_kick_age = 0.0
	if CLAP[step]:
		_clap_age = 0.0
	if ZABUMBA[step]:
		_zabumba_age = 0.0
	if TRIANGLE[step]:
		_triangle_age = 0.0
	if step % 2 == 0:
		var semitones: int = MELODY[step]
		_note = 0.0 if semitones == 0 and step % 8 != 0 else 392.0 * pow(2.0, semitones / 12.0)


func _kick(dt: float) -> float:
	var frequency := 48.0 + 110.0 * exp(-_kick_age * 28.0)
	_kick_phase += TAU * frequency * dt
	return sin(_kick_phase) * exp(-_kick_age * 7.0) * 0.9


func _clap() -> float:
	return _rng.randf_range(-1.0, 1.0) * exp(-_clap_age * 22.0) * 0.45


func _zabumba() -> float:
	return sin(TAU * 92.0 * _zabumba_age) * exp(-_zabumba_age * 9.0) * 0.6


func _triangle() -> float:
	var ring := sin(TAU * 4100.0 * _triangle_age) + sin(TAU * 6300.0 * _triangle_age)
	return ring * exp(-_triangle_age * 30.0) * 0.08


func _accordion(dt: float) -> float:
	if _note <= 0.0:
		return 0.0
	var vibrato := 1.0 + 0.006 * sin(TAU * 5.5 * _time)
	_note_phase = fmod(_note_phase + _note * vibrato * dt, 1.0)
	# Dente de serra com um pouco de quadrada: lembra uma sanfona
	var saw := 2.0 * _note_phase - 1.0
	var square := 1.0 if _note_phase < 0.5 else -1.0
	return (saw * 0.6 + square * 0.4) * 0.12
