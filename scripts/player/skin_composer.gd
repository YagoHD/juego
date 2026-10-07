class_name SkinComposer
## Pinta una skin (imagen de 64x64, formato Minecraft) a partir de opciones: tono de piel,
## pelo y peinado, ojos, camiseta y mangas, pantalón y zapatos. Es la base del futuro editor
## de personaje: el editor solo tendrá que cambiar estas opciones (o añadir capas nuevas).
##
## Si existe USER_SKIN_PATH (una skin pintada a mano, p. ej. con Blockbench), se usa esa.

const USER_SKIN_PATH := "user://skins/skin.png"
## Capas del náufrago sacadas del arte conceptual; si no están, se pinta la skin por código.
const CASTAWAY_DIR := "res://assets/skins/castaway/"
## Skin del náufrago de cajas del estilo nuevo (tools/skin_desde_guia.py, de la guía visual):
## si está, es la del jugador.
const BOXY_SKIN := "res://assets/skins/naufrago/skin.png"

const DEFAULT_OPTIONS := {
	"skin": Color8(222, 170, 132),
	"hair": Color8(74, 47, 28),
	"hair_style": "corto",      # "corto", "largo", "rapado"
	"eyes": Color8(58, 108, 168),
	"shirt": Color8(60, 96, 150),
	"shirt_style": "camiseta",  # "camiseta" (con bolsillos) o "rota" (la del naufragio)
	"sleeves": "cortas",        # "cortas", "largas", "sin" (solo con la camiseta)
	"pants": Color8(72, 60, 48),
	"pants_style": "largo",     # "largo" (con bolsillos) o "corto" (raído, del naufragio)
	"belt": true,               # cinturón con hebilla
	"straps": false,            # correas de la mochila
	"shoes": Color8(42, 33, 28),
	"barefoot": true,           # descalzo (el náufrago no tiene zapatos)
	"slim": false,              # brazos estrechos (3 px) en vez de normales (4 px)
}

const RAG := Color8(196, 182, 156)       # camiseta del naufragio, desteñida
const BELT := Color8(70, 44, 26)
const BUCKLE := Color8(222, 182, 82)
const STRAP := Color8(96, 66, 38)


## Skin del jugador: la pintada a mano si existe; si no, la compuesta con las opciones.
static func load_player_skin(options := DEFAULT_OPTIONS) -> ImageTexture:
	var image: Image = null
	if FileAccess.file_exists(USER_SKIN_PATH):
		image = Image.load_from_file(ProjectSettings.globalize_path(USER_SKIN_PATH))
	if image == null or image.get_width() != SkinModel.TEXTURE_SIZE or image.get_height() != SkinModel.TEXTURE_SIZE:
		image = compose(options)
	# Mipmaps: de cerca se ven los píxeles nítidos; de lejos la textura no "parpadea".
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func compose(options: Dictionary) -> Image:
	var o := DEFAULT_OPTIONS.duplicate()
	o.merge(options, true)
	if ResourceLoader.exists(BOXY_SKIN):
		var boxy := (load(BOXY_SKIN) as Texture2D).get_image()
		if boxy.is_compressed():
			boxy.decompress()
		boxy.convert(Image.FORMAT_RGBA8)
		return boxy
	if ResourceLoader.exists(CASTAWAY_DIR + "base.png"):
		return _compose_castaway(o)
	var img := Image.create(SkinModel.TEXTURE_SIZE, SkinModel.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # la capa exterior queda transparente salvo lo que se pinte
	var slim: bool = o["slim"]
	var skin: Color = o["skin"]

	# 1. Todo el cuerpo de piel (capa base).
	for part in SkinModel.PARTS:
		_paint(img, part, slim, false, skin)

	# 2. Ropa.
	_paint_shirt(img, o, slim)
	_paint_pants(img, o, slim)
	if o["belt"]:
		_paint_rows(img, "body", slim, false, BELT, 11, 12)
		var front: Rect2i = _rects("body", slim, false)["front"]
		img.fill_rect(Rect2i(front.position.x + 3, front.position.y + 11, 2, 1), BUCKLE)
	if o["straps"]:
		var front: Rect2i = _rects("body", slim, false)["front"]
		for x in [1, 6]:  # dos correas que bajan por el pecho
			img.fill_rect(Rect2i(front.position.x + x, front.position.y, 1, 9), STRAP)
		img.fill_rect(Rect2i(front.position.x + 1, front.position.y + 5, 6, 1), STRAP)
	for leg in ["leg_right", "leg_left"]:
		if o["barefoot"]:
			_paint_rows(img, leg, slim, false, skin.darkened(0.08), 11, 12, false, true)  # pies
		else:
			_paint_rows(img, leg, slim, false, o["shoes"], 9, 12, false, true)

	# 3. Cara y pelo.
	_paint_face(img, o)
	_paint_hair(img, o)

	# 4. Un poco de textura: variación de tono píxel a píxel (como pintado a mano).
	_add_grain(img)
	return img


## El náufrago del arte conceptual (tools/extract_skin.gd): skin al doble de resolución (128x128,
## misma distribución). Sin ropa va en ropa interior; cada prenda puesta es una capa encima.
static func _compose_castaway(o: Dictionary) -> Image:
	var img := _castaway_layer("base")
	var layers := []
	if o["pants_style"] == "largo":
		layers.append("pants")
	if o["shirt_style"] == "camiseta":
		layers.append("shirt")
	if o["belt"]:
		layers.append("belt")
	for layer: String in layers:
		var top := _castaway_layer(layer)
		img.blend_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	if o["straps"]:  # correas de la mochila por el pecho (2 px de ancho: la skin va al doble)
		var front: Rect2i = SkinModel.face_rects(Vector2i(16, 16) * 2, Vector3i(8, 12, 4) * 2)["front"]
		for x in [2, 12]:
			img.fill_rect(Rect2i(front.position.x + x, front.position.y, 2, 18), STRAP)
			img.fill_rect(Rect2i(front.position.x + x, front.position.y + 4, 2, 1), STRAP.lightened(0.15))
		img.fill_rect(Rect2i(front.position.x + 2, front.position.y + 10, 12, 2), STRAP)
	return img


static func _castaway_layer(name: String) -> Image:
	var img := (load(CASTAWAY_DIR + name + ".png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _paint_shirt(img: Image, o: Dictionary, slim: bool) -> void:
	if o["shirt_style"] == "rota":
		# Camiseta de tirantes desteñida, con el bajo deshilachado y algún agujero.
		_paint(img, "body", slim, false, RAG)
		var rects := _rects("body", slim, false)
		for face in ["front", "back", "right", "left"]:
			var r: Rect2i = rects[face]
			for x in r.size.x:
				if (x * 7 + r.position.x) % 3 == 0:
					img.set_pixel(r.position.x + x, r.position.y + r.size.y - 1, o["skin"])  # flecos
		var f: Rect2i = rects["front"]
		img.set_pixel(f.position.x + 5, f.position.y + 4, o["skin"])  # agujeros
		img.set_pixel(f.position.x + 2, f.position.y + 8, o["skin"])
		var b: Rect2i = rects["back"]
		img.set_pixel(b.position.x + 3, b.position.y + 6, o["skin"])
		return
	var shirt: Color = o["shirt"]
	_paint(img, "body", slim, false, shirt)
	var front: Rect2i = _rects("body", slim, false)["front"]
	for x in [1, 5]:  # bolsillos del pecho
		img.fill_rect(Rect2i(front.position.x + x, front.position.y + 3, 2, 2), shirt.darkened(0.2))
	var sleeve_rows := {"cortas": 4, "largas": 10, "sin": 0}
	var rows: int = sleeve_rows.get(o["sleeves"], 4)
	for arm in ["arm_right", "arm_left"]:
		if rows > 0:
			_paint_rows(img, arm, slim, false, shirt, 0, rows, true)


static func _paint_pants(img: Image, o: Dictionary, slim: bool) -> void:
	var pants: Color = o["pants"]
	if o["pants_style"] == "corto":
		# Pantalón corto raído: hasta las rodillas, desteñido y con el borde roto.
		var worn := pants.lightened(0.18)
		for leg in ["leg_right", "leg_left"]:
			_paint_rows(img, leg, slim, false, worn, 0, 5, true)
			var rects := _rects(leg, slim, false)
			for face in ["front", "back", "right", "left"]:
				var r: Rect2i = rects[face]
				for x in r.size.x:
					if (x + r.position.x) % 2 == 0:
						img.set_pixel(r.position.x + x, r.position.y + 5, worn)
		_paint_rows(img, "body", slim, false, worn, 11, 12)
		return
	for leg in ["leg_right", "leg_left"]:
		_paint_rows(img, leg, slim, false, pants, 0, 11, true)
		var front: Rect2i = _rects(leg, slim, false)["front"]
		img.fill_rect(Rect2i(front.position.x + 1, front.position.y + 1, 2, 2), pants.darkened(0.25))  # bolsillo
	_paint_rows(img, "body", slim, false, pants, 11, 12)


# ------------------------------------------------------------------ pintar por partes

static func _rects(part: String, slim: bool, overlay: bool) -> Dictionary:
	var info: Dictionary = SkinModel.PARTS[part]
	return SkinModel.face_rects(info["over"] if overlay else info["base"], SkinModel.part_size(part, slim))


static func _paint(img: Image, part: String, slim: bool, overlay: bool, color: Color) -> void:
	var rects := _rects(part, slim, overlay)
	for face in rects:
		img.fill_rect(rects[face], color)


## Pinta las filas [from, to) de las caras laterales (0 = la de arriba de la parte).
## top/bottom: pintar también la tapa de arriba o la de abajo.
static func _paint_rows(img: Image, part: String, slim: bool, overlay: bool, color: Color,
		from: int, to: int, top := false, bottom := false) -> void:
	var rects := _rects(part, slim, overlay)
	for face in ["right", "front", "left", "back"]:
		var r: Rect2i = rects[face]
		img.fill_rect(Rect2i(r.position.x, r.position.y + from, r.size.x, to - from), color)
	if top:
		img.fill_rect(rects["top"], color)
	if bottom:
		img.fill_rect(rects["bottom"], color)


static func _paint_face(img: Image, o: Dictionary) -> void:
	# Cara delantera de la cabeza: 8x8. Ojo: en la imagen, la izquierda es la derecha del personaje.
	var f: Rect2i = _rects("head", false, false)["front"]
	var x := f.position.x
	var y := f.position.y
	var white := Color8(245, 245, 245)
	var eyes: Color = o["eyes"]
	var skin: Color = o["skin"]
	for p in [Vector2i(1, 4), Vector2i(5, 4)]:
		img.set_pixel(x + p.x, y + p.y, white)
		img.set_pixel(x + p.x + 1, y + p.y, eyes)
	img.set_pixel(x + 1, y + 3, Color(o["hair"]).darkened(0.1))  # cejas
	img.set_pixel(x + 2, y + 3, Color(o["hair"]).darkened(0.1))
	img.set_pixel(x + 5, y + 3, Color(o["hair"]).darkened(0.1))
	img.set_pixel(x + 6, y + 3, Color(o["hair"]).darkened(0.1))
	img.set_pixel(x + 3, y + 5, skin.darkened(0.12))  # nariz
	img.set_pixel(x + 4, y + 5, skin.darkened(0.12))
	img.fill_rect(Rect2i(x + 3, y + 6, 2, 1), skin.darkened(0.3))  # boca


static func _paint_hair(img: Image, o: Dictionary) -> void:
	var hair: Color = o["hair"]
	var style: String = o["hair_style"]
	if style == "rapado":
		_paint_rows(img, "head", false, false, hair.lerp(o["skin"], 0.55), 0, 1, true)
		return
	var long := style == "largo"
	# Capa base: el pelo pegado a la cabeza.
	var base := _rects("head", false, false)
	img.fill_rect(base["top"], hair)
	_fill_rows(img, base["front"], 0, 2, hair)                 # flequillo
	_fill_rows(img, base["right"], 0, 7 if long else 4, hair)
	_fill_rows(img, base["left"], 0, 7 if long else 4, hair)
	_fill_rows(img, base["back"], 0, 8 if long else 6, hair)
	# Capa exterior: volumen (sobresale un poco de la cabeza).
	var over := _rects("head", false, true)
	img.fill_rect(over["top"], hair.lightened(0.06))
	_fill_rows(img, over["front"], 0, 1, hair.lightened(0.06))
	_fill_rows(img, over["right"], 0, 6 if long else 2, hair.lightened(0.06))
	_fill_rows(img, over["left"], 0, 6 if long else 2, hair.lightened(0.06))
	_fill_rows(img, over["back"], 0, 8 if long else 4, hair.lightened(0.06))
	if long:
		# Melena que cae por la espalda (capa exterior del torso).
		var body_over: Dictionary = _rects("body", false, true)
		_fill_rows(img, body_over["back"], 0, 4, hair.lightened(0.06))


static func _fill_rows(img: Image, r: Rect2i, from: int, to: int, color: Color) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y + from, r.size.x, mini(to, r.size.y) - from), color)


static func _add_grain(img: Image) -> void:
	for y in SkinModel.TEXTURE_SIZE:
		for x in SkinModel.TEXTURE_SIZE:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var h: int = (x * 73856093) ^ (y * 19349663)
			h = (h ^ (h >> 13)) * 1274126177
			var n := float(h & 0xff) / 255.0
			img.set_pixel(x, y, c.darkened(n * 0.07))
