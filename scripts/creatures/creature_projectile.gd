extends Node3D
class_name CreatureProjectile
## Proyectil con barrido de colisión por segmento: no atraviesa paredes aunque vaya rápido.
var source: CreatureActor
var velocity := Vector3.ZERO
var damage := 10.0
var lifetime := 4.0
var kind := "bolt"

static func launch(parent: Node, caster: CreatureActor, from: Vector3, to: Vector3, amount: float, projectile_kind := "bolt") -> CreatureProjectile:
	var bolt := CreatureProjectile.new()
	bolt.source = caster
	bolt.position = from
	bolt.velocity = (to - from).normalized() * 8.0
	bolt.damage = amount
	bolt.kind = projectile_kind
	if projectile_kind in ["arrow", "enchanted_arrow"]:
		bolt.velocity *= 2.0
	parent.add_child(bolt)
	bolt.global_position = from
	return bolt

func _ready() -> void:
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	visual.mesh = sphere
	if kind in ["arrow", "enchanted_arrow"]:
		var arrow := BoxMesh.new()
		arrow.size = Vector3(0.05, 0.05, 0.5)
		visual.mesh = arrow
		if velocity.length_squared() > 0.0:
			visual.rotation.y = atan2(-velocity.x, -velocity.z)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.28, 1.0)
	if kind == "electric_orb":
		material.albedo_color = Color(0.25, 0.75, 1.0)
	if kind == "arrow":
		material.albedo_color = Color(0.8, 0.65, 0.35)
	visual.material_override = material
	add_child(visual)
	add_to_group("creature_projectiles")

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | CreatureActor.LAYER)
	if is_instance_valid(source):
		query.exclude = [source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var victim: Node = hit["collider"]
		if victim is Player:
			(victim as Player).combat.take_damage(damage, global_position, 0.0, source)
		elif victim is CreatureActor and not (victim as CreatureActor).stats["enemy"]:
			(victim as CreatureActor).take_damage(damage, source)
		queue_free()
		return
	global_position = next
