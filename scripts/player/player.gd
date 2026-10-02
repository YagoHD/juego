extends CharacterBody3D
class_name Player
## Jugador en primera persona: camina, salta, mira con el ratón y rompe/coloca bloques.
## Encuentra el VoxelTerrain por el grupo "voxel_terrain".

const SPEED := 5.2
const BODY_HEIGHT := 1.5   # altura del personaje en metros (3 bloques de 0,5 m)
const EYE_HEIGHT := 1.35   # altura de la cámara (los ojos)
const JUMP_VELOCITY := 7.0  # salto de ~1 m: sube 2 bloques
const GRAVITY := 24.0
const SENSITIVITY := 0.0025
const REACH := 8.0
const STEP_HEIGHT := 0.55  # sube solo escalones de hasta ~1 bloque (0.5 m); para 2+ hay que saltar
const FLY_SPEED := 18.0
const FLY_SPEED_FAST := 60.0

var _flying := false
var _spawn_point := Vector3.ZERO
var _waiting_for_ground := true  # no aplicar gravedad hasta que exista suelo con colisión

## Radio (en voxels) de terreno detallado alrededor del jugador. Lo fija main.gd.
var near_view_voxels := 320

var _camera: Camera3D
var _terrain: VoxelTerrain
var _pitch := 0.0
var _current_block := IslandGenerator.GRASS
var _captured := true


func _ready() -> void:
	# Colisión (cápsula).
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = BODY_HEIGHT
	capsule.radius = 0.35
	shape.shape = capsule
	shape.position = Vector3(0, BODY_HEIGHT * 0.5, 0)
	add_child(shape)

	# Cámara a la altura de los ojos.
	_camera = Camera3D.new()
	_camera.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(_camera)
	_camera.current = true

	# Observadores del terreno: uno amplio solo para dibujar (la zona detallada) y otro
	# pequeño solo para las colisiones, que son caras de calcular.
	var visual_viewer := VoxelViewer.new()
	visual_viewer.view_distance = near_view_voxels
	visual_viewer.view_distance_vertical_ratio = 2.5  # que no haya huecos al volar alto
	visual_viewer.requires_collisions = false
	_camera.add_child(visual_viewer)

	var collision_viewer := VoxelViewer.new()
	collision_viewer.view_distance = 48
	collision_viewer.requires_visuals = false
	_camera.add_child(collision_viewer)

	var terrains := get_tree().get_nodes_in_group("voxel_terrain")
	if terrains.size() > 0:
		_terrain = terrains[0] as VoxelTerrain

	_spawn_point = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _captured:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * SENSITIVITY)
		_pitch = clampf(_pitch - motion.relative.y * SENSITIVITY, -1.5, 1.5)
		_camera.rotation = Vector3(_pitch, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_edit_block(false)
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_edit_block(true)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed:
			if key.keycode == KEY_1:
				_current_block = IslandGenerator.GRASS
			elif key.keycode == KEY_2:
				_current_block = IslandGenerator.DIRT
			elif key.keycode == KEY_3:
				_current_block = IslandGenerator.STONE
			elif key.keycode == KEY_4:
				_current_block = IslandGenerator.SAND
			elif key.keycode == KEY_5:
				_current_block = IslandGenerator.SNOW
			elif key.keycode == KEY_6:
				_current_block = IslandGenerator.WOOD
			elif key.keycode == KEY_7:
				_current_block = IslandGenerator.LEAVES
			elif key.keycode == KEY_8:
				_current_block = IslandGenerator.WATER
			elif key.keycode == KEY_9:
				_current_block = IslandGenerator.WHEAT
			elif key.keycode == KEY_F:
				_flying = not _flying
				velocity = Vector3.ZERO
			elif key.keycode == KEY_ESCAPE:
				_captured = not _captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if _waiting_for_ground:
		_wait_for_ground()
		return
	if _flying:
		_fly(delta)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += transform.basis.x
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var was_on_floor := is_on_floor()
	move_and_slide()
	if was_on_floor:
		_try_step_up(delta)

	# Red de seguridad: si se cae del mundo, reaparece arriba.
	if global_position.y < -60.0:
		global_position = _spawn_point + Vector3.UP * 2.0
		velocity = Vector3.ZERO
		_waiting_for_ground = true


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
	if Input.is_key_pressed(KEY_W): dir -= cam.z
	if Input.is_key_pressed(KEY_S): dir += cam.z
	if Input.is_key_pressed(KEY_A): dir -= cam.x
	if Input.is_key_pressed(KEY_D): dir += cam.x
	if Input.is_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL): dir -= Vector3.UP
	var speed := FLY_SPEED_FAST if Input.is_key_pressed(KEY_SHIFT) else FLY_SPEED
	velocity = dir.normalized() * speed
	move_and_slide()


func _try_step_up(delta: float) -> void:
	# Si vamos contra una pared baja de ≤1 bloque, nos subimos solos.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < 0.05:
		return
	var motion := horizontal * delta
	if not test_move(global_transform, motion):
		return  # nada bloqueando al frente
	var lifted := Transform3D(global_transform.basis, global_transform.origin + Vector3.UP * STEP_HEIGHT)
	if test_move(lifted, motion):
		return  # la pared es más alta que un escalón: no trepar
	# Hay hueco un escalón más arriba: subimos, avanzamos y bajamos hasta el suelo.
	global_position += Vector3.UP * STEP_HEIGHT
	move_and_collide(motion)
	move_and_collide(Vector3.DOWN * STEP_HEIGHT)


func _edit_block(place: bool) -> void:
	if _terrain == null:
		return
	# Rayo de física contra la colisión del terreno (en coordenadas del mundo).
	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z) * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var hit_point: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	var half_voxel: float = _terrain.scale.x * 0.5

	var tool := _terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	if place:
		# Un poco hacia fuera de la cara golpeada = la celda vacía donde colocar.
		var voxel_pos := _world_to_voxel(hit_point + hit_normal * half_voxel)
		tool.set_voxel(voxel_pos, _current_block)
	else:
		# Un poco hacia dentro = la celda del bloque golpeado.
		var voxel_pos := _world_to_voxel(hit_point - hit_normal * half_voxel)
		tool.set_voxel(voxel_pos, IslandGenerator.AIR)


func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local := _terrain.to_local(world_pos)
	return Vector3i(floori(local.x), floori(local.y), floori(local.z))


func get_current_block() -> int:
	return _current_block
