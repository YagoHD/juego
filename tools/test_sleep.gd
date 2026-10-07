extends SceneTree
## Prueba del saco de dormir sobre la isla, sin ventana (ya no hay cansancio: decisión de Yago).
## Uso: godot --headless --path . --script res://tools/test_sleep.gd
##   1. No hay cansancio: con comida y agua se corre siempre; no se guarda nada de sueño.
##   2. De día, el saco solo marca dónde reaparecer (no se duerme).
##   3. De noche, se duerme hasta la mañana: pasa el día y se recupera algo de vida.
##   4. El grano de alba se come como comida.

var _main: Node
var _step := 0
var _wait := 0
var _day := 0
var _health := 0.0


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	if _wait < 30:
		return false
	var needs: Needs = _main.get("_needs")
	var clock: DayNight = _main.get("_day_night")
	match _step:
		0:
			player.set_creative(false)
			needs.hunger = 100.0
			needs.thirst = 100.0
			needs._process(60.0 * 60.0 * 0.1)  # seis minutos despierto
			_check("Sin cansancio: se puede correr", needs.can_sprint())
			_check("No se guarda nada de sueño", not needs.to_data().has("fatigue"))
			needs.hunger = 50.0
			_check("El grano de alba se come", needs.eat("dawn_bean") and needs.hunger > 50.0)
			clock.set_hour(12.0)
			var at := player.global_position + Vector3(2, 0, 0)
			_main.call("_sleep", at)
			_check("De día no se duerme", absf(clock.hour - 12.0) < 0.1 and not _main.get("_sleeping"))
			_check("De día, el saco marca dónde reaparecer", player.get("_spawn_point").distance_to(at + Vector3.UP * 0.3) < 0.01)
			clock.set_hour(22.0)
			_day = clock.day
			player.combat.health = 40.0
			_health = player.combat.health
			_main.call("_sleep", player.global_position)
			_step = 1
			_wait = 0
		1:
			if _main.get("_sleeping"):
				return false
			_check("De noche se duerme hasta la mañana (%.1f h)" % clock.hour, clock.hour > 6.0 and clock.hour < 7.5 and clock.day == _day + 1)
			_check("Dormir recupera vida", player.combat.health > _health + 10.0)
			print("OK")
			return true
	return false
