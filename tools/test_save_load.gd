extends SceneTree
## Prueba de guardar y cargar la partida (sin ventana): se cambian cosas del jugador (hambre,
## ropa, recetas, diario, cultivo plantado...), se guarda, se cierra el mundo y se vuelve a abrir
## sin borrarlo: todo debe seguir igual y sin errores.
## Uso: godot --headless --path . --script res://tools/test_save_load.gd

var _main: Node
var _step := 0
var _wait := 0
var _fails := 0
var _saved_spawn := Vector3.ZERO


func _init() -> void:
	Main.test_mode = true
	_open()


func _open() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_wait = 0


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	if _wait < 20:
		return false
	match _step:
		0:
			player.set_creative(false)
			player.find_journal()
			player.learn("chest")
			player.equip("shirt", "shirt")
			player.inventory.add("rope", 7)
			player.combat.health = 63.0
			_saved_spawn = player.global_position + Vector3(2, 0, 2)
			player.set_spawn_point(_saved_spawn)
			var bag := DeathBackpack.new()
			bag.contents = [{"id": "stone_axe", "count": 1, "dur": 13}]
			bag.position = player.global_position + Vector3(4, 0.1, 0)
			_main.add_child(bag)
			var needs: Needs = _main.get("_needs")
			needs.hunger = 42.0
			player.farm.from_data({"1,2,3": 99.0})
			_main.call("_save_world")
			_main.free()  # del todo, ya: que el mundo nuevo no encuentre el terreno viejo
			Main.keep_test_world = true
			_step = 1
			_wait = 0
			call_deferred("_open")
			return false
		1:
			var needs: Needs = _main.get("_needs")
			_check("El hambre se conserva (%.0f)" % needs.hunger, absf(needs.hunger - 42.0) < 2.0)
			_check("La ropa se conserva", player.equipment["shirt"] == "shirt")
			_check("El diario y las recetas se conservan", player.has_journal and player.known_recipes.has("chest"))
			_check("El inventario se conserva", player.inventory.count_of("rope") == 7)
			_check("Lo plantado se conserva", player.farm.to_data().has("1,2,3"))
			_check("La vida se conserva", absf(player.combat.health - 63.0) < 2.0)
			_check("Esperar terreno no borra el punto de descanso", player.get_spawn_point().distance_to(_saved_spawn) < 0.01)
			var bags := get_nodes_in_group("death_backpacks")
			_check("La mochila de muerte se conserva", bags.size() == 1 and int((bags[0] as DeathBackpack).contents[0]["dur"]) == 13)
			print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
			return true
	return false


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
