class_name DecorModels
## Modelos de la decoración del suelo (no son cubos): hierba alta y flores como planos cruzados
## con textura recortada (como en Hytale o Cube World), y piedrecitas, palos y conchas como
## cajitas pequeñas. Las mallas van en el espacio de un bloque (0..1).

const S := 16


## Modelo del motor de bloques para esta decoración: sin choque y sin tapar a sus vecinos.
static func make_model(id: int) -> VoxelBlockyModelMesh:
	var model := VoxelBlockyModelMesh.new()
	match id:
		IslandGenerator.TALL_GRASS, IslandGenerator.FLOWER_RED, IslandGenerator.FLOWER_YELLOW:
			model.mesh = _cross()
			model.set_material_override(0, _cutout_material(_plant_image(id)))
		_:
			var piece := piece_of(id)
			if piece >= 0:  # piedrecitas, palitos, concha: modelos de cubitos como en el concepto
				model.mesh = PrefabLibrary.mesh(piece)
				model.set_material_override(0, PrefabLibrary.material())
			else:
				model.mesh = _pieces(id)
				model.set_material_override(0, _color_material(Blocks.color_of(id)))
	model.set_mesh_collision_enabled(0, false)
	model.collision_aabbs = []
	model.culls_neighbors = false
	model.transparency_index = 2
	return model


# ------------------------------------------------------------------ plantas: planos cruzados

static func _cross() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes := [
		[Vector3(0.1, 0, 0.1), Vector3(0.9, 0, 0.9)],
		[Vector3(0.1, 0, 0.9), Vector3(0.9, 0, 0.1)],
	]
	for p in planes:
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var n := (b - a).cross(Vector3.UP).normalized()
		var quad := [a, b, b + Vector3.UP * 0.9, a + Vector3.UP * 0.9]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP * 0.7 + n * 0.3)  # casi hacia arriba: luz suave y pareja
			st.set_uv(uvs[i])
			st.add_vertex(quad[i])
	st.index()  # el motor de bloques quiere mallas indexadas
	return st.commit()


static func _cutout_material(img: Image) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	return material


## Modelos de cubitos de la decoración (prefabs hechos por tools/bake_prefabs.gd).
const PIECES := {
	IslandGenerator.PEBBLES: "decor_pebbles",
	IslandGenerator.GROUND_STICKS: "decor_sticks",
	IslandGenerator.SHELL: "decor_shell",
}


## Id de la pieza de prefab con la forma de esta decoración (o -1).
static func piece_of(id: int) -> int:
	return PrefabLibrary.first_id(PIECES[id]) if PIECES.has(id) else -1


## Dibujos de las plantas (sacados del arte conceptual con tools/extract_concept.gd).
const DRAWN := {
	IslandGenerator.TALL_GRASS: "res://assets/textures/decor/tall_grass.png",
	IslandGenerator.FLOWER_RED: "res://assets/textures/decor/flower_red.png",
	IslandGenerator.FLOWER_YELLOW: "res://assets/textures/decor/flower_yellow.png",
}


static func _plant_image(id: int) -> Image:
	if DRAWN.has(id) and ResourceLoader.exists(DRAWN[id]):
		var drawn := (load(DRAWN[id]) as Texture2D).get_image()
		if drawn.is_compressed():
			drawn.decompress()
		drawn.convert(Image.FORMAT_RGBA8)
		return drawn
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 977
	var green := Color(0.36, 0.6, 0.25)
	# Hojas de hierba: líneas que suben desde abajo, algo torcidas, de distinto alto.
	var blades := 9 if id == IslandGenerator.TALL_GRASS else 4
	for k in blades:
		var x := rng.randf_range(1.0, 14.0)
		var height := rng.randi_range(6, 15) if id == IslandGenerator.TALL_GRASS else rng.randi_range(4, 8)
		var lean := rng.randf_range(-0.25, 0.25)
		var shade := green.darkened(rng.randf_range(0.0, 0.3)).lightened(rng.randf_range(0.0, 0.15))
		for y in height:
			var px := clampi(int(x + lean * y), 0, S - 1)
			img.set_pixel(px, S - 1 - y, shade.lightened(0.012 * y))
	if id != IslandGenerator.TALL_GRASS:
		# Flor: tallo y una corola de 3x3 con el centro distinto.
		var petal := Blocks.color_of(id)
		for y in range(4, 11):
			img.set_pixel(7, S - 1 - y, green.darkened(0.15))
		var cy := S - 1 - 11
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				img.set_pixel(7 + dx, cy + dy, petal.lightened(0.1) if (dx + dy) % 2 == 0 else petal)
		img.set_pixel(7, cy, Color(0.95, 0.85, 0.3) if id == IslandGenerator.FLOWER_RED else Color(0.6, 0.35, 0.15))
	return img


# ------------------------------------------------------------------ piedras, palos, conchas

## Un color por modelo (el motor de bloques no usa los colores de cada vértice).
static func _color_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


static func _pieces(id: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := 1.0 / S  # un píxel
	match id:
		IslandGenerator.PEBBLES:
			var stone := Color(0.55, 0.55, 0.56)
			_box(st, Vector3(3, 0, 4) * p, Vector3(4, 2, 3) * p, stone)
			_box(st, Vector3(9, 0, 8) * p, Vector3(3, 2, 3) * p, stone.darkened(0.15))
			_box(st, Vector3(6, 0, 11) * p, Vector3(2, 1, 2) * p, stone.lightened(0.1))
			_box(st, Vector3(11, 0, 3) * p, Vector3(2, 1, 2) * p, stone.darkened(0.25))
		IslandGenerator.GROUND_STICKS:
			var wood := Color(0.45, 0.32, 0.18)
			_box(st, Vector3(2, 0, 7) * p, Vector3(12, 1, 1) * p, wood)
			_box(st, Vector3(6, 0, 3) * p, Vector3(1, 1, 10) * p, wood.darkened(0.15))
			_box(st, Vector3(9, 1, 6) * p, Vector3(1, 1, 6) * p, wood.lightened(0.1))
		IslandGenerator.SHELL:
			var shell := Color(0.95, 0.86, 0.78)
			_box(st, Vector3(6, 0, 6) * p, Vector3(4, 1, 4) * p, shell)
			_box(st, Vector3(7, 1, 7) * p, Vector3(2, 1, 2) * p, Color(0.92, 0.72, 0.65))
			_box(st, Vector3(10, 0, 11) * p, Vector3(2, 1, 2) * p, Color(0.8, 0.7, 0.85))
	st.index()
	return st.commit()


## Caja de color con su esquina en 'pos' y tamaño 'size' (sin cara de abajo).
static func _box(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	var x0 := pos.x
	var y0 := pos.y
	var z0 := pos.z
	var x1 := pos.x + size.x
	var y1 := pos.y + size.y
	var z1 := pos.z + size.z
	var faces := [
		[Vector3.UP, color, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)]],
		[Vector3.BACK, color.darkened(0.15), [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]],
		[Vector3.FORWARD, color.darkened(0.15), [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)]],
		[Vector3.RIGHT, color.darkened(0.25), [Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1)]],
		[Vector3.LEFT, color.darkened(0.25), [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)]],
	]
	for f in faces:
		var v: Array = f[2]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_color(f[1])
			st.set_normal(f[0])
			st.add_vertex(v[i])
