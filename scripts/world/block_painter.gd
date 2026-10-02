class_name BlockPainter
## Pinta por código las texturas de 16x16 de los bloques, partiendo del color de cada bloque
## (Blocks.COLORS) y añadiendo detalle de píxel. Todo es determinista: siempre sale igual.

const S := 16


static func paint(name: String) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var salt := name.hash()
	match name:
		"grass_top": _grass_top(img, salt)
		"grass_side": _grass_side(img, salt)
		"dirt": _dirt(img, salt)
		"stone": _stone(img, salt)
		"sand": _sand(img, salt)
		"snow": _snow(img, salt)
		"log_side": _log_side(img, salt, Blocks.color_of(IslandGenerator.WOOD))
		"log_top": _log_top(img, salt, Blocks.color_of(IslandGenerator.WOOD), Color(0.72, 0.56, 0.36))
		"dead_log_side": _log_side(img, salt, Blocks.color_of(IslandGenerator.DEAD_WOOD))
		"dead_log_top": _log_top(img, salt, Blocks.color_of(IslandGenerator.DEAD_WOOD), Color(0.42, 0.38, 0.36))
		"leaves": _leaves(img, salt, Blocks.color_of(IslandGenerator.LEAVES))
		"pine_leaves": _pine(img, salt, Blocks.color_of(IslandGenerator.PINE_LEAVES))
		"water": _water(img, salt)
		"corrupt_top": _corrupt(img, salt)
		"corrupt_side": _corrupt_side(img, salt)
		"wheat_top": _wheat_top(img, salt)
		"wheat_side": _wheat_side(img, salt)
		_: img.fill(Color.MAGENTA)
	return img


# ------------------------------------------------------------------ utilidades

static func _rand(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Ruido suave (valor interpolado en celdas de 'cell' píxeles), 0..1, que se repite sin costuras.
static func _smooth(x: int, y: int, cell: int, salt: int) -> float:
	var n := S / cell
	var fx := float(x) / cell
	var fy := float(y) / cell
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _rand(posmod(x0, n), posmod(y0, n), salt)
	var b := _rand(posmod(x0 + 1, n), posmod(y0, n), salt)
	var c := _rand(posmod(x0, n), posmod(y0 + 1, n), salt)
	var d := _rand(posmod(x0 + 1, n), posmod(y0 + 1, n), salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Color base con variación de brillo píxel a píxel.
static func _shade(base: Color, amount: float) -> Color:
	if amount >= 0.0:
		return base.lightened(amount)
	return base.darkened(-amount)


static func _noise_fill(img: Image, base: Color, grain: float, blotch: float, salt: int) -> void:
	for y in S:
		for x in S:
			var g := (_rand(x, y, salt) - 0.5) * grain
			var b := (_smooth(x, y, 4, salt + 7) - 0.5) * blotch
			img.set_pixel(x, y, _shade(base, g + b))


# ------------------------------------------------------------------ texturas

static func _dirt(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.DIRT)
	_noise_fill(img, base, 0.18, 0.16, salt)
	for i in 7:  # guijarros: manchas de 2 px más oscuras o más claras
		var x := int(_rand(i, 1, salt) * S)
		var y := int(_rand(i, 2, salt) * S)
		var c := base.darkened(0.3) if i % 2 == 0 else base.lightened(0.18)
		img.set_pixel(x, y, c)
		img.set_pixel((x + 1) % S, y, c)


static func _grass_top(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.GRASS)
	_noise_fill(img, base, 0.16, 0.14, salt)
	for i in 22:  # briznas claras y oscuras
		var x := int(_rand(i, 3, salt) * S)
		var y := int(_rand(i, 4, salt) * S)
		img.set_pixel(x, y, base.lightened(0.16) if i % 3 != 0 else base.darkened(0.2))


static func _grass_side(img: Image, salt: int) -> void:
	_dirt(img, salt + 1)
	var base := Blocks.color_of(IslandGenerator.GRASS)
	for x in S:
		var depth := 3 + int(_rand(x, 9, salt) * 3.0)  # la hierba cuelga irregular por el borde
		for y in depth:
			var g := (_rand(x, y, salt) - 0.5) * 0.16
			img.set_pixel(x, y, _shade(base.darkened(0.05 * y), g))


static func _stone(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.STONE)
	_noise_fill(img, base, 0.12, 0.28, salt)
	# Grietas: dos trazos quebrados más oscuros.
	for c in 2:
		var x := int(_rand(c, 5, salt) * S)
		var y := int(_rand(c, 6, salt) * S)
		for step in 7:
			img.set_pixel(posmod(x, S), posmod(y, S), base.darkened(0.32))
			x += 1
			y += int(_rand(c, step + 10, salt) * 3.0) - 1


static func _sand(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.SAND)
	_noise_fill(img, base, 0.1, 0.08, salt)
	for i in 10:
		img.set_pixel(int(_rand(i, 7, salt) * S), int(_rand(i, 8, salt) * S), base.darkened(0.2))


static func _snow(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.SNOW)
	for y in S:
		for x in S:
			var g := (_rand(x, y, salt) - 0.5) * 0.05 - _smooth(x, y, 8, salt) * 0.06
			var c := _shade(base, g)
			c.b = minf(c.b + 0.02, 1.0)  # un toque azulado
			img.set_pixel(x, y, c)


static func _log_side(img: Image, salt: int, base: Color) -> void:
	# Corteza: franjas verticales de distinto tono con surcos oscuros.
	for x in S:
		var column := (_rand(x, 0, salt) - 0.5) * 0.22
		var groove := x % 4 == 0 or _rand(x, 1, salt) > 0.85
		for y in S:
			var g := column + (_rand(x, y, salt) - 0.5) * 0.1
			if groove and _rand(x, y + 20, salt) > 0.2:
				g -= 0.28
			img.set_pixel(x, y, _shade(base, g))


static func _log_top(img: Image, salt: int, bark: Color, wood: Color) -> void:
	# Anillos concéntricos y la corteza alrededor.
	for y in S:
		for x in S:
			var dx := x - 7.5
			var dy := y - 7.5
			var r := sqrt(dx * dx + dy * dy)
			var c: Color
			if maxf(absf(dx), absf(dy)) > 6.6:
				c = bark
			else:
				c = wood.darkened(0.16) if int(r) % 3 == 0 else wood
			img.set_pixel(x, y, _shade(c, (_rand(x, y, salt) - 0.5) * 0.08))


static func _leaves(img: Image, salt: int, base: Color) -> void:
	for y in S:
		for x in S:
			var clump := _smooth(x, y, 4, salt)
			var g := (clump - 0.5) * 0.4 + (_rand(x, y, salt) - 0.5) * 0.2
			if _rand(x, y, salt + 3) > 0.9:
				g -= 0.35  # huecos oscuros entre las hojas
			img.set_pixel(x, y, _shade(base, g))


static func _pine(img: Image, salt: int, base: Color) -> void:
	# Agujas: trazos diagonales cortos.
	_noise_fill(img, base, 0.14, 0.18, salt)
	for i in 18:
		var x := int(_rand(i, 11, salt) * S)
		var y := int(_rand(i, 12, salt) * S)
		var c := base.lightened(0.18) if i % 2 == 0 else base.darkened(0.25)
		for k in 3:
			img.set_pixel(posmod(x + k, S), posmod(y + k, S), c)


static func _water(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.WATER)
	for y in S:
		for x in S:
			var wave := sin((x + _smooth(x, y, 8, salt) * 6.0) * 0.8 + y * 0.35)
			var c := _shade(base, wave * 0.07 + (_rand(x, y, salt) - 0.5) * 0.05)
			c.a = base.a
			img.set_pixel(x, y, c)


static func _corrupt(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.CORRUPT_SOIL)
	_noise_fill(img, base, 0.16, 0.2, salt)
	# Venas violetas que brillan un poco.
	var vein := Color(0.62, 0.30, 0.85)
	for v in 2:
		var x := int(_rand(v, 13, salt) * S)
		var y := 0
		while y < S:
			img.set_pixel(posmod(x, S), y, vein.darkened(_rand(x, y, salt) * 0.3))
			x += int(_rand(v, y + 30, salt) * 3.0) - 1
			y += 1


static func _corrupt_side(img: Image, salt: int) -> void:
	_dirt(img, salt + 2)
	var base := Blocks.color_of(IslandGenerator.CORRUPT_SOIL)
	for x in S:
		var depth := 2 + int(_rand(x, 14, salt) * 3.0)
		for y in depth:
			img.set_pixel(x, y, _shade(base, (_rand(x, y, salt) - 0.5) * 0.15))


static func _wheat_top(img: Image, salt: int) -> void:
	_dirt(img, salt + 3)
	var base := Blocks.color_of(IslandGenerator.WHEAT)
	for y in S:
		for x in S:
			if x % 4 != 3 and _rand(x, y, salt) > 0.25:  # hileras de espigas
				img.set_pixel(x, y, _shade(base, (_rand(x, y, salt + 1) - 0.5) * 0.25))


static func _wheat_side(img: Image, salt: int) -> void:
	_dirt(img, salt + 4)
	var base := Blocks.color_of(IslandGenerator.WHEAT)
	for x in S:
		if x % 2 == 1 and _rand(x, 0, salt) > 0.2:
			continue
		var top := int(_rand(x, 15, salt) * 4.0)  # tallos de distinta altura
		for y in range(top, S - 2):
			img.set_pixel(x, y, _shade(base, (_rand(x, y, salt) - 0.5) * 0.2 - 0.02 * (y - top)))
