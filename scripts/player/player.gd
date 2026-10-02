extends CharacterBody3D
class_name Player

signal creative_changed(enabled: bool)
## Cambia cuántos huecos hay (al ponerse o quitarse ropa o la mochila, o al cambiar de modo).
signal inventory_layout_changed
## Clic derecho sobre un bloque que se usa (un cofre...) en vez de colocar encima.
signal block_used(cell: Vector3i, block_id: int)
signal block_broken(cell: Vector3i, block_id: int)
## Mensaje corto para el jugador ("Has aprendido...").
signal notice(text: String)
signal recipe_learned(recipe_id: String)
## Ha encontrado el diario del capitán (se lee con J).
signal journal_found
## Jugador: camina, salta, vuela, mira con el ratón y rompe/coloca bloques.
## Cámara en primera o tercera persona (tecla V). Encuentra el VoxelTerrain por el grupo
## "voxel_terrain".
##
## Jerarquía:  Player (gira a izquierda/derecha)
##               ├─ PlayerAvatar (muñeco; solo visible en tercera persona)
##               └─ head (a la altura de los ojos; gira arriba/abajo)
##                    ├─ observadores del terreno
##                    └─ SpringArm3D (0 m en primera persona, ~3 m en tercera)
##                         └─ Camera3D
##                              └─ HeldBlock (bloque en la mano; solo en primera persona)

# Medidas y velocidades pensadas EN BLOQUES (como en Minecraft) y pasadas a metros con B.
# El tamaño del personaje se cambia en SkinModel.PLAYER_HEIGHT_BLOCKS.
const B := SkinModel.BLOCK_SIZE  # metros por bloque
const BODY_HEIGHT := SkinModel.BODY_HEIGHT       # 1,8 bloques (como Steve)
const BODY_RADIUS := 0.3 * B * SkinModel.PLAYER_HEIGHT_BLOCKS / 1.8  # 0,6 bloques de ancho
const EYE_HEIGHT := BODY_HEIGHT * 0.9            # ojos a 1,62 bloques
const SPEED := 4.3 * B          # andando: 4,3 bloques/s
const SPRINT_SPEED := 6.5 * B   # corriendo (doble toque de W): 6,5 bloques/s
const SPRINT_DOUBLE_TAP := 0.3  # segundos máximos entre los dos toques de W
const SPRINT_FOV_BOOST := 8.0   # grados que se abre la vista al correr
const GRAVITY := 32.0 * B       # 32 bloques/s²
const JUMP_VELOCITY := 9.0 * B  # salto de ~1,25 bloques

const REACH := 6.0 * B          # alcance: 6 bloques desde los ojos
const STEP_HEIGHT := 1.1 * B    # sube solo escalones de 1 bloque; para 2 hay que saltar
const STEP_FORWARD := 0.4 * B   # cuánto avanza al subir un escalón (para quedar bien encima)
const FLY_SPEED := 18.0
const FLY_SPEED_FAST := 60.0
const CAMERA_CATCH_UP := 14.0      # rapidez con la que la cámara alcanza al cuerpo tras un escalón
const THIRD_PERSON_DISTANCE := 4.0 * B  # distancia inicial de la cámara en tercera persona (4 bloques)
const MIN_CAMERA_DISTANCE := 1.5 * B
const MAX_CAMERA_DISTANCE := 14.0 * B
const ZOOM_MOUSE_SPEED := 0.02 * B  # por píxel de ratón (manteniendo V)
const ZOOM_WHEEL_STEP := 0.8 * B    # por paso de rueda (manteniendo V)
const THIRD_PERSON_SHOULDER := 0.6 * B  # desplazamiento a la derecha (vista "por encima del hombro")
const SWIM_SPEED := 3.0 * B        # velocidad horizontal en el agua
const SWIM_UP_SPEED := 4.0 * B     # nadar hacia arriba (Espacio con la cabeza bajo el agua)
const WATER_GRAVITY := 6.0 * B     # en el agua se hunde despacio...
const MAX_SINK_SPEED := 3.0 * B    # ...y sin pasar de esta velocidad

## Radio (en voxels) de terreno detallado alrededor del jugador. Lo fija main.gd.
var near_view_voxels := 320

var _flying := false
var _third_person := false
var _front_view := false        # tercera persona mirando al personaje de frente
var _camera_distance := THIRD_PERSON_DISTANCE
var _zoomed_while_v := false
var _sprinting := false
var _last_w_press := -10.0
var _orbit := Vector2.ZERO       # giro libre de la cámara (x = alrededor, y = arriba/abajo)
var _debug_camera_yaw := 0.0     # solo capturas de prueba (vista de perfil)
var _spawn_point := Vector3.ZERO
var _waiting_for_ground := true  # no aplicar gravedad hasta que exista suelo con colisión
var _camera_lag := Vector3.ZERO  # desfase de la cámara (en el mundo) que se va suavizando
var _step_debt := 0.0            # metros adelantados al subir escalones, pendientes de descontar
var _pitch := 0.0
var _hotbar_index := 0

## Inventario del jugador (36 huecos: 0-8 la barra). En modo creativo se usa otro, con todos
## los bloques e infinitos.
var inventory := Inventory.new(36)
var creative_inventory := Inventory.new(36)
var creative := false
## Ropa y mochila puestas: id del objeto o "" (dan bolsillos e inventario, ver hotbar_size).
var equipment := {"shirt": "", "pants": "", "belt": "", "backpack": ""}
const BASE_HOTBAR := 3    # huecos de la barra sin ropa con bolsillos
const BASE_STORAGE := 9   # huecos de inventario sin mochila
## Recetas de fabricar en el suelo que conoce (se dibujan en el diario del capitán).
var known_recipes: Array = GroundRecipes.KNOWN_AT_START.duplicate()
var ground: GroundCrafting   # objetos dejados en el suelo (lo pone main.gd)
var has_journal := false     # lleva el diario del capitán
var _working := false        # agachado fabricando
var _work_swing := 0.0
var _crouch := 0.0           # 0..1: cuánto baja la vista al agacharse
var _step_distance := 0.0     # metros andados desde el último paso (para el sonido)
var _was_in_air := false
var _breaking := false        # manteniendo el clic izquierdo sobre un bloque
var _break_cell := Vector3i(0, -99999, 0)
var _break_progress := 0.0   # 0..1
var _break_swing := 0.0
var _cracks: BlockCracks
var debug_cracks := false
var _place_ghost: MeshInstance3D   # dónde caería el objeto de la mano al dejarlo (G)
var _place_ghost_id := ""
var _hand_light: OmniLight3D  # luz de la antorcha que se lleva en la mano
var _hand_light_time := 0.0
## true mientras hay una pantalla abierta (inventario, cofre...): no se mueve ni mira.
var ui_open := false
var _captured := true

var _head: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _held: HeldBlock
var _avatar: PlayerAvatar
var _highlight: MeshInstance3D
var _terrain: VoxelTerrain
var _generator: IslandGenerator
var _tool: VoxelTool
var _sea_y := -INF               # altura (mundo) de la superficie del mar
var _head_underwater := false


func _ready() -> void:
	# Colisión (cápsula).
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = BODY_HEIGHT
	capsule.radius = BODY_RADIUS
	shape.shape = capsule
	shape.position = Vector3(0, BODY_HEIGHT * 0.5, 0)
	add_child(shape)

	_avatar = PlayerAvatar.new()
	add_child(_avatar)

	_head = Node3D.new()
	_head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(_head)

	# Brazo de cámara: en tercera persona se aleja hacia atrás y, si choca con el terreno,
	# se acorta para que la cámara nunca quede dentro de una pared.
	_spring = SpringArm3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_spring.shape = probe
	_spring.spring_length = 0.0
	_spring.add_excluded_object(get_rid())
	_head.add_child(_spring)

	_camera = Camera3D.new()
	_spring.add_child(_camera)
	_camera.current = true

	_held = HeldBlock.new()
	_camera.add_child(_held)

	# Skin del jugador (formato Minecraft): la usan el cuerpo y el brazo en primera persona.
	update_appearance()

	# Observadores del terreno: uno amplio solo para dibujar (la zona detallada) y otro
	# pequeño solo para las colisiones, que son caras de calcular.
	var visual_viewer := VoxelViewer.new()
	visual_viewer.view_distance = near_view_voxels
	visual_viewer.view_distance_vertical_ratio = 2.5  # que no haya huecos al volar alto
	visual_viewer.requires_collisions = false
	_head.add_child(visual_viewer)

	var collision_viewer := VoxelViewer.new()
	collision_viewer.view_distance = 48
	collision_viewer.requires_visuals = false
	_head.add_child(collision_viewer)

	_highlight = _make_highlight()
	add_child(_highlight)
	_cracks = BlockCracks.new()
	add_child(_cracks)
	_hand_light = TorchLight.make_light()
	_hand_light.position = Vector3(0.25, EYE_HEIGHT - 0.25, -0.3)
	_hand_light.visible = false
	add_child(_hand_light)
	_place_ghost = MeshInstance3D.new()
	_place_ghost.top_level = true
	_place_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_place_ghost.visible = false
	add_child(_place_ghost)

	var terrains := get_tree().get_nodes_in_group("voxel_terrain")
	if terrains.size() > 0:
		_terrain = terrains[0] as VoxelTerrain
		_generator = _terrain.generator as IslandGenerator
		_tool = _terrain.get_voxel_tool()
		_tool.channel = VoxelBuffer.CHANNEL_TYPE
		_sea_y = IslandGenerator.SEA_LEVEL * _terrain.scale.x - 0.08

	add_to_group("player")
	_fill_creative_inventory()
	inventory.changed.connect(_refresh_held)
	creative_inventory.changed.connect(_refresh_held)
	_select_slot(0)
	_apply_camera_mode()
	_spawn_point = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ entrada

func _input(event: InputEvent) -> void:
	if ui_open:
		return
	if event is InputEventMouseMotion and _captured:
		var motion := event as InputEventMouseMotion
		if Input.is_key_pressed(KEY_V):
			# Manteniendo V, ratón adelante/atrás acerca o aleja la cámara (como en Skyrim).
			_zoom_camera(motion.relative.y * ZOOM_MOUSE_SPEED)
			return
		if _is_orbiting():
			# Girar la cámara alrededor del personaje sin moverlo (para ver la skin).
			_orbit.x -= motion.relative.x * Settings.sensitivity
			_orbit.y = clampf(_orbit.y - motion.relative.y * Settings.sensitivity, -1.2, 1.2)
			return
		rotate_y(-motion.relative.x * Settings.sensitivity)
		var dy := -motion.relative.y if Settings.invert_y else motion.relative.y
		_pitch = clampf(_pitch - dy * Settings.sensitivity, -1.5, 1.5)
		_head.rotation = Vector3(_pitch, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if not _captured:
			_set_captured(true)  # un clic con el ratón suelto lo vuelve a capturar
			return
		var zooming := Input.is_key_pressed(KEY_V)
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if creative:
					_edit_block(false)  # en creativo se rompe al momento
				else:
					_start_breaking()
			MOUSE_BUTTON_RIGHT:
				_edit_block(true)
			MOUSE_BUTTON_WHEEL_UP:
				if zooming:
					_zoom_camera(-ZOOM_WHEEL_STEP)
				else:
					_select_slot(_hotbar_index - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if zooming:
					_zoom_camera(ZOOM_WHEEL_STEP)
				else:
					_select_slot(_hotbar_index + 1)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		if key.keycode == KEY_V:
			if key.pressed:
				_zoomed_while_v = false
			elif not _zoomed_while_v:
				_cycle_camera_mode()  # solo si se soltó V sin haber hecho zoom
			return
		if not key.pressed:
			return
		if key.keycode == KEY_W:
			# Doble toque de W rápido = correr (como en Minecraft).
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_w_press < SPRINT_DOUBLE_TAP:
				_sprinting = true
			_last_w_press = now
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			if key.keycode - KEY_1 < hotbar_size():
				_select_slot(key.keycode - KEY_1)
		elif key.keycode == KEY_Q:
			_throw_held(key.ctrl_pressed)
		elif key.keycode == KEY_G:
			_place_on_ground(_target())
		elif key.keycode == KEY_C:
			set_creative(not creative)
		elif key.keycode == KEY_F:
			_flying = not _flying
			velocity = Vector3.ZERO
		elif key.keycode == KEY_ESCAPE:
			_set_captured(not _captured)


func _cycle_camera_mode() -> void:
	# Primera persona -> tercera por detrás -> tercera de frente -> primera persona.
	if not _third_person:
		_third_person = true
		_front_view = false
	elif not _front_view:
		_front_view = true
	else:
		_third_person = false
		_front_view = false
	_apply_camera_mode()


## Acerca (negativo) o aleja (positivo) la cámara de tercera persona. Acercarse del todo pasa a
## primera persona; alejarse desde primera persona sale a tercera.
func _zoom_camera(amount: float) -> void:
	_zoomed_while_v = true
	if not _third_person:
		if amount <= 0.0:
			return
		_third_person = true
		_front_view = false
		_camera_distance = MIN_CAMERA_DISTANCE  # sale a tercera persona y sigue alejándose
		_apply_camera_mode()
	_camera_distance += amount
	if _camera_distance < MIN_CAMERA_DISTANCE - 0.3:
		_third_person = false
		_front_view = false
		_camera_distance = MIN_CAMERA_DISTANCE
		_apply_camera_mode()
	_camera_distance = clampf(_camera_distance, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)


func _is_orbiting() -> bool:
	return _third_person and (Input.is_key_pressed(KEY_ALT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE))


func _set_captured(captured: bool) -> void:
	_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _select_slot(index: int) -> void:
	_hotbar_index = posmod(index, hotbar_size())
	_refresh_held()


## Actualiza el bloque de la mano (primera y tercera persona) con el hueco seleccionado.
func _refresh_held() -> void:
	var stack := active_inventory().get_slot(_hotbar_index)
	var id: String = "" if stack.is_empty() else stack["id"]
	_held.set_item(id)
	_avatar.set_item(id)
	if _hand_light != null:
		_hand_light.visible = id == "torch"


func _apply_camera_mode() -> void:
	# En primera persona la cámara no dibuja el muñeco (capa 2), pero su sombra sí se ve.
	_held.visible = not _third_person
	if _third_person:
		_camera.cull_mask = 0xFFFFF
	else:
		_camera.cull_mask = 0xFFFFF & ~PlayerAvatar.LAYER


# ------------------------------------------------------------------ movimiento

func _physics_process(delta: float) -> void:
	if _waiting_for_ground:
		_wait_for_ground()
		return
	if _flying:
		_fly(delta)
		_avatar.update_walk(0.0, false, delta)
		_held.update_walk(0.0, delta)
		return

	var feet_wet := _in_water(global_position + Vector3.UP * BODY_HEIGHT * 0.28)
	_head_underwater = _in_water(_head.global_position)

	if feet_wet:
		# Nadando: se hunde despacio; Espacio sube (o, en la superficie, impulsa para salir).
		velocity.y = maxf(velocity.y - WATER_GRAVITY * delta, -MAX_SINK_SPEED)
		if _key(KEY_SPACE):
			velocity.y = SWIM_UP_SPEED if _head_underwater else maxf(velocity.y, JUMP_VELOCITY * 0.75)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta

	var dir := Vector3.ZERO
	if _key(KEY_W): dir -= transform.basis.z
	if _key(KEY_S): dir += transform.basis.z
	if _key(KEY_A): dir -= transform.basis.x
	if _key(KEY_D): dir += transform.basis.x
	dir.y = 0.0
	dir = dir.normalized()
	# Correr dura mientras se mantenga W (y no en el agua ni yendo hacia atrás).
	if not _key(KEY_W) or feet_wet:
		_sprinting = false
	var speed := SWIM_SPEED if feet_wet else (SPRINT_SPEED if _sprinting else SPEED)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_pay_step_debt(delta)

	if _key(KEY_SPACE) and is_on_floor() and not feet_wet:
		velocity.y = JUMP_VELOCITY

	# La dirección deseada se guarda ANTES de mover: al chocar con la pared, move_and_slide
	# anula la velocidad hacia ella y ya no sabríamos hacia dónde quería ir el jugador.
	var desired := Vector3(velocity.x, 0.0, velocity.z)
	var was_on_floor := is_on_floor()
	move_and_slide()
	if was_on_floor and desired.length() > 0.1:
		_try_step_up(desired.normalized())

	var speed01 := Vector2(velocity.x, velocity.z).length() / SPEED
	_avatar.update_walk(speed01, is_on_floor(), delta)
	_footsteps(delta, feet_wet)
	_held.update_walk(speed01 if is_on_floor() else 0.0, delta)

	# Red de seguridad: si se cae del mundo, reaparece arriba.
	if global_position.y < -60.0:
		global_position = _spawn_point + Vector3.UP * 2.0
		velocity = Vector3.ZERO
		_waiting_for_ground = true


func _process(delta: float) -> void:
	# Suavizado de la cámara tras subir un escalón: el desfase se reduce exponencialmente.
	if _camera_lag.length_squared() < 0.000001:
		_camera_lag = Vector3.ZERO
	else:
		_camera_lag = _camera_lag.lerp(Vector3.ZERO, 1.0 - exp(-CAMERA_CATCH_UP * delta))
	# El desfase está en coordenadas del mundo; la cabeza es hija del jugador (que gira).
	# Al trabajar en el suelo se agacha: la vista baja y la mano trabaja a golpecitos.
	_crouch = move_toward(_crouch, 1.0 if _working else 0.0, delta * 4.0)
	if _working:
		_work_swing -= delta
		if _work_swing <= 0.0:
			_held.swing()
			Sfx.play("golpe", global_position, -8.0, 0.2)
			_work_swing = 0.4
	_head.position = Vector3(0, EYE_HEIGHT, 0) + global_basis.inverse() * _camera_lag
	_head.position.y -= _crouch * BODY_HEIGHT * 0.35

	# Transición suave entre primera y tercera persona.
	var target_length := _camera_distance if _third_person else 0.0
	var target_shoulder := THIRD_PERSON_SHOULDER if _third_person and not _front_view else 0.0
	var t := 1.0 - exp(-10.0 * delta)
	_spring.spring_length = lerpf(_spring.spring_length, target_length, t)
	_spring.position.x = lerpf(_spring.position.x, target_shoulder, t)

	# Giro libre de la cámara: al soltar Alt / botón central vuelve sola a su sitio.
	if not _is_orbiting():
		_orbit = _orbit.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	var base_yaw := (PI if _front_view else 0.0) + _debug_camera_yaw
	# Orientación deseada del brazo de cámara: primero el giro horizontal y luego la inclinación
	# (orden YXZ, sin balanceo). Como cuelga de la cabeza, que ya está inclinada, se le quita esa
	# inclinación; si no, al girar la cámara de lado la inclinación se volvería un giro del horizonte.
	var desired := Basis.from_euler(Vector3(_pitch + _orbit.y, base_yaw + _orbit.x, 0.0))
	_spring.basis = _head.basis.inverse() * desired

	# Al correr la vista se abre un poco (sensación de velocidad, como en Minecraft).
	var moving := Vector2(velocity.x, velocity.z).length() > SPEED * 1.1
	var target_fov := Settings.fov + (SPRINT_FOV_BOOST if _sprinting and moving else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))

	_avatar.set_look_pitch(_pitch)
	_update_highlight()
	_update_breaking(delta)
	_update_place_ghost()
	if _hand_light.visible:
		_hand_light_time += delta
		TorchLight.flicker(_hand_light, null, _hand_light_time)


func _wait_for_ground() -> void:
	# Mientras la colisión del terreno se termina de crear, el jugador flota quieto.
	# En cuanto un rayo hacia abajo encuentra suelo, se coloca encima y empieza la física.
	var from := global_position + Vector3.UP * 20.0
	var query := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * 60.0)
	query.exclude = [get_rid()]  # que el rayo no choque con el propio jugador
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var ground: Vector3 = hit.position
	global_position = ground + Vector3.UP * 0.1
	_spawn_point = global_position
	velocity = Vector3.ZERO
	_waiting_for_ground = false


func _fly(_delta: float) -> void:
	# Vuelo libre en la dirección de la cámara (W/S), lateral (A/D) y vertical (Espacio/Ctrl).
	var cam := _camera.global_transform.basis
	var dir := Vector3.ZERO
	if _key(KEY_W): dir -= cam.z
	if _key(KEY_S): dir += cam.z
	if _key(KEY_A): dir -= cam.x
	if _key(KEY_D): dir += cam.x
	if _key(KEY_SPACE): dir += Vector3.UP
	if _key(KEY_CTRL): dir -= Vector3.UP
	var speed := FLY_SPEED_FAST if _key(KEY_SHIFT) else FLY_SPEED
	velocity = dir.normalized() * speed
	move_and_slide()


func _try_step_up(dir: Vector3) -> void:
	# Si vamos contra una pared baja de ≤1 bloque, nos subimos solos.
	var probe := dir * STEP_FORWARD
	if not test_move(global_transform, probe):
		return  # nada bloqueando al frente
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT):
		return  # hay techo encima: no cabe
	var lifted := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(lifted, probe):
		return  # la pared es más alta que un escalón: hay que saltar
	# Hay hueco un escalón más arriba: subir, avanzar hasta quedar encima y apoyarse.
	# Se avanza lo bastante para que la base redondeada del cuerpo quede sobre el escalón
	# y no en su borde (si no, resbalaría hacia atrás).
	var before := global_position
	global_position += Vector3.UP * STEP_HEIGHT + probe
	move_and_collide(Vector3.DOWN * STEP_HEIGHT)
	# El cuerpo ya está arriba, pero la cámara se queda donde estaba y lo alcanza poco a poco
	# (ver _process): así subir un escalón se siente suave y no como un golpe.
	_camera_lag += before - global_position
	# Ese avance extra se "devuelve" andando un poco menos los siguientes instantes: si no, subir
	# una colina escalón a escalón era más rápido que andar en llano.
	_step_debt += probe.length()


# ------------------------------------------------------------------ romper y colocar

## Bloque al que apunta el centro de la pantalla: {"voxel": Vector3i, "place": Vector3i}
## (el bloque golpeado y la celda vacía junto a la cara golpeada), o vacío si no hay ninguno.
func _target() -> Dictionary:
	if _terrain == null:
		return {}
	var from := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var to := from + forward * (REACH + _spring.spring_length)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]  # en tercera persona el rayo pasa junto al propio jugador
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var hit_point: Vector3 = result.position
	if hit_point.distance_to(_head.global_position) > REACH:
		return {}  # demasiado lejos de los ojos del personaje
	var hit_normal: Vector3 = result.normal
	if result.collider is PlacedItem:
		return {"item": result.collider, "point": hit_point, "normal": hit_normal}
	var half_voxel: float = _terrain.scale.x * 0.5
	return {
		"point": hit_point,
		"normal": hit_normal,
		"voxel": _world_to_voxel(hit_point - hit_normal * half_voxel),  # hacia dentro: el bloque
		"place": _world_to_voxel(hit_point + hit_normal * half_voxel),  # hacia fuera: el hueco
	}


func _edit_block(place: bool) -> void:
	_held.swing()
	_avatar.swing()
	if place and _read_note():
		return
	var target := _target()
	if target.is_empty():
		return
	if target.has("item"):
		if place:
			_place_on_ground(target)  # otro objeto al lado del que se apunta
		else:
			_pick_up_placed(target["item"], Input.is_key_pressed(KEY_SHIFT))
		return
	var tool := _terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	if place:
		var used: Vector3i = target["voxel"]
		var used_id := tool.get_voxel(used)
		if used_id == IslandGenerator.CHEST:
			block_used.emit(used, used_id)  # abrir el cofre en vez de colocar encima
			return
		var cell: Vector3i = target["place"]
		var id := get_current_block()
		if id < 0:
			_place_on_ground(target)  # un objeto que no es bloque se deja en el suelo
			return
		if id != IslandGenerator.WATER and _overlaps_body(cell):
			return  # no colocar un bloque dentro de uno mismo
		tool.set_voxel(cell, id)
		Sfx.play("colocar", _terrain.to_global(Vector3(cell)) + Vector3.ONE * _terrain.scale.x * 0.5)
		if not creative:
			inventory.take(_hotbar_index, 1)
	else:
		var cell: Vector3i = target["voxel"]
		var broken := tool.get_voxel(cell)
		tool.set_voxel(cell, IslandGenerator.AIR)
		var size := _terrain.scale.x
		var center := _terrain.to_global(Vector3(cell)) + Vector3.ONE * size * 0.5
		_spawn_break_particles(center, broken)
		Sfx.play("romper_" + Sfx.material_of(broken), center)
		# En supervivencia, el bloque roto cae al suelo como objeto.
		var drop := ItemDB.drop_of(broken)
		if not creative and drop != "":
			ItemDrop.spawn(get_parent(), center - Vector3.UP * size * 0.4, drop, 1)
		block_broken.emit(cell, broken)


func _spawn_break_particles(center: Vector3, block_id: int) -> void:
	# Trocitos del color del bloque que saltan y caen al romperlo.
	var particles := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.07
	chunk.material = Blocks.make_material(block_id)
	particles.mesh = chunk
	particles.amount = 14
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3.ONE * 0.18
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.8
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	get_parent().add_child(particles)
	particles.global_position = center
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


func _overlaps_body(cell: Vector3i) -> bool:
	# ¿La celda del voxel se solapa con la caja que ocupa el cuerpo del jugador?
	var size := _terrain.scale.x
	var cell_box := AABB(_terrain.to_global(Vector3(cell)), Vector3.ONE * size)
	var body_box := AABB(global_position - Vector3(BODY_RADIUS, 0, BODY_RADIUS),
		Vector3(BODY_RADIUS * 2.0, BODY_HEIGHT, BODY_RADIUS * 2.0))
	return cell_box.grow(-0.01).intersects(body_box)


func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local := _terrain.to_local(world_pos)
	return Vector3i(floori(local.x), floori(local.y), floori(local.z))


# ------------------------------------------------------------------ recuadro del bloque apuntado

func _make_highlight() -> MeshInstance3D:
	# Las 12 aristas de un cubo de 1x1x1, en líneas oscuras.
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var lines := PackedVector3Array()
	for edge in edges:
		lines.append(corners[edge[0]])
		lines.append(corners[edge[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.05, 0.05, 0.05)

	var highlight := MeshInstance3D.new()
	highlight.mesh = mesh
	highlight.material_override = material
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.top_level = true  # se coloca en coordenadas del mundo, no relativo al jugador
	highlight.visible = false
	return highlight


func _update_highlight() -> void:
	var target := _target() if _captured else {}
	if target.is_empty():
		_highlight.visible = false
		return
	if target.has("item"):
		# Un objeto dejado en el suelo: recuadro ajustado a su tamaño.
		var item: PlacedItem = target["item"]
		var box := item.get_box()
		_highlight.global_transform = Transform3D(item.global_basis * Basis.from_scale(box.size),
			item.global_transform * box.position)
		_highlight.visible = true
		return
	var cell: Vector3i = target["voxel"]
	var size := _terrain.scale.x
	var grow := 0.004  # un pelín más grande que el bloque para que no parpadee con sus caras
	_highlight.global_transform = Transform3D(
		Basis.from_scale(Vector3.ONE * (size + grow * 2.0)),
		_terrain.to_global(Vector3(cell)) - Vector3.ONE * grow)
	_highlight.visible = true


# ------------------------------------------------------------------ consultas

## Bloque del hueco seleccionado, o -1 si está vacío o no es un bloque.
func get_current_block() -> int:
	var stack := active_inventory().get_slot(_hotbar_index)
	return -1 if stack.is_empty() else ItemDB.block_of(stack["id"])


func get_hotbar_index() -> int:
	return _hotbar_index


## Inventario en uso: el normal, o el de modo creativo (todos los bloques, infinitos).
func active_inventory() -> Inventory:
	return creative_inventory if creative else inventory


## Mete objetos recogidos en el inventario (solo en los huecos desbloqueados).
## Devuelve los que no cupieron.
func pick_up(id: String, count: int) -> int:
	if id == "captain_journal":
		find_journal()  # no ocupa hueco: va siempre con el personaje
		return 0
	return inventory.add(id, count, unlocked_slots())


## ¿Cabe al menos uno de estos objetos? (para que no vuelen hacia él si va lleno)
func can_pick_up(id: String) -> bool:
	if id == "captain_journal":
		return true
	for i in unlocked_slots():
		var s := inventory.get_slot(i)
		if s.is_empty() or (s["id"] == id and int(s["count"]) < ItemDB.max_stack(id)):
			return true
	return false


func set_creative(enabled: bool) -> void:
	creative = enabled
	creative_changed.emit(enabled)
	_select_slot(_hotbar_index)
	inventory_layout_changed.emit()


func _fill_creative_inventory() -> void:
	var slot := 0
	for block in Blocks.HOTBAR:
		creative_inventory.set_slot(slot, {"id": ItemDB.item_of_block(block), "count": 1})
		slot += 1
	for id in ItemDB.BLOCK_ITEMS.keys() + ItemDB.OTHER_ITEMS.keys():
		if slot < creative_inventory.size() and creative_inventory.count_of(id) == 0:
			creative_inventory.set_slot(slot, {"id": id, "count": 1})
			slot += 1


# ------------------------------------------------------------------ ropa y bolsillos

## Huecos de la barra disponibles: 3 de base + los bolsillos de la ropa puesta (máx. 9).
func hotbar_size() -> int:
	if creative:
		return Hotbar.SLOTS
	var size := BASE_HOTBAR
	for slot in equipment:
		size += ItemDB.pockets(equipment[slot])
	return mini(size, Hotbar.SLOTS)


## Huecos de inventario disponibles: 9 de base + los de la mochila (máx. 27).
func storage_size() -> int:
	if creative:
		return inventory.size() - Hotbar.SLOTS
	var size := BASE_STORAGE
	for slot in equipment:
		size += ItemDB.storage(equipment[slot])
	return mini(size, inventory.size() - Hotbar.SLOTS)


## Índices de los huecos que se pueden usar (barra 0-8 e inventario 9-35, según la ropa).
func unlocked_slots() -> Array:
	return range(0, hotbar_size()) + range(Hotbar.SLOTS, Hotbar.SLOTS + storage_size())


## Ponerse una prenda (o la mochila). Devuelve false si no es para ese hueco o ya hay otra.
func equip(slot: String, id: String) -> bool:
	if ItemDB.wear_slot(id) != slot or equipment.get(slot, "x") != "":
		return false
	equipment[slot] = id
	_on_equipment_changed()
	return true


## ¿Se puede quitar? Solo si los huecos que deja de dar (bolsillos o mochila) están vacíos.
func can_unequip(slot: String) -> bool:
	var id: String = equipment.get(slot, "")
	if id == "":
		return false
	var before := unlocked_slots()
	equipment[slot] = ""
	var after := unlocked_slots()
	equipment[slot] = id
	for i in before:
		if not after.has(i) and not inventory.is_empty_slot(i):
			return false
	return true


## Quitarse una prenda: devuelve su id ("" si no se puede).
func unequip(slot: String) -> String:
	if not can_unequip(slot):
		return ""
	var id: String = equipment[slot]
	equipment[slot] = ""
	_on_equipment_changed()
	return id


## Para cargar la partida: pone el equipo guardado (ignora lo que no encaje en su hueco).
func set_equipment(data: Dictionary) -> void:
	for slot in equipment:
		var id := str(data.get(slot, ""))
		equipment[slot] = id if ItemDB.wear_slot(id) == slot else ""
	_on_equipment_changed()


func _on_equipment_changed() -> void:
	_select_slot(_hotbar_index)
	update_appearance()
	inventory_layout_changed.emit()


## Pinta la skin según la ropa que lleva (salvo que haya una skin propia en user://skins) y
## muestra u oculta la mochila.
func update_appearance() -> void:
	var options := SkinComposer.DEFAULT_OPTIONS.duplicate()
	options["shirt_style"] = "camiseta" if equipment["shirt"] != "" else "rota"
	options["pants_style"] = "largo" if equipment["pants"] != "" else "corto"
	options["belt"] = equipment["belt"] != ""
	options["straps"] = equipment["backpack"] != ""
	apply_skin(SkinComposer.load_player_skin(options), options["slim"])
	_avatar.set_backpack(equipment["backpack"])

## Cambia la skin del jugador (cuerpo y brazo). El futuro editor de personaje la usará.
func apply_skin(texture: Texture2D, slim: bool) -> void:
	_avatar.build(texture, slim)
	_held.set_skin(texture, slim)
	if _hotbar_index >= 0 and _held != null:
		_refresh_held()


func is_third_person() -> bool:
	return _third_person


## ¿Hay agua en este punto del mundo? Ríos y lagos son bloques de agua; el mar es un plano,
## y solo cuenta donde el terreno original estaba bajo el nivel del mar (un hoyo cavado en la
## playa no se llena de agua imaginaria).
func _in_water(world_pos: Vector3) -> bool:
	if _tool == null:
		return false
	var cell := _world_to_voxel(world_pos)
	var id := _tool.get_voxel(cell)
	if id == IslandGenerator.WATER:
		return true
	if world_pos.y < _sea_y and id == IslandGenerator.AIR and _generator != null:
		return _generator.get_ground_height(cell.x, cell.z) < IslandGenerator.SEA_LEVEL
	return false


func is_head_underwater() -> bool:
	return _head_underwater


## Ya está apoyado en el suelo (la colisión del terreno existe bajo sus pies).
func is_on_ground_ready() -> bool:
	return not _waiting_for_ground


## Solo para capturas de prueba: congela una animación del cuerpo ("voltereta", ...) en t (0..1).
func debug_avatar_action(action: String, t: float) -> void:
	_avatar.debug_freeze_action(action, t)


## Solo para capturas de prueba: lanza la animación de golpe (sin romper nada).
func debug_swing() -> void:
	_held.swing()
	_avatar.swing()


## Solo para capturas de prueba: coloca cámara y postura sin usar teclado ni ratón.
func debug_pose(third_person: bool, pitch: float, yaw_degrees: float, up_meters: float) -> void:
	_third_person = third_person
	_apply_camera_mode()
	_pitch = pitch
	_head.rotation = Vector3(_pitch, 0.0, 0.0)
	rotation.y = deg_to_rad(yaw_degrees)
	if up_meters > 0.0:
		_flying = true
		global_position += Vector3.UP * up_meters
	if OS.get_cmdline_user_args().has("--front"):
		_front_view = true  # cámara delante del personaje, mirándolo de frente
	elif OS.get_cmdline_user_args().has("--side"):
		_debug_camera_yaw = PI / 2.0  # cámara a su derecha, mirándolo de perfil


## Tecla de movimiento pulsada (siempre "no" mientras hay una pantalla abierta).
func _key(key: Key) -> bool:
	return not ui_open and Input.is_key_pressed(key)


## Descuenta del movimiento de este instante lo adelantado al subir escalones.
func _pay_step_debt(delta: float) -> void:
	if _step_debt <= 0.0:
		return
	var frame_distance := Vector2(velocity.x, velocity.z).length() * delta
	if frame_distance <= 0.0:
		_step_debt = 0.0  # se ha parado: nada que descontar
		return
	var pay := minf(_step_debt, frame_distance)
	var keep := 1.0 - pay / frame_distance
	velocity.x *= keep
	velocity.z *= keep
	_step_debt -= pay


# ------------------------------------------------------------------ objetos en el suelo y recetas

## Deja en el suelo uno del objeto de la mano, donde se apunta (sobre la cara de arriba de un
## bloque, o junto a otro objeto ya dejado). Queda en ese punto exacto, girado al azar.
func _place_on_ground(target: Dictionary) -> bool:
	if ground == null or target.is_empty():
		return false
	var stack := active_inventory().get_slot(_hotbar_index)
	if stack.is_empty():
		return false
	var point: Vector3 = target["point"]
	var support: Vector3i
	var yaw := rotation.y + randf_range(-0.6, 0.6)
	if target.has("item"):
		var other: PlacedItem = target["item"]
		var normal_up: Vector3 = target["normal"]
		if normal_up.y > 0.7:
			# Apuntando a la cara de arriba de un objeto: se apila encima (fabricar en vertical).
			if ground.stack_on(other, stack["id"], yaw) == null:
				notice.emit("No se puede apilar más alto.")
				return false
			Sfx.play("colocar", other.global_position, -8.0)
			if not creative:
				inventory.take(_hotbar_index, 1)
			return true
		point.y = other.base_y  # apuntando a un lado: al suelo, junto a él
		support = other.support
	else:
		var normal: Vector3 = target["normal"]
		if normal.y < 0.7:
			return false  # solo sobre superficies horizontales
		support = target["voxel"]
	ground.place(point, stack["id"], yaw, support)
	Sfx.play("colocar", point, -8.0)
	if not creative:
		inventory.take(_hotbar_index, 1)
	return true


## Recoge un objeto del suelo; con Mayúsculas, todo el montón que se toca con él.
func _pick_up_placed(item: PlacedItem, whole_group := false) -> void:
	var items: Array[PlacedItem] = [item]
	if whole_group:
		items = ground.group_of(item)
	# De arriba abajo, para que no se "caigan" los de encima mientras se recogen.
	items.sort_custom(func(a: PlacedItem, b: PlacedItem) -> bool: return a.level > b.level)
	for it in items:
		if it.item_id == "captain_journal":
			ground.remove(it)
			find_journal()
			continue
		if not creative and not can_pick_up(it.item_id):
			notice.emit("No te cabe todo.")
			return
		var id := ground.remove(it)
		if not creative:
			pick_up(id, 1)
	Sfx.play("recoger", null, -6.0, 0.15)


## Con una nota en la mano, clic derecho la lee y se aprende lo que enseña.
func _read_note() -> bool:
	var stack := active_inventory().get_slot(_hotbar_index)
	if stack.is_empty() or ItemDB.teaches(stack["id"]) == "":
		return false
	var recipe_id := ItemDB.teaches(stack["id"])
	if learn(recipe_id):
		var result: String = GroundRecipes.RECIPES[recipe_id]["result"]
		Sfx.play("aprender")
		notice.emit("Has aprendido a hacer: %s. Está en el diario (J)." % ItemDB.display_name(result))
		if not creative:
			inventory.take(_hotbar_index, 1)
	else:
		notice.emit("Ya sabías hacer esto.")
	return true


## Aprende una receta. Devuelve false si ya la sabía.
func learn(recipe_id: String) -> bool:
	if known_recipes.has(recipe_id) or not GroundRecipes.RECIPES.has(recipe_id):
		return false
	known_recipes.append(recipe_id)
	recipe_learned.emit(recipe_id)
	if ground != null:
		ground.refresh()
	return true


## Agacharse a trabajar (lo pide GroundCrafting mientras se mantiene R junto a una receta).
func set_working(on: bool) -> void:
	if on == _working:
		return
	_working = on
	_work_swing = 0.0
	_avatar.set_working(on)


## Solo capturas: postura de trabajar agachado (sin necesidad de una receta delante).
func debug_work_pose() -> void:
	_working = true
	_avatar.set_working(true)


## Q: tira uno del objeto de la mano (Ctrl + Q: el montón entero), como en Minecraft.
func _throw_held(whole_stack: bool) -> void:
	var stack := active_inventory().get_slot(_hotbar_index)
	if stack.is_empty():
		return
	var amount := int(stack["count"]) if whole_stack else 1
	if not creative:
		inventory.take(_hotbar_index, amount)
	var look := -_camera.global_basis.z
	ItemDrop.throw(get_parent(), _head.global_position + look * 0.4 - Vector3.UP * 0.25, look, stack["id"], amount)
	Sfx.play("tirar", null, -4.0)
	_held.swing()
	_avatar.swing()


## Recoge el diario del capitán: de él se salvan las recetas básicas.
func find_journal() -> void:
	if has_journal:
		return
	has_journal = true
	for recipe_id in GroundRecipes.JOURNAL_RECIPES:
		learn(recipe_id)
	notice.emit("Has encontrado el diario del capitán. Pulsa J para leerlo.")
	journal_found.emit()


## Sonido de pasos según el suelo, cada ~0,8 m andados; también al caer de un salto.
func _footsteps(delta: float, feet_wet: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor and _was_in_air:
		_step_distance = 0.0
		_play_step(feet_wet, -4.0)  # aterrizaje
	_was_in_air = not on_floor and not feet_wet
	if not on_floor and not feet_wet:
		return
	_step_distance += Vector2(velocity.x, velocity.z).length() * delta
	if _step_distance >= 0.8:
		_step_distance = 0.0
		_play_step(feet_wet, -10.0 if not _sprinting else -7.0)


func _play_step(feet_wet: bool, volume_db: float) -> void:
	var material := "agua"
	if not feet_wet and _tool != null:
		material = Sfx.material_of(_tool.get_voxel(_world_to_voxel(global_position - Vector3.UP * 0.1)))
	Sfx.play("paso_" + material, null, volume_db, 0.12)


# ------------------------------------------------------------------ romper manteniendo el clic

## Clic izquierdo en supervivencia: un objeto del suelo se coge al momento; un bloque empieza a
## romperse y hay que mantener el clic (cuánto, según el bloque y la herramienta de la mano).
func _start_breaking() -> void:
	var target := _target()
	if target.has("item"):
		_edit_block(false)
		return
	_breaking = true
	_break_swing = 0.0


## Segundos para romper este bloque con lo que se lleva en la mano.
func break_time(block_id: int) -> float:
	var t := Blocks.hardness(block_id)
	var held := active_inventory().get_slot(_hotbar_index)
	if not held.is_empty():
		t /= ItemDB.tool_speed(held["id"], block_id)
	return t


func _update_breaking(delta: float) -> void:
	if debug_cracks:
		return  # solo capturas: grietas fijas
	if _breaking and (ui_open or not _captured or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_breaking = false
	var target := _target() if _breaking else {}
	if not target.has("voxel") or _tool == null:
		_reset_breaking()
		return
	var cell: Vector3i = target["voxel"]
	var block := _tool.get_voxel(cell)
	if block == IslandGenerator.AIR:
		_reset_breaking()
		return
	if cell != _break_cell:
		_break_cell = cell
		_break_progress = 0.0
	var size := _terrain.scale.x
	var corner := _terrain.to_global(Vector3(cell))
	_break_progress += delta / maxf(break_time(block), 0.01)
	_break_swing -= delta
	if _break_swing <= 0.0 and _break_progress < 1.0:
		_break_swing = 0.27
		_held.swing()
		_avatar.swing()
		Sfx.play("paso_" + Sfx.material_of(block), corner + Vector3.ONE * size * 0.5, -2.0, 0.15)  # golpecito
	if _break_progress >= 1.0:
		_edit_block(false)
		_break_progress = 0.0
		_break_cell = Vector3i(0, -99999, 0)
		_break_swing = 0.15  # breve pausa antes de empezar el siguiente
	_cracks.show_on(corner, size, _break_progress)


func _reset_breaking() -> void:
	_break_progress = 0.0
	_break_cell = Vector3i(0, -99999, 0)
	if _cracks != null:
		_cracks.visible = false


## Con un objeto que no es bloque en la mano, apuntando al suelo (o encima de otro objeto):
## se ve en transparente dónde quedaría al dejarlo con G o clic derecho.
func _update_place_ghost() -> void:
	var stack := active_inventory().get_slot(_hotbar_index)
	var id: String = "" if stack.is_empty() else stack["id"]
	var target := _target() if _captured and not ui_open and id != "" and ItemDB.block_of(id) < 0 \
		and ItemDB.teaches(id) == "" else {}
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
		var other: PlacedItem = ground._top_of(target["item"]) if ground != null else target["item"]
		pos = other.global_position + Vector3.UP * other.height()
	_place_ghost.global_transform = Transform3D(Basis(Vector3.UP, rotation.y) * Basis(Vector3.RIGHT, -PI / 2.0),
		pos + Vector3.UP * 0.012)
	_place_ghost.visible = true
