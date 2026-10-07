extends Node
class_name BlockAim
## Apuntar con el centro de la pantalla: qué bloque, objeto, planta o balsa se mira, por qué
## cara, y el recuadro que lo rodea siguiendo su forma (los trozos de árbol, la mesa, una
## alfombra... no son cubos). Es una parte del jugador (Player.aim) y usa sus piezas internas
## (cámara, terreno...).

var player: Player
var highlight: MeshInstance3D      # el recuadro (líneas oscuras) alrededor de lo que se apunta
var cube_outline: Mesh             # recuadro de un cubo
var _outlines := {}                # id de bloque -> recuadro con la forma de ese bloque


func _ready() -> void:
	highlight = _make_highlight()
	player.add_child(highlight)


## Bloque al que apunta el centro de la pantalla: {"voxel": Vector3i, "place": Vector3i}
## (el bloque golpeado y la celda vacía junto a la cara golpeada), o vacío si no hay ninguno.
func target() -> Dictionary:
	if player._terrain == null:
		return {}
	var from := player._camera.global_position
	var forward := -player._camera.global_transform.basis.z
	var to := from + forward * (Player.REACH + player._spring.spring_length)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # criaturas/bolsas no son voxels
	query.exclude = [player.get_rid()]  # en tercera persona el rayo pasa junto al propio jugador
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		var only_decor := decor_hit(from, forward, Player.REACH + player._spring.spring_length)
		return {} if only_decor.is_empty() else decor_target(only_decor["cell"])
	var hit_point: Vector3 = result.position
	if hit_point.distance_to(player._head.global_position) > Player.REACH:
		return {}  # demasiado lejos de los ojos del personaje
	var hit_normal: Vector3 = result.normal
	# La hierba, flores, piedrecitas... no chocan: se buscan aparte, y gana lo que esté más cerca.
	var decor := decor_hit(from, forward, from.distance_to(hit_point))
	if not decor.is_empty():
		return decor_target(decor["cell"])
	if result.collider is Raft:
		return {"raft": result.collider, "point": hit_point, "normal": hit_normal}
	if result.collider is PlacedItem:
		return {"item": result.collider, "point": hit_point, "normal": hit_normal}
	return {
		"point": hit_point,
		"normal": hit_normal,
		# El bloque golpeado: un pelín hacia dentro del punto de impacto (no medio bloque: con
		# piezas que no llenan su bloque, como un tronco, medio bloque caía en el de detrás).
		"voxel": hit_cell(hit_point, hit_normal),
		"place": hit_cell(hit_point, hit_normal) + Vector3i(hit_normal.round()),  # el hueco de al lado
	}


## Bloque golpeado por el rayo en 'point' (cara con normal 'normal'): un pelín hacia dentro. Si el
## punto cae justo en la frontera entre dos bloques (el borde de una alfombra, de un trozo de
## tronco...) y ese lado está vacío, es el bloque del otro lado.
func hit_cell(point: Vector3, normal: Vector3) -> Vector3i:
	var local := player._terrain.to_local(point - normal * 0.02)
	var cell := Vector3i(local.floor())
	if player._tool == null or player._tool.get_voxel(cell) != IslandGenerator.AIR:
		return cell
	for axis in 3:
		if absf(normal[axis]) > 0.5:
			continue
		var f := local[axis] - floorf(local[axis])
		var other := cell
		if f < 0.02:
			other[axis] -= 1
		elif f > 0.98:
			other[axis] += 1
		else:
			continue
		if player._tool.get_voxel(other) != IslandGenerator.AIR:
			return other
	return cell


func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local := player._terrain.to_local(world_pos)
	return Vector3i(floori(local.x), floori(local.y), floori(local.z))


func _make_highlight() -> MeshInstance3D:
	# Las 12 aristas de un cubo de 1x1x1, en líneas oscuras.
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var lines := PackedVector3Array()
	for edge in edges:
		lines.append(corners[edge[0]])
		lines.append(corners[edge[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.05, 0.05, 0.05)

	var highlight := MeshInstance3D.new()
	highlight.mesh = mesh
	cube_outline = mesh
	highlight.material_override = material
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.top_level = true  # se coloca en coordenadas del mundo, no relativo al jugador
	highlight.visible = false
	return highlight


func update_highlight() -> void:
	var target := target() if player._captured else {}
	if target.is_empty():
		highlight.visible = false
		return
	if target.has("item"):
		# Un objeto dejado en el suelo: recuadro ajustado a su tamaño.
		var item: PlacedItem = target["item"]
		var box := item.get_box()
		highlight.global_transform = Transform3D(item.global_basis * Basis.from_scale(box.size),
			item.global_transform * box.position)
		highlight.visible = true
		return
	if target.has("raft"):
		var boat: Raft = target["raft"]
		highlight.global_transform = Transform3D(boat.global_basis * Basis.from_scale(Vector3(1.6, 0.25, 1.7)), boat.global_position)
		highlight.visible = true
		return
	var cell: Vector3i = target["voxel"]
	var size := player._terrain.scale.x
	var grow := 0.004  # un pelín más grande que el bloque para que no parpadee con sus caras
	# Bloques que no son cubos (piezas de árbol y roca, la mesa, la alfombra, la hierba...): el
	# recuadro sigue su forma.
	highlight.mesh = shape_outline(player._tool.get_voxel(cell)) if player._tool != null else cube_outline
	highlight.global_transform = Transform3D(
		Basis.from_scale(Vector3.ONE * (size + grow * 2.0)),
		player._terrain.to_global(Vector3(cell)) - Vector3.ONE * grow)
	highlight.visible = true


## La decoración no tiene choque (se atraviesa): se busca recorriendo el rayo bloque a bloque.
## Devuelve {"cell", "dist"} de la primera que encuentre antes de max_dist (o de un bloque sólido).
func decor_hit(from: Vector3, dir: Vector3, max_dist: float, want_water := false) -> Dictionary:
	if player._tool == null:
		return {}
	var vs := player._terrain.scale.x
	var p := player._terrain.to_local(from)
	var cell := Vector3i(p.floor())
	var step := Vector3i(int(signf(dir.x)), int(signf(dir.y)), int(signf(dir.z)))
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis in 3:
		if absf(dir[axis]) > 0.000001:
			var boundary := float(cell[axis] + (1 if dir[axis] > 0.0 else 0))
			t_max[axis] = (boundary - p[axis]) / dir[axis]
			t_delta[axis] = absf(1.0 / dir[axis])
	var t := 0.0
	var max_t := minf(max_dist, Player.REACH + player._spring.spring_length) / vs
	while t <= max_t:
		var id := player._tool.get_voxel(cell)
		if want_water:
			if Blocks.is_water(id):
				return {"cell": cell, "dist": t * vs}
		elif Blocks.is_decor(id) and shape_box(id).intersects_ray(p - Vector3(cell), dir) != null:
			# Solo si se apunta a la planta o a la hoja de verdad, no al hueco de su cubo.
			if player._terrain.to_global(Vector3(cell) + Vector3.ONE * 0.5).distance_to(player._head.global_position) <= Player.REACH + 0.3:
				return {"cell": cell, "dist": t * vs}
			return {}
		if id != IslandGenerator.AIR and not Blocks.is_water(id) and not Blocks.is_decor(id):
			return {}
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			t = t_max.x
			t_max.x += t_delta.x
			cell.x += step.x
		elif t_max.y <= t_max.z:
			t = t_max.y
			t_max.y += t_delta.y
			cell.y += step.y
		else:
			t = t_max.z
			t_max.z += t_delta.z
			cell.z += step.z
	return {}


func decor_target(cell: Vector3i) -> Dictionary:
	var center := player._terrain.to_global(Vector3(cell) + Vector3(0.5, 0.0, 0.5))
	# Colocar un bloque apuntando a la hierba la sustituye (como en Minecraft).
	return {"voxel": cell, "place": cell, "point": center, "normal": Vector3.UP, "decor": true}


# ------------------------------------------------------------------ forma de los bloques

## Bloques con modelo de cubitos propio (un prefab de una pieza).
const SHAPED := {IslandGenerator.WORKBENCH: "workbench", IslandGenerator.STUMP: "stump_block",
	IslandGenerator.CHEST: "chest_closed", IslandGenerator.CHEST_OPEN: "chest_open"}


## Caja que ocupa de verdad un bloque dentro de su celda (0..1): la alfombra es fina, la hierba
## no llena el cubo, cada trozo de árbol o roca tiene su tamaño...
static func shape_box(id: int) -> AABB:
	if Blocks.SLABS.has(id):
		return Blocks.SLABS[id]
	if Blocks.THIN.has(id):
		return Blocks.THIN[id]
	if SHAPED.has(id):
		return PrefabLibrary.box(PrefabLibrary.first_id(SHAPED[id]))
	if id == IslandGenerator.CLOTH:
		return AABB(Vector3.ZERO, Vector3(1.0, 1.0 / 16.0, 1.0))
	if id == IslandGenerator.TALL_GRASS:
		return AABB(Vector3(0.12, 0.0, 0.12), Vector3(0.76, 0.9, 0.76))
	if DecorModels.piece_of(id) >= 0:
		return PrefabLibrary.box(DecorModels.piece_of(id))
	if PrefabLibrary.is_prefab(id):
		return PrefabLibrary.box(id)
	return AABB(Vector3.ZERO, Vector3.ONE)


## Recuadro de selección con la forma del bloque (sus aristas de cubitos, o su caja).
func shape_outline(id: int) -> Mesh:
	if _outlines.has(id):
		return _outlines[id]
	var lines := PackedVector3Array()
	var piece := id
	if SHAPED.has(id):
		piece = PrefabLibrary.first_id(SHAPED[id])
	elif DecorModels.piece_of(id) >= 0:
		piece = DecorModels.piece_of(id)
	if PrefabLibrary.is_prefab(piece):
		lines = PrefabLibrary.outline(piece)
	if lines.is_empty():
		var b := shape_box(id)
		if b == AABB(Vector3.ZERO, Vector3.ONE):
			_outlines[id] = cube_outline
			return cube_outline
		var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
		for e in edges:
			for k: int in e:
				lines.append(b.position + b.size * Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_outlines[id] = mesh
	return mesh


