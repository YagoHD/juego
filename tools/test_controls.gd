extends SceneTree
## Prueba de controles simulando teclado y ratón, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_controls.gd
##   1. Doble toque de W: el jugador corre (más rápido que andando).
##   2. Mantener V y mover el ratón hacia atrás: sale a tercera persona y aleja la cámara.
##   3. Soltar V tras hacer zoom: NO cambia de cámara.
##   4. Pulsar y soltar V sin zoom: cambia de cámara (tercera por detrás -> de frente).

var _main: Node
var _step := 0
var _wait := 0


func _init() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _mouse_motion(dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(0, dy)
	Input.parse_input_event(e)


func _physics_process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	match _step:
		0:
			if _wait < 20: return false
			_key(KEY_W, true); _key(KEY_W, false); _key(KEY_W, true)  # doble toque y mantener
			_step = 1; _wait = 0
		1:
			if _wait < 40: return false  # ~0,7 s corriendo
			var speed := Vector2(player.velocity.x, player.velocity.z).length()
			var ok: bool = player.get("_sprinting") and speed > Player.SPEED + 0.5
			print("Doble W -> corre a %.1f m/s (andando %.1f): %s" % [speed, Player.SPEED, "OK" if ok else "FALLO"])
			_key(KEY_W, false)
			_step = 2; _wait = 0
		2:
			if _wait < 10: return false
			_key(KEY_V, true)
			_mouse_motion(150.0)  # ratón hacia atrás = alejar
			_step = 3; _wait = 0
		3:
			if _wait < 3: return false
			var dist: float = player.get("_camera_distance")
			var ok := player.is_third_person() and dist > Player.MIN_CAMERA_DISTANCE
			print("V + ratón atrás -> tercera persona a %.1f m: %s" % [dist, "OK" if ok else "FALLO"])
			_key(KEY_V, false)
			_step = 4; _wait = 0
		4:
			if _wait < 3: return false
			var still_back: bool = player.is_third_person() and not player.get("_front_view")
			print("Soltar V tras zoom no cambia de cámara: %s" % ("OK" if still_back else "FALLO"))
			_key(KEY_V, true); _key(KEY_V, false)
			_step = 5; _wait = 0
		5:
			if _wait < 3: return false
			print("V sin zoom cambia a vista de frente: %s" % ("OK" if player.get("_front_view") else "FALLO"))
			return true
	return false
