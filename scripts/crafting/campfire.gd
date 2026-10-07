extends Node3D
class_name Campfire
## Hoguera (vive dentro de un PlacedItem "campfire"): anillo de piedras y leña. Clic derecho:
##   - con pedernal: intentar encenderla (saltan chispas; no siempre prende);
##   - con palos, troncos o tablas: echar leña (más tiempo ardiendo);
##   - con algo crudo (insecto, bayas): cocinarlo; a los pocos segundos sale asado.
## Encendida da luz y calor, chisporrotea y echa humo; cuando se acaba la leña se apaga.

const FUEL := {"sticks": 45.0, "wood": 150.0, "board": 120.0, "planks": 90.0, "fiber": 10.0, "resin": 30.0}
const COOKS := {"raw_meat": "cooked_meat", "raw_poultry": "cooked_poultry", "insect": "roasted_insect", "berries": "roasted_berries", "seeds": "roasted_seeds", "mushroom": "roasted_mushroom", "raw_fish": "cooked_fish", "wheat": "flatbread", "raw_crab": "cooked_crab"}
const COOK_TIME := 4.0
const LIGHT_CHANCE := 0.45

var lit := false
var fuel := 60.0        # segundos de leña que le quedan
var _cooking: Array[Dictionary] = []   # {"id": cocinado, "left": segundos}
var _light: OmniLight3D
var _flames: Node3D
var _smoke: CPUParticles3D
var _time := 0.0
var _crackle := 0.0


func _ready() -> void:
	add_to_group("campfires")  # la lluvia avisa con call_group("campfires", "rained_on")
	var pit_path := "res://assets/models/voxel/campfire_pit.res"
	if ResourceLoader.exists(pit_path):
		# Anillo de piedras con leña (Kenney Survival Kit, en cubitos).
		var pit := MeshInstance3D.new()
		pit.mesh = load(pit_path)
		pit.scale = Vector3.ONE * 0.75
		add_child(pit)
	else:
		# Piedras en anillo.
		for k in 8:
			var a := TAU * k / 8.0
			_box(Vector3(cos(a) * 0.17, 0.035, sin(a) * 0.17), Vector3(0.08, 0.07, 0.07), Color(0.52, 0.52, 0.54).darkened(0.1 * (k % 3)), a)
		# Leña cruzada en el centro.
		_box(Vector3(0, 0.05, 0), Vector3(0.24, 0.045, 0.045), Color(0.42, 0.28, 0.15), 0.6)
		_box(Vector3(0, 0.08, 0), Vector3(0.24, 0.045, 0.045), Color(0.38, 0.25, 0.13), -0.7)
	_flames = Node3D.new()
	add_child(_flames)
	for k in 3:
		var flame := TorchLight.make_flame()
		flame.position = Vector3(cos(k * 2.1) * 0.04, 0.12 + k * 0.03, sin(k * 2.1) * 0.04)
		flame.scale = Vector3.ONE * (1.5 - k * 0.3)
		_flames.add_child(flame)
	_light = TorchLight.make_light()
	_light.omni_range = 10.0
	_light.position.y = 0.4
	add_child(_light)
	_smoke = CPUParticles3D.new()
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE * 0.08
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.55, 0.55, 0.45)
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = grey
	_smoke.mesh = puff
	_smoke.amount = 14
	_smoke.lifetime = 3.0
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.gravity = Vector3(0.15, 0.6, 0.0)
	_smoke.initial_velocity_min = 0.3
	_smoke.initial_velocity_max = 0.6
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.8
	_smoke.position.y = 0.3
	add_child(_smoke)
	_show_lit()


func _box(pos: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	part.material_override = material
	part.position = pos
	part.rotation.y = yaw
	add_child(part)


func _show_lit() -> void:
	_flames.visible = lit
	_light.visible = lit
	_smoke.emitting = lit


## Clic derecho con 'held' (el montón de la mano, o {}). Devuelve lo que se gasta de la mano (0
## o 1) y avisa al jugador con un texto.
func interact(held: Dictionary, player: Player) -> int:
	var id: String = "" if held.is_empty() else held["id"]
	if id == "flint":
		if lit:
			player.notice.emit("Ya está encendida.")
			return 0
		if fuel <= 0.0:
			player.notice.emit("No tiene leña: échale palos o un tronco.")
			return 0
		_sparks()
		if randf() < LIGHT_CHANCE:
			lit = true
			_show_lit()
			get_tree().call_group("objectives", "mark", "hoguera")
			Sfx.play("fabricado", global_position, -6.0)
			player.notice.emit("¡La hoguera ha prendido!")
		else:
			player.notice.emit("Saltan chispas, pero no prende. Prueba otra vez.")
		return 0
	if FUEL.has(id):
		fuel += FUEL[id]
		Sfx.play("colocar", global_position, -6.0)
		player.notice.emit("Echas leña: %d s de fuego." % int(fuel))
		return 1
	if COOKS.has(id):
		if not lit:
			player.notice.emit("Primero hay que encenderla (clic derecho con pedernal).")
			return 0
		_cooking.append({"id": COOKS[id], "left": COOK_TIME})
		Sfx.play("colocar", global_position, -8.0)
		player.notice.emit("Asando %s..." % ItemDB.display_name(id).to_lower())
		return 1
	if lit:
		player.notice.emit("Arde. Echa leña (palos, troncos) o pon a asar insectos o bayas.")
	else:
		player.notice.emit("Hoguera apagada: enciéndela con pedernal (clic derecho).")
	return 0


## Llueve: si no hay nada encima que la tape, puede apagarse.
func rained_on() -> void:
	if not lit or randf() > 0.35:
		return
	var from := global_position + Vector3.UP * 0.6
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 8.0, 1))
	if not hit.is_empty():
		return  # a cubierto
	lit = false
	_show_lit()
	Sfx.play("romper_hierba", global_position, -2.0)


func _sparks() -> void:
	var sparks := CPUParticles3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3.ONE * 0.02
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.3)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.1)
	material.emission_energy_multiplier = 4.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = material
	sparks.mesh = dot
	sparks.amount = 18
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 70.0
	sparks.direction = Vector3.UP
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.0
	sparks.position.y = 0.12
	add_child(sparks)
	sparks.emitting = true
	Sfx.play("golpe", global_position, 0.0, 0.3)
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)


func _process(delta: float) -> void:
	if not lit:
		return
	_time += delta
	TorchLight.flicker(_light, null, _time)
	_light.light_energy *= 1.4
	for k in _flames.get_child_count():
		var f := _flames.get_child(k) as Node3D
		var s := 1.0 + sin(_time * (9.0 + k * 3.0) + k) * 0.15
		f.scale = Vector3.ONE * (1.5 - k * 0.3) * Vector3(1.0, s, 1.0)
	fuel -= delta
	if fuel <= 0.0:
		fuel = 0.0
		lit = false
		_show_lit()
		Sfx.play("romper_hierba", global_position, -6.0)
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = randf_range(0.3, 1.2)
		Sfx.play("golpe", global_position, -14.0, 0.5)
	for c in _cooking.duplicate():
		c["left"] = float(c["left"]) - delta
		if float(c["left"]) <= 0.0:
			_cooking.erase(c)
			ItemDrop.spawn(get_parent().get_parent(), global_position + Vector3.UP * 0.3, c["id"], 1)
			Sfx.play("recoger", global_position, -6.0)


func get_state() -> Dictionary:
	return {"lit": lit, "fuel": fuel}


func set_state(state: Dictionary) -> void:
	lit = bool(state.get("lit", false))
	fuel = float(state.get("fuel", fuel))
	if _flames != null:
		_show_lit()
