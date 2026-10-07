extends VBoxContainer
class_name ItemInspector
## Visor del inventario (como en Skyrim): el objeto en 3D girando despacio; arrastrando con el
## ratón se gira en cualquier dirección y con la rueda se acerca o se aleja. Debajo, su nombre (del
## color de su rareza) y sus datos: hueco, protección, peso, desgaste, conjunto, efectos, arma...

const VIEW_SIZE := Vector2i(230, 200)
const EFFECT_NAMES := {"stamina_regen": "recuperas resistencia", "melee": "daño cuerpo a cuerpo",
	"sneak": "menos visible agachado", "corruption_resist": "resistencia a la corrupción"}

var _viewport: SubViewport
var _pivot: Node3D
var _mesh: MeshInstance3D
var _camera: Camera3D
var _name: Label
var _details: Label
var _id := ""
var _yaw := 0.0
var _pitch := -0.35
var _distance := 1.0
var _dragging := false
var _idle := 0.0              # segundos sin tocarlo: vuelve a girar solo


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(VIEW_SIZE.x, 0)
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(VIEW_SIZE)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(_on_view_input)
	holder.tooltip_text = "Arrastra para girarlo · rueda para acercar"
	add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(_viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.55
	environment.environment = env
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.2
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 140, 0)
	rim.light_energy = 0.5
	_viewport.add_child(rim)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_pivot.add_child(_mesh)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	_camera.current = true
	_viewport.add_child(_camera)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 16)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 12)
	_details.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(VIEW_SIZE.x, 0)
	add_child(_details)
	show_stack({})


## Enseña este montón ({} = nada). 'dur' es lo que le queda si se desgasta.
func show_stack(stack: Dictionary) -> void:
	var id := "" if stack.is_empty() else str(stack["id"])
	if id == "":
		_mesh.mesh = null
		_name.text = "Pasa el ratón por un objeto"
		_name.add_theme_color_override("font_color", Color(0.8, 0.76, 0.68))
		_details.text = ""
		_id = ""
		return
	if id != _id:
		_id = id
		_mesh.mesh = ItemMesh.make(id, 0.5)
		_mesh.material_override = ItemMesh.make_material(id)
		# Centrar y encuadrar: la cámara se aleja según lo grande que sea.
		var box := _mesh.mesh.get_aabb()
		_mesh.position = -box.get_center()
		_distance = maxf(box.size.length() * 1.6, 0.4)
		_yaw = 0.6
		_pitch = -0.35
	_name.text = ItemDB.display_name(id)
	_name.add_theme_color_override("font_color", GearDB.rarity_color(id))
	_details.text = describe(stack)


## Los datos del objeto, en texto.
static func describe(stack: Dictionary) -> String:
	var id := str(stack["id"])
	var lines: Array[String] = []
	if GearDB.is_gear(id):
		var info: Dictionary = GearDB.GEAR[id]
		lines.append("%s · %s · %s" % [GearDB.SLOT_NAMES[info["slot"]], GearDB.RARITIES[info["rarity"]]["name"], GearDB.ORIGINS.get(info["origin"], "")])
		lines.append("Protección %d · Peso %.1f kg · Nivel %d" % [int(info.get("armor", 0.0)), float(info.get("weight", 0.0)), int(info.get("level", 1))])
		var durability := int(info.get("durability", 0))
		if durability > 0:
			lines.append("Desgaste: %d / %d" % [int(stack.get("dur", durability)), durability])
		else:
			lines.append("No se desgasta")
		for key in info.get("effects", {}):
			lines.append("+%d%% %s" % [int(float(info["effects"][key]) * 100.0), EFFECT_NAMES.get(key, key)])
		if info.has("set"):
			lines.append("Conjunto: %s" % GearDB.SETS[info["set"]]["name"])
		lines.append(str(info.get("desc", "")))
	elif GearDB.WEAPONS.has(id):
		var weapon: Dictionary = GearDB.WEAPONS[id]
		lines.append("Arma %s · %s" % [weapon.get("style", ""), GearDB.RARITIES[weapon.get("rarity", "common")]["name"]])
		lines.append("Daño %d · Alcance %.1f m · Esfuerzo %d" % [int(weapon["damage"]), float(weapon["reach"]), int(weapon["cost"])])
	if stack.has("dur") and not GearDB.is_gear(id):
		lines.append("Desgaste: %d" % int(stack["dur"]))
	if int(stack.get("count", 1)) > 1:
		lines.append("Cantidad: %d" % int(stack["count"]))
	lines.append("Valor: %.1f monedas" % VillageLaw.value_of(id))
	return "\n".join(lines)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 0.2)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 5.0)
		_idle = 0.0
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw += motion.relative.x * 0.01
		_pitch = clampf(_pitch + motion.relative.y * 0.01, -1.5, 1.5)
		_idle = 0.0
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle += delta
	if not _dragging and _idle > 2.0:
		_yaw += delta * 0.6  # gira solo mientras nadie lo toca
	_pivot.rotation = Vector3(0.0, _yaw, 0.0)
	_camera.position = Vector3(0, -sin(_pitch), cos(_pitch)) * _distance
	_camera.look_at(Vector3.ZERO)
