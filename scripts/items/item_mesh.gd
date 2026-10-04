class_name ItemMesh
## Malla 3D de un objeto para verlo en la mano o en el suelo: los bloques son cubos con su
## textura; las herramientas con modelo (hacha, pico) son sus modelos de cubitos (Kenney Survival
## Kit, voxelizados); el resto (cuerda, ropa...) es su icono con grosor, un prisma por píxel.

## Objetos con modelo de cubitos (res://assets/models/voxel/<nombre>.res).
const VOXEL_MODELS := {"stone_axe": "tool_axe", "stone_pick": "tool_pickaxe", "raw_fish": "fish"}

static var _voxel_cache := {}


static func make(id: String, size: float) -> Mesh:
	var block := ItemDB.block_of(id)
	if Player.SHAPED.has(block):  # la mesa, el cofre...: su modelo de cubitos
		return PrefabLibrary.centered_mesh(PrefabLibrary.first_id(Player.SHAPED[block]), size)
	if block >= 0:
		return BlockTextures.make_block_mesh(block, size)
	if VOXEL_MODELS.has(id):
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
		if Player.SHAPED.has(block):
			return PrefabLibrary.material()
		return BlockTextures.make_material(block == IslandGenerator.WATER)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # los colores del dibujo son sRGB (si no, salen desvaídos)
	material.roughness = 1.0
	return material


static func _flat(id: String, size: float) -> Mesh:
	var img := ItemPainter.paint(id)
	var n := ItemPainter.S
	var px := size / n
	var half := n * 0.5
	# Los objetos de mano deben tener volumen visible; la ropa sigue siendo una pieza fina.
	var depth := px * (0.8 if id in ["shirt", "pants", "belt", "cloth", "note_belt", "note_backpack", "note_pick"] else 2.6)
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
