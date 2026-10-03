extends SceneTree
## Prueba del inventario de rodillas y la vista de fabricar, sobre la isla real (sin ventana):
##   abrir el inventario arrodilla al personaje y pone la cámara de escena; "Fabricar" pasa a la
##   vista de la zona de trabajo; 3 hojas en línea dan el botón "Retorcer · Cuerda", que fabrica
##   la cuerda al inventario; lo que se deja sin usar vuelve al inventario al cerrar; al final el
##   jugador recupera el control.
## Uso: godot --headless --path . --script res://tools/test_craft_session.gd

var _main: Node
var _step := 0
var _wait := 0
var _fails := 0
var _t0 := 0


func _init() -> void:
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _lay_leaves(session: CraftSession, ground: GroundCrafting, count: int, row: int) -> void:
	var c := GroundRecipes.CELL
	var base := (session._area_center / c).floor() * c + Vector3(0.5, 0, 0.5 + row) * c
	for i in count:
		var p := base + Vector3(c * (i - 1), 0, 0)
		p.y = session._ground_y(p)
		session._placed.append(ground.place(p, "fiber", 0.0, Vector3i((p / 0.5 - Vector3(0, 0.5, 0)).floor())))


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	var session: CraftSession = _main.get("_session")
	var ground: GroundCrafting = _main.get("_ground")
	var screen: InventoryScreen = _main.get("_inventory_screen")
	match _step:
		0:
			if _wait < 30:
				return false
			player.set_creative(false)
			player.inventory.clear()
			player.learn("rope")
			_main.call("open_inventory")
			_check("Abrir el inventario arrodilla al personaje", session.active() and player.is_kneeling() and screen.visible)
			_check("La cámara de escena es la que se ve", root.get_viewport().get_camera_3d() != player.get_camera())
			session._enter_craft()
			_check("Fabricar pasa a la vista de la zona de trabajo", session.state == CraftSession.State.CRAFT and screen.layout() == "craft")
			_lay_leaves(session, ground, 3, 0)
			_step = 1
			_wait = 0
		1:
			if _wait < 5:
				return false
			var matches := ground.matches_near(session._area_center, 1.4)
			_check("3 hojas en línea en la zona = receta lista", matches.size() == 1 and GroundCrafting.label_of(matches[0]) == "Retorcer · Cuerda")
			session._update_buttons()
			_check("Aparece el botón de la receta", session._buttons_box.get_child_count() >= 1)
			session._start_working(matches[0])
			_t0 = Time.get_ticks_msec()
			_step = 2
		2:
			if Time.get_ticks_msec() - _t0 < 2000:
				return false
			_check("Al terminar, la cuerda está en el inventario", player.inventory.count_of("rope") == 1)
			_lay_leaves(session, ground, 2, 2)  # dos hojas sueltas, sin terminar nada
			screen.close()
			_check("Al cerrar, lo que no se usó vuelve al inventario", player.inventory.count_of("fiber") == 2)
			_check("Se levanta", not player.is_kneeling())
			_t0 = Time.get_ticks_msec()
			_step = 3
		3:
			if session.active() and Time.get_ticks_msec() - _t0 < 4000:
				return false
			_check("La cámara vuelve y el jugador recupera el control", not session.active() and not player.ui_open
				and root.get_viewport().get_camera_3d() == player.get_camera())
			print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
			return true
	return false


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
