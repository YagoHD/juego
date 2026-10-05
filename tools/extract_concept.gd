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
	_icons()
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


# ------------------------------------------------------------------ iconos de objetos (hoja 6...)

const ITEMS_OUT := "res://assets/textures/items/"
const ICON := 32
## Hojas de iconos: [hoja, columnas de cada fila ([x0, x1] dentro de las líneas de la cuadrícula),
## filas ([y0, y1]), objetos de cada casilla en orden ("" = no se usa; "a|b" = el mismo dibujo
## para varios objetos)]. Los números de debajo se quitan solos (_icon).
const ICON_SHEETS := [
	["res://docs/concept/hoja6_recoleccion.png",
		[[[0, 384], [384, 768], [768, 1152], [1152, 1536]]],
		[[0, 318], [345, 640], [680, 955]],
		["fiber", "rope", "sticks", "rock", "flint", "sharp_rock", "resin", "seeds",
		"insect", "shell", "mushroom", "berries"]],
	["res://docs/concept/hoja7_herramientas.png",
		[[[8, 302], [318, 606], [622, 915], [932, 1220], [1236, 1528]],
		[[8, 372], [388, 762], [778, 1142], [1158, 1528]],
		[[8, 507], [523, 1012], [1028, 1528]]],
		[[8, 352], [368, 672], [688, 1016]],
		["stone_knife", "stone_axe", "stone_pick", "spear", "torch", "board", "shirt", "pants",
		"belt", "rough_backpack", "backpack", "captain_journal"]],
	["res://docs/concept/hoja8_comida.png",
		[[[8, 376], [392, 760], [776, 1144], [1160, 1528]]],
		[[8, 338], [353, 642], [658, 1016]],
		["raw_fish", "cooked_fish", "raw_crab", "cooked_crab", "roasted_insect", "roasted_berries",
		"roasted_seeds", "roasted_mushroom", "flatbread", "wheat", "green_ore",
		"note_belt|note_backpack|note_pick"]],
	["res://docs/concept/hoja9_colocables.png",
		[[[8, 504], [520, 1016], [1032, 1528]]],
		[[8, 504], [520, 1016]],
		["campfire", "", "", "bedroll", "raft", ""]],
]


func _icons() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEMS_OUT))
	for sheet: Array in ICON_SHEETS:
		_img = Image.load_from_file(ProjectSettings.globalize_path(sheet[0]))
		_img.convert(Image.FORMAT_RGBA8)
		var col_sets: Array = sheet[1]
		var rows: Array = sheet[2]
		var names: Array = sheet[3]
		var i := 0
		for row in rows.size():
			var cols: Array = col_sets[mini(row, col_sets.size() - 1)]
			for col: Array in cols:
				if i >= names.size():
					break
				var name: String = names[i]
				i += 1
				if name == "":
					continue
				var ys: Array = rows[row]
				var icon := _icon(Rect2i(col[0], ys[0], col[1] - col[0], ys[1] - ys[0]))
				for id in name.split("|"):
					icon.save_png(ProjectSettings.globalize_path(ITEMS_OUT + id + ".png"))
					print("[icono] ", id)


## Recorta un objeto de su casilla: el fondo (lo que toca el borde y se parece a él) se vuelve
## transparente; el objeto queda centrado en un cuadrado de ICON x ICON con 1 px de margen.
func _icon(r: Rect2i) -> Image:
	var cut := _img.get_region(r)
	var w := cut.get_width()
	var h := cut.get_height()
	var bg := cut.get_pixel(2, 2)
	var is_bg := func(c: Color) -> bool: return absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) < 0.14
	# Relleno desde los bordes: solo es fondo lo que está conectado con el borde.
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x] != 0:
			continue
		if not is_bg.call(cut.get_pixelv(p)):
			continue
		seen[p.y * w + p.x] = 1
		cut.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.UP)
		stack.append(p + Vector2i.DOWN)
	# Huecos cerrados (el aro de la cuerda): lo que es casi igual que el fondo.
	for y in h:
		for x in w:
			var c := cut.get_pixel(x, y)
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) < 0.07:
				cut.set_pixel(x, y, Color(0, 0, 0, 0))
	_remove_labels(cut)
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if cut.get_pixel(x, y).a > 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var side := maxi(hi.x - lo.x, hi.y - lo.y) + 1
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var bw := hi.x - lo.x + 1
	var bh := hi.y - lo.y + 1
	square.blit_rect(cut, Rect2i(lo, Vector2i(bw, bh)), Vector2i((side - bw) / 2, (side - bh) / 2))
	var inner := ICON - 2
	var out := Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var step := float(side) / inner
	for y in inner:
		for x in inner:
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
			if n > 0 and n * 2 >= total:
				var col := sum / n
				col.a = 1.0
				out.set_pixel(x + 1, y + 1, col)
	return out


## Quita los números de la hoja: trozos sueltos pequeños, grises y oscuros (el objeto es mayor o
## tiene color; las chispas o semillas sueltas tienen color y se quedan).
func _remove_labels(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	for start_y in h:
		for start_x in w:
			if label[start_y * w + start_x] != -1 or img.get_pixel(start_x, start_y).a < 0.5:
				continue
			var part: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
			label[start_y * w + start_x] = 1
			var sat := 0.0
			var lum := 0.0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				part.append(p)
				var c := img.get_pixelv(p)
				sat += maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
				lum += c.get_luminance()
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or label[q.y * w + q.x] != -1:
						continue
					if img.get_pixelv(q).a < 0.5:
						continue
					label[q.y * w + q.x] = 1
					stack.append(q)
			var n := part.size()
			if n < w * h * 0.02 and sat / n < 0.12 and lum / n < 0.5:
				for p in part:
					img.set_pixelv(p, Color(0, 0, 0, 0))
