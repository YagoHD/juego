extends Node
class_name CraftSession
## Inventario de rodillas y vista de fabricar.
##   1. Al abrir el inventario (E) el personaje se arrodilla, deja la mochila abierta en el suelo
##      y la cámara sale a tercera persona; el inventario se ve semitransparente a la izquierda.
##      Si hay una mesa de trabajo cerca, se gira hacia ella.
##   2. Con el botón "Fabricar" la cámara se acerca a la zona de trabajo (el suelo delante del
##      personaje o el tablero de la mesa). Los objetos se arrastran del inventario al mundo y
##      quedan donde se suelten (encima de otro: apilados). Cuando forman una receta conocida
##      aparece un botón ("Coser · Mochila improvisada") y el personaje trabaja con las manos.
##      A la derecha, el recetario: al elegir una receta se dibuja en transparente en su sitio.
##   3. Al cerrar, lo que se dejó y no se usó vuelve al inventario; el personaje recoge la
##      mochila, se levanta y la cámara vuelve a su sitio.

signal ended  # la cámara ya volvió: el jugador recupera el control

enum State { OFF, KNEEL, CRAFT, LEAVING }

const TABLE_SEARCH := 4          # bloques alrededor en los que se busca una mesa
const AREA_RADIUS := 0.85        # metros: tamaño de la zona de trabajo en el suelo
const CAMERA_SPEED := 7.0        # rapidez con la que la cámara llega a su sitio

var player: Player
var ground: GroundCrafting
var screen: InventoryScreen
var state := State.OFF

var _camera: Camera3D
var _cam_target := Transform3D()
var _area_center := Vector3.ZERO
var _table := Vector3i.ZERO
var _has_table := false
var _orbit := 0.0                # giro de la vista de fabricar alrededor de la zona (radianes)
var _distance := 1.25            # distancia de la vista de fabricar
var _rotating := false
var _placed: Array[PlacedItem] = []
var _backpack_prop: Node3D
var _preview: MeshInstance3D
var _preview_id := ""
var _preview_yaw := 0.0
var _working := {}               # receta que se está trabajando (o {})
var _work_time := 0.0
var _work_tick := 0.0
var _ui: Control
var _craft_button: Button
var _craft_panel: Control
var _buttons_box: HBoxContainer
var _hint: Label
var _book: Control
var _buttons_key := ""


func active() -> bool:
	return state != State.OFF


# ------------------------------------------------------------------ empezar y terminar

## Empieza al abrir el inventario. Devuelve false si ahora no puede arrodillarse (en el agua,
## en el aire, volando o en creativo): entonces el inventario se abre como siempre.
func begin() -> bool:
	if state != State.OFF or player.creative or not player.can_kneel():
		return false
	state = State.KNEEL
	_find_table()
	if _has_table:
		_face(_table_top())
	player.set_kneeling(true)
	_put_backpack_down()
	screen.set_layout("kneel")
	_camera = Camera3D.new()
	_camera.fov = Settings.fov
	_camera.cull_mask = 0xFFFFF
	get_parent().add_child(_camera)
	_camera.global_transform = player.get_camera().global_transform
	_camera.make_current()
	_cam_target = _kneel_view()
	_build_ui()
	Sfx.play("pagina", null, -10.0, 0.2)
	return true


## Termina (al cerrar el inventario): devuelve lo sobrante y la cámara vuelve sola a su sitio.
func end() -> void:
	if state == State.OFF or state == State.LEAVING:
		return
	_stop_working()
	_return_leftovers()
	ground.set_template("")
	if _preview != null:
		_preview.queue_free()
		_preview = null
	_ui = null  # la pantalla de inventario libera su capa extra al cerrarse
	player.set_kneeling(false)
	_pick_backpack_up()
	state = State.LEAVING
	_cam_target = player.get_camera().global_transform


func _finish() -> void:
	state = State.OFF
	player.get_camera().make_current()
	if _camera != null:
		_camera.queue_free()
		_camera = null
	ended.emit()


# ------------------------------------------------------------------ cada fotograma

func _process(delta: float) -> void:
	if state == State.OFF or _camera == null:
		return
	if state == State.LEAVING:
		_cam_target = player.get_camera().global_transform
	elif state == State.CRAFT:
		_cam_target = _craft_view()
	var k := 1.0 - exp(-CAMERA_SPEED * delta)
	_camera.global_transform = _camera.global_transform.interpolate_with(_cam_target, k)
	if state == State.LEAVING:
		if _camera.global_position.distance_to(_cam_target.origin) < 0.05:
			_finish()
		return
	if state == State.CRAFT:
		_update_preview()
		_update_work(delta)
		_update_buttons()


# ------------------------------------------------------------------ cámaras

## Vista de rodillas: el personaje de frente y algo de lado, a la derecha de la pantalla (a la
## izquierda queda el inventario).
func _kneel_view() -> Transform3D:
	var p := player.global_position
	var fwd := -player.global_basis.z
	var right := player.global_basis.x
	var pos := p + fwd * 1.7 + right * 0.7 + Vector3.UP * 0.95
	var look := p + Vector3.UP * 0.4
	var t := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	# Mirar un poco a la izquierda del personaje: así queda a la derecha de la pantalla.
	look -= t.basis.x * 0.6
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


## Vista de fabricar: desde detrás del personaje, mirando la zona de trabajo desde arriba.
func _craft_view() -> Transform3D:
	var back := (_area_center - player.global_position)
	back.y = 0.0
	back = -back.normalized() if back.length() > 0.05 else player.global_basis.z
	# Casi desde arriba y algo de lado (si no, la cabeza del personaje tapa la zona).
	back = back.rotated(Vector3.UP, _orbit + 0.9)
	var pos := _area_center + back * _distance * 0.55 + Vector3.UP * _distance * 1.05
	var look := _area_center
	var t := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	look -= t.basis.x * _distance * 0.28  # la zona, a la derecha (a la izquierda, el inventario)
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


func _enter_craft() -> void:
	if state != State.KNEEL:
		return
	state = State.CRAFT
	_orbit = 0.0
	_distance = 1.25
	if _has_table:
		_area_center = _table_top()
	else:
		var fwd := -player.global_basis.z
		fwd.y = 0.0
		_area_center = player.global_position + fwd.normalized() * 0.8
	screen.set_layout("craft")
	_craft_button.visible = false
	_craft_panel.visible = true
	_book.visible = true
	_buttons_key = "?"
	Sfx.play("clic", null, -6.0)


func _back_to_kneel() -> void:
	if state != State.CRAFT:
		return
	_stop_working()
	state = State.KNEEL
	ground.set_template("")
	if _preview != null:
		_preview.visible = false
	screen.set_layout("kneel")
	_cam_target = _kneel_view()
	_craft_button.visible = true
	_craft_panel.visible = false
	_book.visible = false


# ------------------------------------------------------------------ mesa de trabajo

func _find_table() -> void:
	_has_table = false
	if player._tool == null:
		return
	var feet := Vector3i((player.global_position / 0.5).floor())
	var best := INF
	for dx in range(-TABLE_SEARCH, TABLE_SEARCH + 1):
		for dz in range(-TABLE_SEARCH, TABLE_SEARCH + 1):
			for dy in [-1, 0, 1]:
				var c := feet + Vector3i(dx, dy, dz)
				if player._tool.get_voxel(c) == IslandGenerator.WORKBENCH:
					var d := Vector2(dx, dz).length()
					if d < best:
						best = d
						_table = c
						_has_table = true


func _table_top() -> Vector3:
	return (Vector3(_table) + Vector3(0.5, 1.0, 0.5)) * 0.5


## Gira al personaje hacia un punto (solo en horizontal).
func _face(point: Vector3) -> void:
	var d := point - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player.rotation.y = atan2(-d.x, -d.z)


# ------------------------------------------------------------------ mochila en el suelo

func _put_backpack_down() -> void:
	var kind: String = player.equipment["backpack"]
	if kind == "":
		return
	player._avatar.set_backpack("")
	_backpack_prop = Node3D.new()
	get_parent().add_child(_backpack_prop)
	var right := player.global_basis.x
	var fwd := -player.global_basis.z
	_backpack_prop.global_position = player.global_position + right * 0.32 + fwd * 0.12
	_backpack_prop.rotation.y = player.rotation.y + 0.5
	var rough := kind == "rough_backpack"
	var body := Color(0.8, 0.75, 0.63) if rough else Color(0.5, 0.36, 0.2)
	var flap := Color(0.72, 0.58, 0.38) if rough else Color(0.58, 0.43, 0.25)
	# Bolsa abierta: el cuerpo de pie y la solapa caída hacia delante, con algo asomando.
	_prop_box(Vector3(0, 0.1, 0), Vector3(0.17, 0.2, 0.1), body)
	_prop_box(Vector3(0, 0.012, -0.11), Vector3(0.17, 0.024, 0.12), flap)
	_prop_box(Vector3(0.03, 0.2, 0.0), Vector3(0.06, 0.05, 0.05), Color(0.82, 0.68, 0.45))  # cuerda
	_prop_box(Vector3(-0.04, 0.2, 0.01), Vector3(0.05, 0.035, 0.05), Color(0.86, 0.82, 0.72))  # tela


func _prop_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	part.material_override = material
	part.position = pos
	_backpack_prop.add_child(part)


func _pick_backpack_up() -> void:
	if _backpack_prop != null:
		_backpack_prop.queue_free()
		_backpack_prop = null
	player._avatar.set_backpack(player.equipment["backpack"])


# ------------------------------------------------------------------ poner objetos en el mundo

## Lo que hay bajo el ratón: {"point", "normal", "item"?} ({} si nada).
func _mouse_hit() -> Dictionary:
	var mouse := player.get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var to := from + _camera.project_ray_normal(mouse) * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var out := {"point": hit.position, "normal": hit.normal}
	if hit.collider is PlacedItem:
		out["item"] = hit.collider
	return out


## ¿Se puede dejar algo ahí? Devuelve {"point", "support"} o {"stack_on": PlacedItem}, o {}.
func _drop_spot(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit["normal"]
	if hit.has("item"):
		var other: PlacedItem = hit["item"]
		if not _in_area(other.global_position, other.support):
			return {}
		if normal.y > 0.7:
			return {"stack_on": other}
		var p: Vector3 = hit["point"]
		p.y = other.base_y
		return {"point": p, "support": other.support}
	if normal.y < 0.7:
		return {}
	var point: Vector3 = hit["point"]
	var support := Vector3i(((point - normal * 0.25) / 0.5).floor())
	if not _in_area(point, support):
		return {}
	return {"point": point, "support": support}


func _in_area(point: Vector3, support: Vector3i) -> bool:
	if _has_table:
		return player._tool != null and player._tool.get_voxel(support) == IslandGenerator.WORKBENCH \
			and point.distance_to(_area_center) < 1.6
	var flat := Vector2(point.x - _area_center.x, point.z - _area_center.z)
	return flat.length() < AREA_RADIUS and absf(point.y - _area_center.y) < 0.8


## Deja uno del montón que lleva el ratón donde está el ratón.
func _drop_one() -> void:
	var held := screen.cursor_stack()
	if held.is_empty() or not _working.is_empty():
		return
	var spot := _drop_spot(_mouse_hit())
	if spot.is_empty():
		return
	var id: String = held["id"]
	var item: PlacedItem
	if spot.has("stack_on"):
		item = ground.stack_on(spot["stack_on"], id, _preview_yaw)
		if item == null:
			player.notice.emit("No se puede apilar más alto.")
			return
	else:
		item = ground.place(spot["point"], id, _preview_yaw, spot["support"])
	_placed.append(item)
	var left := int(held["count"]) - 1
	screen.set_cursor_stack({} if left <= 0 else {"id": id, "count": left})
	Sfx.play("colocar", item.global_position, -8.0)
	_preview_yaw += randf_range(-0.4, 0.4)  # cada uno un poco distinto, como dejado a mano


## Clic en un objeto del mundo con la mano vacía: se coge (para moverlo o devolverlo).
func _take(item: PlacedItem) -> void:
	if not _in_area(item.global_position, item.support):
		return
	var id := ground.remove(item)
	_placed.erase(item)
	screen.set_cursor_stack({"id": id, "count": 1})
	Sfx.play("recoger", null, -8.0, 0.15)


func _return_leftovers() -> void:
	for item in _placed:
		if is_instance_valid(item) and ground.has_placed(item):
			var id := ground.remove(item)
			var left := player.pick_up(id, 1)
			if left > 0:
				ItemDrop.spawn(get_parent(), item.global_position + Vector3.UP * 0.3, id, left)
	_placed.clear()


func _update_preview() -> void:
	var held := screen.cursor_stack()
	var mouse := player.get_viewport().get_mouse_position()
	var spot := {} if held.is_empty() or screen.is_over_ui(mouse) else _drop_spot(_mouse_hit())
	if spot.is_empty():
		if _preview != null:
			_preview.visible = false
		return
	var id: String = held["id"]
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(_preview)
	if id != _preview_id:
		_preview_id = id
		var is_block := ItemDB.block_of(id) >= 0
		_preview.mesh = ItemMesh.make(id, 0.18 if is_block else 0.3)
		var material := ItemMesh.make_material(id)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 1, 1, 0.5)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview.material_override = material
	var pos: Vector3
	if spot.has("stack_on"):
		var top: PlacedItem = ground._top_of(spot["stack_on"])
		pos = top.global_position + Vector3.UP * top.height()
	else:
		pos = spot["point"]
	var is_block_item := ItemDB.block_of(id) >= 0
	var basis := Basis(Vector3.UP, _preview_yaw)
	if not is_block_item:
		basis = basis * Basis(Vector3.RIGHT, -PI / 2.0)
	_preview.global_transform = Transform3D(basis, pos + Vector3.UP * (0.09 if is_block_item else 0.012))
	_preview.visible = true


# ------------------------------------------------------------------ ratón sobre el mundo

func _on_world_input(event: InputEvent) -> void:
	if state != State.CRAFT:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _rotating:
			_orbit -= motion.relative.x * 0.008
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
			_rotating = button.pressed
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not button.pressed:
				return
			var dir := 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if not screen.cursor_stack().is_empty():
				_preview_yaw += dir * 0.35  # con algo cogido, la rueda lo gira
			else:
				_distance = clampf(_distance - dir * 0.12, 0.7, 2.6)  # si no, acerca o aleja
		MOUSE_BUTTON_LEFT:
			if not button.pressed:
				return
			if not screen.cursor_stack().is_empty():
				_drop_one()
			else:
				var hit := _mouse_hit()
				if hit.has("item"):
					_take(hit["item"])


# ------------------------------------------------------------------ fabricar

func _update_buttons() -> void:
	if _buttons_box == null:
		return
	var matches := ground.matches_near(_area_center, 1.4)
	var key := ""
	for m in matches:
		key += GroundCrafting.label_of(m) + "|"
	key += str(_working.is_empty())
	if key != _buttons_key:
		_buttons_key = key
		for child in _buttons_box.get_children():
			child.queue_free()
		for m in matches:
			var b := PauseMenu.menu_button(GroundCrafting.label_of(m))
			b.custom_minimum_size = Vector2(260, 44)
			b.disabled = not _working.is_empty()
			b.pressed.connect(_start_working.bind(m))
			_buttons_box.add_child(b)
	# Pista: qué falta (o cómo se usa).
	if not _working.is_empty():
		var recipe: Dictionary = GroundRecipes.RECIPES[_working["recipe"]]
		_hint.text = "%s...  %d%%" % [GroundCrafting.label_of(_working), int(_work_time / float(recipe["time"]) * 100.0)]
	elif not matches.is_empty():
		_hint.text = "¡Listo! Pulsa el botón para hacerlo."
	else:
		var partials := ground.partials_near(_area_center, 1.4)
		_hint.text = GroundCrafting.missing_text(partials[0]) if not partials.is_empty() else \
			"Arrastra objetos del inventario al suelo con la forma de lo que quieres hacer."


func _start_working(m: Dictionary) -> void:
	if not _working.is_empty():
		return
	_working = m
	_work_time = 0.0
	_work_tick = 0.0
	player.set_working(true)


func _update_work(delta: float) -> void:
	if _working.is_empty():
		return
	for item: PlacedItem in _working["items"]:
		if not is_instance_valid(item) or not ground.has_placed(item):
			_stop_working()  # alguien movió las piezas
			return
	_work_time += delta
	_work_tick -= delta
	if _work_tick <= 0.0:
		_work_tick = 0.4
		Sfx.play("golpe", _working["center"], -6.0, 0.2)
	if _work_time >= float(GroundRecipes.RECIPES[_working["recipe"]]["time"]):
		var m := _working
		_stop_working()
		ground.craft(m)


func _stop_working() -> void:
	if not _working.is_empty():
		_working = {}
		player.set_working(false)
		_buttons_key = "?"


# ------------------------------------------------------------------ paneles

func _build_ui() -> void:
	_ui = screen.overlay
	if not screen.world_input.is_connected(_on_world_input):
		screen.world_input.connect(_on_world_input)
		screen.world_drop.connect(_drop_one)
		player.recipe_learned.connect(func(_id: String) -> void: _refresh_book())

	_craft_button = PauseMenu.menu_button("Fabricar" + ("  (mesa de trabajo)" if _has_table else ""))
	_craft_button.custom_minimum_size = Vector2(300, 52)
	_craft_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_craft_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_craft_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_craft_button.offset_right = -40
	_craft_button.offset_bottom = -40
	_craft_button.pressed.connect(_enter_craft)
	_ui.add_child(_craft_button)

	# Abajo, en el centro de la zona derecha: pista y botones de las recetas que ya están listas.
	var bottom := PanelContainer.new()
	var style := UiTheme.panel(0.9, 14.0)
	bottom.add_theme_stylebox_override("panel", style)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 80
	bottom.offset_right = 520
	bottom.offset_bottom = -24
	bottom.visible = false
	_ui.add_child(bottom)
	_craft_panel = bottom
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bottom.add_child(column)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(420, 0)
	column.add_child(_hint)
	_buttons_box = HBoxContainer.new()
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_box.add_theme_constant_override("separation", 10)
	column.add_child(_buttons_box)
	var help := Label.new()
	help.text = "Arrastra al suelo · rueda: girar el objeto / acercar · botón derecho: girar la vista"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	column.add_child(help)
	var back := PauseMenu.menu_button("Volver")
	back.custom_minimum_size = Vector2(140, 34)
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(_back_to_kneel)
	var back_holder := CenterContainer.new()
	back_holder.add_child(back)
	column.add_child(back_holder)

	_book = _build_book()
	_book.visible = false
	_ui.add_child(_book)


## Rehace el recetario (al aprender algo, p. ej. desmontando).
func _refresh_book() -> void:
	if _book == null or not is_instance_valid(_book) or _ui == null:
		return
	var was_visible := _book.visible
	_book.queue_free()
	_book = _build_book()
	_book.visible = was_visible
	_ui.add_child(_book)


## Recetario (a la derecha): las recetas conocidas; al pulsar una se dibuja en la zona.
func _build_book() -> Control:
	var panel := PanelContainer.new()
	var style := UiTheme.panel(0.9, 14.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_top = 16
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Recetario"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
	column.add_child(title)
	for recipe_id in player.known_recipes:
		if not GroundRecipes.RECIPES.has(recipe_id):
			continue
		var recipe: Dictionary = GroundRecipes.RECIPES[recipe_id]
		var on_table: bool = recipe.get("surface", "") == "workbench"
		var b := Button.new()
		b.text = ItemDB.display_name(recipe["result"]) + ("  (mesa)" if on_table else "")
		b.icon = ItemDB.icon(recipe["result"])
		b.expand_icon = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_constant_override("icon_max_width", 20)
		b.disabled = on_table and not _has_table
		b.tooltip_text = "Dibuja la forma en la zona de trabajo"
		b.pressed.connect(_show_template.bind(recipe_id))
		column.add_child(b)
	var clear := Button.new()
	clear.text = "Quitar dibujo"
	clear.focus_mode = Control.FOCUS_NONE
	clear.pressed.connect(func() -> void: ground.set_template(""))
	column.add_child(clear)
	return panel


## Dibuja la receta en la zona de trabajo (empezando por su esquina, centrada en la zona).
func _show_template(recipe_id: String) -> void:
	var recipe: Dictionary = GroundRecipes.RECIPES[recipe_id]
	var rows: Array = (recipe["layers"] as Array)[0]
	var width := (rows[0] as String).length()
	var depth := rows.size()
	var corner: Vector3
	if _has_table:
		corner = (Vector3(_table) + Vector3(0.0, 1.0, 0.0)) * 0.5 + Vector3(0.01, 0.0, 0.01)
	else:
		corner = _area_center - Vector3(width, 0, depth) * GroundRecipes.CELL * 0.5
		corner.y = _ground_y(corner)
	ground.set_template(recipe_id, corner)
	Sfx.play("pagina", null, -8.0, 0.2)


## Altura del suelo bajo un punto (para la plantilla).
func _ground_y(p: Vector3) -> float:
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 2.0, 1))
	return p.y if hit.is_empty() else (hit.position as Vector3).y
