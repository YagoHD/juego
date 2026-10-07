extends Node3D
## Flecha del jugador: barrido físico y daño calculado con posición de lanzamiento.
var source: Player
var launch_origin := Vector3.ZERO
var velocity := Vector3.ZERO
var base_damage := 22.0
var stealth := false
var lifetime := 4.0

static func damage_multiplier(distance: float, height_advantage: float, sneak: bool, unaware: bool) -> float:
	var range_bonus := 1.0 + clampf(distance / 50.0, 0.0, 0.6)
	var height_bonus := 1.0 + clampf(height_advantage * 0.06, 0.0, 0.5)
	return range_bonus * height_bonus * (1.5 if sneak and unaware else 1.0)

func _ready() -> void:
	add_to_group("player_arrows")
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.45)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.5, 0.2)
	visual.material_override = material
	add_child(visual)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(source):
		queue_free()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | CreatureActor.LAYER)
	query.exclude = [source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var victim := hit["collider"] as CreatureActor
		if victim != null:
			var unaware := victim.alert_seconds <= 0.0 and victim.state not in ["chase", "windup", "charge", "recover"]
			var multiplier := damage_multiplier(launch_origin.distance_to(hit["position"]), launch_origin.y - victim.eye_position().y, stealth, unaware)
			victim.take_damage(base_damage * multiplier, source)
		queue_free()
		return
	global_position = next
	# look_at falla si la flecha va justo en vertical (dirección paralela a "arriba").
	if velocity.length_squared() > 0.0 and absf(velocity.normalized().y) < 0.999:
		look_at(global_position + velocity)
