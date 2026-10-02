class_name ItemPainter
## Dibuja por código los iconos de 16x16 de los objetos que no son bloques (cuerda, ropa,
## mochila...), con fondo transparente y contorno oscuro para que se lean bien en la barra.

const S := 16


static func paint(id: String) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"rope": _rope(img)
		"wheat": _wheat_bundle(img)
		"sticks": _sticks(img)
		"stone_knife": _stone_knife(img)
		"stone_axe": _stone_axe(img)
		"captain_journal": _journal(img)
		"berries": _berries(img)
		"shirt": _shirt(img)
		"pants": _pants(img)
		"belt": _belt(img)
		"backpack": _backpack(img)
		"rough_backpack": _rough_backpack(img)
		"note_belt", "note_backpack", "note_pick": _note(img)
		"stone_pick": _stone_pick(img)
		_: img.fill(Color.MAGENTA)
	_outline(img)
	return img


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, c)


static func _line(img: Image, from: Vector2i, to: Vector2i, c: Color) -> void:
	var steps := maxi(abs(to.x - from.x), abs(to.y - from.y))
	for i in range(steps + 1):
		var t := float(i) / maxf(float(steps), 1.0)
		img.set_pixel(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)), c)


static func _wheat_bundle(img: Image) -> void:
	var stem := Color(0.66, 0.43, 0.19)
	var gold := Color(0.92, 0.69, 0.26)
	var light := Color(1.0, 0.84, 0.43)
	# Un pequeño manojo atado, con espigas abiertas arriba.
	for offset in [-2, 0, 2]:
		_line(img, Vector2i(7 + offset, 14), Vector2i(8 + offset, 4 + abs(offset)), stem)
		_line(img, Vector2i(8 + offset, 4 + abs(offset)), Vector2i(5 + offset, 2 + abs(offset)), gold)
		_line(img, Vector2i(8 + offset, 5 + abs(offset)), Vector2i(11 + offset, 3 + abs(offset)), light)
		img.set_pixel(8 + offset, 4 + abs(offset), light)
	# Cinta de fibra alrededor de los tallos.
	_line(img, Vector2i(5, 10), Vector2i(11, 9), Color(0.42, 0.25, 0.12))
	_line(img, Vector2i(5, 11), Vector2i(11, 10), Color(0.79, 0.54, 0.24))


static func _sticks(img: Image) -> void:
	var bark := Color(0.39, 0.25, 0.14)
	var light := Color(0.72, 0.52, 0.31)
	_line(img, Vector2i(3, 13), Vector2i(11, 3), bark)
	_line(img, Vector2i(5, 14), Vector2i(13, 4), light)
	_line(img, Vector2i(2, 10), Vector2i(10, 7), bark)
	_line(img, Vector2i(4, 12), Vector2i(12, 9), Color(0.57, 0.38, 0.21))
	# Extremos astillados.
	img.set_pixel(11, 2, Color(0.87, 0.68, 0.42))
	img.set_pixel(13, 3, Color(0.87, 0.68, 0.42))


static func _stone_knife(img: Image) -> void:
	# Mango de madera y hoja de sílex lascada.
	_line(img, Vector2i(3, 13), Vector2i(7, 9), Color(0.23, 0.14, 0.09))
	_line(img, Vector2i(4, 14), Vector2i(8, 10), Color(0.59, 0.35, 0.17))
	_line(img, Vector2i(5, 14), Vector2i(8, 11), Color(0.78, 0.53, 0.28))
	_line(img, Vector2i(7, 10), Vector2i(10, 4), Color(0.18, 0.20, 0.23))
	_line(img, Vector2i(7, 9), Vector2i(12, 2), Color(0.75, 0.79, 0.80))
	_line(img, Vector2i(8, 10), Vector2i(13, 4), Color(0.55, 0.61, 0.64))
	_line(img, Vector2i(12, 2), Vector2i(13, 4), Color(0.9, 0.92, 0.9))
	img.set_pixel(9, 6, Color(0.92, 0.94, 0.93))


static func _berries(img: Image) -> void:
	var red := [Color(0.62, 0.12, 0.16), Color(0.76, 0.20, 0.18), Color(0.54, 0.08, 0.13)]
	var centers := [Vector2i(5, 9), Vector2i(9, 8), Vector2i(7, 12), Vector2i(11, 11)]
	for i in centers.size():
		var p: Vector2i = centers[i]
		for y in range(-2, 3):
			for x in range(-2, 3):
				if x * x + y * y <= 4:
					img.set_pixel(p.x + x, p.y + y, red[i % red.size()])
		img.set_pixel(p.x - 1, p.y - 1, Color(0.98, 0.48, 0.35))
	_line(img, Vector2i(6, 7), Vector2i(9, 4), Color(0.24, 0.48, 0.20))
	_line(img, Vector2i(9, 6), Vector2i(12, 5), Color(0.39, 0.62, 0.24))


## Contorno oscuro alrededor de lo dibujado (píxeles transparentes junto a uno opaco).
static func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < S and n.y < S and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, Color(0.1, 0.08, 0.07, 0.9))
					break


static func _rope(img: Image) -> void:
	# Rollo trenzado con el cabo cruzado por delante.
	var light := Color(0.88, 0.73, 0.49)
	var mid := Color(0.72, 0.56, 0.35)
	var dark := Color(0.46, 0.34, 0.20)
	for y in S:
		for x in S:
			var dx := x - 7.5
			var dy := y - 7.5
			var r := sqrt(dx * dx + dy * dy)
			if r < 6.6 and r > 2.2:
				var strand := int(r * 1.25 + atan2(dy, dx) * 1.5) % 3
				img.set_pixel(x, y, light if strand == 0 else (mid if strand == 1 else dark))
	# El cabo pasa por encima del rollo y cae hacia abajo.
	_line(img, Vector2i(6, 7), Vector2i(11, 11), light)
	_line(img, Vector2i(11, 11), Vector2i(12, 14), mid)
	img.set_pixel(12, 14, light)


static func _shirt(img: Image) -> void:
	var c := Color(0.27, 0.42, 0.65)
	_rect(img, 4, 3, 11, 13, c)      # cuerpo
	_rect(img, 1, 3, 3, 7, c)        # manga izquierda
	_rect(img, 12, 3, 14, 7, c)      # manga derecha
	_rect(img, 4, 3, 5, 12, c.darkened(0.16))  # costura y sombra lateral
	_rect(img, 10, 4, 11, 12, c.lightened(0.1))
	_rect(img, 6, 3, 9, 4, c.darkened(0.35))  # cuello
	_rect(img, 5, 7, 7, 9, c.darkened(0.08))  # bolsillo cosido
	_line(img, Vector2i(5, 9), Vector2i(7, 9), c.lightened(0.18))
	_line(img, Vector2i(2, 7), Vector2i(3, 7), c.lightened(0.2))  # puños
	_line(img, Vector2i(12, 7), Vector2i(13, 7), c.lightened(0.2))
	_line(img, Vector2i(8, 5), Vector2i(8, 12), c.lightened(0.12))  # pliegue


static func _pants(img: Image) -> void:
	var c := Color(0.36, 0.29, 0.22)
	_rect(img, 3, 2, 12, 5, c)       # cintura
	_rect(img, 3, 6, 7, 14, c)       # pierna izquierda
	_rect(img, 8, 6, 12, 14, c)      # pierna derecha
	_rect(img, 3, 2, 12, 2, c.darkened(0.35))
	_rect(img, 4, 4, 5, 5, c.lightened(0.15))   # bolsillos
	_rect(img, 10, 4, 11, 5, c.lightened(0.15))
	_line(img, Vector2i(7, 6), Vector2i(7, 13), c.darkened(0.35))  # tiro
	_line(img, Vector2i(4, 12), Vector2i(6, 12), c.lightened(0.12))  # rodilleras
	_line(img, Vector2i(9, 12), Vector2i(11, 12), c.lightened(0.12))
	_line(img, Vector2i(4, 3), Vector2i(5, 3), Color(0.75, 0.62, 0.39))  # trabillas
	_line(img, Vector2i(10, 3), Vector2i(11, 3), Color(0.75, 0.62, 0.39))


static func _belt(img: Image) -> void:
	var c := Color(0.32, 0.2, 0.12)
	_rect(img, 1, 6, 14, 9, c)
	_rect(img, 1, 7, 14, 7, c.lightened(0.12))
	var gold := Color(0.86, 0.7, 0.3)
	_rect(img, 6, 5, 9, 10, gold)    # hebilla
	_rect(img, 7, 6, 8, 9, c)
	_rect(img, 11, 7, 12, 8, c.darkened(0.4))  # agujeros
	_line(img, Vector2i(2, 6), Vector2i(5, 6), c.lightened(0.3))  # pespunte
	_line(img, Vector2i(10, 9), Vector2i(14, 9), c.darkened(0.35))
	img.set_pixel(6, 5, gold.lightened(0.25))


static func _backpack(img: Image) -> void:
	var c := Color(0.5, 0.36, 0.2)
	_rect(img, 3, 3, 12, 14, c)      # bolsa
	_rect(img, 4, 2, 11, 2, c)
	_rect(img, 3, 3, 4, 13, c.darkened(0.2))
	_rect(img, 11, 4, 12, 13, c.lightened(0.12))
	_rect(img, 3, 3, 12, 6, c.lightened(0.15))   # solapa
	_line(img, Vector2i(4, 6), Vector2i(11, 6), c.darkened(0.24))
	_rect(img, 7, 6, 8, 7, Color(0.85, 0.7, 0.3))  # cierre
	_rect(img, 5, 9, 10, 12, c.darkened(0.15))   # bolsillo delantero
	_line(img, Vector2i(5, 9), Vector2i(10, 9), c.lightened(0.18))
	_rect(img, 6, 0, 9, 1, c.darkened(0.3))      # asa
	_line(img, Vector2i(4, 7), Vector2i(5, 12), c.lightened(0.08))  # tirante
	_line(img, Vector2i(11, 7), Vector2i(10, 12), c.darkened(0.22))


static func _rough_backpack(img: Image) -> void:
	# Saco de tela de vela, cerrado con cuerda y con un remiendo.
	var c := Color(0.82, 0.77, 0.65)
	_rect(img, 3, 4, 12, 14, c)
	_rect(img, 4, 3, 11, 3, c)
	_rect(img, 3, 5, 12, 5, Color(0.72, 0.56, 0.36))   # cuerda que lo cierra
	_rect(img, 6, 1, 6, 4, Color(0.72, 0.56, 0.36))    # asa de cuerda
	_rect(img, 9, 1, 9, 4, Color(0.72, 0.56, 0.36))
	_rect(img, 6, 1, 9, 1, Color(0.72, 0.56, 0.36))
	_rect(img, 8, 9, 11, 12, Color(0.68, 0.64, 0.55))  # remiendo
	_rect(img, 4, 13, 12, 14, c.darkened(0.15))


static func _note(img: Image) -> void:
	# Papel doblado con renglones y un dibujo.
	var paper := Color(0.93, 0.88, 0.74)
	_rect(img, 3, 2, 12, 14, paper)
	_rect(img, 11, 2, 12, 3, paper.darkened(0.2))     # esquina doblada
	var ink := Color(0.35, 0.3, 0.28)
	for y in [5, 7, 9]:
		_rect(img, 5, y, 10, y, ink)
	_rect(img, 5, 11, 6, 12, Color(0.6, 0.38, 0.22))  # dibujito
	_rect(img, 8, 11, 9, 12, Color(0.6, 0.38, 0.22))


static func _stone_axe(img: Image) -> void:
	# Mango de palo en diagonal, cabeza de piedra atada con cuerda.
	var wood := Color(0.55, 0.38, 0.2)
	_line(img, Vector2i(3, 14), Vector2i(11, 4), wood)
	_line(img, Vector2i(4, 14), Vector2i(12, 4), wood.darkened(0.2))
	var stone := Color(0.55, 0.56, 0.58)
	_rect(img, 8, 1, 13, 5, stone)
	_rect(img, 12, 2, 14, 7, stone.darkened(0.15))
	_rect(img, 8, 1, 9, 2, stone.lightened(0.2))
	_rect(img, 10, 5, 11, 6, Color(0.78, 0.65, 0.42))  # atadura de cuerda


static func _journal(img: Image) -> void:
	# Libro de tapas de cuero, hinchado por el agua, con cierre de latón.
	var leather := Color(0.42, 0.24, 0.13)
	_rect(img, 2, 2, 13, 13, leather)
	_rect(img, 2, 2, 3, 13, leather.darkened(0.3))          # lomo
	_rect(img, 13, 3, 14, 12, Color(0.88, 0.82, 0.66))     # hojas por el canto
	_rect(img, 5, 5, 10, 6, leather.lightened(0.18))       # grabado
	_rect(img, 6, 8, 9, 8, leather.lightened(0.18))
	_rect(img, 11, 7, 13, 8, Color(0.82, 0.66, 0.3))       # cierre
	_rect(img, 4, 11, 6, 12, Color(0.3, 0.32, 0.36, 1.0))  # mancha de agua


static func _stone_pick(img: Image) -> void:
	# Mango en diagonal y cabeza de piedra curvada en T.
	var wood := Color(0.55, 0.38, 0.2)
	_line(img, Vector2i(3, 14), Vector2i(10, 5), wood)
	_line(img, Vector2i(4, 14), Vector2i(11, 5), wood.darkened(0.2))
	var stone := Color(0.55, 0.56, 0.58)
	_line(img, Vector2i(4, 4), Vector2i(8, 2), stone)
	_line(img, Vector2i(8, 2), Vector2i(12, 3), stone)
	_line(img, Vector2i(12, 3), Vector2i(14, 7), stone)
	_line(img, Vector2i(4, 5), Vector2i(8, 3), stone.darkened(0.15))
	_line(img, Vector2i(12, 4), Vector2i(13, 8), stone.darkened(0.15))
	_rect(img, 9, 5, 10, 6, Color(0.78, 0.65, 0.42))  # atadura
