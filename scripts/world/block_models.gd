class_name BlockModels
## Los modelos de todos los bloques para el motor de bloques: cubos con las texturas del atlas
## (con relieve), la alfombra, el agua (quieta, que cae y que corre), medias losas, velas y
## cuerdas, la mesa y el cofre de cubitos, la decoración del suelo y las piezas de los prefabs.


## La biblioteca de modelos, un modelo por id de bloque (en orden: el id es la posición).
static func build_library(generator: IslandGenerator) -> VoxelBlockyLibrary:
	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())  # 0 AIR
	# Todos los bloques comparten un material con el atlas de texturas (se dibujan más rápido);
	# el agua lleva el suyo.
	var solid := BlockTextures.make_terrain_material()  # con relieve, como en el arte conceptual
	var water := _make_water_material(generator)
	for id in range(1, Blocks.LAST_ID + 1):
		if id == IslandGenerator.WATER_FALL:
			library.add_model(_make_flow(1.0, water))
		elif id >= IslandGenerator.WATER_FLOW_1 and id <= IslandGenerator.WATER_FLOW_1 + 6:
			library.add_model(_make_flow(WaterFlow.level_of(id) / 8.0, water))
		elif id == IslandGenerator.WATER:
			library.add_model(_make_water(water))
		elif Blocks.SLABS.has(id):
			library.add_model(_make_partial(id, Blocks.SLABS[id], solid, true))
		elif Blocks.THIN.has(id):
			library.add_model(_make_partial(id, Blocks.THIN[id], solid, false))
		elif id == IslandGenerator.CHEST or id == IslandGenerator.CHEST_OPEN:  # cofre de cubitos (como el del concepto)
			library.add_model(PrefabLibrary.make_model(PrefabLibrary.first_id(BlockAim.SHAPED[id])))
		elif id == IslandGenerator.STUMP:
			library.add_model(PrefabLibrary.make_model(PrefabLibrary.first_id("stump_block")))
		elif id == IslandGenerator.WORKBENCH:
			library.add_model(_make_bench())
		elif id == IslandGenerator.CLOTH:
			library.add_model(_make_carpet(id, solid))
		elif id == IslandGenerator.ORE:
			library.add_model(_make_cube(id, solid))  # el mineral brilla (lo hace el material de los bloques)
		elif Blocks.is_decor(id):
			library.add_model(DecorModels.make_model(id))  # hierba, flores, piedrecitas...
		else:
			library.add_model(_make_cube(id, solid))
	# Huecos hasta los prefabs (ids libres para bloques futuros) y las piezas de los prefabs.
	for id in range(Blocks.LAST_ID + 1, PrefabLibrary.FIRST_ID):
		library.add_model(VoxelBlockyModelEmpty.new())
	for id in range(PrefabLibrary.FIRST_ID, PrefabLibrary.last_id() + 1):
		library.add_model(PrefabLibrary.make_model(id))  # palmeras, rocas... troceadas
	library.bake()
	return library


static func _make_cube(id: int, material: Material) -> VoxelBlockyModelCube:
	# Cubo con las texturas del atlas: arriba, lados y abajo según BlockTextures.FACES.
	var cube := VoxelBlockyModelCube.new()
	cube.atlas_size_in_tiles = BlockTextures.atlas_size_in_tiles()
	var sides := {
		VoxelBlockyModel.SIDE_POSITIVE_Y: Vector3i.UP, VoxelBlockyModel.SIDE_NEGATIVE_Y: Vector3i.DOWN,
		VoxelBlockyModel.SIDE_POSITIVE_X: Vector3i.RIGHT, VoxelBlockyModel.SIDE_NEGATIVE_X: Vector3i.LEFT,
		VoxelBlockyModel.SIDE_POSITIVE_Z: Vector3i.BACK, VoxelBlockyModel.SIDE_NEGATIVE_Z: Vector3i.FORWARD,
	}
	for side: int in sides:
		cube.set_tile(side, BlockTextures.side_tile(id, sides[side]))
	cube.set_material_override(0, material)
	return cube


static func _make_carpet(id: int, material: Material) -> VoxelBlockyModelCube:
	# Capa fina tumbada en el suelo (como la alfombra de Minecraft): 1/16 de bloque de alto.
	# No tapa las caras de los bloques vecinos (si no, el suelo de debajo se vería hueco).
	var cube := _make_cube(id, material)
	cube.height = 1.0 / 16.0
	cube.culls_neighbors = false
	return cube


## Material del agua (ríos, lagos y la que corre): color liso con ondas que siguen la corriente.
static func _make_water_material(generator: IslandGenerator) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/water.gdshader")
	mat.set_shader_parameter("flow_map", ImageTexture.create_from_image(generator.build_flow()))
	mat.set_shader_parameter("map_half", IslandGenerator.MAP_HALF)
	mat.set_shader_parameter("voxel_size", Main.VOXEL_SIZE)
	mat.set_shader_parameter("water_color", Color(0.13, 0.6, 0.72, 0.74))  # turquesa, como en el concepto
	mat.set_shader_parameter("foam_color", Color(0.78, 0.96, 0.97))
	return mat


## Agua que corre: una caja de la altura de su nivel (1 = bloque entero, la que cae).
static func _make_flow(height: float, material: Material) -> VoxelBlockyModelMesh:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, height, 1.0)
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0.5, height * 0.5, 0.5)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var model := VoxelBlockyModelMesh.new()
	model.mesh = mesh
	model.set_material_override(0, material)
	model.transparency_index = 1  # como el agua quieta: no se dibujan las caras entre aguas
	model.culls_neighbors = true
	model.set_mesh_collision_enabled(0, false)
	model.collision_aabbs = []
	return model


static func _make_water(material: Material) -> VoxelBlockyModelCube:
	# Agua de ríos y lagos: translúcida, sin caras internas y atravesable.
	var cube := _make_cube(IslandGenerator.WATER, material)
	cube.transparency_index = 1
	cube.set_mesh_collision_enabled(0, false)
	return cube


## Mesa de trabajo: el modelo de cubitos del arte conceptual (tools/bake_prefabs.gd), que choca
## como un bloque entero (el martillo y el trapo que sobresalen no estorban).
static func _make_bench() -> VoxelBlockyModelMesh:
	var model := PrefabLibrary.make_model(PrefabLibrary.first_id("workbench"))
	model.collision_aabbs = [AABB(Vector3.ZERO, Vector3.ONE)]
	return model


## Bloque que solo ocupa una parte de su hueco (media losa, vela, cuerda): una caja con las
## texturas del bloque, que choca solo donde está.
static func _make_partial(id: int, box: AABB, material: Material, culls: bool) -> VoxelBlockyModelMesh:
	var model := VoxelBlockyModelMesh.new()
	model.mesh = BlockTextures.make_box_mesh(id, box)
	model.set_material_override(0, material)
	model.collision_aabbs = [box]
	model.culls_neighbors = culls  # las losas tapan la cara del vecino que cubren entera
	return model
