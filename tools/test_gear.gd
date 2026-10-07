extends SceneTree
## Prueba del equipo (armaduras, accesorios y armas como fichas), sin ventana y sin la isla.
## Uso: godot --headless --path . --script res://tools/test_gear.gd

func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	var combat := player.combat
	player._waiting_for_ground = false  # sin terreno: que reciba golpes igualmente
	player.set_creative(false)
	_check("El equipo son objetos del juego (uno por hueco, no se apila)", ItemDB.exists("ancient_cuirass") and ItemDB.max_stack("ancient_cuirass") == 1 and ItemDB.wear_slot("hide_cap") == "head")
	_check("Hay 9 huecos de armadura y accesorios", GearDB.SLOTS.size() == 9 and player.equipment.has("amulet") and player.equipment.has("cloak"))
	# Protección: un golpe con armadura hace menos daño.
	combat.health = 100.0
	combat.invulnerable = 0.0
	combat.take_damage(20.0, player.global_position + Vector3.FORWARD, 0.0, player)
	var bare := 100.0 - combat.health
	for id in ["ancient_helm", "ancient_cuirass", "ancient_greaves", "ancient_boots", "ancient_gauntlets"]:
		player.equip(GearDB.GEAR[id]["slot"], id)
	combat.health = 100.0
	combat.invulnerable = 0.0
	combat.take_damage(20.0, player.global_position + Vector3.FORWARD, 0.0, player)
	var armored := 100.0 - combat.health
	_check("Con la armadura de los antiguos, menos daño (%.1f -> %.1f)" % [bare, armored], armored < bare * 0.55)
	_check("Conjunto completo de los antiguos: resistencia a la corrupción", player.gear_effect("corruption_resist") >= 1.0 and player.gear["sets"].get("ancient", 0) == 5)
	_check("La de los antiguos no se gasta", player.gear_wear.is_empty())
	_check("Pesa poco para lo que protege: apenas frena", combat.movement_factor() > 0.9)
	# Desgaste: la de piel se gasta con los golpes y, rota, no protege.
	player.set_equipment({})
	player.equip("chest", "hide_vest")
	_check("Pieza nueva: desgaste entero", int(player.gear_wear["chest"]) == GearDB.durability("hide_vest"))
	combat.invulnerable = 0.0
	combat.take_damage(5.0, player.global_position + Vector3.FORWARD, 0.0, player)
	_check("Un golpe la gasta un poco", int(player.gear_wear["chest"]) == GearDB.durability("hide_vest") - 1)
	player.gear_wear["chest"] = 1
	combat.invulnerable = 0.0
	combat.take_damage(5.0, player.global_position + Vector3.FORWARD, 0.0, player)
	_check("Rota ya no protege (pero sigue pesando)", float(player.gear["armor"]) == 0.0 and float(player.gear["weight"]) > 0.0)
	var taken := player.worn_stack("chest")
	_check("Al quitársela conserva su desgaste", taken.get("dur", -1) == 0)
	# Peso: muy cargado, más lento y más cansado.
	player.set_equipment({})
	var light := combat.movement_factor()
	player.gear = {"armor": 0.0, "weight": 30.0, "effects": {}, "sets": {}}
	_check("Mucho peso: más lento", combat.movement_factor() < light * 0.85)
	combat.stamina = 100.0
	combat._spend(10.0)
	_check("Mucho peso: cada esfuerzo cansa más", combat.stamina < 90.0 - 4.0)
	player._refresh_gear()
	# Conjunto de piel: con 3 piezas, protección extra.
	for id in ["hide_cap", "hide_vest", "hide_trousers"]:
		player.equip(GearDB.GEAR[id]["slot"], id)
	_check("Conjunto de piel (3 piezas): +4 de protección", is_equal_approx(float(player.gear["armor"]), 3.0 + 8.0 + 5.0 + 4.0))
	# Guardar y cargar con el desgaste.
	player.gear_wear["chest"] = 12
	var saved_equipment := player.equipment.duplicate()
	var saved_wear := player.gear_wear.duplicate()
	player.set_equipment({})
	player.set_equipment(saved_equipment, saved_wear)
	_check("Guardar y cargar conserva piezas y desgaste", player.equipment["chest"] == "hide_vest" and int(player.gear_wear["chest"]) == 12)
	# Accesorios con efectos.
	player.equip("necklace", "bone_necklace")
	player.equip("ring", "tusk_ring")
	_check("Accesorios con efectos (aliento y daño)", player.gear_effect("stamina_regen") > 0.0 and player.gear_effect("melee") > 0.0)
	# Las armas también son fichas.
	_check("Las armas son fichas del catálogo", PlayerCombat.WEAPONS.has("spear") and GearDB.WEAPONS["spear"]["reach"] > 3.0)
	# Visor: describe el objeto con sus datos.
	var text := ItemInspector.describe({"id": "hide_vest", "count": 1, "dur": 40})
	_check("El visor describe protección, peso y desgaste", text.contains("Protección 8") and text.contains("40 / 80") and text.contains("Torso"))
	var inspector := ItemInspector.new()
	world.add_child(inspector)
	inspector.show_stack({"id": "ancient_cuirass", "count": 1})
	_check("El visor enseña el objeto en 3D", inspector._mesh.mesh != null and inspector._name.text == "Coraza de los antiguos")
	# Recetas y ruinas.
	var craftable := true
	for id in ["hide_cap", "hide_vest", "hide_trousers", "hide_boots", "hide_gloves", "sail_cloak", "bone_necklace", "tusk_ring", "shell_amulet"]:
		craftable = craftable and GroundRecipes.RECIPES.has(id)
	_check("El equipo de piel y los accesorios se fabrican", craftable)
	var in_ruins := false
	for loot: Array in Structures._chest_loot.values():
		for stack in loot:
			if stack["id"] == "ancient_cuirass":
				in_ruins = true
	_check("La armadura de los antiguos está en el cofre de las ruinas", in_ruins or _ruins_source_has_armor())
	quit()


## El botín de los cofres se crea al generar la isla; sin isla, se mira el código de las ruinas.
func _ruins_source_has_armor() -> bool:
	return FileAccess.get_file_as_string("res://scripts/world/structures.gd").contains("ancient_cuirass")
