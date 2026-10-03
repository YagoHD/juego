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
]

var _palette := {}   # Color -> índice
var _palette_list: Array[Color] = []


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
		prefabs.append(_cut(entry[0], cells, entry[3]))
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
				var cell := Vector3i(((p + Vector3(0.25, 0.0, 0.25)) / voxel).floor())
				if not cells.has(cell):
					cells[cell] = t[3]
	return cells


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
		p.meshes.append(_piece_mesh(sub))
		var green := 0
		var avg := Color(0, 0, 0)
		for col: Color in sub.values():
			avg += col
			if col.g > col.r * 1.08:
				green += 1
		avg /= sub.size()
		var kind := default_kind
		if default_kind == "tree":
			kind = "leaves" if green * 2 > sub.size() else "wood"
		elif default_kind == "bush":
			kind = "leaves"
		p.kinds.append(kind)
		p.colors.append(avg)
	return p


## Malla de un trozo: cubitos de 1/N, solo caras que dan al aire dentro del trozo (en el borde
## del bloque se dibujan siempre: si se rompe el vecino, no queda un agujero).
func _piece_mesh(sub: Dictionary) -> ArrayMesh:
	var faces := [
		[Vector3i.UP, 1.0, [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[Vector3i.DOWN, 0.6, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[Vector3i.BACK, 0.85, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3i.FORWARD, 0.8, [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]],
		[Vector3i.RIGHT, 0.75, [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]],
		[Vector3i.LEFT, 0.7, [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	]
	var size := 1.0 / N
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector3i in sub:
		var base := Vector3(c) * size
		var color: Color = sub[c]
		for f in faces:
			if sub.has(c + (f[0] as Vector3i)):
				continue
			var shade := color * float(f[1])
			shade.a = 1.0
			var idx := _color_index(shade)
			var v: Array = f[2]
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3(f[0] as Vector3i))
				st.set_uv(Vector2(idx, 0.5))  # índice de la paleta (se pasa a UV al final)
				st.add_vertex(base + (v[i] as Vector3) * size)
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
