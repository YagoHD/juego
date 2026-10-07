extends Node
class_name PlayerCombat
## Vida y combate del jugador. Se añade tanto en la isla como en la arena; no crea enemigos.
signal before_death
signal persistence_requested
signal health_changed(value: float)
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const ArrowScript = preload("res://scripts/player/player_arrow.gd")
const PARRY_WINDOW := 0.22
const COMBO_WINDOW := 1.5
const BOW_FULL_DRAW := 1.5
const BOW_FATIGUE := 2.5
const HEAVY_CHARGE := 0.55
const COMBOS := {"LHL": {"damage": 1.5, "stun": 0.6}, "LLH": {"damage": 1.65, "stun": 1.0}, "HLL": {"damage": 1.4, "stun": 0.5}}
const WEAPONS := {
	"": {"damage": 5.0, "reach": 1.8, "cooldown": 0.55, "cost": 7.0},
	"stone_knife": {"damage": 12.0, "reach": 2.0, "cooldown": 0.45, "cost": 10.0},
	"stone_axe": {"damage": 22.0, "reach": 2.3, "cooldown": 0.85, "cost": 18.0},
	"stone_pick": {"damage": 16.0, "reach": 2.3, "cooldown": 0.8, "cost": 16.0},
	"spear": {"damage": 18.0, "reach": 3.1, "cooldown": 0.7, "cost": 13.0},
}
var player: Player
var health := MAX_HEALTH
var stamina := MAX_STAMINA
var invulnerable := 0.0
var knockback := Vector3.ZERO
var _cooldown := 0.0
var _poison := 0.0
var _poison_tick := 1.0
var _dying := false
var _status: Label
var blocking := false
var _block_time := 0.0
var _block_rearm := 0.0
var _guard_broken := 0.0
var _regen_delay := 0.0
var _pending: Dictionary = {}
var _windup := 0.0
var _combo := ""
var _combo_weapon := ""
var _combo_timer := 0.0
var _dodge_time := 0.0
var _dodge_direction := Vector3.ZERO
var _dodge_speed := 0.0
var _double_dodge := 0.0
var _roll := false
var drawing_bow := false
var draw_seconds := 0.0
var _bow_slot := -1
var _rng := RandomNumberGenerator.new()
var charging_melee := false
var melee_charge_seconds := 0.0
var _charge_id := ""
var _charge_slot := -1
var _shock_seconds := 0.0
var _shock_speed := 1.0

func apply_shock(seconds: float, speed_factor: float) -> void:
	_shock_seconds = maxf(_shock_seconds, seconds)
	_shock_speed = clampf(speed_factor, 0.2, 1.0)

func movement_factor() -> float:
	return _shock_speed if _shock_seconds > 0.0 else 1.0

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 3
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(16, 76)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 4)
	canvas.add_child(_status)

func _process(delta: float) -> void:
	_shock_seconds = maxf(0.0, _shock_seconds - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_block_rearm = maxf(0.0, _block_rearm - delta)
	_guard_broken = maxf(0.0, _guard_broken - delta)
	_regen_delay = maxf(0.0, _regen_delay - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	_double_dodge = maxf(0.0, _double_dodge - delta)
	_dodge_time = maxf(0.0, _dodge_time - delta)
	if player.ui_open or not player.is_on_ground_ready() or _dying or not player._captured:
		cancel_actions()
	if blocking:
		_block_time += delta
		_regen_delay = maxf(_regen_delay, 0.25)
	if charging_melee:
		if selected_id() != _charge_id or player._hotbar_index != _charge_slot:
			cancel_melee_charge()
		else:
			melee_charge_seconds += delta
			_regen_delay = maxf(_regen_delay, 0.25)
	if drawing_bow:
		if selected_id() != "bow" or player._hotbar_index != _bow_slot:
			cancel_bow()
		else:
			draw_seconds += delta
			_regen_delay = maxf(_regen_delay, 0.3)
			if not player.creative:
				stamina = maxf(0.0, stamina - delta * (18.0 if draw_seconds > BOW_FATIGUE else 3.0))
				if stamina <= 0.0:
					cancel_bow()
					player.notice.emit("Sin resistencia: sueltas la tensión del arco.")
	if not _pending.is_empty():
		_windup -= delta
		if _windup <= 0.0:
			var attack := _pending
			_pending = {}
			if selected_id() == attack["id"] and player._hotbar_index == attack["slot"]:
				_resolve_attack(attack)
	if player.is_on_ground_ready():
		invulnerable = maxf(0.0, invulnerable - delta)
	knockback = knockback.move_toward(Vector3.ZERO, delta * 10.0)
	if not player.ui_open and not _dying:
		if _regen_delay <= 0.0 and not blocking and not drawing_bow and _dodge_time <= 0.0:
			stamina = minf(MAX_STAMINA, stamina + delta * 18.0)
		if health > 0.0 and player.needs != null and player.needs.hunger > 50.0 and player.needs.thirst > 40.0 and _poison <= 0.0:
			health = minf(MAX_HEALTH, health + delta * 0.5)
	if _poison > 0.0 and not player.creative and not _dying:
		_poison = maxf(0.0, _poison - delta)
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 1.0
			take_damage(2.0, player.global_position, 0.0, null, false)
	var action := ""
	if charging_melee:
		action = " · Pesado listo: suelta el clic" if melee_charge_seconds >= HEAVY_CHARGE else " · Cargando ataque"
	elif drawing_bow:
		action = " · Arco %d%%%s" % [int(minf(draw_seconds / BOW_FULL_DRAW, 1.0) * 100), " — pulso inestable" if draw_seconds > BOW_FATIGUE else ""]
	elif blocking:
		action = " · Bloqueando con escudo" if has_shield() else " · Bloqueando"
	elif _dodge_time > 0.0:
		action = " · Voltereta" if _roll else " · Esquiva"
	elif _combo_timer > 0.0:
		action = " · Combo " + _combo
	_status.text = "Vida %d/100    Resistencia %d/100%s%s%s" % [ceili(health), int(stamina), "    Veneno" if _poison > 0.0 else "", action, " · Ralentizado" if _shock_seconds > 0.0 else ""]
	_status.visible = player.is_on_ground_ready()
	player._avatar.set_combat_pose("block" if blocking else ("bow" if drawing_bow else ("heavy" if charging_melee or not _pending.is_empty() else "")))

## El clic corto y el largo son excluyentes: no golpea ligero antes de cargar el pesado.
func press_primary() -> bool:
	if selected_id() == "bow":
		return start_bow_draw()
	if _dying or player.ui_open or not player.is_on_ground_ready():
		return false
	if blocking or charging_melee or _cooldown > 0.0 or _dodge_time > 0.0 or _guard_broken > 0.0:
		return true
	var id := selected_id()
	var weapon: Dictionary = WEAPONS.get(id, WEAPONS[""])
	var hit := _ray(maxf(Player.REACH, float(weapon["reach"])))
	if not hit.is_empty() and not hit["collider"] is CreatureActor:
		return false  # mantiene el picado de bloques/herramientas
	if hit.is_empty() and not WEAPONS.has(id):
		return false
	charging_melee = true
	melee_charge_seconds = 0.0
	_charge_id = id
	_charge_slot = player._hotbar_index
	player.breaker.reset()
	return true

func release_primary() -> bool:
	if drawing_bow:
		return release_bow()
	if not charging_melee:
		return false
	var heavy := melee_charge_seconds >= HEAVY_CHARGE
	var valid := selected_id() == _charge_id and player._hotbar_index == _charge_slot
	cancel_melee_charge()
	if valid:
		return try_attack(heavy, true)
	return true

func cancel_melee_charge() -> void:
	charging_melee = false
	melee_charge_seconds = 0.0
	_charge_slot = -1

func _ray(distance: float) -> Dictionary:
	var camera := player.get_camera()
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * (distance + player._spring.spring_length), 1 | CreatureActor.LAYER | DeathBackpack.LAYER)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and player.eye_position().distance_to(hit["position"]) > distance:
		return {}
	return hit

## Devuelve true cuando hay criatura apuntada incluso durante cooldown: no pica el suelo.
func try_attack(heavy := false, prepared := false) -> bool:
	if _dying or player.ui_open or not player.is_on_ground_ready():
		return false
	var id := selected_id()
	if id == "bow":
		return true if heavy else start_bow_draw()
	if blocking or drawing_bow or _dodge_time > 0.0 or _guard_broken > 0.0 or not _pending.is_empty():
		return true
	var weapon: Dictionary = WEAPONS.get(id, WEAPONS[""])
	var hit := _ray(float(weapon["reach"]))
	if not heavy and (hit.is_empty() or not hit["collider"] is CreatureActor):
		return false
	player.breaker.reset()
	if _cooldown > 0.0 or blocking or drawing_bow or _dodge_time > 0.0 or _guard_broken > 0.0:
		return true
	var cost := float(weapon["cost"]) * (1.8 if heavy else 1.0)
	if not _spend(cost):
		player.notice.emit("Te falta energía para golpear.")
		return true
	_cooldown = float(weapon["cooldown"]) * (1.7 if heavy else 1.0)
	if _combo_timer <= 0.0 or _combo_weapon != id:
		_combo = ""
	_combo_weapon = id
	_combo += "H" if heavy else "L"
	_combo = _combo.right(3)
	_combo_timer = COMBO_WINDOW + _cooldown
	var finisher: Dictionary = COMBOS.get(_combo, {})
	var airborne := not player.is_on_floor() and not player._flying and player.raft == null
	var attack := {"id": id, "slot": player._hotbar_index, "reach": weapon["reach"],
		"damage": float(weapon["damage"]) * (2.0 if heavy else 1.0) * (1.25 if airborne else 1.0) * float(finisher.get("damage", 1.0)),
		"stun": float(finisher.get("stun", 0.0)), "heavy": heavy}
	player._held.swing()
	player._avatar.swing()
	if heavy and not prepared:
		_pending = attack
		_windup = 0.55
	else:
		_resolve_attack(attack)
	if not finisher.is_empty():
		player.notice.emit("Combo %s: remate." % _combo)
		_combo = ""
	return true

func _resolve_attack(attack: Dictionary) -> void:
	if attack.get("heavy", false):
		player._held.swing()
		player._avatar.swing()
	var hit := _ray(float(attack["reach"]))
	if hit.is_empty() or not hit["collider"] is CreatureActor:
		return
	var victim := hit["collider"] as CreatureActor
	var id := str(attack["id"])
	if id != "" and WEAPONS.has(id) and victim.can_backstab(player):
		victim.backstab(float(attack["damage"]), player)
		player.notice.emit("Ataque por la espalda: golpe crítico.")
	else:
		victim.take_damage(float(attack["damage"]), player)
		if float(attack["stun"]) > 0.0:
			victim.stun(float(attack["stun"]))
	if WEAPONS.has(id) and id != "":
		player.survival.wear_tool()

func selected_id() -> String:
	var stack := player.active_inventory().get_slot(player._hotbar_index)
	return "" if stack.is_empty() else str(stack["id"])

func _spend(amount: float) -> bool:
	if player.creative:
		return true
	if stamina < amount:
		return false
	stamina -= amount
	_regen_delay = 0.7
	return true

func has_shield() -> bool:
	return player.equipment.get("offhand", "") == "wooden_shield" or selected_id() == "wooden_shield"

func set_blocking(on: bool) -> void:
	if not on:
		blocking = false
		return
	if blocking or player.ui_open or _dying or not player.is_on_ground_ready() or _cooldown > 0.0 or _dodge_time > 0.0 or drawing_bow or _guard_broken > 0.0 or stamina <= 0.0:
		return
	blocking = true
	cancel_melee_charge()
	# Volver a levantar guardia inmediatamente no reinicia el parry.
	_block_time = 0.0 if _block_rearm <= 0.0 else PARRY_WINDOW
	_block_rearm = 0.7

func dodge(direction: Vector3) -> bool:
	if player.ui_open or _dying or not player.is_on_ground_ready() or not player.is_on_floor() or player._flying or player.raft != null or _guard_broken > 0.0:
		return false
	var roll := _double_dodge > 0.0 and not _roll
	if _dodge_time > 0.0 and not roll:
		return false
	if not _spend(32.0 if roll else 12.0):
		player.notice.emit("Te falta resistencia para esquivar.")
		return false
	direction.y = 0.0
	_dodge_direction = direction.normalized() if direction.length_squared() > 0.0 else player.global_basis.z.normalized()
	_dodge_time = 0.65 if roll else 0.22
	_dodge_speed = 7.5 if roll else 4.5
	_roll = roll
	_double_dodge = 0.0 if roll else 0.4
	blocking = false
	cancel_bow()
	cancel_melee_charge()
	_pending = {}
	_combo = ""
	_combo_timer = 0.0
	if roll:
		invulnerable = maxf(invulnerable, _dodge_time)
		player._avatar.combat_roll(_dodge_time)
	return true

func movement_velocity() -> Vector3:
	return _dodge_direction * _dodge_speed if _dodge_time > 0.0 else Vector3.ZERO

func cancel_bow() -> void:
	drawing_bow = false
	draw_seconds = 0.0
	_bow_slot = -1

func weapon_changed() -> void:
	blocking = false
	cancel_bow()
	cancel_melee_charge()
	_pending = {}
	_combo = ""
	_combo_timer = 0.0

func cancel_actions() -> void:
	blocking = false
	cancel_bow()
	cancel_melee_charge()
	_pending = {}
	_combo = ""
	_combo_timer = 0.0
	_dodge_time = 0.0
	_double_dodge = 0.0
	_roll = false

func _arrow_slot() -> int:
	for index in player.unlocked_slots():
		var stack := player.active_inventory().get_slot(index)
		if not stack.is_empty() and stack["id"] == "arrow":
			return index
	return -1

func start_bow_draw() -> bool:
	if selected_id() != "bow":
		return false
	if drawing_bow or _cooldown > 0.0 or blocking or _dodge_time > 0.0 or _guard_broken > 0.0 or player.ui_open or not player.is_on_ground_ready():
		return true
	if not player.creative and (_arrow_slot() < 0 or stamina < 6.0):
		player.notice.emit("Necesitas una flecha y resistencia para tensar el arco.")
		return true
	drawing_bow = true
	draw_seconds = 0.0
	_bow_slot = player._hotbar_index
	player.breaker.reset()
	return true

func release_bow() -> bool:
	if not drawing_bow:
		return false
	var charge := draw_seconds
	var slot := _bow_slot
	cancel_bow()
	if player.ui_open or not player.is_on_ground_ready() or selected_id() != "bow" or player._hotbar_index != slot:
		return true
	var ammo := _arrow_slot()
	if not player.creative and ammo < 0:
		return true
	if not _spend(6.0):
		return true
	if not player.creative:
		player.active_inventory().take(ammo, 1)
	var camera := player.get_camera()
	var from := player.eye_position()
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 65.0, 1 | CreatureActor.LAYER)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim: Vector3 = hit["position"] if not hit.is_empty() else camera.global_position - camera.global_basis.z * 65.0
	var direction := (aim - from).normalized()
	var spread := bow_spread(charge)
	direction = direction.rotated(camera.global_basis.y, _rng.randf_range(-spread, spread)).rotated(camera.global_basis.x, _rng.randf_range(-spread, spread))
	var arrow = ArrowScript.new()
	arrow.source = player
	arrow.launch_origin = from
	arrow.base_damage = 22.0 * lerpf(0.25, 1.0, minf(charge / BOW_FULL_DRAW, 1.0))
	arrow.stealth = player.is_sneaking()
	arrow.velocity = direction * lerpf(14.0, 30.0, minf(charge / BOW_FULL_DRAW, 1.0))
	player.get_parent().add_child(arrow)
	arrow.global_position = from
	_cooldown = 0.4
	player.survival.wear_tool()
	player._held.swing()
	return true

static func bow_spread(seconds: float) -> float:
	return minf(0.18, 0.004 + maxf(0.0, seconds - BOW_FATIGUE) * 0.025)

func try_recover_backpack() -> bool:
	var hit := _ray(Player.REACH)
	if hit.is_empty() or not hit["collider"] is DeathBackpack:
		return false
	(hit["collider"] as DeathBackpack).recover(player)
	# queue_free se completa antes de guardar: una bolsa vacía no reaparece al cargar.
	persistence_requested.emit.call_deferred()
	return true

func take_damage(amount: float, from: Vector3, poison_seconds := 0.0, attacker: Node3D = null, blockable := true) -> void:
	if amount <= 0.0 or player.creative or _dying or invulnerable > 0.0 or not player.is_on_ground_ready():
		return
	if blocking and blockable and not player.ui_open:
		var toward := from - player.global_position
		toward.y = 0.0
		var forward := -player.global_basis.z
		forward.y = 0.0
		if toward.length_squared() > 0.01 and forward.normalized().dot(toward.normalized()) >= 0.5:
			if _block_time < PARRY_WINDOW:
				_block_time = PARRY_WINDOW
				_block_rearm = 0.7
				invulnerable = 0.15
				if is_instance_valid(attacker) and attacker is CreatureActor and player.global_position.distance_to(attacker.global_position) <= 4.0:
					(attacker as CreatureActor).stun(1.5)
				player.notice.emit("Bloqueo perfecto: contraataca.")
				return
			var shield := has_shield()
			var cost := amount * (1.5 if shield else 0.7)
			if _spend(cost):
				if shield:
					return
				amount *= 0.35
				poison_seconds = 0.0
			else:
				stamina = 0.0
				blocking = false
				_guard_broken = 1.0
				_regen_delay = 1.0
				player.notice.emit("Guardia rota: sin resistencia.")
	_pending = {}
	_combo = ""
	_combo_timer = 0.0
	cancel_bow()
	cancel_melee_charge()
	health = maxf(0.0, health - amount)
	invulnerable = 0.55
	_poison = maxf(_poison, poison_seconds)
	health_changed.emit(health)
	player.notice.emit("Recibes %d de daño." % ceili(amount))
	var away := player.global_position - from
	away.y = 0.0
	knockback = away.normalized() * 2.0
	if health <= 0.0:
		_dying = true
		_die.call_deferred()

func _die() -> void:
	cancel_actions()
	_shock_seconds = 0.0
	before_death.emit()  # cierra fabricación y devuelve materiales antes de vaciar inventario
	var bag := DeathBackpack.new()
	bag.contents = player.inventory.to_data().filter(func(s: Dictionary) -> bool: return not s.is_empty())
	bag.equipment = player.equipment.duplicate(true)
	bag.position = player.global_position + Vector3.UP * 0.15
	player.get_parent().add_child(bag)
	player.inventory.clear()
	player.set_equipment({})
	if player.raft != null:
		player.rafts.dismount()
	player.global_position = player.get_spawn_point() + Vector3.UP * 0.15
	player._waiting_for_ground = true  # el punto puede estar fuera del terreno cargado
	player.velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	player._flying = false
	player._sprinting = false
	player.set_working(false)
	player.set_kneeling(false)
	player.ui_open = false
	player._set_captured(true)
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	_poison = 0.0
	invulnerable = 4.0
	_dying = false
	player.notice.emit("Has muerto. Tu inventario está en la mochila donde caíste.")
	persistence_requested.emit()

func to_data() -> Dictionary:
	return {"health": health, "stamina": stamina, "poison": _poison}

func from_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", MAX_HEALTH)), 1.0, MAX_HEALTH)
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	_poison = clampf(float(data.get("poison", 0.0)), 0.0, 30.0)
	invulnerable = 3.0
