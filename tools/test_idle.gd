extends SceneTree
## Prueba del reposo del personaje, sin ventana y con el tiempo acelerado: quieto durante
## ~40 s de juego debe parpadear varias veces y hacer al menos una acción de reposo.
## Uso: godot --headless --path . --script res://tools/test_idle.gd

var _main: Node
var _game_time := 0.0
var _actions := {}
var _blinks := 0
var _lids_were_visible := false


func _init() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	Engine.time_scale = 4.0
	_game_time += delta
	var avatar: PlayerAvatar = player.get("_avatar")
	var action: String = avatar.get("_action")
	if action != "":
		_actions[action] = true
	var lids: Node3D = avatar.get("_lids")
	if lids.visible and not _lids_were_visible:
		_blinks += 1
	_lids_were_visible = lids.visible
	if _game_time >= 40.0:
		print("En 40 s quieto: %d parpadeos, acciones: %s -> %s" % [
			_blinks, _actions.keys(), "OK" if _blinks >= 4 and _actions.size() >= 1 else "FALLO"])
		return true
	return false
