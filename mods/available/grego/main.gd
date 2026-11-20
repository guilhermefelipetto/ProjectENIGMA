extends Node
## Todo texto do jogo passa a ser escrito com letras gregas. Só a tela muda: códigos, valores,
## emails e o que você digita continuam no nosso alfabeto, então pagar e denunciar funciona igual

const GAME_SCENE := "res://scenes/game_screen.tscn"
const LETTERS := {
	"a": "α", "b": "β", "c": "κ", "d": "δ", "e": "ε", "f": "φ", "g": "γ", "h": "η", "i": "ι",
	"j": "ξ", "k": "κ", "l": "λ", "m": "μ", "n": "ν", "o": "ο", "p": "π", "q": "θ", "r": "ρ",
	"s": "σ", "t": "τ", "u": "υ", "v": "β", "w": "ω", "x": "χ", "y": "ψ", "z": "ζ",
	"á": "ά", "à": "α", "â": "α", "ã": "α", "é": "έ", "ê": "ε", "í": "ί", "ó": "ό", "ô": "ο",
	"õ": "ο", "ú": "ύ", "ç": "ς",
}

var api: ModAPI
## Palavras que ficam como estão: com número, @ ou barra, e siglas/códigos em maiúsculas
var _keep := RegEx.create_from_string("[0-9@/$]|^[A-Z]{2,8}[.,!?:]*$")
var _bbcode := RegEx.create_from_string("\\[[^\\]]*\\]")


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.watch_nodes(
		func(node: Node) -> bool: return node is Label or node is RichTextLabel or node is Button,
		func(node: Control) -> void:
			# Agora (já pode estar na tela) e sempre que for desenhado de novo, o que acontece
			# quando o texto muda
			_translate.call_deferred(node)
			node.draw.connect(_translate.bind(node), CONNECT_DEFERRED)
	)


## node sem tipo: pode chegar já liberado, numa chamada adiada
func _translate(node) -> void:
	if not api.is_on() or not is_instance_valid(node) or not _in_game(node):
		return
	var current: String = node.text
	var greek := _to_greek_bbcode(current) if node is RichTextLabel else to_greek(current)
	# Igual de novo não redesenha, então não entra em laço
	if greek != current:
		node.text = greek


func _in_game(node: Node) -> bool:
	var scene := node.get_tree().current_scene if node.is_inside_tree() else null
	return scene != null and scene.scene_file_path == GAME_SCENE


func to_greek(text: String) -> String:
	var words := text.split(" ")
	for index in words.size():
		if not _keep.search(words[index]):
			words[index] = _word(words[index])
	return " ".join(words)


func _word(word: String) -> String:
	var out := ""
	for index in word.length():
		var character := word[index]
		var lower := character.to_lower()
		if not LETTERS.has(lower):
			out += character
			continue
		var greek: String = LETTERS[lower]
		# Sigma final
		if greek == "σ" and (index == word.length() - 1 or not word[index + 1].is_valid_identifier()):
			greek = "ς"
		out += greek.to_upper() if character != lower else greek
	return out


## Num RichTextLabel, as tags [b] [color] ficam intactas
func _to_greek_bbcode(text: String) -> String:
	var out := ""
	var last := 0
	for found in _bbcode.search_all(text):
		out += to_greek(text.substr(last, found.get_start() - last)) + found.get_string()
		last = found.get_end()
	return out + to_greek(text.substr(last))
