extends SceneTree
## Prueba del pueblo principal en la isla (sin ventana): se lleva al jugador al llano de B4 y se
## comprueba que están los vecinos, que cerca de él piensan con IA completa, que siguen la hora
## de la isla, que se puede hablar con uno, y que las pistas y las luces de los faros existen.
## Uso: godot --headless --path . --script res://tools/test_island_village.gd

var _main: Node
var _step := 0
var _wait := 0
var _fails := 0


func _init() -> void:
	Engine.max_fps = 60
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var island_village: IslandVillage = _main.get("_village")
	_wait += 1
	match _step:
		0:
			_check("El pueblo existe en la isla", island_village != null and island_village.village != null)
			if island_village == null:
				return _end()
			var village := island_village.village
			_check("Tiene %d vecinos" % village.records.size(), village.records.size() == VillageLayout.POPULATION.size())
			var facts := get_nodes_in_group("clues").map(func(c: Node) -> String: return (c as Clue).fact)
			_check("Pistas en el mundo: %s" % ", ".join(facts), facts.has("joyero_vacio") and facts.has("quilla_violeta"))
			_check("Luces de los faros (%d)" % (_main.get("_lamps") as Array).size(), (_main.get("_lamps") as Array).size() == 3)
			# Al pueblo: desde arriba, y a esperar a que haya suelo.
			var c := VillageLayout.ISLAND_CENTER
			var gen: IslandGenerator = _main.get("_generator")
			var ground := gen.get_ground_height(roundi((c.x + 3.0) * 2.0), roundi((c.y + 3.0) * 2.0)) * 0.5
			player.global_position = Vector3(c.x + 3.0, ground + 6.0, c.y + 3.0)  # el rayo del suelo mira 60 m hacia abajo
			player.set("_waiting_for_ground", true)
			_step = 1
			_wait = 0
		1:
			if _wait < 240:
				return false
			var village := island_village.village
			_check("Cerca del jugador, vecinos con IA completa (%d)" % village.active_count(), village.active_count() >= 5)
			var day_night: DayNight = _main.get("_day_night")
			_check("El pueblo sigue la hora de la isla", is_equal_approx(village.hour, day_night.hour))
			# Hablar con el vecino más cercano.
			var nearest: Villager = null
			for actor in village._actors.values():
				if is_instance_valid(actor) and not actor.dead and (nearest == null or actor.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
					nearest = actor
			_check("Hay alguien cerca para hablar", nearest != null)
			if nearest != null:
				player.talk_requested.emit(nearest)
				_check("Se abre el diálogo con %s" % nearest.villager_name, island_village.dialogue_open())
				island_village.close_dialogue()
			# Se guarda con la partida.
			_check("El pueblo se guarda con la partida", not island_village.to_data().is_empty())
			return _end()
	return false


func _end() -> bool:
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	return true


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
