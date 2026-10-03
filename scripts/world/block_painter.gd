class_name BlockPainter
## Pinta por código las texturas de 16x16 de los bloques, partiendo del color de cada bloque
## (Blocks.COLORS) y añadiendo detalle de píxel. Todo es determinista: siempre sale igual.

const S := 16


static func paint(name: String) -> Image:
	if name.ends_with("_h"):  # la misma textura tumbada (corteza de un tronco caído)
		var turned := paint(name.trim_suffix("_h"))
		turned.rotate_90(CLOCKWISE)
		return turned
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
		"planks": _planks(img, salt, Blocks.color_of(IslandGenerator.PLANKS))
		"mossy_stone": _mossy_stone(img, salt)
		"driftwood": _driftwood(img, salt)
		"chest_top": _chest(img, salt, false)
		"chest_side": _chest(img, salt, true)
		"chest_back": _chest(img, salt, false, true)
		"cloth": _cloth(img, salt)
		"workbench_top": _workbench_top(img, salt)
		"workbench_side": _workbench_side(img, salt)
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
	_noise_fill(img, base, 0.15, 0.18, salt)
	# Grumos de tierra y piedrecillas cálidas, agrupados para que no parezca ruido uniforme.
	for i in 11:
		var x := int(_rand(i, 1, salt) * S)
		var y := int(_rand(i, 2, salt) * S)
		var c := base.darkened(0.28) if i % 3 == 0 else base.lightened(0.12)
		img.set_pixel(x, y, c)
		if i % 2 == 0:
			img.set_pixel((x + 1) % S, y, c)
		if i % 4 == 0:
			img.set_pixel(x, (y + 1) % S, c.darkened(0.08))


static func _grass_top(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.GRASS)
	_noise_fill(img, base, 0.11, 0.22, salt)
	# Matas legibles a tamaño real: dos píxeles de luz y una sombra corta al pie.
	for tuft in 9:
		var x := int(_rand(tuft, 3, salt) * S)
		var y := int(_rand(tuft, 4, salt) * S)
		var leaf := base.lightened(0.22) if tuft % 3 != 0 else base.darkened(0.24)
		img.set_pixel(x, y, leaf)
		img.set_pixel(posmod(x + 1, S), y, leaf.lightened(0.03))
		img.set_pixel(x, posmod(y + 1, S), leaf.darkened(0.08))
		if tuft % 2 == 0:
			img.set_pixel(posmod(x + 1, S), posmod(y + 1, S), leaf.darkened(0.12))


static func _grass_side(img: Image, salt: int) -> void:
	_dirt(img, salt + 1)
	var base := Blocks.color_of(IslandGenerator.GRASS)
	for x in S:
		var depth := 2 + int(_rand(x, 9, salt) * 4.0)  # la hierba cuelga irregular por el borde
		for y in depth:
			var g := (_rand(x, y, salt) - 0.5) * 0.13
			img.set_pixel(x, y, _shade(base.darkened(0.035 * y), g))
		if x % 5 == 1:
			img.set_pixel(x, depth, base.darkened(0.16))


static func _stone(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.STONE)
	_noise_fill(img, base, 0.10, 0.22, salt)
	# Facetas minerales pequeñas, en tonos fríos y cálidos.
	for i in 18:
		var x := int(_rand(i, 2, salt) * S)
		var y := int(_rand(i, 3, salt) * S)
		var fleck := base.lightened(0.15) if i % 3 != 0 else base.darkened(0.19)
		img.set_pixel(x, y, fleck)
		if i % 4 == 0:
			img.set_pixel(posmod(x + 1, S), y, fleck)
	# Dos grietas cortas e irregulares, separadas de los destellos de mineral.
	for c in 2:
		var x := int(_rand(c, 5, salt) * S)
		var y := int(_rand(c, 6, salt) * S)
		for step in 5:
			img.set_pixel(posmod(x, S), posmod(y, S), base.darkened(0.30))
			if step % 2 == 0:
				img.set_pixel(posmod(x + 1, S), posmod(y, S), base.darkened(0.20))
			x += 1
			y += int(_rand(c, step + 10, salt) * 3.0) - 1


static func _mossy_stone(img: Image, salt: int) -> void:
	var stone := Blocks.color_of(IslandGenerator.STONE)
	var moss := Blocks.color_of(IslandGenerator.MOSSY_STONE)
	_noise_fill(img, stone, 0.09, 0.20, salt)
	for y in S:
		for x in S:
			var patch := _smooth(x, y, 4, salt + 11)
			if patch > 0.57 and _rand(x, y, salt + 12) > 0.28:
				var shade := (patch - 0.55) * 0.48 + (_rand(x, y, salt + 13) - 0.5) * 0.16
				img.set_pixel(x, y, _shade(moss, shade))
	# Pale flecks on the rock and tiny bright moss tips.
	for i in 12:
		var x := int(_rand(i, 30, salt) * S)
		var y := int(_rand(i, 31, salt) * S)
		var c := moss.lightened(0.2) if i % 2 == 0 else stone.lightened(0.16)
		img.set_pixel(x, y, c)


static func _driftwood(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.DRIFTWOOD)
	_noise_fill(img, base, 0.18, 0.12, salt)
	# Sun-bleached grain and a few deep splits make this read differently from fresh planks.
	for y in S:
		for x in S:
			if _rand(x, y, salt + 20) > 0.78:
				img.set_pixel(x, y, base.lightened(0.20))
	for split in 4:
		var x := int(_rand(split, 32, salt) * S)
		var y := int(_rand(split, 33, salt) * S)
		for step in 5:
			img.set_pixel(posmod(x, S), posmod(y, S), base.darkened(0.28))
			x += 1
			y += int(_rand(split, step + 34, salt) * 3.0) - 1


static func _sand(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.SAND)
	_noise_fill(img, base, 0.08, 0.08, salt)
	# Ondas de arena suaves con algún grano oscuro, en vez de manchas de piedra.
	for y in S:
		var ripple := 0.5 + 0.5 * sin(float(y) * 0.78 + _smooth(0, y, 8, salt) * 2.0)
		if ripple > 0.88:
			for x in S:
				if _rand(x, y, salt + 2) > 0.35:
					img.set_pixel(x, y, base.lightened(0.08))
	for i in 12:
		var x := int(_rand(i, 7, salt) * S)
		var y := int(_rand(i, 8, salt) * S)
		img.set_pixel(x, y, base.darkened(0.16))
		if i % 3 == 0:
			img.set_pixel(posmod(x + 1, S), y, base.lightened(0.1))


static func _snow(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.SNOW)
	for y in S:
		for x in S:
			var g := (_rand(x, y, salt) - 0.5) * 0.045 - _smooth(x, y, 8, salt) * 0.055
			var c := _shade(base, g)
			c.b = minf(c.b + 0.035, 1.0)  # sombra fría de nieve compactada
			img.set_pixel(x, y, c)
	for i in 9:
		var x := int(_rand(i, 17, salt) * S)
		var y := int(_rand(i, 18, salt) * S)
		img.set_pixel(x, y, Color(0.78, 0.86, 0.95))
		if i % 3 == 0:
			img.set_pixel(posmod(x + 1, S), y, Color(0.88, 0.93, 0.98))


static func _log_side(img: Image, salt: int, base: Color) -> void:
	# Corteza en bandas anchas, con surcos finos y vetas claras quebradas.
	for x in S:
		var band := sin(float(x) * 0.72 + _smooth(x, 0, 8, salt) * 3.0) * 0.08
		var column := (_rand(x, 0, salt) - 0.5) * 0.12 + band
		var groove := x % 5 == 0 or _rand(x, 1, salt) > 0.9
		for y in S:
			var g := column + (_rand(x, y, salt) - 0.5) * 0.08
			if groove and _rand(x, y + 20, salt) > 0.25:
				g -= 0.24
			elif x % 5 == 1 and _rand(x, y + 40, salt) > 0.76:
				g += 0.13
			img.set_pixel(x, y, _shade(base, g))


static func _log_top(img: Image, salt: int, bark: Color, wood: Color) -> void:
	# Anillos ligeramente irregulares: veta de madera clara y corteza gruesa alrededor.
	for y in S:
		for x in S:
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			var r := sqrt(dx * dx * 0.92 + dy * dy * 1.08) + (_rand(x, y, salt) - 0.5) * 0.35
			var c: Color
			if maxf(absf(dx), absf(dy)) > 6.4:
				c = bark
			else:
				c = wood.darkened(0.22) if int(r) % 3 == 0 else wood.lightened(0.025)
			img.set_pixel(x, y, _shade(c, (_rand(x, y, salt) - 0.5) * 0.07))


static func _leaves(img: Image, salt: int, base: Color) -> void:
	for y in S:
		for x in S:
			var clump := _smooth(x, y, 4, salt)
			var g := (clump - 0.5) * 0.34 + (_rand(x, y, salt) - 0.5) * 0.13
			if _rand(x, y, salt + 3) > 0.93:
				g -= 0.35  # huecos oscuros entre las hojas
			img.set_pixel(x, y, _shade(base, g))
	for i in 10:
		var x := int(_rand(i, 21, salt) * S)
		var y := int(_rand(i, 22, salt) * S)
		img.set_pixel(x, y, base.lightened(0.2))


static func _pine(img: Image, salt: int, base: Color) -> void:
	# Agujas agrupadas en ramilletes diagonales, con sombras profundas entre ramas.
	_noise_fill(img, base, 0.10, 0.22, salt)
	for i in 15:
		var x := int(_rand(i, 11, salt) * S)
		var y := int(_rand(i, 12, salt) * S)
		var c := base.lightened(0.2) if i % 2 == 0 else base.darkened(0.27)
		for k in 4:
			img.set_pixel(posmod(x + k, S), posmod(y + k, S), c)
			if k < 3 and i % 3 == 0:
				img.set_pixel(posmod(x + k, S), posmod(y + k + 1, S), c.darkened(0.08))


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
	# Grietas violetas ramificadas: el brillo queda rodeado por un borde oscuro.
	var vein := Color(0.64, 0.34, 0.88)
	for v in 3:
		var x := int(_rand(v, 13, salt) * S)
		var y := int(_rand(v, 14, salt) * 5.0)
		while y < S:
			img.set_pixel(posmod(x, S), y, vein.darkened(_rand(x, y, salt) * 0.22))
			if _rand(x, y, salt + 5) > 0.65:
				img.set_pixel(posmod(x + 1, S), y, vein.darkened(0.34))
			if _rand(x, y, salt + 6) > 0.88:
				var branch := x + (1 if _rand(x, y, salt + 7) > 0.5 else -1)
				img.set_pixel(posmod(branch, S), y, vein.lightened(0.08))
			x += int(_rand(v, y + 30, salt) * 3.0) - 1
			y += 1 + int(_rand(v, y + 31, salt) * 2.0)


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


static func _planks(img: Image, salt: int, base: Color) -> void:
	# Tablas anchas con veta suave, juntas finas y nudos ocasionales.
	for y in S:
		var board := y / 4
		var tone := (_rand(board, 40, salt) - 0.5) * 0.15
		for x in S:
			var g := tone + (_rand(x, y, salt) - 0.5) * 0.06
			if _rand(x / 3, y, salt + 1) > 0.78:
				g -= 0.07  # veta
			var c := _shade(base, g)
			if y % 4 == 3:
				c = base.darkened(0.28)  # junta entre tablas
			img.set_pixel(x, y, c)
		# Extremo de la tabla desplazado en cada fila (como un suelo de madera).
		var seam := (board * 7 + 3) % S
		if y % 4 != 3:
			img.set_pixel(seam, y, base.darkened(0.24))
	for board in 3:
		var kx := (board * 5 + 4) % S
		var ky := board * 4 + 1
		img.set_pixel(kx, ky, base.darkened(0.25))
		img.set_pixel(posmod(kx + 1, S), ky, base.lightened(0.08))


static func _chest(img: Image, salt: int, side: bool, plain_side := false) -> void:
	var wood := Blocks.color_of(IslandGenerator.CHEST)
	_planks(img, salt, wood)
	var band := Color(0.38, 0.36, 0.34)
	for i in S:  # bandas de hierro en el borde
		img.set_pixel(i, 0, band)
		img.set_pixel(i, S - 1, band.darkened(0.2))
		img.set_pixel(0, i, band)
		img.set_pixel(S - 1, i, band.darkened(0.2))
	if plain_side:  # lados y trasera: solo la junta de la tapa, sin cerradura
		for x in S:
			img.set_pixel(x, 5, wood.darkened(0.5))
	if side:
		for x in S:  # junta de la tapa
			img.set_pixel(x, 5, wood.darkened(0.5))
		var gold := Color(0.85, 0.7, 0.3)  # cerradura
		for y in range(4, 9):
			for x in range(7, 9):
				img.set_pixel(x, y, gold if y != 7 else gold.darkened(0.45))


static func _cloth(img: Image, salt: int) -> void:
	var base := Blocks.color_of(IslandGenerator.CLOTH)
	for y in S:
		for x in S:
			var weave := 0.04 if (x + y) % 2 == 0 else -0.04  # trama de la lona
			var dirt := (_smooth(x, y, 4, salt) - 0.5) * 0.18
			img.set_pixel(x, y, _shade(base, weave + dirt + (_rand(x, y, salt) - 0.5) * 0.05))


static func _workbench_top(img: Image, salt: int) -> void:
	# Tablero grueso y gastado, con marco oscuro y marcas de cortes y de herramientas.
	var wood := Blocks.color_of(IslandGenerator.WORKBENCH)
	_planks(img, salt, wood.lightened(0.05))
	var frame := wood.darkened(0.35)
	for i in S:
		img.set_pixel(i, 0, frame)
		img.set_pixel(i, S - 1, frame)
		img.set_pixel(0, i, frame)
		img.set_pixel(S - 1, i, frame)
	for k in 5:  # cortes de cuchillo
		var x := 3 + int(_rand(k, 1, salt) * 9.0)
		var y := 3 + int(_rand(k, 2, salt) * 9.0)
		img.set_pixel(x, y, wood.darkened(0.3))
		img.set_pixel(x + 1, y + 1, wood.darkened(0.3))
	# Una piedra de afilar y una cuerda enrollada en una esquina.
	for y in range(2, 5):
		for x in range(10, 14):
			img.set_pixel(x, y, Color(0.5, 0.5, 0.52).darkened(0.1 * (y - 2)))
	img.set_pixel(3, 12, Color(0.8, 0.66, 0.42))
	img.set_pixel(4, 12, Color(0.72, 0.58, 0.36))
	img.set_pixel(3, 13, Color(0.72, 0.58, 0.36))
	img.set_pixel(4, 13, Color(0.8, 0.66, 0.42))


static func _workbench_side(img: Image, salt: int) -> void:
	# Tablero arriba y dos patas, con un travesaño; entre las patas, sombra.
	var wood := Blocks.color_of(IslandGenerator.WORKBENCH)
	var shadow := Color(0.16, 0.12, 0.09)
	for y in S:
		for x in S:
			var c := shadow
			var top := y < 4
			var leg := (x < 3 or x > 12) and y >= 4
			var rail := y >= 9 and y <= 10
			if top or leg or rail:
				var g := (_rand(x, y, salt) - 0.5) * 0.08
				c = _shade(wood if not top else wood.lightened(0.05), g)
				if top and y == 3:
					c = wood.darkened(0.3)
			img.set_pixel(x, y, c)
