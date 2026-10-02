extends SceneTree
## Prueba de física del jugador, sin ventana:
##   - sube solo un escalón de 1 bloque y se para ante uno de 2;
##   - subiendo una escalera (colina) avanza lo mismo que en llano (no "acelera").
## Uso: godot --headless --path . --script res://tools/test_step_up.gd

const B := SkinModel.BLOCK_SIZE
const SECONDS := 3.0
# Casos: [nombre, función que construye el escenario]
var _cases := ["escalon_1", "escalon_2", "llano", "escalera"]
var _results := {}
var _player: Player
var _frames := 0
var _case := 0
const WALK := Vector3(1, 0, 0)


func _init() -> void:
	_setup()


func _setup() -> void:
	for child in root.get_children():
		child.queue_free()
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(0, -0.5, 0), Vector3(80, 1, 40))  # suelo con la cara de arriba en y=0
	match _cases[_case]:
		"escalon_1":
			_add_box(world, Vector3(18, B / 2.0, 0), Vector3(30, B, 40))
		"escalon_2":
			_add_box(world, Vector3(18, B, 0), Vector3(30, 2.0 * B, 40))
		"escalera":
			# Peldaños de 1 bloque de alto cada 2 bloques de largo, a partir de x = 1.
			for i in 30:
				var x0 := 1.0 + i * 2.0 * B
				_add_box(world, Vector3(x0 + 15.0, (i + 1) * B / 2.0, 0), Vector3(30, (i + 1) * B, 40))
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
	_player._pay_step_debt(delta)
	var was_on_floor := _player.is_on_floor()
	_player.move_and_slide()
	if was_on_floor:
		_player._try_step_up(WALK)

	if _frames == int(SECONDS * 60):
		var name: String = _cases[_case]
		_results[name] = _player.global_position
		_case += 1
		if _case >= _cases.size():
			_report()
			return true
		_setup()
	return false


func _report() -> void:
	var s1: Vector3 = _results["escalon_1"]
	var s2: Vector3 = _results["escalon_2"]
	print("Escalón de 1 bloque: termina a %.2f m de altura -> %s" % [s1.y, "SUBE (OK)" if s1.y > B - 0.05 else "NO SUBE (FALLO)"])
	print("Escalón de 2 bloques: termina a %.2f m de altura -> %s" % [s2.y, "NO SUBE (OK)" if s2.y < 0.1 else "SUBE (FALLO)"])
	var flat: float = (_results["llano"] as Vector3).x
	var stairs: Vector3 = _results["escalera"]
	var ratio := stairs.x / flat
	print("En %.0f s: llano %.2f m, escalera %.2f m (subiendo %.1f m) -> %.0f%% de la velocidad en llano: %s" % [
		SECONDS, flat, stairs.x, stairs.y, ratio * 100.0, "OK" if ratio <= 1.02 else "FALLO (más rápido subiendo)"])
