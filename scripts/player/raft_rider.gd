extends Node
class_name RaftRider
## La balsa del jugador: echarla al agua, subirse, remar (W/S) y girar (A/D), bajarse (Espacio,
## a tierra si hay cerca) y recogerla. Es una parte del jugador (Player.rafts).

var player: Player


## Con la balsa en la mano, clic derecho apuntando al mar: se echa al agua.
func launch() -> bool:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	if stack.is_empty() or stack["id"] != "raft":
		return false
	var water := player.aim.decor_hit(player._camera.global_position, -player._camera.global_transform.basis.z, Player.REACH, true)
	if water.is_empty():
		player.notice.emit("La balsa se echa al agua del mar: apunta al agua.")
		return true
	var cell: Vector3i = water["cell"]
	var boat := Raft.new()
	boat.generator = player._generator
	boat.voxel_size = player._terrain.scale.x
	var spot := player._terrain.to_global(Vector3(cell) + Vector3(0.5, 0.0, 0.5))
	if not boat.is_water(spot):
		boat.free()
		player.notice.emit("Aquí no flota: hace falta el mar, con algo de fondo.")
		return true
	player.get_parent().add_child(boat)
	boat.add_to_group("rafts")
	boat.global_position = Vector3(spot.x, boat.sea_y(), spot.z)
	boat.rotation.y = player.rotation.y
	if not player.creative:
		player.inventory.take(player._hotbar_index, 1)
	Sfx.play("paso_agua", spot, 0.0, 0.2)
	player.notice.emit("Balsa al agua. Clic derecho sobre ella para subir.")
	return true


## Clic izquierdo sobre la balsa (sin ir montado): se recoge.
func pick_up_boat(boat: Raft) -> void:
	if player.raft == boat:
		return
	if not player.creative and not player.can_pick_up("raft"):
		player.notice.emit("No te cabe la balsa.")
		return
	boat.queue_free()
	if not player.creative:
		player.pick_up("raft", 1)
	Sfx.play("recoger", null, -6.0, 0.15)


func board(boat: Raft) -> void:
	player.raft = boat
	player._flying = false
	player._sprinting = false
	player.velocity = Vector3.ZERO
	player.notice.emit("W/S: remar  ·  A/D: girar  ·  Espacio: bajar")


## Montado: W/S reman, A/D giran la balsa (y la vista con ella). No entra en tierra.
func ride(delta: float) -> void:
	if not is_instance_valid(player.raft):
		player.raft = null
		return
	var forward := (1.0 if player._key(KEY_W) else 0.0) - (1.0 if player._key(KEY_S) else 0.0)
	var turn := (1.0 if player._key(KEY_A) else 0.0) - (1.0 if player._key(KEY_D) else 0.0)
	var yaw_before := player.raft.rotation.y
	player.raft.steer(forward, turn, delta)
	player.rotate_y(player.raft.rotation.y - yaw_before)
	player.velocity = Vector3.ZERO
	player.global_position = player.raft.global_position + Vector3.UP * 0.1
	player._avatar.update_walk(0.0, true, delta)
	player._held.update_walk(0.0, delta)
	if absf(forward) > 0.01:
		player._step_distance += delta
		if player._step_distance > 0.9:
			player._step_distance = 0.0
			Sfx.play("paso_agua", player.raft.global_position, -6.0, 0.2)


## Espacio: bajar. Si hay tierra al lado se baja a ella; si no, al agua.
func dismount() -> void:
	var boat := player.raft
	player.raft = null
	if not is_instance_valid(boat):
		return
	var vs := player._terrain.scale.x
	for k in 16:
		var a := TAU * k / 16.0
		for dist in [1.4, 2.2]:
			var p := boat.global_position + Vector3(cos(a), 0, sin(a)) * float(dist)
			var h := player._generator.get_ground_height(int(floorf(p.x / vs)), int(floorf(p.z / vs)))
			if h > IslandGenerator.SEA_LEVEL:
				player.global_position = Vector3(p.x, h * vs + 0.05, p.z)
				return
	player.global_position = boat.global_position + Vector3(1.2, 0.3, 0).rotated(Vector3.UP, player.rotation.y)

