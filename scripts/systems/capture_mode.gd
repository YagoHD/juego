extends Node
class_name CaptureMode
## Modo captura (para revisar el aspecto sin jugar): arranca, coloca la cámara y la escena según
## los argumentos (ver tools/capture.ps1), guarda una imagen y sale. No es parte del juego: solo
## se usa con "--capture=". Usa las piezas internas de Main.

var main: Main

# Modo captura: arranca, coloca la cámara, guarda una imagen y sale. Sirve para revisar el
# aspecto del juego sin tener que jugar. Ejemplo:
#   godot --path . -- --capture=C:/tmp/foto.png --tp --pitch=-0.3 --yaw=40 --up=30
var frames := -1


func update() -> void:
	var path := main._arg("--capture=")
	if path == "":
		return
	if frames < 0:
		if not main._player.is_on_ground_ready():
			return
		var at := main._arg("--at=")  # "x,z" en voxels: teletransporte (volando) a ese punto
		if at != "":
			var xz := at.split(",")
			var vx := int(xz[0])
			var vz := int(xz[1])
			var ground := main._generator.get_ground_height(vx, vz)
			main._player.global_position = Vector3(vx, ground + 2, vz) * Main.VOXEL_SIZE
		main._player.debug_pose(OS.get_cmdline_user_args().has("--tp"), float(main._arg("--pitch=", "0")),
			float(main._arg("--yaw=", str(rad_to_deg(main._player.rotation.y)))), float(main._arg("--up=", "0")) + (0.01 if at != "" else 0.0))
		var wear := main._arg("--wear=")  # ropa para la foto: "shirt,pants,belt,backpack"
		if wear != "":
			for id in wear.split(","):
				main._player.equip(ItemDB.wear_slot(id), id)
		var give := main._arg("--give=")  # objetos para la foto: "stone:12,dirt:30"
		if give != "":
			main._player.inventory.clear()
			for entry in give.split(","):
				var pair := entry.split(":")
				main._player.pick_up(pair[0], int(pair[1]))
		if OS.get_cmdline_user_args().has("--rain"):  # que llueva ya
			main._player.weather.force(true)
		if OS.get_cmdline_user_args().has("--campfire"):  # hoguera encendida delante
			var cf := -main._player.global_basis.z
			var cp: Vector3 = main._player.global_position + Vector3(cf.x, 0, cf.z).normalized() * 2.2
			var chit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cp + Vector3.UP * 3.0, cp + Vector3.DOWN * 6.0))
			if not chit.is_empty():
				var cpt: Vector3 = chit.position
				var fire := main._ground.place(cpt, "campfire", 0.0, Vector3i((cpt / Main.VOXEL_SIZE - Vector3(0, 0.5, 0)).floor()))
				fire.campfire.set_state({"lit": true, "fuel": 300.0})
		if OS.get_cmdline_user_args().has("--torches"):  # dos antorchas clavadas delante
			var fwd := -main._player.global_basis.z
			for k in [-1.2, 1.2]:
				var p: Vector3 = main._player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 3.0 + main._player.global_basis.x * float(k)
				var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0))
				if not hit.is_empty():
					var pt: Vector3 = hit.position
					main._ground.place(pt, "torch", 0.0, Vector3i((pt / Main.VOXEL_SIZE - Vector3(0, 0.5, 0)).floor()))
		if OS.get_cmdline_user_args().has("--showcase"):  # modelos voxelizados delante (pruebas de estilo)
			var fwd := -main._player.global_basis.z
			fwd.y = 0.0
			var names := ["palmera", "roca", "setas"]
			for k in names.size():
				var model_path := "res://assets/models/voxel/%s.res" % names[k]
				if not ResourceLoader.exists(model_path):
					continue
				var show := MeshInstance3D.new()
				show.mesh = load(model_path)
				main.add_child(show)
				var p: Vector3 = main._player.global_position + fwd.normalized() * (4.0 + k * 0.5) + main._player.global_basis.x * (float(k) - 1.0) * 2.2
				var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 8.0))
				show.global_position = hit.position if not hit.is_empty() else p
		if OS.get_cmdline_user_args().has("--bench"):
			_debug_bench()
		var shape := main._arg("--shape=")  # receta dibujada en el suelo delante del jugador
		if shape != "":
			_debug_lay_shape(shape)
		if OS.get_cmdline_user_args().has("--working"):
			main._player.debug_work_pose()
		if main._arg("--drop=") != "":  # soltar un objeto delante del jugador para verlo en el suelo
			var forward := -main._player.global_basis.z
			ItemDrop.spawn(self, main._player.global_position + forward * 1.6 + Vector3.UP, main._arg("--drop="), 1)
		if OS.get_cmdline_user_args().has("--journal"):  # recoger el diario y abrirlo en la página --page
			main._player.find_journal()
			for r in main._arg("--learn=").split(",", false):
				main._player.learn(r)
			main.open_journal()
			main._journal._spread = int(main._arg("--page=", "0"))
			main._journal.open()
		if main._arg("--cracks=") != "":  # grietas en el bloque apuntado, con ese avance (0..1)
			var t := main._player.aim.target()
			if t.has("voxel"):
				main._player.breaker.debug_cracks = true
				main._player.breaker.cracks.show_on(main._terrain.to_global(Vector3(t["voxel"])), Main.VOXEL_SIZE, float(main._arg("--cracks=")))
		if OS.get_cmdline_user_args().has("--pause"):  # menú de pausa a la vista (sin pausar: la foto debe salir)
			main._pause.visible = true
			if main._arg("--page=") != "":  # una página del menú: "graphics", "options"...
				main._pause._show_page(main._arg("--page="))
		if OS.get_cmdline_user_args().has("--fps"):  # el texto de rendimiento (F3)
			Settings.show_fps = true
		if OS.get_cmdline_user_args().has("--help"):
			main._help_on = true
		if OS.get_cmdline_user_args().has("--inventory"):
			main.open_inventory()
		if OS.get_cmdline_user_args().has("--craft"):  # inventario de rodillas y vista de fabricar
			main._player.inventory.add("fiber", 3)
			main.open_inventory()
			main._session._enter_craft()
			main._player.learn("rope")
			var c := GroundRecipes.CELL
			var base := (main._session._area_center / c).floor() * c + Vector3(0.5, 0, 0.5) * c
			for i in 3:
				var p := base + Vector3(c * (i - 1) + randf_range(-0.07, 0.07), 0, randf_range(-0.07, 0.07))
				p.y = main._session._ground_y(p)
				main._session._placed.append(main._ground.place(p, "fiber", randf() * TAU, Vector3i((p / Main.VOXEL_SIZE - Vector3(0, 0.5, 0)).floor())))
		if OS.get_cmdline_user_args().has("--open-chest"):  # abrir el cofre más cercano (con algo dentro)
			var me := Vector3i((main._player.global_position / Main.VOXEL_SIZE).floor())
			for d in 14:
				var found := false
				for x in range(-d, d + 1):
					for z in range(-d, d + 1):
						for y in range(-3, 4):
							var c := me + Vector3i(x, y, z)
							if not found and WorldVoxels.tool().get_voxel(c) == IslandGenerator.CHEST:
								var box := main._chests.get_or_create(c)
								if range(box.size()).all(func(i: int) -> bool: return box.get_slot(i).is_empty()):
									for item in [["rope", 5], ["wood", 30], ["berries", 12], ["stone_axe", 1], ["flint", 3], ["cloth", 8]]:
										box.add(item[0], item[1])
								# Solo el cofre (sin la ventana, que lo taparía), con el jugador delante mirándolo.
								main._open_chest = ChestVisual.open_at(self, main._terrain, c, box)
								main._player.global_position = (Vector3(c) + Vector3(0.5, 0.0, -2.2)) * Main.VOXEL_SIZE
								main._player.rotation.y = PI
								found = true
				if found:
					break
		var time := main._arg("--time=")  # hora del día para la foto, p. ej. "19.4" (atardecer)
		if time != "":
			main._day_night.set_hour(float(time))
		var action := main._arg("--action=")  # "nombre:t", p. ej. "voltereta:0.5"
		if action != "":
			var parts := action.split(":")
			main._player.debug_avatar_action(parts[0], float(parts[1]))
		frames = int(main._arg("--wait=", "90"))
		return
	frames -= 1
	var swing_at := int(main._arg("--swing=", "-1"))  # frames antes de la foto en que lanzar un golpe
	if frames == swing_at:
		main._player.debug_swing()
	if frames == 0:
		main.get_viewport().get_texture().get_image().save_png(path)
		print("[captura] guardada en ", path)
		main.get_tree().quit()


## Solo capturas: aprende la receta y deja su forma en el suelo, delante del jugador.
func _debug_lay_shape(recipe_id: String) -> void:
	main._player.learn(recipe_id)
	# Ejes del mundo más parecidos a "delante" y "derecha" (la cuadrícula invisible va alineada
	# con el mundo), y el origen en el centro de una celda.
	var f := -main._player.global_basis.z
	var forward := Vector3(signf(f.x), 0, 0) if absf(f.x) > absf(f.z) else Vector3(0, 0, signf(f.z))
	var right := forward.cross(Vector3.UP)
	var origin := main._player.global_position + forward * 1.1 - right * 0.3
	origin = (origin / GroundRecipes.CELL).floor() * GroundRecipes.CELL + Vector3(0.5, 0, 0.5) * GroundRecipes.CELL
	var space := main.get_world_3d().direct_space_state
	var cells := GroundRecipes.cells_of(recipe_id)
	for c: Vector2i in cells:
		var p := origin + right * (c.x * GroundRecipes.CELL) + forward * (c.y * GroundRecipes.CELL) \
			+ Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08))  # sueltos, sin anclar
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0))
		if hit.is_empty():
			continue
		var point: Vector3 = hit.position
		var support := Vector3i((point / Main.VOXEL_SIZE - Vector3(0, 0.5, 0)).floor())
		main._ground.place(point, cells[c], randf() * TAU, support)


## Solo capturas: dos mesas de trabajo delante del jugador, con el pico a medio montar encima.
func _debug_bench() -> void:
	var f := -main._player.global_basis.z
	var forward := Vector3i(int(signf(f.x)), 0, 0) if absf(f.x) > absf(f.z) else Vector3i(0, 0, int(signf(f.z)))
	var right := Vector3i(Vector3(forward).cross(Vector3.UP))
	var feet := Vector3i((main._player.global_position / Main.VOXEL_SIZE).floor())
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var cells := [feet + forward * 3, feet + forward * 3 + right]
	for c: Vector3i in cells:
		tool.set_voxel(c, IslandGenerator.WORKBENCH)
		tool.set_voxel(c + Vector3i.UP, IslandGenerator.AIR)
	main._player.learn("stone_pick")
	var top := (Vector3(cells[0]) + Vector3(0.25, 1.0, 0.25)) * Main.VOXEL_SIZE
	var cell := GroundRecipes.CELL
	var a := main._ground.place(top, "sticks", 0.3, cells[0])
	main._ground.place(top + Vector3(0, 0, cell), "sticks", -0.2, cells[0])
	main._ground.place(top + Vector3(cell, 0, 0), "rope", 0.5, cells[0])
	main._ground.stack_on(a, "stone", 0.1)


