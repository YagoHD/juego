extends CharacterBody3D
class_name CreatureActor
## IA reutilizable sin depender del modelo: patrulla, percepción con obstáculos, persecución,
## retirada, ataque anunciado y recuperación. Las señales permiten añadir animaciones después.
signal state_changed(state: String)
signal attack_started(kind: String, seconds: float)
signal damaged(amount: float)
signal died(actor: CreatureActor)

const LAYER := 1 << 5  # capa propia (la 8 es la de los troncos que caen, ver TreeFelling)
const NavigationScript = preload("res://scripts/creatures/creature_navigation.gd")
var navigator = NavigationScript.new()
const PREY := ["pig", "deer", "rabbit", "hen"]
var species := "tracker"
var stats: Dictionary = {}
var health := 0.0
var state := "idle"
var home := Vector3.ZERO
var player: Player
var hour := 12.0
var target: Node3D
var dead := false
var drop_loot := true
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _material: StandardMaterial3D
var _label: Label3D
var _destination := Vector3.ZERO
var _decision := 0.0
var _timer := 0.0
var _cooldown := 0.0
var _aggro := 0.0
var _last_seen := Vector3.ZERO
var _attack_point := Vector3.ZERO
var _attack_direction := Vector3.FORWARD
var _combo_left := 0
var _attack_count := 0
var _attack_kind := "melee"
var _knockback := Vector3.ZERO
var _flash := 0.0
var _charge_hit := false
var _telegraph: MeshInstance3D
var alert_seconds := 0.0
var _alert_cooldown := 0.0
var _search_seconds := 0.0
var _search_step := 0.0
var squad: Node
var squad_slot := 0
var team_damage := 1.0
var team_shield := 0.0
var team_role := ""
var enchanted_arrow := false
var _beam_visual: MeshInstance3D
var _beam_direction := Vector3.FORWARD
var _beam_link_seconds := 0.0
var _beam_tick := 0.65
## Sondeos del suelo y las paredes de delante: se repiten unas 8 veces por segundo, no en cada paso
## de física (con muchos personajes era lo que más gastaba). Entre sondeo y sondeo se usa el último.
const PROBE_SECONDS := 0.12
var _probe_left := 0.0
var _probe_stop := false   # el último sondeo vio un precipicio (o suelo sin cargar) delante
var _probe_turn := 0.0     # giro para rodear la pared que vio el último sondeo (0 = recto)

func _ready() -> void:
	stats = CreatureDB.profile(species)
	assert(not stats.is_empty(), "Especie desconocida: " + species)
	health = float(stats["hp"])
	_rng.randomize()
	home = global_position
	_destination = home
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(stats["radius"])
	capsule.height = maxf(float(stats["height"]), capsule.radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_build_placeholder(capsule.height)
	add_to_group("creatures")
	_set_state("patrol" if stats["enemy"] else "idle")
	_timer = _rng.randf_range(1.0, 3.0)

func _build_placeholder(height: float) -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"  # Sustituir este nodo por el modelo final.
	add_child(_visual)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = float(stats["radius"])
	sphere.height = height
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	_material = StandardMaterial3D.new()
	_material.albedo_color = stats["color"]
	mesh.material_override = _material
	mesh.position.y = height * 0.5
	_visual.add_child(mesh)
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.10, 0.10, float(stats["radius"]) + 0.15)
	nose.mesh = box
	nose.position = Vector3(0, height * 0.65, -float(stats["radius"]))
	nose.material_override = _material
	_visual.add_child(nose)
	_label = Label3D.new()
	_label.position.y = height + 0.35
	_label.font_size = 26
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_update_label()

func _set_state(next: String) -> void:
	if state != next:
		state = next
		state_changed.emit(state)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if is_instance_valid(player) and not player.is_on_ground_ready():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_aggro = maxf(0.0, _aggro - delta)
	_flash = maxf(0.0, _flash - delta)
	alert_seconds = maxf(0.0, alert_seconds - delta)
	_alert_cooldown = maxf(0.0, _alert_cooldown - delta)
	_timer -= delta
	_decision -= delta
	if _decision <= 0.0:
		_decision = 0.2  # percepción a 5 Hz, movimiento en cada paso de física
		_choose_target()
	var direction := Vector3.ZERO
	var speed := float(stats["speed"])
	match state:
		"channel":
			_tick_beam(delta)
		"stunned":
			if _timer <= 0.0:
				_set_state("chase" if _target_valid() else "search")
		"search":
			_search_seconds -= delta
			_search_step -= delta
			direction = _destination - global_position
			if _search_seconds <= 0.0:
				_set_state("return")
			elif direction.length() < 0.8 or _search_step <= 0.0:
				var angle := _rng.randf() * TAU
				_destination = _last_seen + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.0, 4.0)
				_search_step = 3.0
		"windup":
			if _timer <= 0.0:
				_execute_attack()
		"charge":
			direction = _attack_direction
			speed *= 3.0
			if not _charge_hit and _target_valid() and global_position.distance_to(target.global_position) < float(stats["range"]) + 0.4 and can_see(target):
				_hit_target(target)
				_charge_hit = true
			if _timer <= 0.0 or is_on_wall():
				_begin_recovery()
		"recover":
			if _timer <= 0.0:
				if _combo_left > 0 and _target_valid():
					_combo_left -= 1
					_begin_attack(true)
				else:
					_set_state("chase" if _target_valid() else "return")
		"stagger":
			if _timer <= 0.0:
				_set_state("chase" if _target_valid() else "flee")
		"chase":
			if _target_valid():
				var offset := target.global_position - global_position
				var distance := offset.length()
				if distance <= float(stats["range"]) and can_see(target) and _cooldown <= 0.0 and (not is_instance_valid(squad) or squad.request_attack(self)):
					_begin_attack()
				elif stats["attack"] in ["bolt", "arrow"] and distance < 5.0:
					direction = -offset
				elif stats["attack"] in ["bolt", "arrow"] and distance <= (12.0 if species == "archer" else 9.0):
					direction = Vector3.ZERO
				else:
					direction = offset
					if is_instance_valid(squad) and distance > 2.5 and species in ["tracker", "soldier", "captain"]:
						var side := Vector3(-offset.z, 0, offset.x).normalized()
						direction += side * (2.0 if squad_slot % 2 == 0 else -2.0)
				_face(offset, delta)
			else:
				_set_state("return")
		"flee":
			var threat := _last_seen
			if _target_valid():
				threat = target.global_position
			direction = global_position - threat
			speed *= 2.3
			if _aggro <= 0.0 and direction.length() > 8.0:
				target = null
				_set_state("return")
		"return":
			direction = (squad.destination(self) if is_instance_valid(squad) else home) - global_position
			if direction.length() < 0.9:
				target = null
				_set_state("idle")
				_timer = 2.0
		"patrol", "roam":
			if is_instance_valid(squad):
				_destination = squad.destination(self)
				_timer = 8.0
			direction = _destination - global_position
			if is_instance_valid(squad) and squad.rest_seconds > 0.0:
				direction = Vector3.ZERO
			if direction.length() < 0.8 or _timer <= 0.0:
				_set_state("idle")
				_timer = _rng.randf_range(1.0, 3.0)
		"perch":
			direction = _destination - global_position
			if direction.length() < 0.15:
				_set_state("rest" if (hour < 6.0 or hour >= 20.0) else "feed")
				_timer = 4.0
		"idle", "feed", "rest":
			if _timer <= 0.0:
				_choose_routine()
	if not stats["flying"]:
		direction.y = 0.0
	_move(direction, speed, delta)
	_material.albedo_color = Color(1.0, 0.35, 0.15) if state == "windup" else (Color.WHITE if _flash > 0.0 else stats["color"])
	_update_label()

func _target_valid() -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target is CreatureActor:
		return not (target as CreatureActor).dead
	if target is Player:
		return not (target as Player).creative and (target as Player).combat.health > 0.0
	return false

func can_see(other: Node3D) -> bool:
	if not is_instance_valid(other):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye_position(), _target_center(other), 1 | LAYER)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == other

func eye_position() -> Vector3:
	return global_position + Vector3.UP * float(stats["height"]) * 0.7

func _target_center(other: Node3D) -> Vector3:
	if other is CreatureActor:
		return (other as CreatureActor).eye_position()
	if other is Player:
		return (other as Player).eye_position()
	return other.global_position

func _choose_target() -> void:
	if stats["enemy"]:
		_choose_enemy_target()
		return
	if state in ["windup", "charge", "recover", "stagger"]:
		return
	if _target_valid():
		var too_far := global_position.distance_to(home) > float(stats["leash"])
		if too_far or (_aggro <= 0.0 and not can_see(target)):
			target = null
			_set_state("return")
			return
		_last_seen = target.global_position
		return
	target = null
	if state == "return":
		return
	if stats["temper"] in ["predator", "hunter"]:
		for node in get_tree().get_nodes_in_group("creatures"):
			var prey := node as CreatureActor
			if prey != self and not prey.dead and PREY.has(prey.species) and global_position.distance_to(prey.global_position) < float(stats["sense"]) and can_see(prey):
				target = prey
				_aggro = 8.0
				_set_state("chase")
				return
	if not is_instance_valid(player) or player.creative or player.combat.health <= 0.0 or player.combat.invulnerable > 1.0:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance > float(stats["sense"]) or not can_see(player):
		return
	_last_seen = player.global_position
	if stats["enemy"] or stats["temper"] in ["territorial", "predator"]:
		target = player
		_aggro = 5.0
		_set_state("chase")
	elif stats["temper"] in ["timid", "shy"] and distance < (4.5 if stats["temper"] == "timid" else 2.5):
		target = player
		_aggro = 2.0
		_set_state("flee")

func detects_player() -> bool:
	if not is_instance_valid(player) or player.creative or player.combat.health <= 0.0 or player.combat.invulnerable > 1.0:
		return false
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var sense := float(stats["sense"]) * (1.35 if alert_seconds > 0.0 else 1.0)
	if player.is_sneaking():
		sense *= 0.45 * player.skills.bonus("stealth", -0.04) * (1.0 - player.gear_effect("sneak"))
	if distance > sense or not can_see(player):
		return false
	var facing := -global_basis.z
	facing.y = 0.0
	var threshold := 0.17 if alert_seconds > 0.0 else 0.5
	# El ruido de caminar/correr delata a corta distancia; agachado no.
	return facing.normalized().dot(offset.normalized()) >= threshold or (not player.is_sneaking() and distance < (6.0 if player._sprinting else 3.0))

func _choose_enemy_target() -> void:
	var anchor: Vector3 = squad.destination(self) if is_instance_valid(squad) else home
	if global_position.distance_to(anchor) > float(stats["leash"]):
		if state not in ["windup", "charge", "channel", "recover", "stunned", "stagger"]:
			target = null
			_set_state("return")
		return
	if detects_player():
		target = player
		_last_seen = player.global_position
		alert_seconds = 60.0
		_aggro = 10.0
		if _alert_cooldown <= 0.0:
			_broadcast_alert()
		if state not in ["windup", "charge", "channel", "recover", "stunned", "stagger"]:
			_set_state("chase")
	elif _target_valid() and state not in ["windup", "charge", "channel", "recover", "stunned", "stagger"]:
		_start_search(_last_seen)
	elif not _target_valid() and state == "chase":
		_start_search(_last_seen)

func _start_search(point: Vector3) -> void:
	target = null
	_last_seen = point
	_destination = point
	_search_seconds = 12.0
	_search_step = 5.0
	_set_state("search")

func _broadcast_alert() -> void:
	_alert_cooldown = 10.0
	for node in get_tree().get_nodes_in_group("creatures"):
		var ally := node as CreatureActor
		if ally == self or ally.dead or not ally.stats["enemy"] or global_position.distance_to(ally.global_position) > 10.0:
			continue
		ally.alert_seconds = 60.0
		# Comparte el último lugar conocido, no la posición actual tras una pared.
		if ally.state not in ["chase", "windup", "charge", "channel", "recover", "stunned", "stagger", "search"]:
			ally._start_search(_last_seen)

func can_backstab(attacker: Player) -> bool:
	if dead or not stats["enemy"] or not attacker.is_sneaking() or alert_seconds > 0.0:
		return false
	if state in ["chase", "windup", "charge", "recover", "stunned", "stagger"]:
		return false
	var offset := attacker.global_position - global_position
	offset.y = 0.0
	return global_basis.z.normalized().dot(offset.normalized()) >= 0.5 and can_see(attacker)

func backstab(amount: float, attacker: Player) -> void:
	if not can_backstab(attacker):
		take_damage(amount, attacker)
		return
	if species in ["tracker", "mage", "archer"]:
		take_damage(health / maxf(0.01, (1.0 - float(stats["armor"])) * (1.0 - team_shield)) + 1.0, attacker)
	else:
		take_damage(maxf(amount * 3.0, float(stats["hp"]) * 0.35), attacker)
		if not dead:
			_clear_marker()
			_combo_left = 0
			_set_state("stunned")
			_timer = 1.5 if species == "tower_guardian" else 2.5

func _choose_routine() -> void:
	if is_instance_valid(squad):
		_destination = squad.destination(self)
		_set_state("patrol")
		_timer = 8.0
		return
	var night := hour < 6.0 or hour >= 20.0
	if stats["flying"] and (night or _rng.randf() < 0.35):
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 12.0, 1)
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty():
			_destination = ground["position"] + Vector3.UP * 0.05
			_set_state("perch")
			return
	if not stats["enemy"] and night != bool(stats["nocturnal"]):
		_set_state("rest")
		_timer = 4.0
		return
	if not stats["enemy"] and _rng.randf() < 0.35:
		_set_state("feed")
		_timer = _rng.randf_range(2.0, 5.0)
		return
	var angle := _rng.randf() * TAU
	_destination = home + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(2.0, 7.0)
	if stats["flying"]:
		_destination.y = home.y + _rng.randf_range(0.0, 3.0)
	_set_state("patrol" if stats["enemy"] else "roam")
	_timer = 8.0

func _begin_attack(combo := false) -> void:
	if not _target_valid():
		return
	_attack_count += 1
	_attack_kind = stats["attack"]
	if species == "mage":
		_attack_kind = ["bolt", "lightning", "beam"][(_attack_count - 1) % 3]
	if species == "tower_guardian":
		_attack_kind = "bolt" if health < float(stats["hp"]) * 0.5 and _attack_count % 2 == 0 else "slam"
	_attack_point = target.global_position  # fija la zona durante el aviso: se puede esquivar
	_attack_direction = (_attack_point - global_position).normalized()
	if not stats["flying"]:
		_attack_direction.y = 0.0
		_attack_direction = _attack_direction.normalized()
	if not combo:
		_combo_left = int(stats["combo"]) - 1
	_timer = float(stats["windup"]) * (0.65 if combo else 1.0)
	if _attack_kind == "lightning":
		_timer = 2.0
	if species == "tower_guardian" and health < float(stats["hp"]) * 0.5:
		_timer *= 0.75
	_set_state("windup")
	if _attack_kind == "slam":
		_show_slam_marker()
	elif _attack_kind == "lightning":
		_show_slam_marker(2.0, Color(0.2, 0.65, 1.0, 0.6))
	attack_started.emit(_attack_kind, _timer)

func _show_slam_marker(radius := 2.2, color := Color(1.0, 0.3, 0.1, 0.4)) -> void:
	_clear_marker()
	_telegraph = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.03
	disk.radial_segments = 24
	_telegraph.mesh = disk
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	_telegraph.material_override = material
	add_child(_telegraph)
	_telegraph.top_level = true
	_telegraph.global_position = _attack_point + Vector3.UP * 0.06
	if _attack_kind == "lightning":
		var ground_query := PhysicsRayQueryParameters3D.create(_attack_point + Vector3.UP * 0.1, _attack_point + Vector3.DOWN * 5.0, 1)
		ground_query.exclude = [get_rid(), target.get_rid()]
		var ground := get_world_3d().direct_space_state.intersect_ray(ground_query)
		if not ground.is_empty():
			_telegraph.global_position = ground["position"] + Vector3.UP * 0.06

func _clear_marker() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	if is_instance_valid(_beam_visual):
		_beam_visual.queue_free()
	_beam_visual = null
	_beam_link_seconds = 0.0

func _execute_attack() -> void:
	if not _target_valid():
		_begin_recovery()
		return
	match _attack_kind:
		"lightning":
			_execute_lightning()
		"beam":
			_beam_direction = (_target_center(target) - eye_position()).normalized()
			_beam_link_seconds = 0.0
			_beam_tick = 0.65
			_timer = 3.0
			_beam_visual = _make_ray_visual()
			_set_state("channel")
			return
		"bolt":
			CreatureProjectile.launch(get_parent(), self, eye_position(), _attack_point + Vector3.UP * 0.5, float(stats["damage"]) * team_damage, "electric_orb" if species == "mage" else "bolt")
		"arrow":
			CreatureProjectile.launch(get_parent(), self, eye_position(), _attack_point + Vector3.UP * 0.6, float(stats["damage"]) * team_damage * (1.8 if enchanted_arrow else 1.0), "enchanted_arrow" if enchanted_arrow else "arrow")
			enchanted_arrow = false
		"charge":
			_charge_hit = false
			_timer = 0.8
			_set_state("charge")
			return
		"slam":
			# El golpe cae donde se anunció; nunca atraviesa paredes.
			if target.global_position.distance_to(_attack_point) < 2.2 and global_position.distance_to(target.global_position) <= float(stats["range"]) + 0.3 and can_see(target):
				_hit_target(target)
		_:
			var toward := target.global_position - global_position
			toward.y = 0.0
			if toward.length() <= float(stats["range"]) + 0.3 and _attack_direction.dot(toward.normalized()) > 0.3 and can_see(target):
				_hit_target(target)
	_begin_recovery()

func _make_ray_visual() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.045
	cylinder.height = 1.0
	visual.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.8, 1.0)
	visual.material_override = material
	add_child(visual)
	visual.top_level = true
	return visual

func _position_ray(visual: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var offset := to - from
	if offset.length() < 0.01:
		visual.hide()
		return
	visual.show()
	visual.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, offset.normalized())).scaled(Vector3(1, offset.length(), 1)), (from + to) * 0.5)

func _execute_lightning() -> void:
	var top := _attack_point + Vector3.UP * 12.0
	var query := PhysicsRayQueryParameters3D.create(top, _attack_point + Vector3.UP * 0.1, 1 | LAYER)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = hit["position"] if not hit.is_empty() else _attack_point
	var flash := _make_ray_visual()
	_position_ray(flash, top, endpoint)
	get_tree().create_timer(0.2).timeout.connect(flash.queue_free)
	if not target is Player:
		return
	var offset := target.global_position - _attack_point
	if Vector2(offset.x, offset.z).length() > 2.0 or absf(offset.y) > 2.5 or not can_see(target):
		return
	# Comprueba cubierta sobre la posición actual dentro del área, no solo el centro.
	var roof := PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 12.0, _target_center(target), 1 | LAYER)
	roof.exclude = [get_rid()]
	var cover := get_world_3d().direct_space_state.intersect_ray(roof)
	if not cover.is_empty() and cover["collider"] != target:
		return
	(target as Player).combat.take_damage(24.0 * team_damage, top, 0.0, self, false)

func _tick_beam(delta: float) -> void:
	if _timer <= 0.0 or not _target_valid():
		_begin_recovery()
		return
	var origin := eye_position()
	# Seguimiento limitado: desplazarse lateralmente permite romper el enlace.
	if can_see(target):
		var desired := (_target_center(target) - origin).normalized()
		var angle := _beam_direction.angle_to(desired)
		_beam_direction = _beam_direction.slerp(desired, minf(1.0, delta * 0.75 / maxf(angle, 0.001))).normalized()
	var endpoint := origin + _beam_direction * float(stats["range"])
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1 | LAYER)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit["position"]
	if is_instance_valid(_beam_visual):
		_position_ray(_beam_visual, origin, endpoint)
	if hit.is_empty() or hit["collider"] != target or not target is Player:
		_beam_link_seconds = 0.0
		_beam_tick = 0.65
		return
	_beam_link_seconds += delta
	_beam_tick -= delta
	if _beam_tick > 0.0:
		return
	_beam_tick = 0.65
	var victim := target as Player
	var before := victim.combat.health
	victim.combat.take_damage(minf(14.0, 4.0 + _beam_link_seconds * 3.0) * team_damage, origin, 0.0, self)
	if victim.combat.health < before:
		victim.combat.apply_shock(0.8, 0.55)

func _hit_target(victim: Node3D) -> void:
	var amount := float(stats["damage"]) * team_damage
	if species == "tower_guardian" and health < float(stats["hp"]) * 0.5:
		amount *= 1.2
	if victim is Player:
		(victim as Player).combat.take_damage(amount, global_position, float(stats["poison"]), self)
	elif victim is CreatureActor:
		(victim as CreatureActor).take_damage(amount, self)

func _begin_recovery() -> void:
	_clear_marker()
	_set_state("recover")
	_timer = 0.28 if _combo_left > 0 else 0.65
	_cooldown = float(stats["cooldown"])

func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)

func _move(direction: Vector3, speed: float, delta: float) -> void:
	if not stats["flying"] and state in ["chase", "search", "return", "patrol", "roam"] and direction.length() > 0.7:
		direction = navigator.steer(self, global_position + direction, delta)
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		if not stats["flying"]:
			_probe_left -= delta
			if _probe_left <= 0.0 or state == "charge":
				_probe_left = PROBE_SECONDS
				_probe(direction)
			if _probe_stop:
				direction = Vector3.ZERO
			elif _probe_turn != 0.0:
				direction = direction.rotated(Vector3.UP, _probe_turn)
		_face(direction, delta)
	velocity.x = direction.x * speed + _knockback.x
	velocity.z = direction.z * speed + _knockback.z
	if stats["flying"]:
		velocity.y = direction.y * speed + _knockback.y
	else:
		velocity.y = maxf(velocity.y - 18.0 * delta, -25.0)
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 12.0)
	var before := global_position
	var was_floor := is_on_floor()
	move_and_slide()
	if was_floor and is_on_wall() and direction.length_squared() > 0.1 and not stats["flying"]:
		var raised := global_transform.translated(Vector3.UP * 0.55)
		if not test_move(global_transform, Vector3.UP * 0.55) and not test_move(raised, direction * 0.3):
			global_position += Vector3.UP * 0.55 + direction * 0.3
			move_and_collide(Vector3.DOWN * 0.55)
	if global_position.y < -40.0:
		global_position = home
		velocity = Vector3.ZERO
	if before.distance_to(global_position) < 0.001 and state in ["roam", "patrol"]:
		_timer = minf(_timer, 0.4)

## Mira delante: precipicio (o suelo aún sin cargar) que obliga a parar, o pared que rodear girando.
## Rodeo local; no sustituye a un navegador de caminos largos.
func _probe(direction: Vector3) -> void:
	_probe_turn = 0.0
	var ahead := global_position + direction * (float(stats["radius"]) + 0.6)
	var floor_query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 1.0, ahead + Vector3.DOWN * 1.8, 1)
	floor_query.exclude = [get_rid()]
	_probe_stop = get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty()
	if _probe_stop or state == "charge" or not test_move(global_transform, direction * 0.35):
		return
	for turn in [0.7, -0.7, 1.4, -1.4]:
		if not test_move(global_transform, direction.rotated(Vector3.UP, turn) * 0.35):
			_probe_turn = turn
			return


func take_damage(amount: float, source: Node3D = null) -> void:
	if dead or amount <= 0.0:
		return
	var actual := amount * (1.0 - float(stats["armor"])) * (1.0 - team_shield)
	health = maxf(0.0, health - actual)
	_flash = 0.15
	damaged.emit(actual)
	if health <= 0.0:
		_die()
		return
	if is_instance_valid(source):
		target = source
		_last_seen = source.global_position
		_aggro = 10.0
		_knockback = (global_position - source.global_position).normalized() * 2.5
		if stats["enemy"]:
			alert_seconds = 60.0
			_broadcast_alert()
	var fights: bool = stats["enemy"] or stats["temper"] in ["defensive", "territorial", "predator", "hunter"]
	if species != "tower_guardian" and state != "stunned":
		_clear_marker()
		_set_state("stagger" if fights else "flee")
		_timer = 0.25
		_combo_left = 0
	# Aviso al grupo cercano (soldados/capitán o manada de lobos), sin aggro global.
	if species == "wolf":
		for node in get_tree().get_nodes_in_group("creatures"):
			var ally := node as CreatureActor
			if ally != self and not ally.dead and ((stats["enemy"] and ally.stats["enemy"]) or ally.species == species) and global_position.distance_to(ally.global_position) < 7.0 and is_instance_valid(source):
				ally.target = source
				ally._aggro = 8.0
				if ally.state not in ["windup", "recover", "charge"]:
					ally._set_state("chase")

func stun(seconds: float) -> void:
	if dead or seconds <= 0.0:
		return
	var remaining := _timer if state == "stunned" else 0.0
	_clear_marker()
	_combo_left = 0
	_set_state("stunned")
	_timer = maxf(remaining, seconds)
	_cooldown = maxf(_cooldown, seconds)

func _die() -> void:
	if dead:
		return
	dead = true
	_clear_marker()
	_set_state("dead")
	collision_layer = 0
	collision_mask = 0
	if drop_loot:
		for stack in CreatureDB.roll_loot(species, _rng):
			ItemDrop.spawn(get_parent(), global_position + Vector3.UP * 0.4, stack["id"], stack["count"])
	died.emit(self)
	queue_free()

func _update_label() -> void:
	if _label != null:
		var names := {"search": "Buscando", "chase": "Persiguiendo", "return": "Regresando", "stunned": "Aturdido", "patrol": "Patrullando", "idle": "Esperando", "windup": "Preparando " + {"lightning": "descarga", "beam": "rayo continuo", "bolt": "bola de rayos"}.get(_attack_kind, "ataque"), "channel": "Canalizando rayo", "recover": "Recuperándose"}
		_label.text = "%s  %d/%d\n%s%s\n%s" % [stats["name"], ceili(health), int(stats["hp"]), names.get(state, state), " · Alerta" if alert_seconds > 0.0 else "", "Flecha encantada" if enchanted_arrow else team_role]
