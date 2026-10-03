extends SceneTree
## Prueba de la balsa, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_raft.gd
## Busca mar cerca del inicio, echa una balsa, sube, navega (no entra en tierra) y baja.

var _main: Node
var _boat: Raft
var _frames := 0
var _start := Vector3.ZERO


func _init() -> void:
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var gen: IslandGenerator = _main.get("_generator")
	if _boat == null:
		var sea := _find_sea(gen, player.global_position)
		if sea == Vector3.INF:
			print("FALLO: no hay mar cerca")
			return true
		_boat = Raft.new()
		_boat.generator = gen
		_main.add_child(_boat)
		_boat.add_to_group("rafts")
		_boat.global_position = Vector3(sea.x, _boat.sea_y(), sea.z)
		var out := sea - player.global_position
		_boat.rotation.y = atan2(-out.x, -out.z)  # proa mar adentro
		player.call("_board", _boat)
		_start = _boat.global_position
		return false
	_frames += 1
	if _frames <= 240:
		_boat.steer(1.0, 0.0, delta)  # remar recto 4 segundos
		return false
	var moved := Vector2(_boat.global_position.x - _start.x, _boat.global_position.z - _start.z).length()
	var on_water := _boat.is_water(_boat.global_position)
	var follows := player.global_position.distance_to(_boat.global_position) < 0.5
	print("balsa: recorrido %.1f m, sigue en el mar=%s, jugador encima=%s" % [moved, on_water, follows])
	player.call("_dismount")
	var off := player.raft == null
	var saved: Array = get_nodes_in_group("rafts").map(func(r: Node) -> Dictionary: return (r as Raft).to_data())
	print("bajar=%s, guardado=%s" % [off, saved])
	print("OK" if moved > 3.0 and on_water and follows and off and saved.size() == 1 else "FALLO")
	return true


func _find_sea(gen: IslandGenerator, from: Vector3) -> Vector3:
	for r in range(10, 600, 4):
		for k in 32:
			var a := TAU * k / 32.0
			var p := from + Vector3(cos(a), 0, sin(a)) * r * 0.5
			var h := gen.get_ground_height(int(floorf(p.x / 0.5)), int(floorf(p.z / 0.5)))
			if h <= IslandGenerator.SEA_LEVEL - 10:
				return p
	return Vector3.INF
