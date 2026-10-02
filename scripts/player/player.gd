extends CharacterBody3D
class_name Player

signal creative_changed(enabled: bool)
## Clic derecho sobre un bloque que se usa (un cofre...) en vez de colocar encima.
signal block_used(cell: Vector3i, block_id: int)
signal block_broken(cell: Vector3i, block_id: int)
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
const SENSITIVITY := 0.0025
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
var _base_fov := 75.0
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
	apply_skin(SkinComposer.load_player_skin(), SkinComposer.DEFAULT_OPTIONS["slim"])

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
			_orbit.x -= motion.relative.x * SENSITIVITY
			_orbit.y = clampf(_orbit.y - motion.relative.y * SENSITIVITY, -1.2, 1.2)
			return
		rotate_y(-motion.relative.x * SENSITIVITY)
		_pitch = clampf(_pitch - motion.relative.y * SENSITIVITY, -1.5, 1.5)
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
				_edit_block(false)
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
			_select_slot(key.keycode - KEY_1)
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
	_hotbar_index = posmod(index, Hotbar.SLOTS)
	_refresh_held()


## Actualiza el bloque de la mano (primera y tercera persona) con el hueco seleccionado.
func _refresh_held() -> void:
	var id := get_current_block()
	_held.set_block(id)
	_avatar.set_block(id)


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
	_head.position = Vector3(0, EYE_HEIGHT, 0) + global_basis.inverse() * _camera_lag

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
	var target_fov := _base_fov + (SPRINT_FOV_BOOST if _sprinting and moving else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))

	_avatar.set_look_pitch(_pitch)
	_update_highlight()


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
	var half_voxel: float = _terrain.scale.x * 0.5
	return {
		"voxel": _world_to_voxel(hit_point - hit_normal * half_voxel),  # hacia dentro: el bloque
		"place": _world_to_voxel(hit_point + hit_normal * half_voxel),  # hacia fuera: el hueco
	}


func _edit_block(place: bool) -> void:
	_held.swing()
	_avatar.swing()
	var target := _target()
	if target.is_empty():
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
			return  # mano vacía (o el objeto no es un bloque)
		if id != IslandGenerator.WATER and _overlaps_body(cell):
			return  # no colocar un bloque dentro de uno mismo
		tool.set_voxel(cell, id)
		if not creative:
			inventory.take(_hotbar_index, 1)
	else:
		var cell: Vector3i = target["voxel"]
		var broken := tool.get_voxel(cell)
		tool.set_voxel(cell, IslandGenerator.AIR)
		var size := _terrain.scale.x
		var center := _terrain.to_global(Vector3(cell)) + Vector3.ONE * size * 0.5
		_spawn_break_particles(center, broken)
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


## Mete objetos recogidos en el inventario. Devuelve los que no cupieron.
func pick_up(id: String, count: int) -> int:
	return inventory.add(id, count)


## ¿Cabe al menos uno de estos objetos? (para que no vuelen hacia él si va lleno)
func can_pick_up(id: String) -> bool:
	for i in inventory.size():
		var s := inventory.get_slot(i)
		if s.is_empty() or (s["id"] == id and int(s["count"]) < ItemDB.max_stack(id)):
			return true
	return false


func set_creative(enabled: bool) -> void:
	creative = enabled
	creative_changed.emit(enabled)
	_refresh_held()


func _fill_creative_inventory() -> void:
	var slot := 0
	for block in Blocks.HOTBAR:
		creative_inventory.set_slot(slot, {"id": ItemDB.item_of_block(block), "count": 1})
		slot += 1
	for id in ItemDB.BLOCK_ITEMS:
		if slot < creative_inventory.size() and creative_inventory.count_of(id) == 0:
			creative_inventory.set_slot(slot, {"id": id, "count": 1})
			slot += 1


## Cambia la skin del jugador (cuerpo y brazo). El futuro editor de personaje la usará.
func apply_skin(texture: Texture2D, slim: bool) -> void:
	_avatar.build(texture, slim)
	_held.set_skin(texture, slim)
	if _hotbar_index >= 0 and _held != null:
		_avatar.set_block(get_current_block())


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
