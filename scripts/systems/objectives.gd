extends Node
class_name Objectives
## Objetivos del tutorial (la isla del naufragio): una lista de pasos que se van cumpliendo en
## orden; el actual se ve arriba a la derecha. Cada paso se comprueba solo (cada medio segundo)
## mirando al jugador, o con marcas que ponen otros sistemas: mark("diario_leido")...

signal completed(text: String)

## [texto que se muestra, comprobación (nombre de función de este script)]
const STEPS := [
	["Recoge el diario que hay en la arena (clic izquierdo)", "_has_journal"],
	["Lee el diario del capitán (J)", "_read_journal"],
	["Busca los cofres del naufragio (clic derecho para abrirlos)", "_opened_chest"],
	["Ponte la ropa que encuentres: abre el inventario (E) y llévala a su hueco", "_wears_clothes"],
	["Haz cuerda: arranca hierba alta para sacar fibra; luego E, Fabricar y 3 fibras en línea", "_made_rope"],
	["Lee la nota de la mochila (clic derecho) y fabrícala", "_has_backpack"],
	["Desmonta el cofre: en Fabricar, arrástralo solo al suelo y pulsa Desmontar", "_knows_chest"],
	["Explora la isla: busca las ruinas del noroeste (mira el mapa del diario); dicen que hay un cofre", "_near_ruins"],
]

var player: Player
var step := 0
var _flags := {}
var _timer := 0.0
var _label: Label
var _panel: PanelContainer


## Construye el recuadro de la pantalla (arriba a la derecha) dentro de 'canvas'.
func build_ui(canvas: CanvasLayer) -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.border_color = Color(0.55, 0.42, 0.28, 0.6)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -16
	_panel.offset_right = -16
	_panel.offset_top = 12
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Objetivo"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
	box.add_child(title)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(300, 0)
	_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_label)
	canvas.add_child(_panel)
	_refresh()


func mark(flag: String) -> void:
	_flags[flag] = true


func show_panel(on: bool) -> void:
	if _panel != null:
		_panel.visible = on and step < STEPS.size()


func _process(delta: float) -> void:
	if player == null or step >= STEPS.size():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	# Puede cumplirse más de uno a la vez (p. ej. si ya llevaba ropa).
	while step < STEPS.size() and bool(call(STEPS[step][1])):
		step += 1
		if step < STEPS.size():
			completed.emit("¡Hecho! Siguiente: " + String(STEPS[step][0]))
		else:
			completed.emit("¡Has aprendido lo básico de la isla! Ahora es toda tuya.")
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_panel.visible = step < STEPS.size()
	if step < STEPS.size():
		_label.text = "%s\n(%d/%d)" % [STEPS[step][0], step + 1, STEPS.size()]


# ------------------------------------------------------------------ comprobaciones

func _has_journal() -> bool:
	return player.has_journal


func _read_journal() -> bool:
	return _flags.has("diario_leido")


func _opened_chest() -> bool:
	return _flags.has("cofre_abierto")


func _wears_clothes() -> bool:
	return player.equipment["shirt"] != "" or player.equipment["pants"] != ""


func _made_rope() -> bool:
	return _flags.has("hecho_rope") or player.inventory.count_of("rope") > 6


func _has_backpack() -> bool:
	return player.equipment["backpack"] != ""


func _knows_chest() -> bool:
	return player.known_recipes.has("chest")


func _near_ruins() -> bool:
	var ruins := Structures.ruins_voxel()
	var me := Vector2(player.global_position.x, player.global_position.z) / 0.5
	return me.distance_to(Vector2(ruins)) < 40.0


# ------------------------------------------------------------------ guardar

func to_data() -> Dictionary:
	return {"step": step, "flags": _flags.keys()}


func from_data(data: Dictionary) -> void:
	step = clampi(int(data.get("step", 0)), 0, STEPS.size())
	_flags.clear()
	var flags: Array = data.get("flags", [])
	for f in flags:
		_flags[str(f)] = true
	_refresh()
