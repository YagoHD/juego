extends Node3D
## Fase 1 — Test técnico de godot_voxel.
## Construye un terreno de voxels por ruido y lo recorre con una cámara libre, mostrando FPS.
## Objetivo: confirmar que el rendimiento aguanta antes de comprometerse.
##
## REQUISITO: ejecutar con el Godot de Zylann (build con el módulo voxel integrado), ver README.md.

# Escala del terreno. Valores < 1 = voxels más pequeños (más detalle, estilo Cube World) y más coste.
# Con una RTX 4070 podemos empezar fino; sube este valor si cae el rendimiento.
const VOXEL_SIZE := 0.5

var _hud: Label


func _ready() -> void:
	_build_terrain()
	_build_camera()
	_build_hud()
	print("[voxel_test] Terreno de voxels creado. VOXEL_SIZE=%.2f" % VOXEL_SIZE)


func _build_terrain() -> void:
	# Ruido para un terreno con colinas suaves.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01

	var generator := VoxelGeneratorNoise.new()
	generator.noise = noise
	generator.height_range = 80.0

	var terrain := VoxelLodTerrain.new()
	terrain.generator = generator
	terrain.mesher = VoxelMesherTransvoxel.new()
	terrain.lod_count = 6
	terrain.scale = Vector3.ONE * VOXEL_SIZE
	add_child(terrain)

	# Luz direccional para dar relieve.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Cielo procedural.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)


func _build_camera() -> void:
	var cam := FreeCamera.new()
	cam.position = Vector3(0, 60, 0)
	add_child(cam)
	cam.current = true

	# El VoxelViewer le dice al terreno dónde está el jugador para cargar/descargar chunks.
	var viewer := VoxelViewer.new()
	cam.add_child(viewer)


func _build_hud() -> void:
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	var canvas := CanvasLayer.new()
	canvas.add_child(_hud)
	add_child(canvas)


func _process(_delta: float) -> void:
	if _hud != null:
		_hud.text = "FPS: %d   (WASD mover · ratón mirar · Shift correr · Espacio/Ctrl subir-bajar · Esc liberar ratón)" \
			% Engine.get_frames_per_second()


## Cámara libre de vuelo para inspeccionar el terreno.
class FreeCamera extends Camera3D:
	const SPEED := 20.0
	const SPEED_FAST := 60.0
	const SENS := 0.0025
	var _yaw := 0.0
	var _pitch := 0.0
	var _captured := true

	func _ready() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and _captured:
			var motion := event as InputEventMouseMotion
			_yaw -= motion.relative.x * SENS
			_pitch = clampf(_pitch - motion.relative.y * SENS, -1.5, 1.5)
			rotation = Vector3(_pitch, _yaw, 0.0)
		elif event is InputEventKey:
			var key := event as InputEventKey
			if key.pressed and key.keycode == KEY_ESCAPE:
				_captured = not _captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE

	func _process(delta: float) -> void:
		var dir := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): dir -= transform.basis.z
		if Input.is_key_pressed(KEY_S): dir += transform.basis.z
		if Input.is_key_pressed(KEY_A): dir -= transform.basis.x
		if Input.is_key_pressed(KEY_D): dir += transform.basis.x
		if Input.is_key_pressed(KEY_SPACE): dir += Vector3.UP
		if Input.is_key_pressed(KEY_CTRL): dir -= Vector3.UP
		var speed := SPEED_FAST if Input.is_key_pressed(KEY_SHIFT) else SPEED
		position += dir.normalized() * speed * delta
