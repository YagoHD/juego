extends Node3D
## Fase 1 — Test técnico de godot_voxel.
## Construye un terreno de voxels pequeños por ruido y lo recorre con una cámara libre,
## mostrando FPS. Objetivo: confirmar que el rendimiento aguanta antes de comprometerse.
##
## REQUISITO: la extensión godot_voxel debe estar instalada en addons/ (ver README.md).
## Si no lo está, este script avisa por consola en vez de romper.

# Tamaño del voxel en metros. Más pequeño = más detalle (estilo Cube World) y más coste.
# Con una RTX 4070 podemos empezar fino; sube este valor si cae el rendimiento.
const VOXEL_SIZE := 0.25

func _ready() -> void:
	if not ClassDB.class_exists("VoxelLodTerrain"):
		push_error("godot_voxel NO está instalado. Copia la extensión en addons/ (ver README.md).")
		print("[voxel_test] Falta la extensión godot_voxel. Nada que renderizar todavía.")
		_add_hud("Falta godot_voxel en addons/ (ver README.md)")
		return

	_build_terrain()
	_build_camera()
	_add_hud("")
	print("[voxel_test] Terreno de voxels creado. VOXEL_SIZE=%.2f m" % VOXEL_SIZE)

func _build_terrain() -> void:
	# Ruido para un terreno con colinas suaves.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01

	var generator := ClassDB.instantiate("VoxelGeneratorNoise")
	generator.set("noise", noise)
	generator.set("height_range", 80.0)

	var terrain := ClassDB.instantiate("VoxelLodTerrain")
	terrain.set("generator", generator)
	terrain.set("voxel_bounds", AABB(Vector3(-4096, -2048, -4096), Vector3(8192, 4096, 8192)))
	terrain.set("lod_count", 6)
	terrain.scale = Vector3.ONE * VOXEL_SIZE

	# Material simple para ver la forma del terreno.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.6, 0.35)
	terrain.set("material_override", mat)

	add_child(terrain)

	# Luz direccional para dar relieve.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment = e
	add_child(env)

func _build_camera() -> void:
	var cam := FreeCamera.new()
	cam.position = Vector3(0, 40, 0)
	add_child(cam)
	cam.current = true

func _add_hud(extra: String) -> void:
	var label := Label.new()
	label.name = "HUD"
	label.position = Vector2(12, 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	if extra != "":
		label.text = extra
	var canvas := CanvasLayer.new()
	canvas.add_child(label)
	add_child(canvas)
	set_meta("hud_label", label)
	set_meta("hud_extra", extra)

func _process(_delta: float) -> void:
	if not has_meta("hud_label"):
		return
	var label: Label = get_meta("hud_label")
	if get_meta("hud_extra") != "":
		return
	label.text = "FPS: %d   (WASD mover, ratón mirar, Shift correr, Esc liberar ratón)" % \
		Engine.get_frames_per_second()


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
			_yaw -= event.relative.x * SENS
			_pitch = clampf(_pitch - event.relative.y * SENS, -1.5, 1.5)
			rotation = Vector3(_pitch, _yaw, 0.0)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
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
