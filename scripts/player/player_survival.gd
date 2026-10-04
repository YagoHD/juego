extends Node
class_name PlayerSurvival
## Lo que el jugador hace para sobrevivir con lo que lleva en la mano: comer, beber (del río o
## de la lluvia), pescar con lanza, coger cangrejos, plantar semillas, y el desgaste de las
## herramientas. Es una parte del jugador (Player.survival).

var player: Player


## Clic derecho con comida en la mano: se come una.
func try_eat() -> bool:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if player.needs == null or stack.is_empty() or not Needs.is_food(stack["id"]):
		return false
	if player.needs.eat(stack["id"]):
		var food_id: String = stack["id"]
		if food_id.begins_with("roasted") or food_id in ["cooked_fish", "flatbread", "cooked_crab"]:
			player.get_tree().call_group("objectives", "mark", "comido_asado")
		if not player.creative:
			player.inventory.take(player._hotbar_index, 1)
		Sfx.play("recoger", null, -2.0, 0.25)
		player.notice.emit("Comes %s." % ItemDB.display_name(stack["id"]).to_lower())
	return true


## Clic derecho con la mano vacía mirando agua dulce (ríos y lagos) cerca: se bebe.
func try_drink() -> bool:
	if player.needs == null or not player.active_inventory().get_slot(player._hotbar_index).is_empty():
		return false
	if player.weather != null and player.weather.is_raining() and player._pitch > 0.6:  # mirando al cielo bajo la lluvia
		if player.needs.drink():
			Sfx.play("paso_agua", null, -2.0, 0.2)
			player.notice.emit("Bebes agua de lluvia.")
		return true
	var from := player._camera.global_position
	var water := player.aim.decor_hit(from, -player._camera.global_transform.basis.z, Player.REACH, true)
	if water.is_empty():
		return false
	if player.needs.drink():
		Sfx.play("paso_agua", null, 0.0, 0.2)
		player.notice.emit("Bebes agua del río. Fresca.")
	return true


## Con la lanza en la mano, clic izquierdo: lanzazo; si hay un pez cerca y delante, se pesca.
func spear_fish() -> bool:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if player.fish == null or stack.is_empty() or stack["id"] != "spear":
		return false
	player._held.swing()
	player._avatar.swing()
	wear_tool()
	Sfx.play("tirar", null, -4.0)
	if player.fish.try_spear(player._camera.global_position, -player._camera.global_transform.basis.z):
		Sfx.play("paso_agua", null, 0.0, 0.2)
		if player.pick_up("raw_fish", 1) > 0:
			ItemDrop.spawn(player.get_parent(), player.global_position + Vector3.UP, "raw_fish", 1)
		player.notice.emit("¡Has pescado un pez!")
		return true
	return false


## Con semillas en la mano, clic derecho sobre la cara de arriba de hierba o tierra: se plantan.
func try_plant(target: Dictionary) -> bool:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if player.farm == null or stack.is_empty() or stack["id"] != "seeds" or not target.has("voxel") or target.has("decor"):
		return false
	var normal: Vector3 = target.get("normal", Vector3.ZERO)
	if normal.y < 0.7 or not Farming.can_plant_on(player._tool.get_voxel(target["voxel"])):
		return false
	if player.farm.plant(target["place"]):
		if not player.creative:
			player.inventory.take(player._hotbar_index, 1)
		Sfx.play("colocar", null, -6.0)
		player.notice.emit("Has plantado trigo. Tardará unos minutos en madurar.")
	return true


## Gasta un uso de la herramienta de la mano (si es de las que se gastan). Al acabarse, se rompe.
func wear_tool() -> void:
	if player.creative:
		return
	var stack := player.inventory.get_slot(player._hotbar_index)
	if stack.is_empty():
		return
	var top := ItemDB.max_durability(stack["id"])
	if top <= 0:
		return
	var left := int(stack.get("dur", top)) - 1
	if left <= 0:
		player.inventory.take(player._hotbar_index, 1)
		Sfx.play("romper_madera", null, 0.0, 0.1)
		player.notice.emit("Se ha roto tu %s." % ItemDB.display_name(stack["id"]).to_lower())
		return
	var worn := stack.duplicate()
	worn["dur"] = left
	player.inventory.set_slot(player._hotbar_index, worn)


## Clic izquierdo con la mano vacía: si hay un cangrejo cerca y delante, se coge.
func grab_crab() -> bool:
	if player.wildlife == null or not player.active_inventory().get_slot(player._hotbar_index).is_empty():
		return false
	if not player.wildlife.try_grab(player._camera.global_position, -player._camera.global_transform.basis.z):
		return false
	player._held.swing()
	player._avatar.swing()
	Sfx.play("recoger", null, 0.0, 0.2)
	if player.pick_up("raw_crab", 1) > 0:
		ItemDrop.spawn(player.get_parent(), player.global_position + Vector3.UP, "raw_crab", 1)
	player.notice.emit("¡Has cogido un cangrejo!")
	return true



