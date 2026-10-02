extends Control
class_name Hotbar
## Barra de abajo: los 9 primeros huecos del inventario del jugador (icono y cantidad), el
## seleccionado resaltado y el nombre del objeto encima. Teclas 1-9 o rueda para cambiar.

const SLOTS := 9
const SLOT_SIZE := 52
const SLOT_GAP := 6

var _slots: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _name_label: Label
var _mode_label: Label
var _selected := -1
var _inventory: Inventory
var _infinite := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := SLOTS * SLOT_SIZE + (SLOTS - 1) * SLOT_GAP
	# Anclada abajo en el centro; los márgenes (offsets) la colocan respecto a ese punto.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -width / 2.0
	offset_right = width / 2.0
	offset_top = -SLOT_SIZE - 18
	offset_bottom = -18

	for i in SLOTS:
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.position = Vector2(i * (SLOT_SIZE + SLOT_GAP), 0)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		add_child(slot)
		_slots.append(slot)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(10, 10)
		icon.size = Vector2(SLOT_SIZE - 20, SLOT_SIZE - 20)
		slot.add_child(icon)
		_icons.append(icon)

		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = str(i + 1)
		number.position = Vector2(4, 0)
		number.add_theme_font_size_override("font_size", 12)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 3)
		slot.add_child(number)

		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(0, SLOT_SIZE - 22)
		count.size = Vector2(SLOT_SIZE - 5, 20)
		count.add_theme_font_size_override("font_size", 14)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		slot.add_child(count)
		_counts.append(count)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, -30)
	_name_label.size = Vector2(width, 26)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)

	_mode_label = Label.new()
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label.position = Vector2(width + 12, SLOT_SIZE * 0.5 - 12)
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mode_label.add_theme_constant_override("outline_size", 4)
	add_child(_mode_label)


## Muestra este inventario (infinite = modo creativo: sin cantidades).
func bind(inventory: Inventory, infinite: bool) -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	_infinite = infinite
	_inventory.changed.connect(_refresh)
	_mode_label.text = "Creativo (C)" if infinite else ""
	_refresh()


func select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_refresh()


func _refresh() -> void:
	if _inventory == null:
		return
	for i in SLOTS:
		_slots[i].add_theme_stylebox_override("panel", _slot_style(i == _selected))
		var stack := _inventory.get_slot(i)
		_icons[i].texture = null if stack.is_empty() else ItemDB.icon(stack["id"])
		if stack.is_empty():
			_counts[i].text = ""
		elif _infinite:
			_counts[i].text = "∞"
		else:
			_counts[i].text = str(stack["count"]) if int(stack["count"]) > 1 else ""
	var selected_stack := _inventory.get_slot(maxi(_selected, 0))
	_name_label.text = "" if selected_stack.is_empty() else ItemDB.display_name(selected_stack["id"])


func _slot_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.55)
	style.set_corner_radius_all(6)
	style.set_border_width_all(3 if selected else 1)
	style.border_color = Color(1, 1, 1, 0.95) if selected else Color(1, 1, 1, 0.25)
	return style
