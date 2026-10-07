class_name ItemMesh
## Malla 3D de un objeto para verlo en la mano o en el suelo: los bloques son cubos con su
## textura; las herramientas con modelo (hacha, pico) son sus modelos de cubitos (Kenney Survival
## Kit, voxelizados); el resto (cuerda, ropa...) es su icono con grosor, un prisma por píxel.

## Objetos con modelo de cubitos (res://assets/models/voxel/<nombre>.res).
const VOXEL_MODELS := {"stone_axe": "tool_axe", "stone_pick": "tool_pickaxe", "raw_fish": "fish"}

static var _voxel_cache := {}

## Objetos con modelo 3D hecho con Meshy (tools/import_items.gd): assets/models/items/<id>.res y
## su textura. Tamaño respecto al de un objeto normal (un cuchillo es pequeño, una lanza larga).
const MODELS_DIR := "res://assets/models/items/"
const MODEL_SCALE := {"stone_knife": 0.75, "stone_axe": 0.75, "stone_pick": 1.25, "spear": 2.6, "torch": 1.1,
	"rock": 0.45, "flint": 0.4, "hammer": 1.0, "battle_axe": 1.4, "bow": 1.8, "arrow": 1.6}
static var _model_cache := {}


## Los modelos de Meshy ya no se usan (no encajan con el estilo de cajas de la guía visual):
## los objetos son su icono con grosor hasta que tengan su modelo de cubitos.
const USE_MESHY := false
## Iconos dibujados en diagonal (mango abajo a la izquierda, punta arriba a la derecha): en la mano
## se giran 45° para que el mango quede recto dentro del puño.
const DIAGONAL_ICONS := ["stone_knife", "stone_axe", "stone_pick", "spear", "torch", "hammer", "battle_axe",
	"arrow", "bow", "sticks"]


## Objetos de cubitos sacados de su hoja de vistas (tools/objetos_desde_vistas.py).
const OBJECTS_DIR := "res://assets/models/objetos/"
static var _object_cache := {}


static func has_voxel_object(id: String) -> bool:
	return FileAccess.file_exists(OBJECTS_DIR + id + ".json")


## Malla del objeto de cubitos con su lado más largo igual a "size". Con grip >= 0 (en la mano),
## el punto a "grip" de su alto (desde abajo) queda en el origen; si no, el objeto va centrado.
static func _voxel_object(id: String, size: float, grip := -1.0) -> Mesh:
	var key := "%s:%.3f:%.3f" % [id, size, grip]
	if _object_cache.has(key):
		return _object_cache[key]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OBJECTS_DIR + id + ".json"))
	var dims := Vector3(data["size"][0], data["size"][1], data["size"][2])
	var k := size / maxf(dims.x, maxf(dims.y, dims.z))
	var center := dims * 0.5
	if grip >= 0.0:
		center.y = dims.y * grip
	var filled := {}
	for v: Array in data["voxels"]:
		filled[Vector3i(int(v[0]), int(v[1]), int(v[2]))] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Caras de cada cubito que no tapa otro: color de la vista desde la que se ve esa cara. Delante
	# en el archivo es z = 0; en el juego, delante es -Z.
	var dirs := {Vector3i(0, 0, -1): 3, Vector3i(0, 0, 1): 3, Vector3i(1, 0, 0): 4, Vector3i(-1, 0, 0): 4,
		Vector3i(0, 1, 0): 5, Vector3i(0, -1, 0): 5}
	for v: Array in data["voxels"]:
		var cell := Vector3i(int(v[0]), int(v[1]), int(v[2]))
		for dir: Vector3i in dirs:
			if filled.has(cell + dir):
				continue
			var color := Color.html(v[dirs[dir]])
			if dir == Vector3i(0, 0, 1) or dir == Vector3i(0, -1, 0):
				color = color.darkened(0.15)  # detrás y abajo, un poco más oscuro
			var n := Vector3(dir.x, dir.y, -dir.z)
			var c := (Vector3(cell.x + 0.5, cell.y + 0.5, -(cell.z + 0.5)) - Vector3(center.x, center.y, -center.z)) * k
			var u := Vector3(n.y, n.z, n.x).abs()
			var w := n.cross(u)
			var o := c + n * 0.5 * k
			var a := o + (-u - w) * 0.5 * k
			var b := o + (u - w) * 0.5 * k
			var cc := o + (u + w) * 0.5 * k
			var d := o + (-u + w) * 0.5 * k
			st.set_color(color)
			st.set_normal(n)
			var quad := [a, d, cc, a, cc, b] if u.cross(w).dot(n) > 0.0 else [a, b, cc, a, cc, d]
			for p: Vector3 in quad:
				st.add_vertex(p)
	var mesh := st.commit()
	_object_cache[key] = mesh
	return mesh


static func has_model(id: String) -> bool:
	return USE_MESHY and ResourceLoader.exists(MODELS_DIR + id + ".res")


## El modelo con su medida mayor igual a "size" (las mallas vienen de medida 1).
static func _model(id: String, size: float, grip_fraction := -1.0) -> Mesh:
	var key := "%s:%.3f:%.3f" % [id, size, grip_fraction]
	if not _model_cache.has(key):
		var src: ArrayMesh = load(MODELS_DIR + id + ".res")
		var arrays := src.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		# De pie: si es más largo a lo ancho que a lo alto (el hacha), se gira para que el mango
		# quede vertical, que es como se coge.
		var box := src.get_aabb()
		var turn := Basis(Vector3.BACK, PI * 0.5) if box.size.x > box.size.y * 1.2 else Basis.IDENTITY
		# Las herramientas con mango se cogen por abajo: el punto de agarre (el origen) queda a un
		# cuarto del extremo de abajo y la cabeza, arriba.
		var lift := size * (0.32 if id == "stone_axe" else 0.25) if id in VoxelHand.HANDLED else 0.0
		if grip_fraction >= 0.0:
			lift = size * (0.5 - grip_fraction)
		for i in verts.size():
			verts[i] = turn * verts[i] * size + Vector3(0, lift, 0)
			normals[i] = turn * normals[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in verts.size():
				var tangent := turn * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
				tangents[i * 4] = tangent.x
				tangents[i * 4 + 1] = tangent.y
				tangents[i * 4 + 2] = tangent.z
			arrays[Mesh.ARRAY_TANGENT] = tangents
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_model_cache[key] = out
	return _model_cache[key]


static func make_held(id: String, length: float, grip_fraction: float) -> Mesh:
	if has_voxel_object(id):
		return _voxel_object(id, length, grip_fraction)
	if has_model(id):
		return _model(id, length, grip_fraction)
	if id in DIAGONAL_ICONS and ItemDB.block_of(id) < 0:
		return _diagonal_held(id, length, grip_fraction)
	return make(id, length)


## Icono en diagonal puesto de pie: girado 45° y con el punto de agarre (a "grip" del largo,
## desde abajo) en el origen. "length" es el largo del objeto de punta a punta.
static func _diagonal_held(id: String, length: float, grip: float) -> Mesh:
	var size := length / 1.27  # la diagonal del dibujo mide ~1,27 veces su lado
	var flat := _flat(id, size)
	var arrays := flat.surface_get_arrays(0)
	var rot := Basis(Vector3.BACK, PI / 4.0)
	var shift := Vector3(0, -(-0.636 + 1.273 * grip) * size, 0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = rot * verts[i] + shift
		normals[i] = rot * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func make(id: String, size: float) -> Mesh:
	var block := ItemDB.block_of(id)
	if BlockAim.SHAPED.has(block):  # la mesa, el cofre...: su modelo de cubitos
		return PrefabLibrary.centered_mesh(PrefabLibrary.first_id(BlockAim.SHAPED[block]), size)
	if block >= 0:
		return BlockTextures.make_block_mesh(block, size)
	if has_voxel_object(id):  # modelo de cubitos sacado de su hoja de vistas
		return _voxel_object(id, size)
	if has_model(id):  # modelo 3D de Meshy (assets/models/items)
		return _model(id, size * float(MODEL_SCALE.get(id, 1.0)))
	# Si ya tiene dibujo del arte conceptual, manda el dibujo (el modelo de Kenney era provisional).
	if VOXEL_MODELS.has(id) and not ResourceLoader.exists(ItemPainter.OVERRIDE_DIR + id + ".png"):
		var voxel := _voxel(VOXEL_MODELS[id], size * 1.4)
		if voxel != null:
			return voxel
	return _flat(id, size)


## Modelo de cubitos centrado en el origen y con su medida mayor igual a "size".
static func _voxel(model_name: String, size: float) -> Mesh:
	var key := "%s:%.3f" % [model_name, size]
	if _voxel_cache.has(key):
		return _voxel_cache[key]
	var path := "res://assets/models/voxel/%s.res" % model_name
	if not ResourceLoader.exists(path):
		return null
	var src: ArrayMesh = load(path)
	var box := src.get_aabb()
	var k := size / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.0001))
	var center := box.get_center()
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = (verts[i] - center) * k
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_voxel_cache[key] = out
	return out


static func make_material(id: String) -> StandardMaterial3D:
	var block := ItemDB.block_of(id)
	if block >= 0:
		if BlockAim.SHAPED.has(block):
			return PrefabLibrary.material()
		return BlockTextures.make_material(block == IslandGenerator.WATER)
	if has_model(id):
		var mesh: ArrayMesh = load(MODELS_DIR + id + ".res")
		if mesh.surface_get_material(0) is StandardMaterial3D:
			return mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		var textured := StandardMaterial3D.new()
		var tex_path := MODELS_DIR + str(mesh.get_meta("texture", id)) + ".webp"
		if ResourceLoader.exists(tex_path):
			textured.albedo_texture = load(tex_path)
		textured.roughness = 0.9
		return textured
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # los colores del dibujo son sRGB (si no, salen desvaídos)
	material.roughness = 1.0
	return material


static func _flat(id: String, size: float) -> Mesh:
	var img := ItemPainter.paint(id)
	var n := img.get_width()  # 16 los pintados por código, 32 los del arte conceptual
	var px := size / n
	var half := n * 0.5
	# Los objetos de mano deben tener volumen visible; la ropa sigue siendo una pieza fina.
	var depth := size / ItemPainter.S * (0.8 if id in ["shirt", "pants", "belt", "cloth", "note_belt", "note_backpack", "note_pick"] else 2.6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			c.a = 1.0
			var side := c.darkened(0.25)
			var x0 := (x - half) * px
			var x1 := x0 + px
			var y1 := (half - y) * px  # en la imagen la y crece hacia abajo
			var y0 := y1 - px
			var z0 := -depth * 0.5
			var z1 := depth * 0.5
			_quad(st, c, Vector3.BACK, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)])
			_quad(st, c, Vector3.FORWARD, [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)])
			if not _opaque(img, x - 1, y):
				_quad(st, side, Vector3.LEFT, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)])
			if not _opaque(img, x + 1, y):
				_quad(st, side, Vector3.RIGHT, [Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1)])
			if not _opaque(img, x, y - 1):
				_quad(st, side, Vector3.UP, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)])
			if not _opaque(img, x, y + 1):
				_quad(st, side, Vector3.DOWN, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)])
	return st.commit()


static func _opaque(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a >= 0.5


## Cara de 4 vértices (en sentido antihorario visto desde fuera) como 2 triángulos.
static func _quad(st: SurfaceTool, color: Color, normal: Vector3, v: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v[i])
