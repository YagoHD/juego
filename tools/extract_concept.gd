extends SceneTree
## Saca las texturas de los bloques de la hoja de arte conceptual (docs/concept/hoja1_bloques.png):
## cada cubo está dibujado en isométrico; se toman sus caras de arriba, izquierda y derecha, se
## enderezan a cuadrados y se guardan en assets/textures/blocks/ (que manda sobre las pintadas
## por código). Las caras de los lados se aclaran para que, con la luz del juego, no queden el
## doble de oscuras que en el dibujo.
## Uso: godot --headless --path . --script res://tools/extract_concept.gd

const SRC := "res://docs/concept/hoja1_bloques.png"
const OUT := "res://assets/textures/blocks/"
const SIZE := 32
const INSET := 0.05  # se recorta un poco el borde (la línea oscura del dibujo)
const EXPOSURE := 0.8  # el dibujo ya trae la luz del sol; el juego pone la suya encima

## Esquinas de cada cubo en la hoja (px): arriba T, izquierda UL, derecha UR, abajo B.
## Las caras: arriba = T, UR, C, UL; izquierda = UL, C, B, LL; derecha = C, UR, LR, B.
const CUBES := {
	"grass": [Vector2(100, 56), Vector2(25, 93.3), Vector2(176, 95), Vector2(100, 209.3)],
	"dirt": [Vector2(268.3, 58.3), Vector2(196.7, 96.7), Vector2(339.3, 95), Vector2(268.3, 210)],
	"sand": [Vector2(430, 60), Vector2(363.3, 93.3), Vector2(500, 96.7), Vector2(430, 208.3)],
	"stone": [Vector2(591.7, 58.3), Vector2(525, 95), Vector2(658.3, 96.7), Vector2(591.7, 206.7)],
	"mossy": [Vector2(755, 56.7), Vector2(683.3, 91.7), Vector2(813.3, 91.7), Vector2(755, 208.3)],
	"snow": [Vector2(905, 55), Vector2(840, 90), Vector2(970, 91.7), Vector2(905, 206.7)],
	"corrupt": [Vector2(1061.7, 61.7), Vector2(991.7, 93.3), Vector2(1128.3, 95), Vector2(1060, 210)],
	"ore": [Vector2(1215, 51.7), Vector2(1151.7, 86.7), Vector2(1286.7, 86.7), Vector2(1215, 206.7)],
	"log": [Vector2(108.3, 305), Vector2(36.7, 343.3), Vector2(178.3, 343.3), Vector2(106.7, 461)],
	"planks": [Vector2(311.7, 306.7), Vector2(235, 346.7), Vector2(385, 346.7), Vector2(308.3, 458)],
	"driftwood": [Vector2(511.7, 305), Vector2(441.7, 343.3), Vector2(586.7, 345), Vector2(515, 466.7)],
	"cloth": [Vector2(720, 305), Vector2(645, 343.3), Vector2(786.7, 343.3), Vector2(711.7, 466.7)],
	"chest": [Vector2(943.3, 305), Vector2(851.7, 345), Vector2(1001.7, 336.7), Vector2(913.3, 461)],
}

## Texturas que se guardan: nombre -> [cubo, cara ("top", "left", "right")].
const TEXTURES := {
	"grass_top": ["grass", "top"], "grass_side": ["grass", "left"],
	"dirt": ["dirt", "top"], "dirt_side": ["dirt", "left"],
	"sand": ["sand", "top"], "sand_side": ["sand", "left"],
	"stone": ["stone", "top"], "stone_side": ["stone", "left"],
	"mossy_stone": ["mossy", "top"], "mossy_side": ["mossy", "left"],
	"snow": ["snow", "top"], "snow_side": ["snow", "left"],
	"corrupt_top": ["corrupt", "top"], "corrupt_side": ["corrupt", "left"],
	"ore": ["ore", "top"], "ore_side": ["ore", "left"],
	"log_top": ["log", "top"], "log_side": ["log", "left"],
	"planks": ["planks", "top"], "planks_side": ["planks", "left"],
	"driftwood": ["driftwood", "top"], "driftwood_side": ["driftwood", "left"],
	"cloth": ["cloth", "top"], "cloth_side": ["cloth", "left"],
	"chest_top": ["chest", "top"], "chest_back": ["chest", "left"], "chest_side": ["chest", "right"],
}

## Cubos de un solo material: sirven para medir cuánto más oscuros dibujó los lados.
const PLAIN := ["dirt", "sand", "stone"]

var _img: Image
var _cubes := CUBES.duplicate()


func _init() -> void:
	_img = Image.load_from_file(ProjectSettings.globalize_path(SRC))
	_img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Cuánto más oscuros están los lados que la cara de arriba en el dibujo.
	var ratio := {"left": 0.0, "right": 0.0}
	for cube in PLAIN:
		var top := _lum(_face(cube, "top"))
		ratio["left"] += top / _lum(_face(cube, "left")) / PLAIN.size()
		ratio["right"] += top / _lum(_face(cube, "right")) / PLAIN.size()
	print("lados más oscuros: izquierda x%.2f, derecha x%.2f" % [ratio["left"], ratio["right"]])
	for name: String in TEXTURES:
		var cube: String = TEXTURES[name][0]
		var side: String = TEXTURES[name][1]
		var tex := _face(cube, side)
		if side != "top":
			_brighten(tex, float(ratio[side]) * 0.9 * EXPOSURE)  # un pelín más oscuros que arriba, no el doble
		else:
			_brighten(tex, EXPOSURE)
		tex.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("[textura] ", name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DECOR_OUT))
	for name: String in SPRITES:
		var sprite := _sprite(SPRITES[name])
		sprite.save_png(ProjectSettings.globalize_path(DECOR_OUT + name + ".png"))
		print("[planta] ", name)
	_sheet2()
	_sheet5()
	quit()


const DECOR_OUT := "res://assets/textures/decor/"
## Plantas sueltas de la hoja (zona donde está cada una): se recortan del fondo.
const SPRITES := {
	"tall_grass": Rect2i(532, 575, 142, 175),
	"flower_red": Rect2i(681, 575, 110, 175),
	"flower_yellow": Rect2i(812, 575, 105, 175),
}


## Recorta una planta: el fondo claro y la sombra gris se vuelven transparentes; queda cuadrada,
## apoyada abajo y centrada, de SIZE x SIZE.
func _sprite(r: Rect2i) -> Image:
	var cut := _img.get_region(r)
	var lo := Vector2i(r.size)
	var hi := Vector2i(-1, -1)
	for y in cut.get_height():
		for x in cut.get_width():
			var c := cut.get_pixel(x, y)
			var grey := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.1
			if (grey and c.get_luminance() > 0.55) or (c.r > 0.85 and c.g > 0.82 and c.b > 0.75):
				cut.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var side := maxi(hi.x - lo.x, hi.y - lo.y) + 1
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var w := hi.x - lo.x + 1
	var h := hi.y - lo.y + 1
	square.blit_rect(cut, Rect2i(lo, Vector2i(w, h)), Vector2i((side - w) / 2, side - h))
	# Reducir sin mezclar el color con el transparente: cada píxel, el color medio de lo opaco.
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var step := float(side) / SIZE
	for y in SIZE:
		for x in SIZE:
			var sum := Color(0, 0, 0, 0)
			var n := 0
			var total := 0
			for sy in range(int(y * step), int((y + 1) * step)):
				for sx in range(int(x * step), int((x + 1) * step)):
					total += 1
					var c := square.get_pixel(sx, sy)
					if c.a > 0.5:
						sum += c
						n += 1
			if n * 3 >= total and n > 0:
				var col := sum / n
				out.set_pixel(x, y, Color(col.r * EXPOSURE, col.g * EXPOSURE, col.b * EXPOSURE, 1.0))
	return out


## Cara de un cubo enderezada a SIZE x SIZE (cada píxel, media de 4x4 muestras del dibujo).
func _face(cube: String, side: String) -> Image:
	var c: Array = _cubes[cube]
	var t: Vector2 = c[0]
	var ul: Vector2 = c[1]
	var ur: Vector2 = c[2]
	var b: Vector2 = c[3]
	var center := ul + ur - t
	var down := b - center
	var origin: Vector2
	var u_axis: Vector2
	var v_axis: Vector2
	match side:
		"top":  # de UL hacia T (u) y de UL hacia C (v)
			origin = ul
			u_axis = t - ul
			v_axis = center - ul
		"left":  # de UL a C (u), hacia abajo (v)
			origin = ul
			u_axis = center - ul
			v_axis = down
		"right":  # de C a UR (u), hacia abajo (v)
			origin = center
			u_axis = ur - center
			v_axis = down
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var k := 4
	for y in SIZE:
		for x in SIZE:
			var sum := Color(0, 0, 0, 0)
			for sy in k:
				for sx in k:
					var u := INSET + (1.0 - 2.0 * INSET) * (x + (sx + 0.5) / k) / SIZE
					var v := INSET + (1.0 - 2.0 * INSET) * (y + (sy + 0.5) / k) / SIZE
					sum += _sample(origin + u_axis * u + v_axis * v)
			var col := sum / float(k * k)
			col.a = 1.0
			out.set_pixel(x, y, col)
	return out


func _sample(p: Vector2) -> Color:
	var x := clampi(int(p.x), 0, _img.get_width() - 2)
	var y := clampi(int(p.y), 0, _img.get_height() - 2)
	var fx := p.x - x
	var fy := p.y - y
	var top := _img.get_pixel(x, y).lerp(_img.get_pixel(x + 1, y), fx)
	var bottom := _img.get_pixel(x, y + 1).lerp(_img.get_pixel(x + 1, y + 1), fx)
	return top.lerp(bottom, fy)


func _lum(img: Image) -> float:
	var s := 0.0
	for y in img.get_height():
		for x in img.get_width():
			s += img.get_pixel(x, y).get_luminance()
	return s / (img.get_width() * img.get_height())


func _brighten(img: Image, k: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0))


# ------------------------------------------------------------------ hoja 2 (bloques del suelo, más grandes)

const SHEET2 := "res://docs/concept/hoja2_bloques.png"
## Los 12 cubos van en una cuadrícula de 4x3, todos iguales: la esquina de delante de arriba (C)
## del primero y la separación; las demás esquinas, respecto a C.
const S2_FIRST := Vector2(192.5, 160.0)
const S2_STEP := Vector2(380.0, 321.25)
const S2_NAMES := ["grass", "dirt", "sand", "wet_sand", "stone", "mossy", "snow", "corrupt",
	"ore", "gravel", "clay", "mud"]
## Texturas de la hoja 2 (mandan sobre las de la 1: más resolución). Nombre -> [cubo, cara].
const S2_TEXTURES := {
	"grass_top": ["grass", "top"], "grass_side": ["grass", "left"],
	"dirt": ["dirt", "top"], "dirt_side": ["dirt", "left"],
	"sand": ["sand", "top"], "sand_side": ["sand", "left"],
	"wet_sand": ["wet_sand", "top"], "wet_sand_side": ["wet_sand", "left"],
	"stone": ["stone", "top"], "stone_side": ["stone", "left"],
	"mossy_stone": ["mossy", "top"], "mossy_side": ["mossy", "left"],
	"snow": ["snow", "top"], "snow_side": ["snow", "left"],
	"corrupt_top": ["corrupt", "top"], "corrupt_side": ["corrupt", "left"],
	"ore": ["ore", "top"], "ore_side": ["ore", "left"],
	"gravel": ["gravel", "top"], "gravel_side": ["gravel", "left"],
	"clay": ["clay", "top"], "clay_side": ["clay", "left"],
	"mud": ["mud", "top"], "mud_side": ["mud", "left"],
}


func _sheet2() -> void:
	_img = Image.load_from_file(ProjectSettings.globalize_path(SHEET2))
	_img.convert(Image.FORMAT_RGBA8)
	for i in S2_NAMES.size():
		var c := S2_FIRST + Vector2(i % 4, i / 4) * S2_STEP
		_cubes["s2_" + S2_NAMES[i]] = [c + Vector2(4, -116), c + Vector2(-123, -58), c + Vector2(127, -58), c + Vector2(0, 136)]
	var ratio := {"left": 0.0, "right": 0.0}
	for cube in ["s2_dirt", "s2_sand", "s2_stone"]:
		var top := _lum(_face(cube, "top"))
		ratio["left"] += top / _lum(_face(cube, "left")) / 3.0
		ratio["right"] += top / _lum(_face(cube, "right")) / 3.0
	for name: String in S2_TEXTURES:
		var side: String = S2_TEXTURES[name][1]
		var tex := _face("s2_" + S2_TEXTURES[name][0], side)
		_brighten(tex, (float(ratio[side]) * 0.9 if side != "top" else 1.0) * EXPOSURE)
		if name == "grass_top":
			# Dos hierbas: con las florecitas del dibujo (sale de vez en cuando) y lisa (la normal):
			# en un prado de cientos de bloques, las flores repetidas en todos se veían como un patrón.
			tex.save_png(ProjectSettings.globalize_path(OUT + "grass_top_flowers.png"))
			_remove_flowers(tex)
		tex.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("[textura hoja 2] ", name)


## Quita las florecitas (puntos amarillos y naranjas) de una textura de hierba: cada píxel de
## flor toma el verde medio de sus vecinos que no son flor.
func _remove_flowers(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var flower := func(c: Color) -> bool: return c.r >= c.g * 0.9 or (c.r > 0.75 and c.g > 0.75 and c.b > 0.6)
	for pass_i in 4:
		var changed := false
		var copy := img.duplicate() as Image
		for y in h:
			for x in w:
				if not flower.call(copy.get_pixel(x, y)):
					continue
				var sum := Color(0, 0, 0, 0)
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var c := copy.get_pixel(clampi(x + dx, 0, w - 1), clampi(y + dy, 0, h - 1))
						if not flower.call(c):
							sum += c
							n += 1
				if n > 0:
					var avg := sum / n
					avg.a = 1.0
					img.set_pixel(x, y, avg)
					changed = true
		if not changed:
			break


# ------------------------------------------------------------------ hoja 5 (bloques de árbol)

const SHEET5 := "res://docs/concept/hoja5_bloques_animales.png"
## Esquinas T, UL, UR, B de cada cubo (las hojas son abultadas: se toma el cubo de dentro).
const S5_CUBES := {
	"leaves": [Vector2(196, 38), Vector2(58, 102), Vector2(334, 102), Vector2(196, 312)],
	"pine": [Vector2(572, 52), Vector2(444, 110), Vector2(700, 110), Vector2(572, 306)],
	"dead_log": [Vector2(1338, 46), Vector2(1214, 104), Vector2(1458, 104), Vector2(1335, 318)],
}
const S5_TEXTURES := {
	"leaves": ["leaves", "top"],
	"pine_leaves": ["pine", "top"],
	"dead_log_top": ["dead_log", "top"], "dead_log_side": ["dead_log", "left"],
}
const S5_SIDE_LIGHT := 1.25  # los lados del dibujo, más oscuros que arriba


func _sheet5() -> void:
	_img = Image.load_from_file(ProjectSettings.globalize_path(SHEET5))
	_img.convert(Image.FORMAT_RGBA8)
	for cube: String in S5_CUBES:
		_cubes["s5_" + cube] = S5_CUBES[cube]
	for name: String in S5_TEXTURES:
		var side: String = S5_TEXTURES[name][1]
		var tex := _face("s5_" + S5_TEXTURES[name][0], side)
		_brighten(tex, (S5_SIDE_LIGHT if side != "top" else 1.0) * EXPOSURE)
		tex.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("[textura hoja 5] ", name)
