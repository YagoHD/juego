extends SceneTree
## Prueba del sueño sobre la isla, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_sleep.gd
##   1. El cansancio sube despierto; cansado no se corre; el grano de alba lo baja.
##   2. Dónde se duerme: a la intemperie, bajo techo, entre paredes y techo, sin cama.
##   3. Al llegar al tope de cansancio se desmaya: poca vida, mareo y modorra al despertar.
##   4. Dormir en el saco de noche a la intemperie: amanece, algo de cansancio y mareo.
##   5. El cansancio y el mareo se guardan.

var _main: Node
var _step := 0
var _wait := 0
var _day := 0


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_main.add_child(body)
	body.global_position = at


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
			needs.fatigue = 0.0
			needs._process(60.0)  # un minuto despierto
			_check("El cansancio sube despierto (%.1f)" % needs.fatigue, needs.fatigue > 2.0 and needs.fatigue < 5.0)
			needs.fatigue = Needs.TIRED + 1.0
			_check("Cansado no se corre", not needs.can_sprint())
			_check("El grano de alba despeja", needs.eat("dawn_bean") and needs.fatigue < Needs.TIRED - 30.0)
			# Dónde se duerme: lejos del jugador, en el aire (sin terreno alrededor).
			var space := player.get_world_3d().direct_space_state
			var none: Array[RID] = []
			var spot := player.global_position + Vector3(0, 40, 0)
			_check("Sin nada alrededor: a la intemperie", SleepSpot.evaluate(space, spot, none) == "outdoors")
			_check("Sin cama: en el suelo", SleepSpot.evaluate(space, spot, none, false) == "ground")
			_box(spot + Vector3(0, 2.5, 0), Vector3(4, 0.3, 4))
			_step = 1
		1:
			# Esperar un fotograma de física para que el techo exista.
			var space := player.get_world_3d().direct_space_state
			var none: Array[RID] = []
			var spot := player.global_position + Vector3(0, 40, 0)
			_check("Con techo: bajo techo", SleepSpot.evaluate(space, spot, none) == "roof")
			for i in 4:
				var side := Vector3.FORWARD.rotated(Vector3.UP, i * PI / 2.0) * 1.8
				_box(spot + side + Vector3(0, 1, 0), Vector3(3.8, 2, 3.8) * (Vector3(1, 1, 0.08) if i % 2 == 0 else Vector3(0.08, 1, 1)))
			_step = 2
		2:
			var space := player.get_world_3d().direct_space_state
			var none: Array[RID] = []
			var spot := player.global_position + Vector3(0, 40, 0)
			_check("Entre paredes y con techo: bien", SleepSpot.evaluate(space, spot, none) == "good")
			# Desmayo.
			player.combat.health = 100.0
			_day = clock.day
			clock.set_hour(12.0)
			needs.fatigue = 99.99
			needs._process(1.0)
			_step = 3
			_wait = 0
		3:
			if _wait < 10 or _main.get("_sleeping"):  # fundido, despertar y vuelta
				return false
			_check("Desmayo: poca vida (%d)" % player.combat.health, player.combat.health <= 35.0)
			_check("Desmayo: mareo y modorra", needs.dizzy > 0.0 and needs.groggy > 0.0 and not needs.can_sprint())
			_check("Desmayo: queda algo de cansancio (%.0f)" % needs.fatigue, needs.fatigue <= 41.0 and needs.fatigue > 20.0)
			_check("Desmayo: pasan unas horas (%.1f h)" % clock.hour, clock.hour > 15.0 and clock.hour < 17.0)
			# Saco de noche, al aire libre (la playa del naufragio).
			clock.set_hour(22.0)
			needs.fatigue = 60.0
			needs.dizzy = 0.0
			needs.groggy = 0.0
			_day = clock.day
			_main._sleep(player.global_position, true)
			_step = 4
			_wait = 0
		4:
			if _wait < 10 or _main.get("_sleeping"):
				return false
			_check("Saco de noche: amanece al día siguiente", clock.day == _day + 1 and absf(clock.hour - 6.5) < 0.2)
			_check("A la intemperie: algo de cansancio (%.0f) y mareo" % needs.fatigue, needs.fatigue <= 26.0 and needs.dizzy > 0.0)
			var data := needs.to_data()
			var other := Needs.new()
			other.from_data(data)
			_check("Se guarda el cansancio y el mareo", absf(other.fatigue - needs.fatigue) < 0.01 and absf(other.dizzy - needs.dizzy) < 0.01)
			other.free()
			return true
	return false
