extends RefCounted
## Texturas dos blocos, desenhadas pixel a pixel por código (16x16), e o ícone do app

enum { AIR, GRASS, DIRT, STONE, LOG, PLANKS, LEAVES, SAND, GLASS, BRICK, BEDROCK, GRASS_TOP, TNT }

const SIZE := 16
const NAMES := {
	GRASS: "Grama", DIRT: "Terra", STONE: "Pedra", LOG: "Tronco", PLANKS: "Tábuas",
	LEAVES: "Folhas", SAND: "Areia", GLASS: "Vidro", BRICK: "Tijolo", BEDROCK: "Rocha-mãe",
	TNT: "TNT",
}
## Segundos segurando o dedo para quebrar; rocha-mãe não quebra
const HARDNESS := {
	GRASS: 0.35, DIRT: 0.3, STONE: 0.9, LOG: 0.6, PLANKS: 0.5, LEAVES: 0.12, SAND: 0.25,
	GLASS: 0.15, BRICK: 1.0, BEDROCK: INF, TNT: 0.2,
}

var textures: Dictionary = {}
## Cor média de cada bloco, para os farelos ao quebrar
var colors: Dictionary = {}
var cracks: Array[ImageTexture] = []


func _init() -> void:
	for block in [GRASS, DIRT, STONE, LOG, PLANKS, LEAVES, SAND, GLASS, BRICK, BEDROCK, GRASS_TOP, TNT]:
		var image := _paint(block)
		textures[block] = ImageTexture.create_from_image(image)
		colors[block] = _average(image)
	for stage in 4:
		cracks.append(ImageTexture.create_from_image(_crack(stage)))


func _paint(block: int) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + block
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, _pixel(block, x, y, rng))
	return image


func _pixel(block: int, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var noise := rng.randf_range(-1.0, 1.0)
	match block:
		DIRT:
			return _shade(Color(0.53, 0.37, 0.24), noise * 0.12)
		GRASS:
			# Grama por cima, com a borda irregular, e terra embaixo
			var edge := 3 + int(abs(sin(x * 1.7)) * 2.5)
			if y < edge:
				return _shade(Color(0.36, 0.66, 0.25), noise * 0.1)
			return _shade(Color(0.53, 0.37, 0.24), noise * 0.12)
		GRASS_TOP:
			return _shade(Color(0.36, 0.66, 0.25), noise * 0.12)
		STONE:
			var crack := (x * 7 + y * 3) % 11 == 0 or (x + y * 5) % 13 == 0
			return _shade(Color(0.5, 0.5, 0.52), noise * 0.1 - (0.12 if crack else 0.0))
		LOG:
			var stripe := 0.1 if x % 4 == 1 else (-0.08 if x % 4 == 3 else 0.0)
			return _shade(Color(0.42, 0.3, 0.17), stripe + noise * 0.06)
		PLANKS:
			var seam := y % 4 == 3 or (x == (5 if (y / 4) % 2 == 0 else 12) and y % 4 != 3)
			return _shade(Color(0.72, 0.56, 0.33), noise * 0.05 - (0.22 if seam else 0.0))
		LEAVES:
			if rng.randf() < 0.12:
				return Color(0.12, 0.3, 0.1)
			return _shade(Color(0.24, 0.52, 0.2), noise * 0.15)
		SAND:
			return _shade(Color(0.88, 0.8, 0.55), noise * 0.06)
		GLASS:
			var border := x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1
			var shine := (x - y == 3 or x - y == 5) and x > 3 and x < 13
			if border:
				return Color(0.85, 0.95, 1.0, 0.95)
			return Color(0.9, 0.97, 1.0, 0.6 if shine else 0.12)
		BRICK:
			var row := y / 4
			var mortar := y % 4 == 0 or (x + (4 if row % 2 else 0)) % 8 == 0
			if mortar:
				return _shade(Color(0.78, 0.76, 0.72), noise * 0.04)
			return _shade(Color(0.66, 0.26, 0.2), noise * 0.08)
		BEDROCK:
			return _shade(Color(0.25, 0.25, 0.27), noise * 0.25)
		TNT:
			# Faixa branca com "TNT" escrito no meio do vermelho
			if y >= 5 and y <= 10:
				return Color(0.1, 0.1, 0.1) if _tnt_letter(x - 2, y - 6) else Color(0.93, 0.92, 0.88)
			var stripe := -0.18 if x % 4 == 0 else 0.0
			var top := -0.25 if y <= 1 else 0.0
			return _shade(Color(0.82, 0.18, 0.13), stripe + top + noise * 0.05)
	return Color.TRANSPARENT


## As letras T, N, T em 3x4 pixels, com um pixel entre elas
func _tnt_letter(x: int, y: int) -> bool:
	if y < 0 or y > 3 or x < 0 or x > 10 or x % 4 == 3:
		return false
	var column := x % 4
	if x / 4 == 1:
		return column != 1 or y == 1 or y == 2
	return y == 0 or column == 1


func _shade(color: Color, amount: float) -> Color:
	return color.lightened(amount) if amount > 0 else color.darkened(-amount)


func _average(image: Image) -> Color:
	var total := Color(0, 0, 0, 0)
	for y in SIZE:
		for x in SIZE:
			total += image.get_pixel(x, y)
	return total / float(SIZE * SIZE)


## Rachaduras que crescem a cada estágio
func _crack(stage: int) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for line in (stage + 1) * 2:
		var point := Vector2i(rng.randi_range(4, 11), rng.randi_range(4, 11))
		for step in 3 + stage * 2:
			image.set_pixelv(point, Color(0, 0, 0, 0.75))
			point += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			point = point.clamp(Vector2i.ZERO, Vector2i(SIZE - 1, SIZE - 1))
	return image


## Ícone do app: o quadrado verde dos outros ícones, com um bloco de grama em 3D no meio
func icon(size := 128) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius := size * 0.22
	var top: Image = textures[GRASS_TOP].get_image()
	var side: Image = textures[GRASS].get_image()
	var center := Vector2(size / 2.0, size / 2.0 + size * 0.04)
	var s := size * 0.3
	for y in size:
		for x in size:
			var color := _icon_background(x, y, size, radius)
			if color.a == 0:
				continue
			var face := _cube_pixel(Vector2(x, y) - center, s, top, side)
			image.set_pixel(x, y, face if face.a > 0 else color)
	return ImageTexture.create_from_image(image)


func _icon_background(x: int, y: int, size: int, radius: float) -> Color:
	var corner := Vector2(clampf(x, radius, size - radius), clampf(y, radius, size - radius))
	if Vector2(x, y).distance_to(corner) > radius:
		return Color.TRANSPARENT
	return Color8(43, 191, 140) if x < size / 2 else Color8(38, 166, 122)


## Um cubo isométrico: a face de cima é o topo da grama, as dos lados a lateral, mais escuras
func _cube_pixel(d: Vector2, s: float, top: Image, side: Image) -> Color:
	# Face de cima: losango acima do centro
	var u := (d.x / s + (d.y + s) * 2.0 / s) / 2.0
	var v := ((d.y + s) * 2.0 / s - d.x / s) / 2.0
	if u >= 0 and u < 1 and v >= 0 and v < 1:
		return _sample(top, u, v)
	if d.x >= -s and d.x < 0:
		u = (d.x + s) / s
		v = (d.y + s / 2.0 - u * s / 2.0) / s
		if v >= 0 and v < 1:
			return _sample(side, u, v).darkened(0.15)
	if d.x >= 0 and d.x < s:
		u = d.x / s
		v = (d.y + u * s / 2.0) / s
		if v >= 0 and v < 1:
			return _sample(side, u, v).darkened(0.32)
	return Color.TRANSPARENT


func _sample(image: Image, u: float, v: float) -> Color:
	return image.get_pixel(clampi(int(u * SIZE), 0, SIZE - 1), clampi(int(v * SIZE), 0, SIZE - 1))
