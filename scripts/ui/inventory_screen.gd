extends Control
class_name InventoryScreen
## Pantalla de inventario (y de cofres): muestra una o varias "secciones" de huecos y deja mover
## objetos con el ratón, como en Minecraft:
##   - clic izquierdo: coger el montón entero / soltarlo, juntarlo con otro igual o intercambiar;
##   - clic derecho: coger la mitad / soltar de uno en uno;
##   - Mayúsculas + clic: enviar el montón a la otra sección.
## Cada sección es {"title": String, "inventory": Inventory, "slots": Array[int], "columns": int}
## y, opcional, "hint": String (nota bajo el título).

signal closed
signal overflow(id: String, count: int)  # lo que no cupo al cerrar: se tira al suelo
## En el modo "fabricar": clics, movimiento y rueda del ratón sobre el mundo (fuera de los paneles).
signal world_input(event: InputEvent)
## En el modo "fabricar": se ha soltado sobre el mundo un montón arrastrado desde un hueco.
signal world_drop

const SLOT := 48
const GAP := 4

var _sections: Array[Dictionary] = []
var _slot_views: Array[Dictionary] = []   # {"section": int, "index": int, "panel": Panel, "icon": TextureRect, "count": Label}
var _cursor := {}                          # montón cogido con el ratón ({} si nada)
var _cursor_from := {}                     # {"inventory": Inventory, "index": int} de dónde se cogió
var _cursor_view: Control
var _box: VBoxContainer
var _row: HBoxContainer
var _side: Control                        # panel opcional a la izquierda (equipo y fabricación)
var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _panel_style: StyleBox
var _layout := "normal"
var _press_pos := Vector2.ZERO           # dónde se pulsó en un hueco (para saber si se arrastra)
## Capa para paneles extra (botón Fabricar, recetario...) por encima de todo menos el cursor.
var overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UiTheme.wood_theme()

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var panel := PanelContainer.new()
	_panel = panel
	var style := UiTheme.panel(1.0, 18.0)  # madera (Kenney UI RPG)
	_panel_style = style
	panel.add_theme_stylebox_override("panel", style)
	_center.add_child(panel)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	panel.add_child(_row)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_row.add_child(_box)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_cursor_view = _make_slot_visual(null)
	_cursor_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_view.visible = false
	add_child(_cursor_view)


## Abre la pantalla con estas secciones y, si se da, un panel a la izquierda.
func open(sections: Array[Dictionary], side: Control = null) -> void:
	if _side != null:
		_side.queue_free()
	_side = side
	if _side != null:
		_row.add_child(_side)
		_row.move_child(_side, 0)
	set_sections(sections)
	visible = true


## Cambia los huecos que se ven sin cerrar la pantalla (p. ej. al ponerse la mochila).
func set_sections(sections: Array[Dictionary]) -> void:
	for section in _sections:
		var old: Inventory = section["inventory"]
		if old.changed.is_connected(_refresh):
			old.changed.disconnect(_refresh)
	_sections = sections
	for child in _box.get_children():
		child.queue_free()
	_slot_views.clear()
	for s in _sections.size():
		var section: Dictionary = _sections[s]
		var title := Label.new()
		title.text = section["title"]
		title.add_theme_font_size_override("font_size", 18)
		_box.add_child(title)
		if section.has("hint"):  # nota pequeña bajo el título
			var hint := Label.new()
			hint.text = section["hint"]
			hint.add_theme_font_size_override("font_size", 12)
			hint.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
			_box.add_child(hint)
		var grid := GridContainer.new()
		grid.columns = section["columns"]
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		_box.add_child(grid)
		for index in section["slots"]:
			var view := _make_slot_visual(grid)
			view.gui_input.connect(_on_slot_input.bind(s, int(index)))
			_slot_views.append({"section": s, "index": int(index), "panel": view,
				"icon": view.get_node("icon"), "count": view.get_node("count")})
		var inv: Inventory = section["inventory"]
		if not inv.changed.is_connected(_refresh):
			inv.changed.connect(_refresh)
	_refresh()


func close() -> void:
	if not visible:
		return
	_return_cursor()
	for child in overlay.get_children():
		child.queue_free()
	for section in _sections:
		var inv: Inventory = section["inventory"]
		if inv.changed.is_connected(_refresh):
			inv.changed.disconnect(_refresh)
	if _side != null:
		_side.queue_free()
		_side = null
	visible = false
	set_layout("normal")
	closed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse := get_global_mouse_position()
	# Sobre el mundo, en el modo fabricar, el objeto cogido se ve en 3D (vista previa) y no aquí.
	_cursor_view.visible = not _cursor.is_empty() and (_layout != "craft" or is_over_ui(mouse))
	if _cursor_view.visible:
		_cursor_view.position = mouse - Vector2(SLOT, SLOT) * 0.5


# ------------------------------------------------------------------ clics

func _on_slot_input(event: InputEvent, section: int, index: int) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	if not button.pressed:
		# Arrastrar un montón desde un hueco y soltarlo sobre el mundo (modo fabricar).
		var mouse := get_global_mouse_position()
		if _layout == "craft" and button.button_index == MOUSE_BUTTON_LEFT and not _cursor.is_empty() \
				and mouse.distance_to(_press_pos) > 8.0 and not is_over_ui(mouse):
			world_drop.emit()
		return
	_press_pos = get_global_mouse_position()
	var inv: Inventory = _sections[section]["inventory"]
	if button.shift_pressed and _cursor.is_empty():
		_quick_move(section, index)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		_left_click(inv, index)
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(inv, index)
	_refresh()


func _left_click(inv: Inventory, index: int) -> void:
	var slot := inv.get_slot(index)
	if _cursor.is_empty():
		if not slot.is_empty():  # coger el montón entero
			_cursor = slot.duplicate()
			_cursor_from = {"inventory": inv, "index": index}
			inv.set_slot(index, {})
	elif slot.is_empty():  # soltarlo entero
		inv.set_slot(index, _cursor)
		_cursor = {}
	elif slot["id"] == _cursor["id"]:  # juntar con uno igual
		var room := ItemDB.max_stack(slot["id"]) - int(slot["count"])
		var put := mini(room, int(_cursor["count"]))
		inv.set_slot(index, {"id": slot["id"], "count": int(slot["count"]) + put})
		_cursor["count"] = int(_cursor["count"]) - put
		if int(_cursor["count"]) <= 0:
			_cursor = {}
	else:  # intercambiar
		var previous := slot.duplicate()
		inv.set_slot(index, _cursor)
		_cursor = previous


func _right_click(inv: Inventory, index: int) -> void:
	var slot := inv.get_slot(index)
	if _cursor.is_empty():
		if not slot.is_empty():  # coger la mitad (redondeando hacia arriba)
			var half := int(ceil(int(slot["count"]) / 2.0))
			_cursor = {"id": slot["id"], "count": half}
			_cursor_from = {"inventory": inv, "index": index}
			inv.take(index, half)
	elif slot.is_empty() or (slot["id"] == _cursor["id"] and int(slot["count"]) < ItemDB.max_stack(slot["id"])):
		var current := 0 if slot.is_empty() else int(slot["count"])
		inv.set_slot(index, {"id": _cursor["id"], "count": current + 1})  # dejar uno
		_cursor["count"] = int(_cursor["count"]) - 1
		if int(_cursor["count"]) <= 0:
			_cursor = {}


func _quick_move(section: int, index: int) -> void:
	# Mayúsculas + clic: el montón pasa a la otra sección (o, si solo hay una, entre la barra y la
	# mochila del jugador).
	var inv: Inventory = _sections[section]["inventory"]
	var slot := inv.get_slot(index)
	if slot.is_empty():
		return
	# Destino: el otro inventario que haya en pantalla (cofre <-> jugador); si solo está el del
	# jugador, las otras secciones (barra <-> inventario).
	var target: Inventory = null
	var target_slots: Array = []
	for other in _sections:
		if other["inventory"] != inv and (target == null or other["inventory"] == target):
			target = other["inventory"]
			target_slots.append_array(other["slots"])
	if target == null:
		target = inv
		for other in _sections:
			if other != _sections[section]:
				target_slots.append_array(other["slots"])
	var left := _add_to_slots(target, target_slots, slot["id"], int(slot["count"]))
	inv.set_slot(index, {} if left == 0 else {"id": slot["id"], "count": left})


## Como Inventory.add pero solo en ciertos huecos. Devuelve lo que no cupo.
func _add_to_slots(inv: Inventory, slots: Array, id: String, count: int) -> int:
	var left := count
	var limit := ItemDB.max_stack(id)
	for pass_empty in [false, true]:
		for i in slots:
			if left == 0:
				return 0
			var s := inv.get_slot(i)
			if not pass_empty and not s.is_empty() and s["id"] == id and int(s["count"]) < limit:
				var put := mini(left, limit - int(s["count"]))
				inv.set_slot(i, {"id": id, "count": int(s["count"]) + put})
				left -= put
			elif pass_empty and s.is_empty():
				var put := mini(left, limit)
				inv.set_slot(i, {"id": id, "count": put})
				left -= put
	return left


func _return_cursor() -> void:
	# Al cerrar con algo cogido: vuelve a su hueco, o donde quepa.
	if _cursor.is_empty():
		return
	var inv: Inventory = _cursor_from.get("inventory")
	if inv != null:
		var index: int = _cursor_from["index"]
		if inv.is_empty_slot(index):
			inv.set_slot(index, _cursor)
			_cursor = {}
			return
		var left := _add_to_slots(inv, slots_of(inv), _cursor["id"], int(_cursor["count"]))
		_cursor = {} if left == 0 else {"id": _cursor["id"], "count": left}
	if not _cursor.is_empty() and not _sections.is_empty():
		var first: Inventory = _sections[_sections.size() - 1]["inventory"]
		var rest := _add_to_slots(first, slots_of(first), _cursor["id"], int(_cursor["count"]))
		if rest > 0:
			overflow.emit(_cursor["id"], rest)
	_cursor = {}


# ------------------------------------------------------------------ dibujo

func _make_slot_visual(parent: Control) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)
	panel.size = Vector2(SLOT, SLOT)
	panel.add_theme_stylebox_override("panel", UiTheme.slot())  # hueco hundido de pergamino
	var icon := TextureRect.new()
	icon.name = "icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(8, 8)
	icon.size = Vector2(SLOT - 16, SLOT - 16)
	panel.add_child(icon)
	var count := Label.new()
	count.name = "count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(0, SLOT - 22)
	count.size = Vector2(SLOT - 4, 20)
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 4)
	panel.add_child(count)
	var dur := ColorRect.new()  # desgaste de la herramienta
	dur.name = "dur"
	dur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dur.position = Vector2(6, SLOT - 8)
	dur.size = Vector2(SLOT - 12, 3)
	dur.visible = false
	panel.add_child(dur)
	if parent != null:
		parent.add_child(panel)
	return panel


func _refresh() -> void:
	for view in _slot_views:
		var inv: Inventory = _sections[view["section"]]["inventory"]
		_show_stack(view["icon"], view["count"], inv.get_slot(view["index"]))
		var stack := inv.get_slot(view["index"])
		(view["panel"] as Control).tooltip_text = "" if stack.is_empty() else ItemDB.display_name(stack["id"])  # nombre al pasar el ratón
	_cursor_view.visible = not _cursor.is_empty()
	_show_stack(_cursor_view.get_node("icon"), _cursor_view.get_node("count"), _cursor)


func _show_stack(icon: TextureRect, label: Label, stack: Dictionary) -> void:
	show_durability(icon.get_parent().get_node_or_null("dur"), stack, SLOT - 12)
	if stack.is_empty():
		icon.texture = null
		label.text = ""
	else:
		icon.texture = ItemDB.icon(stack["id"])
		label.text = str(stack["count"]) if int(stack["count"]) > 1 else ""


func _gui_input(event: InputEvent) -> void:
	# Fuera de los paneles: en el modo fabricar, el ratón trabaja sobre el mundo; en los demás,
	# un clic fuera se ignora (para no perder lo que se lleva cogido).
	if _layout == "craft" and (event is InputEventMouseButton or event is InputEventMouseMotion):
		world_input.emit(event)
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()


## Cómo se coloca la pantalla:
##   "normal": centrada y con el fondo oscurecido (cofres);
##   "kneel":  a la izquierda y casi transparente, para ver al personaje arrodillado;
##   "craft":  a la izquierda, sin oscurecer: el ratón trabaja sobre el mundo.
func set_layout(mode: String) -> void:
	_layout = mode
	_dim.color.a = 0.45 if mode == "normal" else (0.12 if mode == "kneel" else 0.0)
	_center.anchor_right = 1.0 if mode == "normal" else (0.55 if mode == "kneel" else 0.42)
	_panel.self_modulate.a = 1.0 if mode == "normal" else 0.85  # algo transparente: se ve el mundo
	if _side != null:
		_side.visible = mode != "craft"


func layout() -> String:
	return _layout


## ¿Está el ratón sobre algún panel (inventario o los de la capa extra)?
func is_over_ui(pos: Vector2) -> bool:
	if _panel.get_global_rect().has_point(pos):
		return true
	for child in overlay.get_children():
		var c := child as Control
		if c != null and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pos):
			return true
	return false


# ------------------------------------------------------------------ para el panel lateral

## Montón que lleva el ratón ({} si nada).
func cursor_stack() -> Dictionary:
	return _cursor


func set_cursor_stack(stack: Dictionary, from_inventory: Inventory = null, from_index := -1) -> void:
	_cursor = stack.duplicate()
	_cursor_from = {} if from_inventory == null else {"inventory": from_inventory, "index": from_index}
	_refresh()


func refresh() -> void:
	_refresh()


## Huecos de este inventario que se ven en pantalla (los que se pueden usar).
func slots_of(inv: Inventory) -> Array:
	var out := []
	for section in _sections:
		if section["inventory"] == inv:
			out.append_array(section["slots"])
	return out


## Barrita de lo que le queda a una herramienta (verde, amarilla, roja); oculta si está nueva.
static func show_durability(bar: ColorRect, stack: Dictionary, full_width: float) -> void:
	if bar == null:
		return
	var top := 0 if stack.is_empty() else ItemDB.max_durability(stack["id"])
	if top <= 0 or int(stack.get("dur", top)) >= top:
		bar.visible = false
		return
	var k := clampf(float(stack["dur"]) / top, 0.0, 1.0)
	bar.visible = true
	bar.size.x = full_width * k
	bar.color = Color(0.9, 0.25, 0.2) if k < 0.25 else (Color(0.95, 0.8, 0.25) if k < 0.6 else Color(0.4, 0.85, 0.35))
