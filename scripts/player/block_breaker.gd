extends Node
class_name BlockBreaker
## Romper bloques en supervivencia: se mantiene el clic y el bloque aguanta un rato (según su
## dureza y la herramienta de la mano) mientras se agrieta; al romperse saltan trocitos. Es una
## parte del jugador (Player.breaker).

var player: Player
var cracks: BlockCracks           # las grietas sobre el bloque que se está rompiendo
var debug_cracks := false         # capturas: grietas fijas, sin romper
var _breaking := false            # manteniendo el clic izquierdo sobre un bloque
var _break_cell := Vector3i(0, -99999, 0)
var _break_progress := 0.0        # 0..1
var _break_swing := 0.0


func _ready() -> void:
	cracks = BlockCracks.new()
	player.add_child(cracks)


func spawn_particles(center: Vector3, block_id: int) -> void:
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
	player.get_parent().add_child(particles)
	particles.global_position = center
	particles.emitting = true
	player.get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


## Clic izquierdo en supervivencia: un objeto del suelo se coge al momento; un bloque empieza a
## romperse y hay que mantener el clic (cuánto, según el bloque y la herramienta de la mano).
func start() -> void:
	var target := player.aim.target()
	if target.has("item") or target.has("raft"):
		player._edit_block(false)
		return
	_breaking = true
	_break_swing = 0.0


## Segundos para romper este bloque con lo que se lleva en la mano.
func break_time(block_id: int) -> float:
	var t := Blocks.hardness(block_id)
	var held := player.active_inventory().get_slot(player._hotbar_index)
	if not held.is_empty():
		t /= ItemDB.tool_speed(held["id"], block_id)
	var skill := Skills.block_skill(block_id)
	if skill != "":
		t /= player.skills.bonus(skill, 0.06)  # la práctica: minería o tala
	return t


func update(delta: float) -> void:
	if debug_cracks:
		return  # solo capturas: grietas fijas
	if _breaking and (player.ui_open or not player._captured or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_breaking = false
	var target := player.aim.target() if _breaking else {}
	if not target.has("voxel") or player._tool == null:
		reset()
		return
	var cell: Vector3i = target["voxel"]
	var block := player._tool.get_voxel(cell)
	if block == IslandGenerator.AIR:
		reset()
		return
	if cell != _break_cell:
		_break_cell = cell
		_break_progress = 0.0
	var size := player._terrain.scale.x
	var corner := player._terrain.to_global(Vector3(cell))
	_break_progress += delta / maxf(break_time(block), 0.01)
	_break_swing -= delta
	if _break_swing <= 0.0 and _break_progress < 1.0:
		_break_swing = 0.27
		player._held.swing()
		player._avatar.swing()
		Sfx.play("paso_" + Sfx.material_of(block), corner + Vector3.ONE * size * 0.5, -2.0, 0.15)  # golpecito
	if _break_progress >= 1.0:
		player._edit_block(false)
		_break_progress = 0.0
		_break_cell = Vector3i(0, -99999, 0)
		_break_swing = 0.15  # breve pausa antes de empezar el siguiente
	cracks.show_on(corner, size, _break_progress, BlockAim.shape_box(player._tool.get_voxel(_break_cell)) if player._tool != null else AABB(Vector3.ZERO, Vector3.ONE))


func reset() -> void:
	_break_progress = 0.0
	_break_cell = Vector3i(0, -99999, 0)
	if cracks != null:
		cracks.visible = false


