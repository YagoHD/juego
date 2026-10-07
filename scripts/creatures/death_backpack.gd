extends CharacterBody3D
class_name DeathBackpack
## Bolsa persistente sin caducidad. Conserva cada montón y el desgaste; recoger parcialmente
## nunca elimina lo que no cabe. También guarda las prendas que se llevaban puestas.
signal recovered
const LAYER := 16
var contents: Array = []
var equipment: Dictionary = {}
var _label: Label3D

func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.35)
	collider.shape = box
	collider.position.y = 0.25
	add_child(collider)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = box.size
	mesh.mesh = visual
	mesh.position.y = 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.39, 0.12)
	mesh.material_override = material
	add_child(mesh)
	_label = Label3D.new()
	_label.text = "Tu mochila\nClic derecho: recuperar"
	_label.position.y = 0.9
	_label.font_size = 28
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	add_to_group("death_backpacks")

func _physics_process(delta: float) -> void:
	# Fuera de la colisión cargada, congelar la bolsa; nunca caer al vacío por streaming.
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player._terrain != null and global_position.distance_to(player.global_position) > 20.0:
		velocity = Vector3.ZERO
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 64.0, 1)
	if player != null:
		query.exclude = [player.get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		velocity = Vector3.ZERO
		return
	velocity.y = maxf(velocity.y - 18.0 * delta, -20.0)
	move_and_slide()

## Recupera equipo primero para devolver los huecos. Respeta equipo nuevo ya puesto.
func recover(player: Player) -> bool:
	for slot in equipment.keys():
		var id := str(equipment[slot])
		if id == "":
			equipment.erase(slot)
		elif str(player.equipment.get(slot, "")) == "" and player.equip(slot, id):
			equipment.erase(slot)
		else:
			contents.append({"id": id, "count": 1})
			equipment.erase(slot)
	for stack in contents.duplicate():
		if not stack is Dictionary or stack.is_empty():
			contents.erase(stack)
			continue
		var left := transfer_stack(player.inventory, stack, player.unlocked_slots())
		if left == 0:
			contents.erase(stack)
		else:
			stack["count"] = left
	var empty := contents.is_empty() and equipment.is_empty()
	player.notice.emit("Has recuperado tu mochila." if empty else "No cabe todo: el resto sigue en la mochila.")
	recovered.emit()
	if empty:
		queue_free()
	return empty

## A diferencia de Inventory.add, conserva 'dur' y cualquier metadata del montón.
static func transfer_stack(inventory: Inventory, stack: Dictionary, allowed: Array) -> int:
	var left := int(stack["count"])
	var limit := ItemDB.max_stack(str(stack["id"]))
	for index in allowed:
		var old := inventory.get_slot(index)
		var old_metadata := old.duplicate(true)
		var new_metadata := stack.duplicate(true)
		old_metadata.erase("count")
		new_metadata.erase("count")
		var same: bool = not old.is_empty() and old_metadata == new_metadata
		if same:
			var added := mini(left, limit - int(old["count"]))
			if added > 0:
				var merged := old.duplicate(true)
				merged["count"] = int(old["count"]) + added
				inventory.set_slot(index, merged)
				left -= added
	for index in allowed:
		if left <= 0:
			break
		if inventory.is_empty_slot(index):
			var added := mini(left, limit)
			var restored := stack.duplicate(true)
			restored["count"] = added
			inventory.set_slot(index, restored)
			left -= added
	return left

func to_data() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z], "contents": contents.duplicate(true), "equipment": equipment.duplicate(true)}

static func restore(parent: Node, data: Dictionary) -> DeathBackpack:
	var bag := DeathBackpack.new()
	for stack in data.get("contents", []):
		if stack is Dictionary and ItemDB.exists(str(stack.get("id", ""))) and int(stack.get("count", 0)) > 0:
			bag.contents.append(stack.duplicate(true))
	for slot in data.get("equipment", {}):
		var id := str(data["equipment"][slot])
		if ItemDB.wear_slot(id) == slot:
			bag.equipment[slot] = id
	var p: Array = data.get("position", [0, 1, 0])
	bag.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	parent.add_child(bag)
	return bag
