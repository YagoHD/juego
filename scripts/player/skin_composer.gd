class_name SkinComposer
## Pinta una skin (imagen de 64x64, formato Minecraft) a partir de opciones: tono de piel,
## pelo y peinado, ojos, camiseta y mangas, pantalón y zapatos. Es la base del futuro editor
## de personaje: el editor solo tendrá que cambiar estas opciones (o añadir capas nuevas).
##
## Si existe USER_SKIN_PATH (una skin pintada a mano, p. ej. con Blockbench), se usa esa.

const USER_SKIN_PATH := "user://skins/skin.png"

const DEFAULT_OPTIONS := {
	"skin": Color8(222, 170, 132),
	"hair": Color8(74, 47, 28),
	"hair_style": "corto",      # "corto", "largo", "rapado"
	"eyes": Color8(58, 108, 168),
	"shirt": Color8(60, 96, 150),
	"sleeves": "cortas",        # "cortas", "largas", "sin"
	"pants": Color8(72, 60, 48),
	"shoes": Color8(42, 33, 28),
	"slim": false,              # brazos estrechos (3 px) en vez de normales (4 px)
}


## Skin del jugador: la pintada a mano si existe; si no, la compuesta con las opciones.
static func load_player_skin(options := DEFAULT_OPTIONS) -> ImageTexture:
	var image: Image = null
	if FileAccess.file_exists(USER_SKIN_PATH):
		image = Image.load_from_file(ProjectSettings.globalize_path(USER_SKIN_PATH))
	if image == null or image.get_width() != SkinModel.TEXTURE_SIZE or image.get_height() != SkinModel.TEXTURE_SIZE:
		image = compose(options)
	return ImageTexture.create_from_image(image)


static func compose(options: Dictionary) -> Image:
	var o := DEFAULT_OPTIONS.duplicate()
	o.merge(options, true)
	var img := Image.create(SkinModel.TEXTURE_SIZE, SkinModel.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # la capa exterior queda transparente salvo lo que se pinte
	var slim: bool = o["slim"]
	var skin: Color = o["skin"]

	# 1. Todo el cuerpo de piel (capa base).
	for part in SkinModel.PARTS:
		_paint(img, part, slim, false, skin)

	# 2. Ropa.
	var shirt: Color = o["shirt"]
	_paint(img, "body", slim, false, shirt)
	_paint_rows(img, "body", slim, false, Color(o["pants"]).darkened(0.25), 11, 12)  # cinturón
	var sleeve_rows := {"cortas": 4, "largas": 10, "sin": 0}
	var rows: int = sleeve_rows.get(o["sleeves"], 4)
	for arm in ["arm_right", "arm_left"]:
		if rows > 0:
			_paint_rows(img, arm, slim, false, shirt, 0, rows, true)
	for leg in ["leg_right", "leg_left"]:
		_paint_rows(img, leg, slim, false, o["pants"], 0, 9, true)
		_paint_rows(img, leg, slim, false, o["shoes"], 9, 12, false, true)

	# 3. Cara y pelo.
	_paint_face(img, o)
	_paint_hair(img, o)

	# 4. Un poco de textura: variación de tono píxel a píxel (como pintado a mano).
	_add_grain(img)
	return img


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
