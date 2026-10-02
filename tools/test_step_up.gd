extends SceneTree
## Prueba de física del jugador: ¿sube solo 1 bloque y se para ante 2?
## Uso: godot --headless --path . --script res://tools/test_step_up.gd

var _player: Player
var _frames := 0
var _case := 0
const CASES := [0.5, 1.0]  # alto del obstáculo en metros (1 y 2 bloques de 0,5 m)
const WALK := Vector3(1, 0, 0)


func _init() -> void:
	_setup(CASES[0])


func _setup(obstacle_height: float) -> void:
	for child in root.get_children():
		child.queue_free()
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(0, -0.5, 0), Vector3(40, 1, 40))  # suelo con la cara de arriba en y=0
	_add_box(world, Vector3(18, obstacle_height / 2.0, 0), Vector3(30, obstacle_height, 40))  # obstáculo desde x=3
	_player = Player.new()
	_player.position = Vector3(0, 0.02, 0)
	world.add_child(_player)
	_player.set_physics_process(false)  # lo movemos desde aquí, sin teclado
	_player.set_process_input(false)
	_frames = 0


func _add_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	parent.add_child(body)


func _physics_process(delta: float) -> bool:
	if _player == null or not _player.is_inside_tree():
		return false
	_frames += 1
	# Lo mismo que hace el jugador al andar, pero con la tecla "pulsada" por la prueba.
	if not _player.is_on_floor():
		_player.velocity.y -= Player.GRAVITY * delta
	_player.velocity.x = WALK.x * Player.SPEED
	_player.velocity.z = 0.0
	var was_on_floor := _player.is_on_floor()
	_player.move_and_slide()
	if was_on_floor:
		_player._try_step_up(WALK)

	if _frames == 120:  # 2 segundos andando
		var h: float = CASES[_case]
		print("Obstáculo de %.1f m (%d bloque/s): jugador termina en x=%.2f y=%.2f -> %s" % [
			h, int(h / 0.5), _player.global_position.x, _player.global_position.y,
			"SUBE" if _player.global_position.y > h - 0.05 else "NO SUBE"])
		_case += 1
		if _case >= CASES.size():
			return true  # fin
		_setup(CASES[_case])
	return false
