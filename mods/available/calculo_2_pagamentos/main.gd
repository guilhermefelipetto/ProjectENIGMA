extends Node
## Troca todo valor em reais do jogo ("R$ 1.480,00") por uma conta que dá esse valor, sem que o
## número apareça escrito: o jogador tem que calcular para saber quanto pagar
##
## Vale para o texto dos dados (mensagens, emails, notas, eventos) e para tudo que o jogo formata
## enquanto roda (Banco, saldo, lojas, carrinho, boletos), pelo filtro "money_text".
##
## A conta é uma árvore gerada a partir da quantia: o número é quebrado numa operação (+ − × ÷ ² √
## ∫ Σ) e cada pedaço pode ser quebrado de novo, até "max_depth" níveis. A quantia é a semente,
## então a mesma quantia vira sempre a mesma conta, no chat, no email e no Banco. Por isso a regra
## "Valor diferente do combinado" continua funcionando: valores iguais dão contas iguais. Os
## centavos ficam como estão.

## "R$ 58", "R$58,90", "R$ 5.000", "R$ 1.480,00"
const MONEY_PATTERN := "R\\$\\s*(\\d{1,3}(?:\\.\\d{3})+|\\d+)(?:,(\\d{1,2}))?"
## Operações e o peso de cada uma no sorteio
const OPERATIONS := {
	"add": 3, "sub": 3, "mul": 3, "mul_add": 2, "div": 2, "square": 2, "root": 1,
	"integral": 1, "integral_2x": 2, "sum": 1, "triangular": 2,
}
## Números menores que isso não são quebrados de novo
const LEAF_BELOW := 10
const ATTEMPTS := 40

var api: ModAPI
var max_depth: int
var max_length: int
var _money_regex := RegEx.create_from_string(MONEY_PATTERN)
var _number_regex := RegEx.create_from_string("\\d+")
## quantia -> conta, para não refazer
var _expressions: Dictionary = {}


func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	max_depth = clampi(int(api.config("max_depth", 2)), 1, 4)
	max_length = maxi(int(api.config("max_length", 48)), 16)
	# Texto escrito nos dados: mensagens, emails, notas e os "contains" dos eventos
	api.patch_json("res://data/*", func(data: Variant, _path: String) -> Variant:
		return _rewrite(data)
	)
	# Tudo que o jogo escreve com GameData.format_brl() enquanto roda
	api.filter("money_text", func(text: String, _value: float) -> String:
		return replace_money(text)
	)
	# As contas não cabem onde o jogo esperava "R$ 49,90": quebram linha
	api.wrap_labels(func(text: String) -> bool: return text.contains("R$ ("))


#region TEXT
func _rewrite(value: Variant) -> Variant:
	if value is String:
		return replace_money(value) if value.contains("R$") else value
	if value is Array:
		for index in value.size():
			value[index] = _rewrite(value[index])
	elif value is Dictionary:
		for key in value:
			value[key] = _rewrite(value[key])
	return value


## Troca cada quantia em reais de um texto pela conta dela
func replace_money(text: String) -> String:
	var result := ""
	var last := 0
	for found in _money_regex.search_all(text):
		var amount := int(found.get_string(1).replace(".", ""))
		var cents := found.get_string(2)
		var written := "R$ %s" % express(amount)
		if cents != "":
			written += ",%s" % cents.rpad(2, "0")
		result += text.substr(last, found.get_start() - last) + written
		last = found.get_end()
	return result + text.substr(last)
#endregion TEXT


#region EXPRESSIONS
## A conta que dá a quantia, entre parênteses, sem a quantia escrita nela
func express(amount: int) -> String:
	if not _expressions.has(amount):
		_expressions[amount] = _make_expression(amount)
	return _expressions[amount]


func _make_expression(amount: int) -> String:
	if amount == 0:
		return "(cos(π/2) × 47)"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(amount)
	# Mais curta a cada tentativa que passa do tamanho
	for attempt in ATTEMPTS:
		var depth := maxi(max_depth - int(float(attempt) / ATTEMPTS * max_depth), 1)
		var node := _build(amount, depth, rng, true)
		assert(node["value"] == amount, "conta errada para %d: %s" % [amount, node["text"]])
		var text: String = node["text"]
		if node["value"] == amount and text.length() <= max_length \
				and not _shows_amount(text, amount):
			return "(%s)" % text
	return "(%d − %d)" % [amount * 2, amount]


## Um nó da conta: {"text", "value", "leaf"}. O valor é calculado dos filhos, não suposto
##
## is_top: A raiz nunca é o próprio número
func _build(number: int, depth: int, rng: RandomNumberGenerator, is_top := false) -> Dictionary:
	if not is_top and (depth <= 0 or number < LEAF_BELOW or rng.randf() < 0.25):
		return _leaf(number)

	var operation := _pick_operation(number, rng)
	match operation:
		"add":
			var left := rng.randi_range(1, number - 1)
			return _join(_child(left, depth, rng), "+", _child(number - left, depth, rng))
		"sub":
			var right := rng.randi_range(2, maxi(number / 2, 9))
			return _join(_child(number + right, depth, rng), "−", _child(right, depth, rng))
		"mul":
			var divisor: int = _divisors(number).pick_random()
			return _join(_child(number / divisor, depth, rng), "×", _child(divisor, depth, rng))
		"mul_add":
			var factor := rng.randi_range(3, 19)
			# Sem "+ 0"
			while number % factor == 0:
				factor += 1
			var product := _join(
				_child(number / factor, depth, rng), "×", _child(factor, depth, rng)
			)
			return _join(product, "+", _child(number % factor, depth, rng), false)
		"div":
			var divisor := rng.randi_range(2, 9)
			return _join(_child(number * divisor, depth, rng), "÷", _leaf(divisor))
		"square":
			var root := int(sqrt(float(number)))
			var squared := _wrap(_child(root, depth, rng))
			var node := {"text": squared["text"] + "²", "value": root * root, "leaf": false}
			if number == root * root:
				return node
			return _join(node, "+", _child(number - root * root, depth, rng), false)
		"root":
			return {"text": "√%d" % (number * number), "value": number, "leaf": false}
		"integral":
			var start := rng.randi_range(1, 600)
			return {
				"text": "∫ dx de %d a %d" % [start, start + number], "value": number, "leaf": false
			}
		"integral_2x":
			var limit := int(sqrt(float(number)))
			return {"text": "∫ 2x dx de 0 a %d" % limit, "value": limit * limit, "leaf": false}
		"sum":
			var first := rng.randi_range(1, 600)
			return {
				"text": "Σ 1, de k=%d a %d" % [first, first + number - 1], "value": number,
				"leaf": false,
			}
		_:
			var last := _triangular_side(number)
			return {
				"text": "Σ k, de k=1 a %d" % last, "value": last * (last + 1) / 2, "leaf": false
			}


## Sorteia uma operação que sirva para o número
func _pick_operation(number: int, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = {}
	for operation in OPERATIONS:
		if _fits(operation, number):
			weights[operation] = OPERATIONS[operation]
	var roll := rng.randi_range(1, weights.values().reduce(func(a, b): return a + b))
	for operation in weights:
		roll -= weights[operation]
		if roll <= 0:
			return operation
	return "sub"


func _fits(operation: String, number: int) -> bool:
	var root := int(sqrt(float(number)))
	match operation:
		"add":
			return number >= 2
		"mul":
			return not _divisors(number).is_empty()
		"mul_add":
			return number >= 40
		"square":
			return number >= 4
		"root":
			return number <= 99
		"integral_2x":
			return number >= 4 and root * root == number
		"triangular":
			return number >= 6 and _triangular_side(number) > 0
	return true


## Divisores entre 2 e a raiz, para "a × b" sem 1 nem o próprio número
func _divisors(number: int) -> Array:
	var divisors: Array = []
	for divisor in range(2, int(sqrt(float(number))) + 1):
		if number % divisor == 0:
			divisors.append(divisor)
	return divisors


## O m de 1 + 2 + … + m quando o número é essa soma, 0 quando não é
func _triangular_side(number: int) -> int:
	var side := int((sqrt(8.0 * number + 1.0) - 1.0) / 2.0)
	return side if side * (side + 1) / 2 == number else 0


func _child(number: int, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	return _build(number, depth - 1, rng)


func _leaf(number: int) -> Dictionary:
	return {"text": str(number), "value": number, "leaf": true}


## "a op b", com parênteses nos filhos compostos para não depender de precedência
func _join(left: Dictionary, operator: String, right: Dictionary, wrap_left := true) -> Dictionary:
	var value: int
	match operator:
		"+":
			value = left["value"] + right["value"]
		"−":
			value = left["value"] - right["value"]
		"×":
			value = left["value"] * right["value"]
		"÷":
			value = left["value"] / right["value"]
	var left_text: String = (_wrap(left) if wrap_left else left)["text"]
	return {
		"text": "%s %s %s" % [left_text, operator, _wrap(right)["text"]], "value": value,
		"leaf": false,
	}


func _wrap(node: Dictionary) -> Dictionary:
	if node["leaf"] or node["text"].ends_with("²"):
		return node
	return {"text": "(%s)" % node["text"], "value": node["value"], "leaf": false}


## Se a quantia aparece escrita como um número na conta
func _shows_amount(text: String, amount: int) -> bool:
	for found in _number_regex.search_all(text):
		if int(found.get_string()) == amount:
			return true
	return false
#endregion EXPRESSIONS
