extends Control
class_name Hotbar
## Barra de abajo: los primeros huecos del inventario del jugador (icono y cantidad), el
## seleccionado resaltado y el nombre del objeto encima. Teclas 1-9 o rueda para cambiar.
## Sin ropa solo hay 3 huecos: los bolsillos de la camiseta, el pantalón y el cinturón la
## alargan (hasta 9). La barra se dibuja siempre centrada con los huecos que haya.

const SLOTS := 9
const SLOT_SIZE := 52
const SLOT_GAP := 6
const WIDTH := SLOTS * SLOT_SIZE + (SLOTS - 1) * SLOT_GAP

var _slots: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _name_label: Label
var _mode_label: Label
var _selected := -1
var _inventory: Inventory
var _infinite := false
var _unlocked := SLOTS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anclada abajo en el centro; los márgenes (offsets) la colocan respecto a ese punto.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = -SLOT_SIZE - 18
	offset_bottom = -18

	for i in SLOTS:
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var dur := ColorRect.new()  # desgaste de la herramienta
		dur.name = "dur"
		dur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dur.position = Vector2(8, SLOT_SIZE - 9)
		dur.size = Vector2(SLOT_SIZE - 16, 3)
		dur.visible = false
		slot.add_child(dur)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, -30)
	_name_label.size = Vector2(WIDTH, 26)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)

	_mode_label = Label.new()
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mode_label.add_theme_constant_override("outline_size", 4)
	add_child(_mode_label)
	_layout()


## Muestra este inventario (infinite = modo creativo: sin cantidades); solo se ven los
## 'unlocked' primeros huecos.
func bind(inventory: Inventory, infinite: bool, unlocked := SLOTS) -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	_infinite = infinite
	_unlocked = clampi(unlocked, 1, SLOTS)
	_inventory.changed.connect(_refresh)
	_mode_label.text = "Creativo (C)" if infinite else ""
	_layout()
	_refresh()


func select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_refresh()


## Coloca los huecos disponibles centrados (y oculta el resto).
func _layout() -> void:
	var used := _unlocked * SLOT_SIZE + (_unlocked - 1) * SLOT_GAP
	var start := (WIDTH - used) / 2.0
	for i in SLOTS:
		_slots[i].visible = i < _unlocked
		_slots[i].position = Vector2(start + i * (SLOT_SIZE + SLOT_GAP), 0)
	_mode_label.position = Vector2(start + used + 12, SLOT_SIZE * 0.5 - 12)


func _refresh() -> void:
	if _inventory == null:
		return
	for i in _unlocked:
		_slots[i].add_theme_stylebox_override("panel", _slot_style(i == _selected))
		var stack := _inventory.get_slot(i)
		_icons[i].texture = null if stack.is_empty() else ItemDB.icon(stack["id"])
		InventoryScreen.show_durability(_slots[i].get_node("dur"), stack, SLOT_SIZE - 16)
		if stack.is_empty():
			_counts[i].text = ""
		elif _infinite:
			_counts[i].text = "∞"
		else:
			_counts[i].text = str(stack["count"]) if int(stack["count"]) > 1 else ""
	var selected_stack := _inventory.get_slot(clampi(_selected, 0, _unlocked - 1))
	_name_label.text = "" if selected_stack.is_empty() else ItemDB.display_name(selected_stack["id"])


func _slot_style(selected: bool) -> StyleBox:
	return UiTheme.slot_light(0.95) if selected else UiTheme.slot(0.9)
