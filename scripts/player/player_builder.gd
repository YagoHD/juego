extends Node
class_name PlayerBuilder
## Colocar cosas: objetos dejados en el suelo (antorchas, hogueras, sacos... en el punto exacto,
## apilables), recogerlos, la silueta transparente de dónde caería la antorcha, la forma de los
## bloques según dónde se pongan (medias losas, velas) y colgar cuerdas. Es una parte del
## jugador (Player.builder).

var player: Player
var _place_ghost: MeshInstance3D   # dónde caería el objeto de la mano al dejarlo
var _place_ghost_id := ""


func _ready() -> void:
	_place_ghost = MeshInstance3D.new()
	_place_ghost.top_level = true
	_place_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_place_ghost.visible = false
	player.add_child(_place_ghost)


## Clic derecho con una antorcha o una hoguera en la mano: se pone en el suelo, donde se apunta.
func place_torch(target: Dictionary) -> void:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if not stack.is_empty() and (stack["id"] in ["torch", "campfire", "bedroll"]):
		place_on_ground(target)


## Deja en el suelo uno del objeto de la mano, donde se apunta (sobre la cara de arriba de un
## bloque, o junto a otro objeto ya dejado). Queda en ese punto exacto, girado al azar.
func place_on_ground(target: Dictionary) -> bool:
	if player.ground == null or target.is_empty():
		return false
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if stack.is_empty():
		return false
	var point: Vector3 = target["point"]
	var support: Vector3i
	var yaw := player.rotation.y + randf_range(-0.6, 0.6)
	if target.has("item"):
		var other: PlacedItem = target["item"]
		var normal_up: Vector3 = target["normal"]
		if normal_up.y > 0.7:
			# Apuntando a la cara de arriba de un objeto: se apila encima (fabricar en vertical).
			if player.ground.stack_on(other, stack["id"], yaw) == null:
				player.notice.emit("No se puede apilar más alto.")
				return false
			Sfx.play("colocar", other.global_position, -8.0)
			if not player.creative:
				player.inventory.take(player._hotbar_index, 1)
			return true
		point.y = other.base_y  # apuntando a un lado: al suelo, junto a él
		support = other.support
	else:
		var normal: Vector3 = target["normal"]
		if normal.y < 0.7:
			return false  # solo sobre superficies horizontales
		support = target["voxel"]
	player.ground.place(point, stack["id"], yaw, support)
	Sfx.play("colocar", point, -8.0)
	if not player.creative:
		player.inventory.take(player._hotbar_index, 1)
	return true


## Recoge un objeto del suelo; con Mayúsculas, todo el montón que se toca con él.
func pick_up_placed(item: PlacedItem, whole_group := false) -> void:
	var items: Array[PlacedItem] = [item]
	if whole_group:
		items = player.ground.group_of(item)
	# De arriba abajo, para que no se "caigan" los de encima mientras se recogen.
	items.sort_custom(func(a: PlacedItem, b: PlacedItem) -> bool: return a.level > b.level)
	for it in items:
		if it.item_id == "captain_journal":
			player.ground.remove(it)
			player.find_journal()
			continue
		if not player.creative and not player.can_pick_up(it.item_id):
			player.notice.emit("No te cabe todo.")
			return
		var id := player.ground.remove(it)
		if not player.creative:
			player.pick_up(id, 1)
	Sfx.play("recoger", null, -6.0, 0.15)


## Con una antorcha en la mano, apuntando al suelo (o encima de otro objeto):
## se ve en transparente dónde quedaría al clavarla con clic derecho.
func update_place_ghost() -> void:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	var id: String = "" if stack.is_empty() else stack["id"]
	var target := player.aim.target() if player._captured and not player.ui_open and id == "torch" else {}
	var normal: Vector3 = target.get("normal", Vector3.ZERO)
	if target.is_empty() or normal.y < 0.7:
		_place_ghost.visible = false
		return
	if id != _place_ghost_id:
		_place_ghost_id = id
		_place_ghost.mesh = ItemMesh.make(id, 0.3)
		var material := ItemMesh.make_material(id)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 1, 1, 0.45)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_place_ghost.material_override = material
	var pos: Vector3 = target["point"]
	if target.has("item"):
		var other: PlacedItem = player.ground._top_of(target["item"]) if player.ground != null else target["item"]
		pos = other.global_position + Vector3.UP * other.height()
	_place_ghost.global_transform = Transform3D(Basis(Vector3.UP, player.rotation.y) * Basis(Vector3.RIGHT, -PI / 2.0),
		pos + Vector3.UP * 0.012)
	_place_ghost.visible = true


## La forma del bloque según dónde se coloca: la media losa, abajo si se pone encima de algo,
## arriba si se pone debajo, y de pie pegada a la cara de al lado si se pone en un lateral; la
## tela, tendida en el suelo o de pie como una vela si se pone en un lateral.
func shaped_block(id: int, target: Dictionary) -> int:
	var normal: Vector3 = target.get("normal", Vector3.UP)
	if Blocks.SLABS.has(id):
		if normal.y > 0.7:
			return IslandGenerator.SLAB_DOWN
		if normal.y < -0.7:
			return IslandGenerator.SLAB_UP
		if absf(normal.x) > absf(normal.z):
			return IslandGenerator.SLAB_W if normal.x > 0.0 else IslandGenerator.SLAB_E
		return IslandGenerator.SLAB_N if normal.z > 0.0 else IslandGenerator.SLAB_S
	if id == IslandGenerator.CLOTH and absf(normal.y) < 0.7:
		return IslandGenerator.SAIL_X if absf(normal.x) > absf(normal.z) else IslandGenerator.SAIL_Z
	return id


## Con una cuerda en la mano, clic derecho debajo de un bloque (o sobre una cuerda que cuelga):
## la cuerda queda colgando (alarga la que ya hay). Devuelve true si se colgó.
func hang_rope(target: Dictionary) -> bool:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if stack.is_empty() or stack["id"] != "rope" or not target.has("voxel"):
		return false
	var cell: Vector3i = target["voxel"]
	var normal: Vector3 = target["normal"]
	if player._tool.get_voxel(cell) == IslandGenerator.ROPE_HANGING:
		while player._tool.get_voxel(cell + Vector3i.DOWN) == IslandGenerator.ROPE_HANGING:
			cell += Vector3i.DOWN
	elif normal.y > -0.7:
		return false  # se cuelga de la cara de abajo de algo
	var spot := cell + Vector3i.DOWN
	if player._tool.get_voxel(spot) != IslandGenerator.AIR:
		return false
	player._tool.set_voxel(spot, IslandGenerator.ROPE_HANGING)
	Sfx.play("colocar", player._terrain.to_global(Vector3(spot)) + Vector3.ONE * player._terrain.scale.x * 0.5, -6.0)
	if not player.creative:
		player.inventory.take(player._hotbar_index, 1)
	return true

