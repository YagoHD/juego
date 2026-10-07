extends VBoxContainer
class_name EquipmentPanel
## Panel izquierdo del inventario (E): lo que lleva puesto el jugador (camiseta, pantalón,
## cinturón y mochila). Clic con una prenda cogida para ponérsela; clic en una puesta para
## quitársela (solo si sus bolsillos o la mochila están vacíos).

const SLOT := InventoryScreen.SLOT
const EQUIP_SLOTS := [
	["shirt", "Camiseta", "+2 huecos en la barra"],
	["pants", "Pantalón", "+2 huecos en la barra"],
	["belt", "Cinturón", "+2 huecos en la barra"],
	["backpack", "Mochila", "+18 huecos de inventario"],
	["offhand", "Escudo", "Bloquea con clic derecho; consume resistencia"],
	["head", "Cabeza", "Casco o gorro"], ["chest", "Torso", "Coraza o chaleco"],
	["legs", "Piernas", "Grebas o perneras"], ["feet", "Pies", "Botas"], ["hands", "Manos", "Guantes"],
	["cloak", "Capa", "Capa"], ["ring", "Anillo", "Anillo"], ["necklace", "Colgante", "Colgante"],
	["amulet", "Amuleto", "Amuleto"],
]

var _player: Player
var _screen: InventoryScreen
var _equip_views := {}        # hueco -> Panel
var _message: Label
var _stats: Label


func _init(player: Player, screen: InventoryScreen) -> void:
	_player = player
	_screen = screen
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Equipo"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for entry in EQUIP_SLOTS:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		grid.add_child(column)
		var view := _screen._make_slot_visual(column)
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.tooltip_text = "%s: %s" % [entry[1], entry[2]]
		view.gui_input.connect(_on_equip_input.bind(String(entry[0])))
		_equip_views[entry[0]] = view
		var label := Label.new()
		label.text = entry[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(SLOT + 14, 0)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.8, 0.76, 0.7))
		column.add_child(label)

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 12)
	_stats.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(240, 0)
	add_child(_stats)

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(150, 0)
	add_child(_message)

	_add_skills()
	_player.inventory_layout_changed.connect(_refresh)
	_refresh()


## Habilidades y su nivel (suben con el uso); al pasar el ratón, qué mejoran y cuánto falta.
func _add_skills() -> void:
	var title := Label.new()
	title.text = "Habilidades"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	for skill in Skills.INFO:
		var line := Label.new()
		var level := _player.skills.level(skill)
		line.text = "%s  %d" % [Skills.INFO[skill]["name"], level]
		line.tooltip_text = "%s\nSiguiente nivel: %d%%" % [Skills.INFO[skill]["perk"], int(_player.skills.progress(skill) * 100.0)]
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72) if level > 0 else Color(0.6, 0.57, 0.52))
		add_child(line)


func _exit_tree() -> void:
	if _player.inventory_layout_changed.is_connected(_refresh):
		_player.inventory_layout_changed.disconnect(_refresh)


func _on_equip_input(event: InputEvent, slot: String) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	_message.text = ""
	var held := _screen.cursor_stack()
	var worn: String = _player.equipment[slot]
	if held.is_empty():
		if worn == "":
			return
		var taken := _player.worn_stack(slot)
		if _player.unequip(slot) == "":
			_message.text = "Vacía primero los huecos que da %s." % ItemDB.display_name(worn).to_lower()
			return
		_screen.set_cursor_stack(taken)
	elif ItemDB.wear_slot(held["id"]) != slot:
		_message.text = "Eso no va ahí."
	elif worn == "":
		_player.equip(slot, held["id"], int(held.get("dur", -1)))
		_screen.set_cursor_stack({})
	else:
		# Cambiar una prenda por otra del mismo hueco.
		if not _player.can_unequip(slot):
			_message.text = "Vacía primero los huecos que da %s." % ItemDB.display_name(worn).to_lower()
			return
		var taken := _player.worn_stack(slot)
		_player.unequip(slot)
		_player.equip(slot, held["id"], int(held.get("dur", -1)))
		_screen.set_cursor_stack(taken)
	_refresh()


func _refresh() -> void:
	for slot in _equip_views:
		var view: Panel = _equip_views[slot]
		var worn: String = _player.equipment[slot]
		var icon: TextureRect = view.get_node("icon")
		if worn == "":
			# Silueta gris de lo que va en ese hueco (la dibujada; si no, el icono apagado).
			var outline := UiTheme.icon("slot_" + slot)
			icon.texture = outline if outline != null else ItemDB.icon(slot if not (slot in GearDB.SLOTS or slot == "offhand") else "silhouette_" + slot)
			icon.modulate = Color(1, 1, 1, 0.75 if outline != null else 0.18)
		else:
			icon.texture = ItemDB.icon(worn)
			icon.modulate = Color.WHITE
	var gear: Dictionary = _player.gear
	var burden := GearDB.burden(float(gear["weight"]))
	var lines := "Protección %d (recibes el %d%% del daño) · Peso %.1f kg" % [
		int(gear["armor"]), int(GearDB.damage_factor(float(gear["armor"])) * 100.0), float(gear["weight"])]
	if burden > 0.0:
		lines += "\nCargado: %d%% más lento y %d%% más cansado" % [int(burden * 50.0), int(burden * 100.0)]
	for set_id in gear["sets"]:
		lines += "\n%s: %d piezas" % [GearDB.SETS[set_id]["name"], gear["sets"][set_id]]
	_stats.text = lines

