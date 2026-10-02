extends SceneTree
## Prueba de nado sobre la isla real, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_swim.gd
## Suelta al jugador sobre el mar y sobre el lago y comprueba que se hunde despacio
## (sin pasar de MAX_SINK_SPEED) y que detecta la cabeza bajo el agua.

const SPOTS := {
	"mar abierto": Vector2i(-980, 0),
	"lago de la montaña": Vector2i(488, -257),
}

var _main: Node
var _names: Array = SPOTS.keys()
var _index := -1
var _frames := 0
var _min_vy := 0.0
var _was_underwater := false
var _settle := 0


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	if _index == -1:
		_next(player)
		return false
	_frames += 1
	if _settle > 0:
		_settle -= 1  # esperar a que cargue el terreno alrededor tras el teletransporte
		player.velocity = Vector3.ZERO
		_frames = 0
		return false
	if player.is_head_underwater():
		# Solo ya sumergido: al entrar se llega con la velocidad de la caída y el agua la frena
		# en el fotograma siguiente.
		_min_vy = minf(_min_vy, player.velocity.y)
	_was_underwater = _was_underwater or player.is_head_underwater()
	if _frames == 180:  # 3 segundos en el agua
		var ok := _min_vy >= -Player.MAX_SINK_SPEED - 0.01 and _was_underwater
		print("%s: velocidad de hundimiento máx %.2f m/s, cabeza bajo el agua=%s -> %s" % [
			_names[_index], -_min_vy, _was_underwater, "OK" if ok else "FALLO"])
		if _index + 1 >= _names.size():
			return true
		_next(player)
	return false


func _next(player: Player) -> void:
	_index += 1
	var spot: Vector2i = SPOTS[_names[_index]]
	var gen: IslandGenerator = _main.get("_generator")
	var surface := gen.get_ground_height(spot.x, spot.y)  # en el lago, la superficie del agua
	var top := maxi(surface, IslandGenerator.SEA_LEVEL)
	player.global_position = Vector3(spot.x, top + 1, spot.y) * 0.5
	player.velocity = Vector3.ZERO
	_frames = 0
	_min_vy = 0.0
	_was_underwater = false
	_settle = 120
