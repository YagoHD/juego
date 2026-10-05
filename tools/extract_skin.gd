extends SceneTree
## Saca la skin del náufrago del arte conceptual (docs/concept/personaje_a_cuerpo.png y
## personaje_b_ropa.png) en alta resolución: la misma distribución que una skin de Minecraft pero
## al doble (128x128, la cara de 16x16). Guarda en assets/skins/castaway/:
##   base.png  el cuerpo en ropa interior (vistas de delante, de lado y de detrás) y el pelo con
##             volumen en la capa exterior
##   shirt.png, pants.png, belt.png  la ropa, como capas con transparencia que SkinComposer pone
##             encima según lo que lleve puesto
## Cada cara de cada parte se toma de un cuadrilátero del dibujo (los brazos van inclinados).
## Uso: godot --headless --path . --script res://tools/extract_skin.gd

const BODY := "res://docs/concept/personaje_a_cuerpo.png"
const DRESSED := "res://docs/concept/personaje_b_ropa.png"
const OUT := "res://assets/skins/castaway/"
const K := 2  # píxeles de la imagen por píxel de skin de Minecraft

var _img: Image
var _bg: Color
var _out: Image


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_base()
	_clothes()
	quit()


# ------------------------------------------------------------------ cuerpo (hoja A)

func _base() -> void:
	_load(BODY)
	_out = _new_image()
	var skin := _mean(Rect2i(250, 380, 100, 60))  # el pecho
	var hair := _mean(Rect2i(1150, 60, 160, 60))  # el pelo de la nuca
	var dark := _mean(Rect2i(230, 600, 140, 40))  # la ropa interior
	# Cabeza: delante, detrás y lado (el dibujo de perfil mira a la izquierda: es su lado
	# izquierdo; el derecho es el mismo, en espejo).
	_rect_face("head", "front", Rect2(165, 30, 280, 280), hair)
	_rect_face("head", "back", Rect2(1095, 32, 278, 278), hair)
	_rect_face("head", "left", Rect2(605, 35, 285, 280), hair)
	_rect_face("head", "right", Rect2(605, 35, 285, 280), hair, true)
	_fill_face("head", "top", hair)
	_fill_face("head", "bottom", skin.darkened(0.15))
	# Torso: el lado está tapado por el brazo en el dibujo; se usa ese trozo igualmente (el brazo
	# lo tapa también en el juego).
	_rect_face("body", "front", Rect2(192, 325, 218, 330), skin)
	_rect_face("body", "back", Rect2(1125, 325, 222, 330), skin)
	_rect_face("body", "left", Rect2(700, 325, 130, 330), skin)
	_rect_face("body", "right", Rect2(700, 325, 130, 330), skin, true)
	_fill_face("body", "top", skin)
	_fill_face("body", "bottom", dark)
	# Brazos (inclinados en el dibujo): de delante el derecho está a la izquierda de la imagen.
	_arm("arm_right", "front", Vector2(155, 335), Vector2(88, 692), 92, skin)
	_arm("arm_left", "front", Vector2(447, 335), Vector2(512, 692), 92, skin)
	_arm("arm_left", "back", Vector2(1082, 335), Vector2(1022, 692), 92, skin)
	_arm("arm_right", "back", Vector2(1392, 335), Vector2(1446, 692), 92, skin)
	for arm in ["arm_right", "arm_left"]:
		_rect_face(arm, "left", Rect2(705, 335, 120, 357), skin)
		_rect_face(arm, "right", Rect2(705, 335, 120, 357), skin, true)
		_fill_face(arm, "top", skin)
		_fill_face(arm, "bottom", skin.darkened(0.1))
	# Piernas.
	_rect_face("leg_right", "front", Rect2(180, 655, 116, 330), skin)
	_rect_face("leg_left", "front", Rect2(310, 655, 116, 330), skin)
	_rect_face("leg_left", "back", Rect2(1114, 655, 112, 330), skin)
	_rect_face("leg_right", "back", Rect2(1246, 655, 112, 330), skin)
	for leg in ["leg_right", "leg_left"]:
		_rect_face(leg, "left", Rect2(712, 655, 115, 330), skin)
		_rect_face(leg, "right", Rect2(712, 655, 115, 330), skin, true)
		_fill_face(leg, "top", dark)
		_fill_face(leg, "bottom", skin.darkened(0.12))
	_hair_volume(hair)
	_save("base")


## Capa exterior de la cabeza: el pelo sobresale un poco (por delante solo por encima de las cejas).
func _hair_volume(hair: Color) -> void:
	var base := _rects("head", false)
	var over := _rects("head", true)
	for face: String in ["front", "back", "left", "right", "top"]:
		var b: Rect2i = base[face]
		var o: Rect2i = over[face]
		var rows := b.size.y
		if face == "front":
			rows = 6
		elif face == "left" or face == "right":
			rows = 10
		for y in rows:
			for x in b.size.x:
				var c := _out.get_pixel(b.position.x + x, b.position.y + y)
				if face == "top" or _is_hair(c, hair):
					_out.set_pixel(o.position.x + x, o.position.y + y, c.lightened(0.04))


func _is_hair(c: Color, hair: Color) -> bool:
	return c.get_luminance() < hair.get_luminance() + 0.08 and c.r > c.b and c.get_luminance() < 0.33


# ------------------------------------------------------------------ ropa (hoja B, el náufrago vestido)

## Filas (en píxeles de la skin alta, de 0 a 24) donde empieza cada prenda en el torso.
const BELT_FROM := 13
const BELT_TO := 16
const SHIRT_TO := 13
const SLEEVE_TO := 9
const PANTS_LEG_TO := 14


func _clothes() -> void:
	_load(DRESSED)
	# Lo vestido de delante, en una skin aparte, de donde salen las capas.
	var dressed := _new_image()
	_out = dressed
	var skin := _mean(Rect2i(395, 1290, 30, 60))
	_rect_face("body", "front", Rect2(415, 1010, 180, 255), skin)
	_arm("arm_right", "front", Vector2(392, 1015), Vector2(340, 1272), 80, skin)
	_arm("arm_left", "front", Vector2(615, 1015), Vector2(668, 1272), 80, skin)
	_rect_face("leg_right", "front", Rect2(398, 1265, 102, 235), skin)
	_rect_face("leg_left", "front", Rect2(510, 1265, 105, 235), skin)
	# Camiseta: torso hasta el bajo (roto: lo que ya es pantalón se deja ver) y mangas.
	var shirt := _new_image()
	_copy_rows(dressed, shirt, "body", 0, SHIRT_TO, func(c: Color) -> bool: return not _is_cloth_brown(c))
	for arm in ["arm_right", "arm_left"]:
		_copy_rows(dressed, shirt, arm, 0, SLEEVE_TO, func(c: Color) -> bool: return not _is_skin(c))
	_finish_clothing(shirt, ["body", "arm_right", "arm_left"])
	_out = shirt
	_save("shirt")
	# Pantalón: del cinturón para abajo; la cintura (donde iría el cinturón) con el color del
	# pantalón; las perneras rotas por debajo de la rodilla.
	var pants := _new_image()
	_copy_rows(dressed, pants, "body", BELT_TO, 24, func(_c: Color) -> bool: return true)
	var front: Rect2i = _rects("body", false)["front"]
	for y in range(BELT_FROM, BELT_TO):
		for x in front.size.x:
			pants.set_pixel(front.position.x + x, front.position.y + y,
				dressed.get_pixel(front.position.x + x, front.position.y + BELT_TO + 1).darkened(0.12))
	for leg in ["leg_right", "leg_left"]:
		_copy_rows(dressed, pants, leg, 0, PANTS_LEG_TO, func(c: Color) -> bool: return not _is_skin(c))
	_finish_clothing(pants, ["body", "leg_right", "leg_left"])
	_out = pants
	_save("pants")
	# Cinturón de cuerda (con la bolsita delante).
	var belt := _new_image()
	_copy_rows(dressed, belt, "body", BELT_FROM, BELT_TO, func(c: Color) -> bool: return not _is_skin(c))
	_finish_clothing(belt, ["body"])
	_out = belt
	_save("belt")


## Copia las filas [from, to) de la cara de delante de una parte, donde keep(color) lo permita.
func _copy_rows(src: Image, dst: Image, part: String, from: int, to: int, keep: Callable) -> void:
	var r: Rect2i = _rects(part, false)["front"]
	for y in range(from, mini(to, r.size.y)):
		for x in r.size.x:
			var c := src.get_pixel(r.position.x + x, r.position.y + y)
			if c.a > 0.5 and keep.call(c):
				dst.set_pixel(r.position.x + x, r.position.y + y, c)


## La ropa solo se dibujó de frente: la espalda es la delantera en espejo (en el cuello, la piel
## del escote se tapa con la tela de la misma fila) y los lados repiten el borde de la delantera.
func _finish_clothing(img: Image, parts: Array) -> void:
	for part: String in parts:
		var rects := _rects(part, false)
		var f: Rect2i = rects["front"]
		var b: Rect2i = rects["back"]
		for y in f.size.y:
			var row_cloth := Color(0, 0, 0, 0)
			for x in f.size.x:
				var c := img.get_pixel(f.position.x + x, f.position.y + y)
				if c.a > 0.5 and not _is_skin(c):
					row_cloth = c
					break
			for x in f.size.x:
				var c := img.get_pixel(f.position.x + f.size.x - 1 - x, f.position.y + y)
				if c.a > 0.5 and _is_skin(c) and row_cloth.a > 0.5:
					c = row_cloth
				img.set_pixel(b.position.x + x, b.position.y + y, c)
			for side in ["right", "left"]:
				var s: Rect2i = rects[side]
				for x in s.size.x:
					var src_x := x if side == "right" else f.size.x - s.size.x + x
					var c := img.get_pixel(f.position.x + src_x, f.position.y + y)
					if c.a > 0.5 and _is_skin(c) and row_cloth.a > 0.5:
						c = row_cloth
					img.set_pixel(s.position.x + x, s.position.y + y, c)
		# Tapas: la de arriba de las mangas y perneras, del color de la tela de la primera fila.
		var top_color := img.get_pixel(f.position.x + f.size.x / 2, f.position.y)
		if top_color.a > 0.5 and part != "body":
			img.fill_rect(rects["top"], top_color)


func _is_skin(c: Color) -> bool:
	return c.h > 0.03 and c.h < 0.1 and c.s > 0.38 and c.v > 0.62


func _is_cloth_brown(c: Color) -> bool:
	return c.h > 0.04 and c.h < 0.14 and c.s > 0.25 and c.v < 0.6


# ------------------------------------------------------------------ utilidades

func _load(path: String) -> void:
	_img = Image.load_from_file(ProjectSettings.globalize_path(path))
	_img.convert(Image.FORMAT_RGBA8)
	_bg = _img.get_pixel(3, 3)


func _new_image() -> Image:
	var img := Image.create(64 * K, 64 * K, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _save(name: String) -> void:
	_out.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("[skin] ", name)


## Rectángulos de las caras de una parte, en la skin alta.
func _rects(part: String, overlay: bool) -> Dictionary:
	var info: Dictionary = SkinModel.PARTS[part]
	var origin: Vector2i = info["over"] if overlay else info["base"]
	var r := SkinModel.face_rects(origin * K, SkinModel.part_size(part, false) * K)
	return r


func _fill_face(part: String, face: String, color: Color) -> void:
	_out.fill_rect(_rects(part, false)[face], color)


## Cara tomada de un rectángulo del dibujo (mirror: en espejo).
func _rect_face(part: String, face: String, src: Rect2, fallback: Color, mirror := false) -> void:
	var o := src.position
	var u := Vector2(src.size.x, 0)
	if mirror:
		o.x += src.size.x
		u = -u
	_quad_face(part, face, o, u, Vector2(0, src.size.y), fallback)


## Brazo inclinado: del centro del hombro al centro de la mano, con su anchura.
func _arm(part: String, face: String, top: Vector2, bottom: Vector2, width: float, fallback: Color) -> void:
	var down := bottom - top
	var across := Vector2(-down.y, down.x).normalized() * width
	if across.x < 0:
		across = -across  # de izquierda a derecha de la imagen
	_quad_face(part, face, top - across * 0.5, across, down, fallback)


## Rellena una cara: cada píxel es la media de la zona central de su trozo del dibujo (sin mezclar
## con el borde: los "píxeles" del dibujo quedan nítidos). El fondo se cambia por fallback.
func _quad_face(part: String, face: String, origin: Vector2, u: Vector2, v: Vector2, fallback: Color) -> void:
	var r: Rect2i = _rects(part, false)[face]
	var n := 3
	for y in r.size.y:
		for x in r.size.x:
			var sum := Color(0, 0, 0, 0)
			var bg_hits := 0
			for sy in n:
				for sx in n:
					var fu := (x + 0.25 + 0.5 * (sx + 0.5) / n) / r.size.x
					var fv := (y + 0.25 + 0.5 * (sy + 0.5) / n) / r.size.y
					var c := _sample(origin + u * fu + v * fv)
					if absf(c.r - _bg.r) + absf(c.g - _bg.g) + absf(c.b - _bg.b) < 0.12:
						bg_hits += 1
					else:
						sum += c
			var col := fallback if bg_hits * 2 > n * n else sum / float(n * n - bg_hits)
			col.a = 1.0
			_out.set_pixel(r.position.x + x, r.position.y + y, col)


func _sample(p: Vector2) -> Color:
	var x := clampi(int(p.x), 0, _img.get_width() - 1)
	var y := clampi(int(p.y), 0, _img.get_height() - 1)
	return _img.get_pixel(x, y)


func _mean(r: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			sum += _img.get_pixel(x, y)
	var c := sum / float(r.size.x * r.size.y)
	c.a = 1.0
	return c
