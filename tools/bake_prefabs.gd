extends SceneTree
## Convierte modelos de Kenney (OBJ) en "prefabs" del mundo: cada modelo se pasa a cubitos (como
## tools/voxelize_model.gd) y se trocea en bloques de medio metro. Cada trozo será un bloque con
## su propia forma (VoxelBlockyModelMesh) que se rompe por separado; el tipo de cada trozo
## (tronco, hojas, roca...) se deduce de sus colores.
## Como el motor de bloques no usa colores de vértice, todos los colores van a una paleta
## (una imagen de 1 fila) y cada cara apunta a su color con las UV.
## Uso: godot --headless --path . --script res://tools/bake_prefabs.gd
## Salida: res://assets/models/prefabs/<nombre>.res y palette.png

const SRC := "res://assets/third_party_raw/kenney_nature-kit/Models/OBJ format/"
const OUT := "res://assets/models/prefabs/"
const N := 5  # cubitos por bloque en cada lado (cubito de 0,1 m)

## [nombre, modelo, medida mayor en metros (alto o ancho), tipo por defecto ("tree": verde = hojas y el resto tronco;
## "rock"; "mushroom"; "bush": todo hojas)]
const LIST := [
	["palm_tall", "tree_palmTall", 6.0, "tree"],
	["palm_bend", "tree_palmBend", 5.0, "tree"],
	["palm_short", "tree_palmDetailedShort", 4.0, "tree"],
	["rock_a", "rock_largeA", 2.0, "rock"],
	["rock_d", "rock_largeD", 2.4, "rock"],
	["rock_tall", "rock_tallC", 2.6, "rock"],
	["bush", "plant_bushDetailed", 1.2, "bush"],
	["stump", "stump_oldTall", 0.9, "tree"],
	["mushrooms_red", "mushroom_redGroup", 0.45, "mushroom"],
	["mushrooms_tan", "mushroom_tanGroup", 0.45, "mushroom"],
	["oak_k", "tree_oak", 6.5, "tree"],
	["fat_k", "tree_fat", 6.0, "tree"],
	["pine_k", "tree_pineTallA_detailed", 8.0, "tree"],
	["log_fallen", "log_large", 2.4, "trunk"],
	["bush_large", "plant_bushLarge", 1.8, "bush"],
	["wheat_a", "crops_wheatStageA", 0.42, "crop"],
	["wheat_b", "crops_wheatStageB", 0.48, "crop"],
]

var _palette := {}   # Color -> índice
var _palette_list: Array[Color] = []


## Mesa de trabajo (como la del arte conceptual, docs/concept/hoja1_bloques.png): tablero grueso
## de tablones con juntas, cuatro patas, travesaños, un martillo, una nota y un trapo azul que
## cuelga por un lado. Cubitos de 1/16 de bloque; lo de encima del tablero sobresale un poco.
const BENCH_RES := 16


func _workbench() -> Prefab:
	var sub := {}
	var wood := Color(0.76, 0.48, 0.25)
	var dark := Color(0.42, 0.25, 0.13)
	var r := BENCH_RES
	# Tablero grueso (5 capas): tablones a lo largo de Z, de 4 cubitos, con juntas marcadas solo
	# arriba, vetas y clavos en las puntas.
	for x in r:
		var plank := x / 4
		for z in r:
			for y in range(11, 16):
				var col := wood.darkened(0.07 * (plank % 2)).lightened(0.03 * ((plank * 7) % 3))
				if (z + plank * 5) % 6 == 0:
					col = col.darkened(0.1)  # vetas
				if x % 4 == 3 and x < r - 1:
					if y == 15:
						continue  # junta entre tablones
					if y == 14:
						col = dark
				if y == 11:
					col = col.darkened(0.15)  # canto de abajo, en sombra
				if (z == 0 or z == r - 1) and x % 4 == 1 and y == 14:
					col = Color(0.58, 0.58, 0.62)  # clavos
				sub[Vector3i(x, y, z)] = col
	# Faldón bajo el tablero (un cubito hacia dentro).
	for x in range(1, r - 1):
		for z in range(1, r - 1):
			if x == 1 or x == r - 2 or z == 1 or z == r - 2:
				for y in range(9, 11):
					sub[Vector3i(x, y, z)] = wood.darkened(0.22)
	# Patas de 4x4 en las esquinas, metidas un cubito.
	for corner in [Vector2i(1, 1), Vector2i(r - 5, 1), Vector2i(1, r - 5), Vector2i(r - 5, r - 5)]:
		for x in 4:
			for z in 4:
				for y in 9:
					var col := wood.darkened(0.12 + (0.07 if (x * 2 + z) % 5 == 0 else 0.0))  # vetas a lo largo
					sub[Vector3i(corner.x + x, y, corner.y + z)] = col
	# Travesaños bajos entre las patas, en los cuatro lados.
	for k in range(5, r - 5):
		for y in range(3, 5):
			for side in [2, r - 3]:
				sub[Vector3i(k, y, side)] = wood.darkened(0.2)
				sub[Vector3i(side, y, k)] = wood.darkened(0.2)
	# Martillo cruzado: mango de madera y cabeza de hierro grande.
	for k in range(5, 13):
		sub[Vector3i(k, 16, 2)] = Color(0.8, 0.55, 0.3)
		sub[Vector3i(k, 16, 3)] = Color(0.72, 0.48, 0.26)
	for x in range(1, 5):
		for z in range(1, 4):
			for y in range(16, 18):
				sub[Vector3i(x, y, z)] = Color(0.32, 0.32, 0.36) if y == 17 else Color(0.24, 0.24, 0.28)
	# Nota de papel con manchas, delante a la izquierda.
	for x in range(2, 7):
		for z in range(9, 13):
			sub[Vector3i(x, 16, z)] = Color(0.9, 0.86, 0.74) if (x * 3 + z) % 7 != 0 else Color(0.58, 0.42, 0.32)
	# Trapo azul: encima, junto al borde +Z, y colgando por ese lado (el que se ve de frente).
	var blue := Color(0.1, 0.52, 0.82)
	for x in range(9, 14):
		for z in range(r - 4, r):
			sub[Vector3i(x, 16, z)] = blue.darkened(0.06 * (x % 2))
		for y in range(3, 17):
			if y < 5 and x % 2 == 1:
				continue  # borde de abajo deshilachado
			var col := blue.darkened(0.06 * (x % 2) + 0.08)
			if y == 7:
				col = Color(0.88, 0.52, 0.2)  # raya naranja
			sub[Vector3i(x, y, r)] = col
	var p := Prefab.new()
	p.prefab_name = "workbench"
	p.cells.append(Vector3i.ZERO)
	p.meshes.append(_piece_mesh(sub, {}, Vector3i.ZERO, r))
	p.outlines.append(_outline(sub, r))
	p.kinds.append("wood")
	p.colors.append(wood)
	return p


## Decoración del suelo como en el arte conceptual: piedrecitas, palitos y concha (1/16 de bloque).
func _decor_prefab(prefab_name: String, sub: Dictionary, kind: String) -> Prefab:
	var p := Prefab.new()
	p.prefab_name = prefab_name
	p.cells.append(Vector3i.ZERO)
	p.meshes.append(_piece_mesh(sub, {}, Vector3i.ZERO, BENCH_RES))
	p.outlines.append(_outline(sub, BENCH_RES))
	p.kinds.append(kind)
	var avg := Color(0, 0, 0)
	for col: Color in sub.values():
		avg += col
	p.colors.append(avg / sub.size())
	return p


## Piedra redondeada: caja sin las esquinas, más clara por arriba.
func _stone_lump(sub: Dictionary, at: Vector3i, size: Vector3i, base: Color) -> void:
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var corner := int(x == 0 or x == size.x - 1) + int(y == size.y - 1 and size.y > 1) + int(z == 0 or z == size.z - 1)
				if corner >= 2 and size.x > 2 and size.z > 2:
					continue
				var col := base.lightened(0.12) if y == size.y - 1 else base
				if (x * 3 + z * 5 + y) % 7 == 0:
					col = col.darkened(0.1)
				sub[at + Vector3i(x, y, z)] = col


func _pebbles() -> Prefab:
	var sub := {}
	_stone_lump(sub, Vector3i(6, 0, 3), Vector3i(5, 3, 4), Color(0.48, 0.46, 0.46))
	_stone_lump(sub, Vector3i(2, 0, 8), Vector3i(4, 2, 3), Color(0.44, 0.43, 0.44))
	_stone_lump(sub, Vector3i(8, 0, 9), Vector3i(4, 2, 4), Color(0.4, 0.42, 0.47))
	for s in [Vector3i(3, 0, 4), Vector3i(12, 0, 6), Vector3i(4, 0, 13), Vector3i(10, 0, 14), Vector3i(13, 0, 11)]:
		_stone_lump(sub, s, Vector3i(2, 1, 2), Color(0.5, 0.49, 0.5))
	return _decor_prefab("decor_pebbles", sub, "rock")


## Palo en diagonal sobre el suelo, de 'a' a 'b' (en cubitos, y = 0), con algún nudo.
func _stick(sub: Dictionary, a: Vector2, b: Vector2, color: Color, y := 0) -> void:
	var steps := int(a.distance_to(b) * 2.0) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var c := Vector3i(int(p.x), y, int(p.y))
		sub[c] = color.darkened(0.12) if i % 5 == 0 else color
		if i % 4 == 0:
			sub[c + Vector3i(1, 0, 0)] = color.lightened(0.08)  # el palo tiene algo de grosor


func _sticks() -> Prefab:
	var sub := {}
	var brown := Color(0.46, 0.29, 0.15)
	_stick(sub, Vector2(1, 3), Vector2(13, 12), brown)
	_stick(sub, Vector2(7, 7), Vector2(11, 3), brown.lightened(0.05))  # ramita
	_stick(sub, Vector2(4, 5), Vector2(3, 9), brown.lightened(0.05))
	_stick(sub, Vector2(3, 10), Vector2(10, 15), brown.darkened(0.08))
	_stick(sub, Vector2(7, 13), Vector2(9, 11), brown.darkened(0.08))
	return _decor_prefab("decor_sticks", sub, "wood")


func _shell() -> Prefab:
	var sub := {}
	var hinge := Vector2(8, 12)
	for x in BENCH_RES:
		for z in BENCH_RES:
			var d := Vector2(x + 0.5, z + 0.5) - hinge
			var r := d.length()
			if r > 6.5 or d.y > 0.5:
				continue  # abanico hacia -Z
			var rib := int(floorf((atan2(d.x, -d.y) + 1.6) / 0.4)) % 2
			var col := Color(0.96, 0.88, 0.78) if rib == 0 else Color(0.93, 0.7, 0.55)
			var h := 1 + int(2.2 * (1.0 - r / 6.5))
			for y in h:
				sub[Vector3i(x, y, z)] = col
	for x in range(6, 11):  # charnela
		for z in range(12, 14):
			sub[Vector3i(x, 0, z)] = Color(0.88, 0.7, 0.55)
	return _decor_prefab("decor_shell", sub, "rock")


## Flor en 3D a partir de su dibujo (assets/textures/decor/, sacado del arte conceptual): se
## mira de frente y de lado con el mismo dibujo y se rellena lo que se ve desde las dos vistas.
func _flower(prefab_name: String, sprite_path: String) -> Prefab:
	var img := Image.load_from_file(ProjectSettings.globalize_path(sprite_path))
	img.convert(Image.FORMAT_RGBA8)
	var r := BENCH_RES
	img.resize(r, r, Image.INTERPOLATE_NEAREST)
	var sub := {}
	var mid := r / 2
	for y in r:
		for x in r:
			var col := img.get_pixel(x, r - 1 - y)
			var sat := maxf(col.r, maxf(col.g, col.b)) - minf(col.r, minf(col.g, col.b))
			if col.a < 0.5 or sat < 0.12:
				continue  # transparente, o resto gris de la sombra del dibujo
			col.a = 1.0
			# Dos planos cruzados de 2 cubitos de grueso: la planta tiene volumen desde cualquier lado.
			for k in [mid - 1, mid]:
				sub[Vector3i(x, y, k)] = col
				sub[Vector3i(k, y, x)] = col.darkened(0.08)
	return _decor_prefab(prefab_name, sub, "crop")


## Cofre como el del arte conceptual: tablones con juntas, bandas de hierro con remaches en las
## esquinas y una cerradura delante (-Z). "body": la caja (hueca si 'open'); "lid": la tapa, que
## gira sobre su bisagra de atrás (+Z) al abrirlo (la mueve ChestVisual).
const CHEST_LID_Y := 10   # la tapa empieza a esta altura (cubitos de 16)


func _chest_part(part: String, open := false) -> Dictionary:
	var sub := {}
	var r := BENCH_RES
	var wood := Color(0.68, 0.42, 0.19)
	var iron := Color(0.27, 0.28, 0.31)
	var y0 := 0 if part == "body" else CHEST_LID_Y
	var y1 := CHEST_LID_Y if part == "body" else r - 1
	for x in range(1, r - 1):
		for z in range(1, r - 1):
			for y in range(y0, y1):
				var edge_x := x == 1 or x == r - 2
				var edge_z := z == 1 or z == r - 2
				var shell := edge_x or edge_z or y == y0 or (part == "lid" and y == y1 - 1)
				if open and part == "body" and not shell:
					continue  # hueco por dentro
				var col := wood.darkened(0.08 * ((y / 3) % 2))  # tablones
				if y % 3 == 0:
					col = wood.darkened(0.3)  # junta entre tablones
				if not shell:
					col = wood.darkened(0.45)  # el fondo de dentro, en sombra
				if part == "lid" and y == y0:
					col = col.darkened(0.35)  # la raya entre la tapa y la caja
				# Bandas de hierro: en las esquinas y abrazando la tapa.
				if (edge_x and edge_z) or (part == "lid" and (x == 3 or x == r - 4)) or (part == "body" and (x == 3 or x == r - 4) and edge_z):
					col = iron
					if (y + x + z) % 4 == 0:
						col = Color(0.55, 0.56, 0.6)  # remache
				sub[Vector3i(x, y, z)] = col
	if part == "body":  # cerradura delante (-Z)
		for x in range(6, 10):
			for y in range(CHEST_LID_Y - 4, CHEST_LID_Y + 1):
				sub[Vector3i(x, y, 0)] = Color(0.6, 0.61, 0.64) if not (x in [7, 8] and y == CHEST_LID_Y - 2) else Color(0.12, 0.12, 0.14)
	return sub


func _chest(prefab_name: String, parts: Array[String], open := false) -> Prefab:
	var sub := {}
	for part in parts:
		sub.merge(_chest_part(part, open))
	return _decor_prefab(prefab_name, sub, "wood")


## Tocón que queda al talar un árbol (y del que rebrota): tronco corto con corteza de surcos,
## anillos arriba y raíces que salen por los lados.
func _stump() -> Prefab:
	var sub := {}
	var bark := Color(0.47, 0.3, 0.16)
	var ring := Color(0.8, 0.6, 0.36)
	var r := BENCH_RES
	var mid := Vector2(7.5, 7.5)
	for x in r:
		for z in r:
			var d := Vector2(x, z).distance_to(mid)
			if d > 5.6:
				continue
			for y in 6:
				var col := bark.darkened(0.15 if (x * 3 + z) % 4 == 0 else 0.0)  # surcos de la corteza
				if y == 5 and d < 4.6:
					col = ring.darkened(0.12) if int(d) % 2 == 0 else ring  # anillos
				sub[Vector3i(x, y, z)] = col
	# Raíces: cuatro, saliendo en cruz y bajando hasta el suelo.
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for k in range(5, 8):
			var p := Vector2i(7, 7) + dir * k
			for w in 2:
				var q := p + Vector2i(dir.y, dir.x) * w
				if q.x >= 0 and q.y >= 0 and q.x < r and q.y < r:
					sub[Vector3i(q.x, 0, q.y)] = bark.darkened(0.1)
					if k == 5:
						sub[Vector3i(q.x, 1, q.y)] = bark
	return _decor_prefab("stump_block", sub, "wood")



## Árboles de la hoja del concepto (TreeBuilder), varias versiones de cada uno. El orden es el de
## PrefabLibrary.NAMES (siempre añadir al final).
var TREES := [
	["t_oak_1", TreeBuilder.oak.bind(11)], ["t_oak_2", TreeBuilder.oak.bind(22)], ["t_oak_3", TreeBuilder.oak.bind(33)],
	["t_lean_1", TreeBuilder.leaning_oak.bind(41)], ["t_lean_2", TreeBuilder.leaning_oak.bind(52)],
	["t_giant_1", TreeBuilder.giant.bind(61)],
	["t_pine_1", TreeBuilder.pine.bind(71, false, false)], ["t_pine_2", TreeBuilder.pine.bind(72, false, false)],
	["t_pine_small_1", TreeBuilder.pine.bind(81, true, false)], ["t_pine_small_2", TreeBuilder.pine.bind(82, true, false)],
	["t_pine_tier_1", TreeBuilder.pine.bind(91, false, true)], ["t_pine_tier_2", TreeBuilder.pine.bind(92, false, true)],
	["t_dead_1", TreeBuilder.dead.bind(101)], ["t_dead_2", TreeBuilder.dead.bind(102)],
	["t_bush_1", TreeBuilder.bush.bind(111, false)], ["t_bush_2", TreeBuilder.bush.bind(112, false)],
	["t_berry_1", TreeBuilder.bush.bind(121, true)], ["t_berry_2", TreeBuilder.bush.bind(122, true)],
	["t_log_1", TreeBuilder.fallen_log.bind(131)], ["t_log_2", TreeBuilder.fallen_log.bind(132)],
]


## Los de la hoja 4 del concepto (NatureBuilder): sustituyen a los de Kenney del mismo nombre.
var NATURE := {
	"palm_tall": NatureBuilder.palm_tall.bind(201), "palm_bend": NatureBuilder.palm_bend.bind(202),
	"palm_short": NatureBuilder.palm_short.bind(203),
	"rock_a": NatureBuilder.boulder.bind(211), "rock_d": NatureBuilder.rock_pile.bind(212),
	"rock_tall": NatureBuilder.pillar.bind(213), "stump": NatureBuilder.big_stump.bind(221),
	"mushrooms_red": NatureBuilder.mushrooms.bind(231, true), "mushrooms_tan": NatureBuilder.mushrooms.bind(232, false),
	"wheat_a": NatureBuilder.wheat.bind(241, false), "wheat_b": NatureBuilder.wheat.bind(242, true),
}


## Trocea un árbol de TreeBuilder en bloques. Cada trozo es "leaves", "wood" o "root" según lo
## que más tenga. Los cubitos que no se ven (rodeados por los 6 lados) van de un solo color: así
## sus caras se juntan y los trozos de dentro de la copa son cubos enteros (tapan a sus vecinos).
func _cut_tree(prefab_name: String, build: Callable) -> Prefab:
	var tree: TreeBuilder = build.call()
	var res := TreeBuilder.RES
	var dirs := [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	var blocks := {}  # bloque -> {cubito local -> Color}
	var counts := {}  # bloque -> {tipo -> cuántos}
	for c: Vector3i in tree.cells:
		var type: String = tree.types[c]
		var col: Color = tree.cells[c]
		var hidden := true
		for d: Vector3i in dirs:
			if not tree.cells.has(c + d):
				hidden = false
				break
		if hidden:
			col = {"leaf": TreeBuilder.LEAF[1], "rock": NatureBuilder.STONE[1]}.get(type, TreeBuilder.BARK[1])
		var b := Vector3i(floori(float(c.x) / res), floori(float(c.y) / res), floori(float(c.z) / res))
		if not blocks.has(b):
			blocks[b] = {}
			counts[b] = {}
		blocks[b][c - b * res] = col
		counts[b][type] = int(counts[b].get(type, 0)) + 1
	var p := Prefab.new()
	p.prefab_name = prefab_name
	for b: Vector3i in blocks:
		var sub: Dictionary = blocks[b]
		if sub.size() < 3:
			continue  # una mota suelta
		var best := ""
		for type: String in counts[b]:
			if best == "" or int(counts[b][type]) > int(counts[b][best]):
				best = type
		p.cells.append(b)
		# Las hojas no dibujan las caras que tocan otro trozo (no se ven nunca; al romper un trozo de
		# hojas se ve el hueco, pero las hojas se atraviesan y al talar saltan): muchas menos caras.
		# La madera sí: un tronco no debe verse hueco al picarlo.
		p.meshes.append(_piece_mesh(sub, tree.cells if best == "leaf" else {}, b * res, res))
		p.outlines.append(_outline(sub, res))
		p.kinds.append({"leaf": "leaves", "wood": "wood", "root": "root", "rock": "rock", "mushroom": "mushroom", "crop": "crop"}[best])
		p.fills.append(float(sub.size()) / (res * res * res))
		var avg := Color(0, 0, 0)
		for col: Color in sub.values():
			avg += col
		p.colors.append(avg / sub.size())
	print("  %s: %d trozos, %d cubitos" % [prefab_name, p.cells.size(), tree.cells.size()])
	return p

func _init() -> void:
	var src_dir := ProjectSettings.globalize_path(SRC)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var prefabs: Array[Prefab] = []
	for entry in LIST:
		if NATURE.has(entry[0]):
			prefabs.append(_cut_tree(entry[0], NATURE[entry[0]] as Callable))  # el de la hoja 4, no el de Kenney
			continue
		var cells := _voxelize(src_dir.path_join(entry[1] + ".obj"), float(entry[2]))
		if cells.is_empty():
			print("FALLO leyendo ", entry[1])
			continue
		for c in cells:
			cells[c] = _recolor(cells[c], entry[3])
		prefabs.append(_cut(entry[0], cells, entry[3]))
	for t in TREES:
		prefabs.append(_cut_tree(t[0], t[1] as Callable))
		print("[árbol] ", t[0])
	prefabs.append(_workbench())
	prefabs.append(_pebbles())
	prefabs.append(_sticks())
	prefabs.append(_shell())
	prefabs.append(_stump())
	prefabs.append(_chest("chest_closed", ["body", "lid"]))
	prefabs.append(_chest("chest_open", ["body"], true))
	prefabs.append(_chest("chest_lid", ["lid"]))
	prefabs.append(_flower("decor_flower_red", "res://assets/textures/decor/flower_red.png"))
	prefabs.append(_flower("decor_flower_yellow", "res://assets/textures/decor/flower_yellow.png"))
	# Paleta: una fila de colores; luego, las UV de cada pieza apuntan a su color.
	var img := Image.create(maxi(_palette_list.size(), 1), 1, false, Image.FORMAT_RGBA8)
	for i in _palette_list.size():
		img.set_pixel(i, 0, _palette_list[i])
	img.save_png(ProjectSettings.globalize_path(OUT + "palette.png"))
	var width := float(_palette_list.size())
	for p in prefabs:
		for m in p.meshes:
			_fix_uvs(m, width)
		ResourceSaver.save(p, OUT + p.prefab_name + ".res")
		print("[prefab] %s: %d bloques" % [p.prefab_name, p.cells.size()])
	print("[prefab] paleta de %d colores" % _palette_list.size())
	quit()


## Colores de nuestra isla: los de Kenney, pasados a nuestra paleta (verdes de nuestras hojas,
## marrones de nuestros troncos, grises de nuestra piedra), conservando lo claro u oscuro de cada
## parte para que se lean los volúmenes.
func _recolor(c: Color, kind: String) -> Color:
	var v := clampf(c.get_luminance() * 1.25 + 0.12, 0.22, 0.88)
	var greenish := c.g > c.r * 1.08 and c.g >= c.b * 0.8
	match kind:
		"rock":
			return Color.from_hsv(0.08, 0.06, v * 0.95)
		"bush":
			return Color.from_hsv(0.27, 0.55, v * 0.85)
		"trunk":
			return Color.from_hsv(0.075, 0.5, v * 0.8)
		"crop":
			return c  # los colores del cultivo, tal cual
		"tree":
			if greenish or c.b > c.r:
				return Color.from_hsv(0.25 + (v - 0.5) * 0.05, 0.6, v * 0.9)  # hojas
			return Color.from_hsv(0.075, 0.5, v * 0.8)  # tronco
	return c


## Cubitos del modelo: {Vector3i (en cubitos, base centrada en un bloque) -> Color}.
func _voxelize(obj: String, height: float) -> Dictionary:
	var script := load("res://tools/voxelize_model.gd")
	var data: Dictionary = script._read_obj(obj)
	if data.is_empty():
		return {}
	var verts: PackedVector3Array = data["verts"]
	var low := Vector3(INF, INF, INF)
	var high := -low
	for v in verts:
		low = low.min(v)
		high = high.max(v)
	var voxel := 0.5 / N
	var extent := high - low
	var k := height / maxf(maxf(extent.x, extent.y), maxf(extent.z, 0.0001))
	var center := Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
	var cells := {}
	for t in data["tris"]:
		var a: Vector3 = (verts[t[0]] - center) * k
		var b: Vector3 = (verts[t[1]] - center) * k
		var c: Vector3 = (verts[t[2]] - center) * k
		var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var steps := maxi(1, int(ceilf(longest / (voxel * 0.45))))
		for i in steps + 1:
			for j in steps + 1 - i:
				var p := a + (b - a) * (float(i) / steps) + (c - a) * (float(j) / steps)
				# Centrado: el eje del modelo cae en el centro del bloque (0, 0).
				# (+1 mm en altura: que el redondeo no deje la base un bloque por debajo del suelo)
				var cell := Vector3i(((p + Vector3(0.25, 0.001, 0.25)) / voxel).floor())
				if not cells.has(cell):
					cells[cell] = t[3]
	_fill_inside(cells)
	return cells


## Los modelos son solo una piel: se rellena por dentro para que, al picar, no se vea hueco.
## Se inunda el aire desde fuera de la caja del modelo; lo que no se alcanza es interior y toma
## el color de la piel más cercana.
func _fill_inside(cells: Dictionary) -> void:
	var low := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var high := -low
	for c: Vector3i in cells:
		low = low.min(c)
		high = high.max(c)
	low -= Vector3i.ONE
	high += Vector3i.ONE
	var dirs := [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	var outside := {low: true}
	var queue: Array[Vector3i] = [low]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		for d: Vector3i in dirs:
			var n := c + d
			if n.x < low.x or n.y < low.y or n.z < low.z or n.x > high.x or n.y > high.y or n.z > high.z:
				continue
			if outside.has(n) or cells.has(n):
				continue
			outside[n] = true
			queue.append(n)
	# Interior: se pinta capa a capa desde la piel hacia dentro.
	var front: Array[Vector3i] = []
	front.assign(cells.keys())
	while not front.is_empty():
		var next: Array[Vector3i] = []
		for c in front:
			for d: Vector3i in dirs:
				var n := c + d
				if cells.has(n) or outside.has(n):
					continue
				if n.x < low.x or n.y < low.y or n.z < low.z or n.x > high.x or n.y > high.y or n.z > high.z:
					continue
				cells[n] = cells[c]
				next.append(n)
		front = next


## Trocea los cubitos en bloques y hace la malla de cada trozo.
func _cut(prefab_name: String, cells: Dictionary, default_kind: String) -> Prefab:
	var blocks := {}  # Vector3i bloque -> {Vector3i cubito local -> Color}
	for c: Vector3i in cells:
		var b := Vector3i(floori(float(c.x) / N), floori(float(c.y) / N), floori(float(c.z) / N))
		if not blocks.has(b):
			blocks[b] = {}
		blocks[b][c - b * N] = cells[c]
	var p := Prefab.new()
	p.prefab_name = prefab_name
	for b: Vector3i in blocks:
		var sub: Dictionary = blocks[b]
		if sub.size() < 2:
			continue  # una mota suelta: fuera
		p.cells.append(b)
		p.meshes.append(_piece_mesh(sub, {}, b * N))  # piel completa: las rocas no se ven huecas al picarlas
		p.outlines.append(_outline(sub, N))
		var green := 0
		var avg := Color(0, 0, 0)
		for col: Color in sub.values():
			avg += col
			if col.g > col.r * 1.08:
				green += 1
		avg /= sub.size()
		var kind := default_kind
		if default_kind == "trunk":
			kind = "wood"
		elif default_kind == "tree":
			kind = "leaves" if green * 2 > sub.size() else "wood"
		elif default_kind == "bush":
			kind = "leaves"
		elif default_kind == "crop":
			kind = "crop"
		p.kinds.append(kind)
		p.colors.append(avg)
	return p


## Malla de un trozo: cubitos de 1/N, con su piel completa (las caras entre trozos vecinos no se
## ven por estar de espaldas, y al romper el vecino el trozo sigue macizo).
func _piece_mesh(sub: Dictionary, all_cells: Dictionary, offset: Vector3i, res := N) -> ArrayMesh:
	var faces := [
		[Vector3i.UP, 1.0, [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[Vector3i.DOWN, 0.6, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[Vector3i.BACK, 0.85, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3i.FORWARD, 0.8, [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]],
		[Vector3i.RIGHT, 0.75, [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]],
		[Vector3i.LEFT, 0.7, [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	]
	var size := 1.0 / res
	# Lo que ocupan los cubitos (pueden salirse un poco del bloque: el martillo de la mesa...).
	var box_lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var box_hi := -box_lo
	for c: Vector3i in sub:
		box_lo = box_lo.min(c)
		box_hi = box_hi.max(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drew := false
	# Por cada dirección y cada capa: máscara de las caras que dan al aire (dentro de la pieza),
	# y se juntan en rectángulos del mismo color (muchas menos caras que una por cubito).
	for f in faces:
		var normal: Vector3i = f[0]
		var axis := 0 if normal.x != 0 else (1 if normal.y != 0 else 2)
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for layer in range(box_lo[axis], box_hi[axis] + 1):
			var mask := {}  # Vector2i(u, v) -> índice de color
			for a in range(box_lo[u], box_hi[u] + 1):
				for b in range(box_lo[v], box_hi[v] + 1):
					var c := Vector3i.ZERO
					c[axis] = layer
					c[u] = a
					c[v] = b
					if not sub.has(c) or sub.has(c + normal) or all_cells.has(offset + c + normal):
						continue
					var shade: Color = (sub[c] as Color) * float(f[1])
					shade.a = 1.0
					mask[Vector2i(a, b)] = _color_index(shade)
			while not mask.is_empty():
				var start: Vector2i = mask.keys()[0]
				var idx: int = mask[start]
				# Crecer a lo largo de u, luego de v mientras toda la fila sea igual.
				var w := 1
				while mask.get(start + Vector2i(w, 0), -1) == idx:
					w += 1
				var h := 1
				var grow := true
				while grow:
					for k in w:
						if mask.get(start + Vector2i(k, h), -1) != idx:
							grow = false
							break
					if grow:
						h += 1
				for k in w:
					for j in h:
						mask.erase(start + Vector2i(k, j))
				var lo := Vector3.ZERO
				var hi := Vector3.ZERO
				lo[axis] = layer
				hi[axis] = layer + 1
				lo[u] = start.x
				hi[u] = start.x + w
				lo[v] = start.y
				hi[v] = start.y + h
				var corners: Array = f[2]
				for i in [0, 2, 1, 0, 3, 2]:
					var t: Vector3 = corners[i]
					st.set_normal(Vector3(normal))
					st.set_uv(Vector2(idx, 0.5))  # índice de la paleta (se pasa a UV al final)
					st.add_vertex((lo + (hi - lo) * t) * size)
					drew = true
	if not drew:
		# Trozo de dentro de la copa, sin ninguna cara a la vista: un triángulo de tamaño cero (el
		# bloque necesita una malla, pero no hay nada que dibujar).
		for i in 3:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, 0.5))
			st.add_vertex(Vector3(0.5, 0.5, 0.5))
	st.index()
	return st.commit()


func _color_index(c: Color) -> int:
	var key := Color(snappedf(c.r, 1.0 / 255.0), snappedf(c.g, 1.0 / 255.0), snappedf(c.b, 1.0 / 255.0))
	if not _palette.has(key):
		_palette[key] = _palette_list.size()
		_palette_list.append(key)
	return _palette[key]


## Las UV llevaban el índice del color; ahora que se sabe cuántos hay, al centro de su píxel.
func _fix_uvs(mesh: ArrayMesh, width: float) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in uvs.size():
		uvs[i] = Vector2((uvs[i].x + 0.5) / width, 0.5)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Contorno de una pieza para el recuadro de selección: las aristas de su forma de cubitos (donde
## de los 4 cubitos que rodean una arista hay 1 o 3, o 2 en diagonal). Pares de puntos, 0..1.
func _outline(sub: Dictionary, res: int) -> PackedVector3Array:
	var lines := PackedVector3Array()
	var box_lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var box_hi := -box_lo
	for c: Vector3i in sub:
		box_lo = box_lo.min(c)
		box_hi = box_hi.max(c)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for i in range(box_lo[u], box_hi[u] + 2):
			for j in range(box_lo[v], box_hi[v] + 2):
				var run_start := -1
				for t in range(box_lo[axis], box_hi[axis] + 2):
					var draw := false
					if t <= box_hi[axis]:
						var occ := []
						for k in 4:
							var c := Vector3i.ZERO
							c[axis] = t
							c[u] = i - 1 + (k & 1)
							c[v] = j - 1 + (k >> 1)
							occ.append(sub.has(c))
						var n := occ.count(true)
						draw = n == 1 or n == 3 or (n == 2 and occ[0] == occ[3])
					if draw and run_start < 0:
						run_start = t
					elif not draw and run_start >= 0:
						var a := Vector3.ZERO
						a[axis] = run_start
						a[u] = i
						a[v] = j
						var b := a
						b[axis] = t
						lines.append(a / res)
						lines.append(b / res)
						run_start = -1
	return lines
