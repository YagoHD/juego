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
var _tree_colors := {}  # "oak_k"/"pine_k" -> {"leaf": Color, "wood": Color}


## El verde y el marrón que más se repiten en un árbol de Kenney (ya pasado a nuestra paleta).
func _common_colors(cells: Dictionary) -> Dictionary:
	var count := {}
	for col: Color in cells.values():
		count[col] = int(count.get(col, 0)) + 1
	var best := {"leaf": [Color.GREEN, 0], "wood": [Color.BROWN, 0]}
	for col: Color in count:
		var key := "leaf" if col.g > col.r * 1.08 else "wood"
		if int(count[col]) > int(best[key][1]):
			best[key] = [col, count[col]]
	return {"leaf": best["leaf"][0], "wood": best["wood"][0]}


## Piezas de nuestros árboles (ver scripts/world/tree_parts.gd; mismo orden que su enum), con los
## colores de los árboles de Kenney para que todos parezcan del mismo juego.
func _tree_parts() -> Prefab:
	var leaf: Color = _tree_colors["oak_k"]["leaf"]
	var pine: Color = _tree_colors["pine_k"]["leaf"]
	var wood: Color = _tree_colors["oak_k"]["wood"]
	var dead := Color.from_hsv(wood.h, wood.s * 0.3, wood.v * 0.8)
	var shapes := [
		["leaves", _shape(leaf, "full")], ["leaves", _shape(leaf, "round")],
		["leaves", _shape(pine, "full")], ["leaves", _shape(pine, "round")],
		["wood", _shape(wood, "y")], ["wood", _shape(wood, "x")], ["wood", _shape(wood, "z")],
		["wood", _shape(dead, "y")], ["wood", _shape(dead, "x")], ["wood", _shape(dead, "z")],
		["wood", _shape(wood, "full")],
	]
	var p := Prefab.new()
	p.prefab_name = "tree_parts"
	for s in shapes:
		var sub: Dictionary = s[1]
		p.cells.append(Vector3i.ZERO)  # no forman un modelo: el generador las coloca una a una
		p.meshes.append(_piece_mesh(sub, {}, Vector3i.ZERO))
		p.kinds.append(s[0])
		var avg := Color(0, 0, 0)
		for col: Color in sub.values():
			avg += col
		p.colors.append(avg / sub.size())
	return p


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
	p.kinds.append("wood")
	p.colors.append(wood)
	return p


## Cubitos de una pieza: "full" (bloque entero), "round" (sin las aristas: la piel redondeada de
## una copa) o "x"/"y"/"z" (tronco fino de 3x3 cubitos a lo largo de ese eje, con vetas).
func _shape(color: Color, kind: String) -> Dictionary:
	var sub := {}
	for x in N:
		for y in N:
			for z in N:
				var c := Vector3i(x, y, z)
				var col := color
				match kind:
					"round":
						var edges := int(x == 0 or x == N - 1) + int(y == 0 or y == N - 1) + int(z == 0 or z == N - 1)
						if edges >= 2:
							continue
					"x", "y", "z":
						var axis := {"x": 0, "y": 1, "z": 2}[kind] as int
						var across := [x, y, z]
						across.remove_at(axis)
						if across[0] < 1 or across[0] > N - 2 or across[1] < 1 or across[1] > N - 2:
							continue
						if (c[axis] + across[0] * 2 + across[1]) % 4 == 0:
							col = color.darkened(0.12)  # vetas de la corteza
				sub[c] = col
	return sub


func _init() -> void:
	var src_dir := ProjectSettings.globalize_path(SRC)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var prefabs: Array[Prefab] = []
	for entry in LIST:
		var cells := _voxelize(src_dir.path_join(entry[1] + ".obj"), float(entry[2]))
		if cells.is_empty():
			print("FALLO leyendo ", entry[1])
			continue
		for c in cells:
			cells[c] = _recolor(cells[c], entry[3])
		if entry[0] in ["oak_k", "pine_k"]:
			_tree_colors[entry[0]] = _common_colors(cells)
		prefabs.append(_cut(entry[0], cells, entry[3]))
	prefabs.append(_tree_parts())
	prefabs.append(_workbench())
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
		p.meshes.append(_piece_mesh(sub, cells, b * N))
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
					if not sub.has(c) or sub.has(c + normal):
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
