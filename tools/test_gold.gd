extends SceneTree
## Prueba del oro, sin ventana y sin cargar la isla: pepitas al picar, horno que funde en monedas.
## Uso: godot --headless --path . --script res://tools/test_gold.gd

func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nuggets := 0
	for i in 4000:
		for drop in ItemDB.drops_for(IslandGenerator.STONE, rng):
			if drop[0] == "gold_nugget":
				nuggets += 1
	_check("Picar piedra a veces da oro (%d de 4000)" % nuggets, nuggets > 60 and nuggets < 200)
	var ore := 0
	for i in 1000:
		for drop in ItemDB.drops_for(IslandGenerator.ORE, rng):
			if drop[0] == "gold_nugget":
				ore += 1
	_check("El mineral da oro más a menudo (%d de 1000)" % ore, ore > 200)
	var world := Node3D.new()
	root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	var furnace := PlacedItem.new()
	furnace.item_id = "furnace"
	world.add_child(furnace)
	var fire := furnace.campfire
	_check("El horno es una lumbre que funde", fire != null and fire.furnace)
	_check("Apagado no funde", fire.interact({"id": "gold_nugget", "count": 1}, player) == 0)
	fire.lit = true
	fire.fuel = 100.0
	_check("Encendido acepta la pepita", fire.interact({"id": "gold_nugget", "count": 1}, player) == 1)
	_check("No asa comida", fire.interact({"id": "raw_fish", "count": 1}, player) == 0)
	fire._process(Campfire.SMELT_TIME + 0.5)
	var coins := 0
	for node in get_nodes_in_group("item_drops"):
		if node.item_id == "gold_coin":
			coins += node.count
	_check("Una pepita fundida da 2 monedas (todo su valor)", coins == 2)
	_check("En el banco valdría menos (1,5)", VillageLaw.value_of("gold_nugget") < 2.0 * VillageLaw.value_of("gold_coin"))
	var campfire := PlacedItem.new()
	campfire.item_id = "campfire"
	world.add_child(campfire)
	campfire.campfire.lit = true
	_check("La hoguera no funde oro", campfire.campfire.interact({"id": "gold_nugget", "count": 1}, player) == 0)
	quit()
