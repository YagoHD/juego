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
]

var _player: Player
var _screen: InventoryScreen
var _equip_views := {}        # hueco -> Panel
var _message: Label


func _init(player: Player, screen: InventoryScreen) -> void:
	_player = player
	_screen = screen
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Equipo"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
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
		label.custom_minimum_size = Vector2(SLOT + 24, 0)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.8, 0.76, 0.7))
		column.add_child(label)

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(150, 0)
	add_child(_message)

	_player.inventory_layout_changed.connect(_refresh)
	_refresh()


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
		if _player.unequip(slot) == "":
			_message.text = "Vacía primero los huecos que da %s." % ItemDB.display_name(worn).to_lower()
			return
		_screen.set_cursor_stack({"id": worn, "count": 1})
	elif ItemDB.wear_slot(held["id"]) != slot:
		_message.text = "Eso no va ahí."
	elif worn == "":
		_player.equip(slot, held["id"])
		_screen.set_cursor_stack({})
	else:
		# Cambiar una prenda por otra del mismo hueco.
		if not _player.can_unequip(slot):
			_message.text = "Vacía primero los huecos que da %s." % ItemDB.display_name(worn).to_lower()
			return
		_player.unequip(slot)
		_player.equip(slot, held["id"])
		_screen.set_cursor_stack({"id": worn, "count": 1})
	_refresh()


func _refresh() -> void:
	for slot in _equip_views:
		var view: Panel = _equip_views[slot]
		var worn: String = _player.equipment[slot]
		var icon: TextureRect = view.get_node("icon")
		if worn == "":
			# Silueta apagada de lo que va en ese hueco.
			icon.texture = ItemDB.icon(slot)
			icon.modulate = Color(1, 1, 1, 0.18)
		else:
			icon.texture = ItemDB.icon(worn)
			icon.modulate = Color.WHITE

