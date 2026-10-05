extends Node3D
class_name PlayerAvatar
## Cuerpo del jugador, construido a partir de su skin (formato Minecraft, ver SkinModel y
## docs/SKINS.md). Mide lo mismo que el jugador (SkinModel.BODY_HEIGHT), mira hacia -Z y se anima solo:
##   - andar: brazos y piernas alternos;
##   - reposo: respiración, balanceo suave del cuerpo y parpadeo;
##   - tras IDLE_ACTION_DELAY s quieto: una acción al azar (estirarse, sentadillas, salto,
##     voltereta hacia atrás). Moverse o golpear la cancela al instante.
## Todas sus mallas están en la capa visual 2: la cámara en primera persona no las dibuja,
## pero siguen proyectando sombra.

const LAYER := 1 << 1
const IDLE_ACTION_DELAY := 15.0
const ACTIONS := {"estirarse": 2.6, "sentadillas": 2.6, "salto": 1.1, "voltereta": 1.4}  # duración (s)
## Escala respecto al diseño original (personaje de 1,4 m): las distancias en metros de las
## animaciones (rebotes, saltos...) se multiplican por K para que vayan con el tamaño.
const K := SkinModel.BODY_HEIGHT / 1.4
const HIP_HEIGHT := 0.7 * K   # centro de giro del cuerpo (para la voltereta)
const SMOOTHING := 14.0   # rapidez con la que las articulaciones alcanzan su pose (más = más seco)

var _root: Node3D          # "cadera": todo cuelga de aquí; se mueve y gira para las acciones
var _head: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _held: MeshInstance3D
var _item_id := ""        # lo que lleva en la mano (para el agarre al rehacer el cuerpo)
var _lids: Node3D          # párpados (visibles un instante al parpadear)
var _backpack: Node3D      # mochila a la espalda (visible si la lleva puesta)
var _backpack_kind := ""     # id de la mochila que lleva ("" = ninguna)
var _working := false
var _work := 0.0             # 0..1: mezcla de la postura de trabajar agachado
var _kneeling := false
var _kneel := 0.0            # 0..1: mezcla de la postura de rodillas (inventario y fabricar)
var _in_leaves := false
var _leaves := 0.0           # 0..1: mezcla de la postura de apartar hojas (cruzando una copa)

var _time := 0.0
var _walk_phase := 0.0
var _walk_amount := 0.0
var _run := 0.0           # 0 andando, 1 corriendo (paso más largo y rápido, más inclinado)
var _swing := 0.0
var _look_pitch := 0.0
var _idle_time := 0.0
var _action := ""
var _action_t := 0.0       # 0..1 a lo largo de la acción
var _frozen := false       # solo para capturas: congela la acción en un instante
var _blink_timer := 3.0
var _rng := RandomNumberGenerator.new()
var _smoothed := {}        # pose actual (persigue a la pose objetivo con inercia)


## Construye el cuerpo con una skin (textura de 64x64). Se puede volver a llamar para cambiarla.
func build(texture: Texture2D, slim: bool) -> void:
	for child in get_children():
		child.queue_free()
	_root = Node3D.new()
	_root.position = Vector3(0, HIP_HEIGHT, 0)
	add_child(_root)

	_add_part(SkinModel.make_part("body", texture, slim, LAYER))
	_head = _add_part(SkinModel.make_part("head", texture, slim, LAYER))
	_arm_right = _add_part(SkinModel.make_part("arm_right", texture, slim, LAYER))
	_arm_left = _add_part(SkinModel.make_part("arm_left", texture, slim, LAYER))
	_leg_right = _add_part(SkinModel.make_part("leg_right", texture, slim, LAYER))
	_leg_left = _add_part(SkinModel.make_part("leg_left", texture, slim, LAYER))

	# Bloque en la mano derecha (al final del brazo, un poco por delante).
	_held = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.15 * K
	_held.mesh = box
	_held.position = Vector3(0, -5.0, -1.5) * SkinModel.PIXEL  # en el antebrazo, junto a la mano
	_held.layers = LAYER
	_arm_right.get_node("lower").add_child(_held)

	_build_lids(texture)
	_build_backpack()
	set_item(_item_id)


func _add_part(part: Node3D) -> Node3D:
	part.position -= Vector3(0, HIP_HEIGHT, 0)  # relativo a la cadera
	_root.add_child(part)
	return part


func _build_lids(texture: Texture2D) -> void:
	# Párpados: dos rectángulos del color de la frente justo delante de los ojos (donde los
	# pinta SkinComposer: filas 4 de la cara, columnas 1-2 y 5-6).
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var k := image.get_width() / SkinModel.TEXTURE_SIZE  # 2 en la skin del náufrago (al doble)
	var face: Rect2i = SkinModel.face_rects(SkinModel.PARTS["head"]["base"], SkinModel.PARTS["head"]["size"])["front"]
	var skin_color := image.get_pixel(face.position.x * 2 + 5, face.position.y * 2 + 12) if k > 1 \
		else image.get_pixel(face.position.x + 3, face.position.y + 2)  # la mejilla / la frente
	# Ojos del náufrago: más abajo y más pequeños (el pelo ocupa la parte de arriba de la cara).
	var eye_x := 1.5 if k > 1 else 2.0
	var eye_y := 2.6 if k > 1 else 3.5
	var eye_size := Vector2(1.4, 0.8) if k > 1 else Vector2(2.0, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = skin_color
	material.roughness = 0.9
	_lids = Node3D.new()
	_lids.visible = false
	_head.add_child(_lids)
	for x in [eye_x, -eye_x]:  # en píxeles: derecha del personaje = +X
		var lid := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(eye_size.x, eye_size.y, 0.1) * SkinModel.PIXEL
		lid.mesh = quad
		lid.material_override = material
		lid.position = Vector3(x, eye_y, -4.06) * SkinModel.PIXEL
		lid.layers = LAYER
		_lids.add_child(lid)


## Mochila a la espalda: el id del objeto ("backpack", "rough_backpack") o "" para ninguna.
func set_backpack(kind: String) -> void:
	_backpack_kind = kind
	if _root != null:
		_build_backpack()


func _build_backpack() -> void:
	# Bolsa de 6x8x3 píxeles de skin pegada a la espalda, con solapa y bolsillo. La improvisada
	# es de tela de vela remendada y atada con cuerda.
	if is_instance_valid(_backpack):
		_backpack.queue_free()
	_backpack = Node3D.new()
	_backpack.position = Vector3(0, 12.0, 3.4) * SkinModel.PIXEL - Vector3(0, HIP_HEIGHT, 0) + Vector3(0, 6.0, 0) * SkinModel.PIXEL
	_root.add_child(_backpack)
	if _backpack_kind == "rough_backpack":
		_add_backpack_box(Vector3(0, -0.5, 0), Vector3(5.5, 7, 2.6), Color(0.8, 0.75, 0.63))
		_add_backpack_box(Vector3(0, 2.4, 0), Vector3(5.8, 0.7, 2.9), Color(0.72, 0.58, 0.38))   # cuerda que la cierra
		_add_backpack_box(Vector3(1.2, -2.0, 1.3), Vector3(2.2, 2.2, 0.3), Color(0.68, 0.64, 0.55))  # remiendo
	else:
		_add_backpack_box(Vector3(0, 0, 0), Vector3(6, 8, 3), Color(0.5, 0.36, 0.2))
		_add_backpack_box(Vector3(0, 2.6, 0.2), Vector3(6.3, 2.8, 3.3), Color(0.58, 0.43, 0.25))   # solapa
		_add_backpack_box(Vector3(0, -1.8, 1.7), Vector3(4, 3, 0.8), Color(0.44, 0.31, 0.17))     # bolsillo
	_backpack.visible = _backpack_kind != ""


func _add_backpack_box(pos_px: Vector3, size_px: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_px * SkinModel.PIXEL
	part.mesh = box
	part.position = pos_px * SkinModel.PIXEL
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	part.material_override = material
	part.layers = LAYER
	_backpack.add_child(part)


func set_item(id: String) -> void:
	_item_id = id
	var hand := _arm_right.get_node_or_null("lower/hand") as VoxelHand if _arm_right != null else null
	if hand != null:
		hand.grip_for(id)  # los dedos se cierran según lo que lleve
		if _held != null:
			# Con mango: dentro del puño; si no, delante de la palma.
			_held.position = (Vector3(0.0, -7.0, -1.4) if id in VoxelHand.HANDLED else Vector3(0.0, -7.2, -2.4)) * SkinModel.PIXEL
	if _held != null:
		_held.visible = id != ""  # "" = mano vacía
		if id == "":
			return
		_held.mesh = ItemMesh.make(id, 0.15 * K)
		_held.material_override = ItemMesh.make_material(id)


## Hacia dónde mira (arriba/abajo), en radianes.
func set_look_pitch(pitch: float) -> void:
	_look_pitch = pitch


func swing() -> void:
	_swing = 1.0
	_cancel_idle()


## speed01 = 0 quieto, 1 andando, >1 corriendo. on_floor = false en el aire.
func update_walk(speed01: float, on_floor: bool, delta: float) -> void:
	var target := clampf(speed01, 0.0, 1.0) if on_floor else 0.0
	_walk_amount = lerpf(_walk_amount, target, 1.0 - exp(-10.0 * delta))
	var run_target := clampf((speed01 - 1.0) / 0.5, 0.0, 1.0) if on_floor else 0.0
	_run = lerpf(_run, run_target, 1.0 - exp(-8.0 * delta))
	_walk_phase += delta * 9.0 * _walk_amount * (1.0 + 0.4 * _run)
	if speed01 > 0.05 or not on_floor:
		_cancel_idle()


## Arrodillarse (al abrir el inventario): una rodilla en el suelo, mirando hacia abajo.
func set_kneeling(on: bool) -> void:
	_kneeling = on
	if on:
		_cancel_idle()


## Cruzando hojas: las manos delante de la cara, apartando las ramas.
func set_in_leaves(on: bool) -> void:
	_in_leaves = on
	if on:
		_cancel_idle()


## Agacharse a trabajar con las manos (fabricar en el suelo).
func set_working(on: bool) -> void:
	_working = on
	if on:
		_cancel_idle()


## Solo para capturas: congela una acción ("estirarse", "voltereta"... o "andar") en el instante t (0..1).
func debug_freeze_action(action: String, t: float) -> void:
	_action = action
	_action_t = t
	_frozen = true


func _cancel_idle() -> void:
	_idle_time = 0.0
	if not _frozen:
		_action = ""


func _process(delta: float) -> void:
	if _root == null:
		return
	_time += delta
	_swing = maxf(_swing - delta * 4.5, 0.0)
	_update_blink(delta)

	# Acciones de reposo largo.
	if not _frozen:
		_idle_time += delta
		if _action == "" and _idle_time > IDLE_ACTION_DELAY:
			var names := ACTIONS.keys()
			_action = names[_rng.randi() % names.size()]
			_action_t = 0.0
		if _action != "":
			_action_t += delta / float(ACTIONS[_action])
			if _action_t >= 1.0:
				_action = ""
				_idle_time = IDLE_ACTION_DELAY - _rng.randf_range(6.0, 12.0)  # la siguiente, en un rato


	if _frozen and _action == "andar":  # solo capturas: paso congelado (t = fase del paso)
		_walk_amount = 1.0
		_walk_phase = _action_t * TAU

	# --- Pose base: andar + reposo (respiración y balanceo) ---
	# Ángulos en X: positivo = la extremidad va hacia delante (el cuerpo mira a -Z). Rodillas
	# en negativo (el pie va hacia atrás) y codos en positivo (la mano va hacia delante).
	var walk := _walk_amount
	var phase := _walk_phase
	var stride := sin(phase) * (0.7 + 0.3 * _run) * walk       # muslo izquierdo (el derecho, opuesto)
	var arm_swing := sin(phase - 0.25) * (0.6 + 0.4 * _run) * walk  # los brazos van un poco por detrás
	var lift_l := maxf(0.0, cos(phase)) * walk                # la pierna izquierda avanza (se dobla)
	var lift_r := maxf(0.0, -cos(phase)) * walk
	var bounce := (absf(cos(phase)) - 0.5) * 0.035 * K * walk     # sube y baja dos veces por paso
	var rest := 1.0 - walk
	var breath := sin(_time * 2.2) * rest                     # ~3 respiraciones cada 8 s
	var sway := sin(_time * 0.9) * rest                       # balanceo lento de lado a lado
	var s := sin(_swing * PI)

	var pose := {
		"root_y": (breath * 0.006 - 0.015 * walk) * K + bounce,
		# Al andar: inclinación hacia delante, giro de caderas con cada paso y vaivén lateral.
		"root_rot": Vector3((-0.06 - 0.12 * _run) * walk, sin(phase) * 0.12 * walk, sway * 0.025 + sin(phase) * 0.03 * walk),
		# La cabeza compensa el giro de caderas (mira al frente) y sigue hacia dónde se apunta.
		"head": Vector3(clampf(_look_pitch, -0.9, 0.7) + breath * 0.02,
			sway * 0.05 - sin(phase) * 0.1 * walk, -sway * 0.02),
		# Brazo derecho: sostiene el bloque con el codo doblado; al golpear, el brazo sube y el
		# codo se estira hacia el bloque.
		"arm_r": Vector3(-arm_swing * 0.6 + 0.15 + s * 1.15, s * 0.3, -s * 0.15 + 0.05 * rest + breath * 0.015 + 0.04 * walk),
		"elbow_r": 0.75 - s * 0.55,
		# Brazo izquierdo: balanceo natural; el codo se dobla más cuando va hacia delante.
		"arm_l": Vector3(arm_swing, 0.0, -0.05 * rest - breath * 0.015 - 0.04 * walk),
		"elbow_l": 0.15 + 0.2 * walk + 0.55 * maxf(0.0, arm_swing),
		"leg_r": Vector3(-stride, 0.0, 0.0),
		"knee_r": -1.15 * lift_r - 0.08 * walk - 0.04,
		"leg_l": Vector3(stride, 0.0, 0.0),
		"knee_l": -1.15 * lift_l - 0.08 * walk - 0.04,
	}
	if ACTIONS.has(_action):
		_blend_action(pose)
	_kneel = move_toward(_kneel, 1.0 if _kneeling else 0.0, delta * 3.0)
	if _kneel > 0.0:
		_kneel_pose(pose, smoothstep(0.0, 1.0, _kneel))
	_leaves = move_toward(_leaves, 1.0 if _in_leaves else 0.0, delta * 5.0)
	if _leaves > 0.0:
		_leaves_pose(pose, smoothstep(0.0, 1.0, _leaves))
	_work = move_toward(_work, 1.0 if _working else 0.0, delta * 4.0)
	if _work > 0.0:
		_work_pose(pose, _work)

	# Inercia: cada articulación persigue su pose objetivo en vez de saltar a ella; quita la
	# sensación "robótica" de las fórmulas puras.
	if _frozen or _smoothed.is_empty():
		_smoothed = pose
	else:
		var k := 1.0 - exp(-SMOOTHING * delta)
		for key in pose:
			_smoothed[key] = _mix(_smoothed[key], pose[key], k)
	_apply(_smoothed)


func _apply(pose: Dictionary) -> void:
	_root.position = Vector3(0, HIP_HEIGHT + float(pose["root_y"]), 0)
	_root.rotation = pose["root_rot"]
	_head.rotation = pose["head"]
	_arm_right.rotation = pose["arm_r"]
	_arm_left.rotation = pose["arm_l"]
	_leg_right.rotation = pose["leg_r"]
	_leg_left.rotation = pose["leg_l"]
	_bend(_arm_right, pose["elbow_r"])
	_bend(_arm_left, pose["elbow_l"])
	_bend(_leg_right, pose["knee_r"])
	_bend(_leg_left, pose["knee_l"])


func _bend(limb: Node3D, angle: float) -> void:
	(limb.get_node("lower") as Node3D).rotation.x = angle


func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_lids.visible = true
		if _blink_timer <= -0.12:  # ojos cerrados 0,12 s
			_lids.visible = false
			_blink_timer = _rng.randf_range(2.5, 6.0)


# ------------------------------------------------------------------ acciones de reposo largo

## De rodillas: la pierna derecha con la rodilla en el suelo, la izquierda delante en ángulo
## recto; el cuerpo algo inclinado y las manos sobre la rodilla.
func _kneel_pose(pose: Dictionary, w: float) -> void:
	var target := {
		"root_y": -0.3 * K,
		"root_rot": Vector3(-0.12, 0.0, 0.0),
		"head": Vector3(-0.3, 0.0, 0.0),
		"leg_l": Vector3(1.45, 0.0, -0.05),
		"knee_l": -1.45,
		"leg_r": Vector3(-0.15, 0.0, 0.08),
		"knee_r": -1.5,
		"arm_l": Vector3(0.55, 0.0, -0.08),
		"elbow_l": 0.7,
		"arm_r": Vector3(0.45, 0.0, 0.1),
		"elbow_r": 0.6,
	}
	for key in target:
		pose[key] = _mix(pose[key], target[key], w)


## En cuclillas, inclinado hacia delante, con las manos trabajando en el suelo por turnos.
func _work_pose(pose: Dictionary, w: float) -> void:
	var a := sin(_time * 8.0)
	var target := {
		"root_y": -0.27 * K,
		"root_rot": Vector3(-0.5, 0.0, 0.0),
		"head": Vector3(-0.45, 0.0, 0.0),
		"leg_r": Vector3(1.4, 0.0, 0.1),
		"leg_l": Vector3(1.4, 0.0, -0.1),
		"knee_r": -1.75,
		"knee_l": -1.75,
		"arm_r": Vector3(1.0 + 0.3 * a, 0.0, 0.12),
		"elbow_r": 0.55 - 0.35 * a,
		"arm_l": Vector3(1.0 - 0.3 * a, 0.0, -0.12),
		"elbow_l": 0.55 + 0.35 * a,
	}
	if _kneeling:  # de rodillas: las piernas se quedan como están; trabajan los brazos
		for key in ["root_y", "leg_r", "leg_l", "knee_r", "knee_l"]:
			target.erase(key)
		target["root_rot"] = Vector3(-0.3, 0.0, 0.0)
	for key in target:
		pose[key] = _mix(pose[key], target[key], w)


## Brazos levantados delante de la cara, codos doblados, apartando ramas a un lado y a otro.
func _leaves_pose(pose: Dictionary, w: float) -> void:
	var a := sin(_time * 5.0)
	var target := {
		"arm_r": Vector3(1.25 + 0.12 * a, 0.0, -0.45 + 0.15 * a),
		"elbow_r": 1.5 - 0.2 * a,
		"arm_l": Vector3(1.25 - 0.12 * a, 0.0, 0.45 + 0.15 * a),
		"elbow_l": 1.5 + 0.2 * a,
		"head": Vector3(-0.15, 0.0, 0.0),
	}
	for key in target:
		pose[key] = _mix(pose[key], target[key], w)


func _blend_action(pose: Dictionary) -> void:
	var t := clampf(_action_t, 0.0, 1.0)
	# Entrada y salida suaves para no saltar de golpe desde/hacia la pose de reposo.
	var w := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.88, 1.0, t))
	var target := pose.duplicate()
	match _action:
		"estirarse":
			# Brazos arriba y estirados, cabeza atrás, un ligero vaivén en el punto más alto.
			var up := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.75, 1.0, t))
			var wobble := sin(t * TAU * 2.0) * 0.08 * up
			target["arm_r"] = Vector3(2.9 * up, 0.0, 0.25 * up + wobble)
			target["arm_l"] = Vector3(2.9 * up, 0.0, -0.25 * up - wobble)
			target["elbow_r"] = 0.0
			target["elbow_l"] = 0.0
			target["head"] = Vector3(0.45 * up, 0.0, 0.0)
			target["root_rot"] = Vector3(0.08 * up, 0.0, wobble * 0.5)
			target["root_y"] = 0.02 * K * up
		"sentadillas":
			# Dos sentadillas de verdad: muslos horizontales, espinillas verticales y brazos al frente.
			var p := 0.5 - 0.5 * cos(t * TAU * 2.0)
			target["leg_r"] = Vector3(1.4 * p, 0.0, 0.0)
			target["leg_l"] = Vector3(1.4 * p, 0.0, 0.0)
			target["knee_r"] = -1.75 * p
			target["knee_l"] = -1.75 * p
			target["arm_r"] = Vector3(1.5 * p, 0.0, 0.0)
			target["arm_l"] = Vector3(1.5 * p, 0.0, 0.0)
			target["elbow_r"] = 0.1
			target["elbow_l"] = 0.1
			target["root_y"] = -0.27 * K * p
			target["root_rot"] = Vector3(-0.32 * p, 0.0, 0.0)
		"salto":
			_jump_pose(target, t, 0.55 * K, 0.0)
		"voltereta":
			_jump_pose(target, t, 0.9 * K, TAU)
	for key in pose:
		pose[key] = _mix(pose[key], target[key], w)


## Salto con agachada previa y aterrizaje. spin = vueltas hacia atrás (radianes) en el aire.
func _jump_pose(target: Dictionary, t: float, height: float, spin: float) -> void:
	const TAKE_OFF := 0.2
	const LAND := 0.82
	var crouch := 0.0
	var air := 0.0
	if t < TAKE_OFF:
		crouch = sin(t / TAKE_OFF * PI)
	elif t < LAND:
		air = (t - TAKE_OFF) / (LAND - TAKE_OFF)
	else:
		crouch = sin((t - LAND) / (1.0 - LAND) * PI) * 0.8
	var lift := sin(air * PI) * height
	var tuck := sin(air * PI) if spin > 0.0 else 0.35 * sin(air * PI)  # piernas encogidas en el aire
	target["root_y"] = lift - 0.17 * K * crouch
	target["root_rot"] = Vector3(smoothstep(0.1, 0.9, air) * spin - 0.25 * crouch, 0.0, 0.0)
	var legs := 0.85 * crouch + 1.5 * tuck
	var knees := -1.4 * crouch - 2.0 * tuck
	target["leg_r"] = Vector3(legs, 0.0, 0.0)
	target["leg_l"] = Vector3(legs, 0.0, 0.0)
	target["knee_r"] = knees
	target["knee_l"] = knees
	var arms := 2.8 * sin(air * PI) - 0.5 * crouch  # brazos atrás al agacharse, arriba al saltar
	target["arm_r"] = Vector3(arms, 0.0, 0.15)
	target["arm_l"] = Vector3(arms, 0.0, -0.15)
	target["elbow_r"] = 0.25 + 0.5 * tuck
	target["elbow_l"] = 0.25 + 0.5 * tuck


func _mix(a: Variant, b: Variant, w: float) -> Variant:
	if a is Vector3:
		return (a as Vector3).lerp(b as Vector3, w)
	return lerpf(float(a), float(b), w)
