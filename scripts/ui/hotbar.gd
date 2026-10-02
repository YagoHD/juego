extends Control
class_name Hotbar
## Barra de bloques abajo en el centro: los bloques de Blocks.HOTBAR con su color y su tecla,
## el seleccionado resaltado y su nombre encima. Teclas 1-9 o rueda del ratón para cambiar.

const SLOT_SIZE := 52
const SLOT_GAP := 6

var _slots: Array[Panel] = []
var _name_label: Label
var _selected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := Blocks.HOTBAR.size()
	var width := count * SLOT_SIZE + (count - 1) * SLOT_GAP
	# Anclada abajo en el centro; los márgenes (offsets) la colocan respecto a ese punto.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -width / 2.0
	offset_right = width / 2.0
	offset_top = -SLOT_SIZE - 18
	offset_bottom = -18

	for i in count:
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.position = Vector2(i * (SLOT_SIZE + SLOT_GAP), 0)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		add_child(slot)
		_slots.append(slot)

		# Icono: la textura de la cara de arriba del bloque, con los píxeles nítidos.
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var region := AtlasTexture.new()
		region.atlas = BlockTextures.atlas()
		region.region = BlockTextures.icon_region(Blocks.HOTBAR[i])
		icon.texture = region
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(10, 10)
		icon.size = Vector2(SLOT_SIZE - 20, SLOT_SIZE - 20)
		slot.add_child(icon)

		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = str(i + 1)
		number.position = Vector2(4, 0)
		number.add_theme_font_size_override("font_size", 13)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 3)
		slot.add_child(number)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, -30)
	_name_label.size = Vector2(width, 26)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)

	select(0)


func select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _slot_style(i == index))
	_name_label.text = Blocks.name_of(Blocks.HOTBAR[index])


func _slot_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.55)
	style.set_corner_radius_all(6)
	style.set_border_width_all(3 if selected else 1)
	style.border_color = Color(1, 1, 1, 0.95) if selected else Color(1, 1, 1, 0.25)
	return style
