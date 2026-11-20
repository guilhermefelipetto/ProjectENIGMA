extends Control
## O mundo de blocos visto de lado. Tocar no ar coloca o bloco escolhido (arrastar vai
## colocando); segurar num bloco quebra, mais devagar nos mais duros. Areia cai.
##
## O céu segue o relógio do jogo: o expediente continua enquanto você constrói.

const Textures := preload("res://mods/available/blocolandia/textures.gd")

const COLS := 15
const ROWS := 21
const FALL_SECONDS := 0.06
const FUSE_SECONDS := 1.6
## TNT acesa por outra explosão estoura logo depois
const CHAIN_FUSE_SECONDS := 0.25
const BLAST_RADIUS := 2.6

## As células do mundo, linha por linha. É do mod (main.gd): sobrevive a fechar o app
var blocks: Array
## O que havia em cada célula quando o mundo nasceu: o subsolo escavado mostra isso, escuro
var backdrop: Array
var textures: Textures
var selected: int = Textures.GRASS

## Quantos blocos foram colocados e quebrados, também do mod
var stats := {"placed": 0, "broken": 0}

var _breaking := Vector2i(-1, -1)
var _break_progress := 0.0
var _placing := false
var _fall_timer := 0.0
## TNT acesa: célula -> segundos até explodir
var _fuses: Dictionary = {}
## Clarões das explosões: {center, life}
var _blasts: Array[Dictionary] = []
var _shake := 0.0
## Farelos de quem quebrou: {position, velocity, color, life}
var _crumbs: Array[Dictionary] = []

signal counts_changed


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## Gera um mundo novo: morros de grama e terra, pedra embaixo, árvores e uma prainha
static func generate(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := []
	cells.resize(COLS * ROWS)
	cells.fill(Textures.AIR)
	var phase := rng.randf() * TAU
	var heights: Array[int] = []
	for x in COLS:
		heights.append(ROWS - 9 + roundi(sin(x * 0.45 + phase) * 1.6 + sin(x * 1.3 + phase) * 0.7))
	var beach := rng.randi_range(0, COLS - 4)
	for x in COLS:
		var surface := heights[x]
		for y in range(surface, ROWS):
			var block: int = Textures.STONE
			if y == ROWS - 1:
				block = Textures.BEDROCK
			elif y == surface:
				block = Textures.SAND if x >= beach and x < beach + 3 else Textures.GRASS
			elif y < surface + 3:
				block = Textures.SAND if x >= beach and x < beach + 3 else Textures.DIRT
			cells[y * COLS + x] = block
	# Árvores longe da praia e umas das outras
	var x := rng.randi_range(1, 3)
	while x < COLS - 1:
		if x < beach - 1 or x > beach + 3:
			_tree(cells, x, heights[x], rng.randi_range(3, 4))
		x += rng.randi_range(4, 6)
	return cells


static func _tree(cells: Array, x: int, ground: int, height: int) -> void:
	var top := ground - height
	for dy in range(-2, 1):
		for dx in range(-2, 3):
			if abs(dx) + abs(dy) > 3 or x + dx < 0 or x + dx >= COLS or top + dy < 0:
				continue
			cells[(top + dy) * COLS + x + dx] = Textures.LEAVES
	for y in range(top, ground):
		cells[y * COLS + x] = Textures.LOG


func cell_size() -> float:
	return floorf(minf(size.x / COLS, size.y / ROWS))


func _origin() -> Vector2:
	var cell := cell_size()
	return Vector2((size.x - cell * COLS) / 2.0, size.y - cell * ROWS)


func _cell_at(point: Vector2) -> Vector2i:
	var local := (point - _origin()) / cell_size()
	return Vector2i(floori(local.x), floori(local.y))


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func get_block(cell: Vector2i) -> int:
	return blocks[cell.y * COLS + cell.x] if _inside(cell) else Textures.BEDROCK


func set_block(cell: Vector2i, block: int) -> void:
	if _inside(cell):
		blocks[cell.y * COLS + cell.x] = block
		queue_redraw()


#region TOQUES
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cell := _cell_at(event.position)
			if not _inside(cell):
				return
			if get_block(cell) == Textures.AIR:
				_placing = true
				_place(cell)
			elif get_block(cell) == Textures.TNT:
				_light(cell, FUSE_SECONDS)
			else:
				_start_breaking(cell)
		else:
			_placing = false
			_breaking = Vector2i(-1, -1)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var cell := _cell_at(event.position)
		if _placing and _inside(cell) and get_block(cell) == Textures.AIR:
			_place(cell)
		elif not _placing and cell != _breaking and _inside(cell) \
				and not get_block(cell) in [Textures.AIR, Textures.TNT]:
			_start_breaking(cell)
		accept_event()


func _place(cell: Vector2i) -> void:
	set_block(cell, selected)
	stats["placed"] += 1
	counts_changed.emit()


func _light(cell: Vector2i, seconds: float) -> void:
	if not _fuses.has(cell):
		_fuses[cell] = seconds


## Tudo num raio vira ar (menos a rocha-mãe), e outras TNTs no caminho acendem
func _explode(center: Vector2i) -> void:
	set_block(center, Textures.AIR)
	var reach := ceili(BLAST_RADIUS)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := center + Vector2i(dx, dy)
			if Vector2(dx, dy).length() > BLAST_RADIUS or not _inside(cell):
				continue
			var block := get_block(cell)
			if block == Textures.TNT:
				_light(cell, CHAIN_FUSE_SECONDS)
			elif block != Textures.AIR and block != Textures.BEDROCK:
				_crumble(cell, block, 3)
				set_block(cell, Textures.AIR)
				stats["broken"] += 1
	var cell_px := cell_size()
	_blasts.append({"center": _origin() + (Vector2(center) + Vector2(0.5, 0.5)) * cell_px,
		"life": 0.35})
	_shake = 0.3
	counts_changed.emit()


func _start_breaking(cell: Vector2i) -> void:
	_breaking = cell
	_break_progress = 0.0
	queue_redraw()
#endregion TOQUES


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _inside(_breaking):
		var block := get_block(_breaking)
		_break_progress += delta / float(Textures.HARDNESS.get(block, 0.3))
		if _break_progress >= 1.0:
			_crumble(_breaking, block)
			set_block(_breaking, Textures.AIR)
			stats["broken"] += 1
			counts_changed.emit()
			_breaking = Vector2i(-1, -1)
		queue_redraw()
	if not _fuses.is_empty():
		for cell in _fuses.keys():
			_fuses[cell] -= delta
			if get_block(cell) != Textures.TNT:
				_fuses.erase(cell)
			elif _fuses[cell] <= 0:
				_fuses.erase(cell)
				_explode(cell)
		queue_redraw()
	if _shake > 0 or not _blasts.is_empty():
		_shake = maxf(_shake - delta, 0)
		for blast in _blasts:
			blast["life"] -= delta
		_blasts = _blasts.filter(func(blast: Dictionary) -> bool: return blast["life"] > 0)
		queue_redraw()
	_fall_timer += delta
	if _fall_timer >= FALL_SECONDS:
		_fall_timer = 0.0
		_fall_sand()
	if not _crumbs.is_empty():
		for crumb in _crumbs:
			crumb["velocity"] += Vector2(0, 600) * delta
			crumb["position"] += crumb["velocity"] * delta
			crumb["life"] -= delta
		_crumbs = _crumbs.filter(func(crumb: Dictionary) -> bool: return crumb["life"] > 0)
		queue_redraw()


## Areia sem nada embaixo desce uma casa por vez
func _fall_sand() -> void:
	for y in range(ROWS - 2, -1, -1):
		for x in COLS:
			var cell := Vector2i(x, y)
			if get_block(cell) == Textures.SAND and get_block(cell + Vector2i.DOWN) == Textures.AIR:
				set_block(cell + Vector2i.DOWN, Textures.SAND)
				set_block(cell, Textures.AIR)


func _crumble(cell: Vector2i, block: int, amount := 8) -> void:
	var cell_px := cell_size()
	var center := _origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px
	for index in amount:
		_crumbs.append({
			"position": center + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * cell_px,
			"velocity": Vector2(randf_range(-90, 90), randf_range(-220, -60)),
			"color": textures.colors[block],
			"life": randf_range(0.35, 0.6),
		})


#region DESENHO
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _sky_color())
	if _shake > 0:
		var strength := _shake * 20
		draw_set_transform(Vector2(randf_range(-strength, strength), randf_range(-strength, strength)))
	_draw_sun()
	var cell := cell_size()
	var origin := _origin()
	for y in ROWS:
		for x in COLS:
			var block: int = blocks[y * COLS + x]
			var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			if block != Textures.AIR:
				draw_texture_rect(textures.textures[block], rect, false)
				continue
			var wall: int = backdrop[y * COLS + x] if backdrop.size() == blocks.size() else 0
			if wall in [Textures.DIRT, Textures.STONE, Textures.SAND, Textures.BEDROCK]:
				draw_texture_rect(textures.textures[wall], rect, false, Color(0.4, 0.4, 0.45))
	if _inside(_breaking):
		var rect := Rect2(origin + Vector2(_breaking) * cell, Vector2(cell, cell))
		var stage := clampi(int(_break_progress * 4), 0, 3)
		draw_texture_rect(textures.cracks[stage], rect, false)
		draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.0)
	# TNT acesa pisca branco, cada vez mais rápido
	for lit in _fuses:
		var rect := Rect2(origin + Vector2(lit) * cell, Vector2(cell, cell))
		var blink := sin(Time.get_ticks_msec() / 1000.0 * (10.0 + 20.0 / maxf(_fuses[lit], 0.1)))
		if blink > 0:
			draw_rect(rect, Color(1, 1, 1, 0.65))
	for crumb in _crumbs:
		draw_rect(Rect2(crumb["position"] - Vector2(2, 2), Vector2(4, 4)), crumb["color"])
	for blast in _blasts:
		var grow: float = 1.0 - blast["life"] / 0.35
		var radius := cell * BLAST_RADIUS * (0.6 + grow * 0.7)
		draw_circle(blast["center"], radius, Color(1.0, 0.75, 0.3, 0.7 * (1.0 - grow)))
		draw_circle(blast["center"], radius * 0.55, Color(1.0, 1.0, 0.85, 0.8 * (1.0 - grow)))
	draw_set_transform(Vector2.ZERO)


## Hora do jogo: manhã clara, meio-dia azul, fim de tarde laranja e, depois do expediente, noite
func _sky_color() -> Color:
	var hour := GameData.hours_minutes / 60.0
	var morning := Color(0.62, 0.82, 0.95)
	var noon := Color(0.45, 0.72, 0.98)
	var sunset := Color(0.98, 0.6, 0.38)
	var night := Color(0.08, 0.1, 0.22)
	if hour < 12:
		return morning.lerp(noon, clampf((hour - 8) / 4.0, 0, 1))
	if hour < 16:
		return noon
	if hour < 18:
		return noon.lerp(sunset, (hour - 16) / 2.0)
	return sunset.lerp(night, clampf(hour - 18, 0, 1))


func _draw_sun() -> void:
	var hour := GameData.hours_minutes / 60.0
	var t := clampf((hour - 7.0) / 12.0, 0, 1)
	var position_px := Vector2(size.x * (0.1 + 0.8 * t), size.y * (0.32 - sin(t * PI) * 0.24))
	var sun_size := cell_size() * 1.6
	var night := hour >= 18.5
	draw_rect(Rect2(position_px - Vector2(sun_size, sun_size) / 2, Vector2(sun_size, sun_size)),
		Color(0.92, 0.94, 1.0) if night else Color(1.0, 0.92, 0.45))
#endregion DESENHO
