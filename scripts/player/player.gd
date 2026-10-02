extends CharacterBody3D
class_name Player
## Jugador en primera persona: camina, salta, mira con el ratón y rompe/coloca bloques.
## Encuentra el VoxelTerrain por el grupo "voxel_terrain".

const SPEED := 6.0
const JUMP_VELOCITY := 8.0
const GRAVITY := 24.0
const SENSITIVITY := 0.0025
const REACH := 8.0

var _camera: Camera3D
var _terrain: VoxelTerrain
var _pitch := 0.0
var _current_block := BlockyTerrainGenerator.GRASS
var _captured := true


func _ready() -> void:
	# Colisión (cápsula).
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	# Cámara a la altura de los ojos.
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.6, 0)
	add_child(_camera)
	_camera.current = true

	# El VoxelViewer hace que el terreno cargue chunks alrededor del jugador.
	var viewer := VoxelViewer.new()
	_camera.add_child(viewer)

	var terrains := get_tree().get_nodes_in_group("voxel_terrain")
	if terrains.size() > 0:
		_terrain = terrains[0] as VoxelTerrain

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
				_current_block = BlockyTerrainGenerator.GRASS
			elif key.keycode == KEY_2:
				_current_block = BlockyTerrainGenerator.DIRT
			elif key.keycode == KEY_3:
				_current_block = BlockyTerrainGenerator.STONE
			elif key.keycode == KEY_ESCAPE:
				_captured = not _captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
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

	move_and_slide()

	# Red de seguridad: si se cae del mundo, reaparece arriba.
	if global_position.y < -60.0:
		global_position = Vector3(0, 40, 0)
		velocity = Vector3.ZERO


func _edit_block(place: bool) -> void:
	if _terrain == null:
		return
	var tool := _terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	# El VoxelTool trabaja en coordenadas de voxel (espacio local del terreno).
	# Como el terreno está escalado, convertimos el rayo del mundo a ese espacio.
	var world_from := _camera.global_position
	var world_dir := -_camera.global_transform.basis.z
	var from := _terrain.to_local(world_from)
	var dir := (_terrain.to_local(world_from + world_dir) - from).normalized()
	var max_distance := REACH / _terrain.scale.x
	var hit := tool.raycast(from, dir, max_distance)
	if hit == null:
		return
	if place:
		tool.set_voxel(hit.previous_position, _current_block)
	else:
		tool.set_voxel(hit.position, BlockyTerrainGenerator.AIR)


func get_current_block() -> int:
	return _current_block
