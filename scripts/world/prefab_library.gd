class_name PrefabLibrary
## Los prefabs (palmeras, rocas, arbustos... troceados en bloques por tools/bake_prefabs.gd) y
## los ids de bloque de sus piezas. Los ids empiezan en FIRST_ID y siguen el orden de NAMES:
## no cambiar el orden (los mundos guardados usan esos números); los nuevos, al final.

const DIR := "res://assets/models/prefabs/"
const NAMES := ["palm_tall", "palm_bend", "palm_short", "rock_a", "rock_d", "rock_tall",
	"bush", "stump", "mushrooms_red", "mushrooms_tan"]
const FIRST_ID := 64

static var _loaded := false
static var _prefabs: Array[Prefab] = []
static var _first: Array[int] = []       # primer id de cada prefab
static var _kind := {}                   # id -> "wood" / "leaves" / "rock" / "mushroom"
static var _color := {}                  # id -> Color
static var _mesh := {}                   # id -> ArrayMesh (espacio 0..1)
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
			_color[next + i] = p.colors[i]
			_mesh[next + i] = p.meshes[i]
		next += p.cells.size()
	_last_id = next - 1


static func last_id() -> int:
	load_all()
	return _last_id


static func is_prefab(id: int) -> bool:
	return id >= FIRST_ID and id <= _last_id


static func kind(id: int) -> String:
	return _kind.get(id, "")


static func color(id: int) -> Color:
	return _color.get(id, Color.MAGENTA)


static func index_of(prefab_name: String) -> int:
	return NAMES.find(prefab_name)


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
	model.culls_neighbors = false
	model.transparency_index = 3
	if kind(id) == "leaves" or kind(id) == "mushroom":
		model.set_mesh_collision_enabled(0, false)
		model.collision_aabbs = []
	else:
		model.collision_aabbs = [mesh.get_aabb()]
	return model


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
