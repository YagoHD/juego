class_name ItemPainter
## Dibuja por código los iconos de 16x16 de los objetos que no son bloques (cuerda, ropa,
## mochila...), con fondo transparente y contorno oscuro para que se lean bien en la barra.

const S := 16


static func paint(id: String) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"rope": _rope(img)
		"shirt": _shirt(img)
		"pants": _pants(img)
		"belt": _belt(img)
		"backpack": _backpack(img)
		_: img.fill(Color.MAGENTA)
	_outline(img)
	return img


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, c)


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
	# Rollo de cuerda: anillo con hebras en espiral.
	var light := Color(0.82, 0.68, 0.45)
	var dark := Color(0.58, 0.45, 0.27)
	for y in S:
		for x in S:
			var dx := x - 7.5
			var dy := y - 7.5
			var r := sqrt(dx * dx + dy * dy)
			if r < 6.6 and r > 2.2:
				var strand := int(r * 1.5 + atan2(dy, dx) * 1.2) % 2 == 0
				img.set_pixel(x, y, light if strand else dark)
	_rect(img, 11, 11, 13, 14, light)  # cabo suelto


static func _shirt(img: Image) -> void:
	var c := Color(0.27, 0.42, 0.65)
	_rect(img, 4, 3, 11, 13, c)      # cuerpo
	_rect(img, 1, 3, 3, 7, c)        # manga izquierda
	_rect(img, 12, 3, 14, 7, c)      # manga derecha
	_rect(img, 6, 3, 9, 4, c.darkened(0.35))  # cuello
	_rect(img, 5, 7, 6, 8, c.darkened(0.2))   # bolsillo
	_rect(img, 9, 7, 10, 8, c.darkened(0.2))  # bolsillo


static func _pants(img: Image) -> void:
	var c := Color(0.36, 0.29, 0.22)
	_rect(img, 3, 2, 12, 5, c)       # cintura
	_rect(img, 3, 6, 7, 14, c)       # pierna izquierda
	_rect(img, 8, 6, 12, 14, c)      # pierna derecha
	_rect(img, 3, 2, 12, 2, c.darkened(0.35))
	_rect(img, 4, 4, 5, 5, c.lightened(0.15))   # bolsillos
	_rect(img, 10, 4, 11, 5, c.lightened(0.15))


static func _belt(img: Image) -> void:
	var c := Color(0.32, 0.2, 0.12)
	_rect(img, 1, 6, 14, 9, c)
	_rect(img, 1, 7, 14, 7, c.lightened(0.12))
	var gold := Color(0.86, 0.7, 0.3)
	_rect(img, 6, 5, 9, 10, gold)    # hebilla
	_rect(img, 7, 6, 8, 9, c)
	_rect(img, 11, 7, 12, 8, c.darkened(0.4))  # agujeros


static func _backpack(img: Image) -> void:
	var c := Color(0.5, 0.36, 0.2)
	_rect(img, 3, 3, 12, 14, c)      # bolsa
	_rect(img, 4, 2, 11, 2, c)
	_rect(img, 3, 3, 12, 6, c.lightened(0.15))   # solapa
	_rect(img, 7, 6, 8, 7, Color(0.85, 0.7, 0.3))  # cierre
	_rect(img, 5, 9, 10, 12, c.darkened(0.15))   # bolsillo delantero
	_rect(img, 6, 0, 9, 1, c.darkened(0.3))      # asa
