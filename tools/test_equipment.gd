extends SceneTree
## Prueba del equipo, sin ventana: sin ropa hay 3 huecos de barra y 9 de inventario; cada
## prenda con bolsillos da +2 de barra, la mochila +18 de inventario; no se puede quitar una
## prenda si sus huecos tienen algo; lo recogido solo entra en huecos disponibles.
## Uso: godot --headless --path . --script res://tools/test_equipment.gd

var _fails := 0
var _p: Player


func _init() -> void:
	_p = Player.new()
	root.add_child.call_deferred(_p)


func _process(_delta: float) -> bool:
	if not _p.is_inside_tree():
		return false
	_p.set_physics_process(false)
	_p.set_process_input(false)
	_run(_p)
	return true


func _run(p: Player) -> void:
	_check("Sin ropa: barra 3, inventario 9", p.hotbar_size() == 3 and p.storage_size() == 9)
	_check("La camiseta no va en el hueco de mochila", not p.equip("backpack", "shirt"))
	p.equip("shirt", "shirt")
	_check("Con camiseta: barra 5", p.hotbar_size() == 5)
	p.equip("pants", "pants")
	p.equip("belt", "belt")
	_check("Con camiseta, pantalón y cinturón: barra 9", p.hotbar_size() == 9)
	p.equip("backpack", "backpack")
	_check("Con mochila: inventario 27", p.storage_size() == 27)
	p.inventory.set_slot(8, {"id": "stone", "count": 3})
	_check("No se quita el cinturón con algo en su bolsillo", p.unequip("belt") == "" and p.equipment["belt"] == "belt")
	p.inventory.set_slot(8, {})
	_check("Con el bolsillo vacío sí se quita", p.unequip("belt") == "belt" and p.hotbar_size() == 7)
	p.unequip("backpack")
	p.unequip("pants")
	p.unequip("shirt")
	p.inventory.clear()
	var left := p.pick_up("dirt", 64 * 20)
	_check("Sin ropa caben 12 montones (3 + 9): sobran %d" % left, left == 64 * 8)
	var used := 0
	for i in p.inventory.size():
		if not p.inventory.is_empty_slot(i):
			used += 1
	_check("Ningún objeto en huecos bloqueados", used == 12 and p.inventory.is_empty_slot(3) and p.inventory.is_empty_slot(18))
	var mesh := ItemMesh.make("rope", 0.3)
	_check("Malla de la cuerda en la mano", mesh != null and mesh.get_aabb().size.x > 0.2)
	p.inventory.clear()
	p.inventory.set_slot(0, {"id": "stone", "count": 5})
	p._hotbar_index = 0
	p._throw_held(false)
	var thrown := get_nodes_in_group("item_drops")
	_check("Q tira una piedra y tarda en volver", p.inventory.count_of("stone") == 4 and thrown.size() == 1
		and (thrown[0] as ItemDrop).pickup_delay >= 2.0)
	p._throw_held(true)
	_check("Ctrl+Q tira el montón entero", p.inventory.count_of("stone") == 0)
	p.inventory.clear()
	p._hotbar_index = 0
	var by_hand := p.break_time(IslandGenerator.WOOD)
	p.inventory.set_slot(0, {"id": "stone_axe", "count": 1})
	var with_axe := p.break_time(IslandGenerator.WOOD)
	_check("Tronco: %.1f s a mano, %.1f s con hacha" % [by_hand, with_axe], by_hand > 2.0 and with_axe < by_hand / 3.0)
	p.inventory.set_slot(0, {"id": "stone_knife", "count": 1})
	_check("El cuchillo corta hojas más rápido", p.break_time(IslandGenerator.LEAVES) < Blocks.hardness(IslandGenerator.LEAVES))
	p.inventory.clear()
	p.inventory.add("stone_axe", 1)
	p._hotbar_index = 0
	for k in 79:
		p.wear_tool()
	_check("El hacha aguanta 79 usos (le queda %d)" % int(p.inventory.get_slot(0).get("dur", -1)), p.inventory.count_of("stone_axe") == 1 and int(p.inventory.get_slot(0)["dur"]) == 1)
	p.wear_tool()
	_check("Al uso 80 se rompe", p.inventory.count_of("stone_axe") == 0)
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	quit()


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
