class_name PrefabLibrary
## Los prefabs (palmeras, rocas, arbustos... troceados en bloques por tools/bake_prefabs.gd) y
## los ids de bloque de sus piezas. Los ids empiezan en FIRST_ID y siguen el orden de NAMES:
## no cambiar el orden (los mundos guardados usan esos números); los nuevos, al final.

const DIR := "res://assets/models/prefabs/"
const NAMES := ["palm_tall", "palm_bend", "palm_short", "rock_a", "rock_d", "rock_tall",
	"bush", "stump", "mushrooms_red", "mushrooms_tan",
	# Nuevos, siempre al final:
	"oak_k", "fat_k", "pine_k", "log_fallen", "bush_large", "wheat_a", "wheat_b", "tree_parts", "workbench", "decor_pebbles", "decor_sticks", "decor_shell", "decor_flower_red", "decor_flower_yellow"]
const FIRST_ID := 64

static var _loaded := false
static var _prefabs: Array[Prefab] = []
static var _first: Array[int] = []       # primer id de cada prefab
static var _kind := {}                   # id -> "wood" / "leaves" / "rock" / "mushroom"
static var _owner := {}                  # id -> nombre del prefab al que pertenece
static var _color := {}                  # id -> Color
static var _mesh := {}                   # id -> ArrayMesh (espacio 0..1)
static var _outline := {}                # id -> PackedVector3Array (contorno, pares de puntos)
static var _last_id := FIRST_ID - 1
static var _material: StandardMaterial3D


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var next := FIRST_ID
	for n in NAMES:
		var p := load(DIR + n + ".res") as Prefab
		if p == null:
			p = Prefab.new()  # falta el archivo: sin piezas (los ids siguientes no se mueven)
		_prefabs.append(p)
		_first.append(next)
		for i in p.cells.size():
			_kind[next + i] = p.kinds[i]
			_owner[next + i] = n
			_color[next + i] = p.colors[i]
			_mesh[next + i] = p.meshes[i]
			_outline[next + i] = p.outlines[i] if i < p.outlines.size() else PackedVector3Array()
		next += p.cells.size()
	_last_id = next - 1


static func last_id() -> int:
	load_all()
	return _last_id


static func is_prefab(id: int) -> bool:
	return id >= FIRST_ID and id <= _last_id


static func kind(id: int) -> String:
	return _kind.get(id, "")


static func prefab_of(id: int) -> String:
	return _owner.get(id, "")


static func color(id: int) -> Color:
	return _color.get(id, Color.MAGENTA)


static func index_of(prefab_name: String) -> int:
	return NAMES.find(prefab_name)


## Id del primer trozo de un prefab (para los de un solo bloque, como los cultivos).
static func first_id(prefab_name: String) -> int:
	load_all()
	var i := NAMES.find(prefab_name)
	return _first[i] if i >= 0 else -1


## Trozos que se atraviesan (hojas, setas, cultivos): se apuntan como la hierba.
static func is_soft(id: int) -> bool:
	return is_prefab(id) and kind(id) in ["leaves", "mushroom", "crop"]


## Piezas de un prefab: [[celda respecto a la base, id], ...].
static func pieces(index: int) -> Array:
	load_all()
	var out := []
	var p := _prefabs[index]
	for i in p.cells.size():
		out.append([p.cells[i], _first[index] + i])
	return out


## Lo que más se aleja del pie (en bloques), para saber cuánto margen necesita el generador.
static func reach() -> int:
	load_all()
	var r := 0
	for p in _prefabs:
		for c in p.cells:
			r = maxi(r, maxi(absi(c.x), absi(c.z)))
	return r


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = load(DIR + "palette.png")
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material.roughness = 1.0
	return _material


## Modelo del motor de bloques para una pieza: su forma, y choque solo donde hay algo (las
## hojas no chocan: se atraviesan, como la copa de una palmera).
static func make_model(id: int) -> VoxelBlockyModelMesh:
	var model := VoxelBlockyModelMesh.new()
	var mesh: ArrayMesh = _mesh[id]
	model.mesh = mesh
	model.set_material_override(0, material())
	# Las piezas que llenan el bloque entero tapan las caras de sus vecinas (las copas de los
	# árboles son casi todo piezas enteras: así no se dibuja su interior).
	var box := mesh.get_aabb()
	model.culls_neighbors = box.size.is_equal_approx(Vector3.ONE) and _is_full(mesh)
	model.transparency_index = 3
	if kind(id) in ["leaves", "mushroom", "crop"]:
		model.set_mesh_collision_enabled(0, false)
		model.collision_aabbs = []
	else:
		model.collision_aabbs = [mesh.get_aabb()]
	return model


## ¿Es un cubo entero? (tras juntar caras, un cubo macizo de un color son 6 caras: 12 triángulos;
## con los tonos de cada lado, igual; algo con huecos o escalones tiene más)
static func _is_full(mesh: ArrayMesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return indices.size() == 36


## Malla de la pieza centrada en el origen y de lado 'size' (para dibujarla suelta: árboles que
## caen, etc.).
static func centered_mesh(id: int, size: float) -> ArrayMesh:
	var src: ArrayMesh = _mesh[id]
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = (verts[i] - Vector3(0.5, 0.5, 0.5)) * size
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, material())
	return out


## Contorno de la pieza (pares de puntos en el espacio 0..1 del bloque): el recuadro de selección
## sigue su forma en vez de ser un cubo.
static func outline(id: int) -> PackedVector3Array:
	return _outline.get(id, PackedVector3Array())


## Caja que ocupa la pieza dentro de su bloque (0..1).
static func box(id: int) -> AABB:
	var mesh: ArrayMesh = _mesh.get(id)
	return mesh.get_aabb() if mesh != null else AABB(Vector3.ZERO, Vector3.ONE)


## Malla de la pieza (espacio 0..1 del bloque).
static func mesh(id: int) -> ArrayMesh:
	load_all()
	return _mesh.get(id)
