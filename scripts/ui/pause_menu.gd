extends Control
class_name PauseMenu
## Menú de pausa (Esc): para el juego y deja continuar, cambiar opciones (sensibilidad del
## ratón, campo de visión, volumen...), ver los controles o guardar y salir.

signal resumed
signal quit_requested

## Controles del juego: [tecla, qué hace]. También se muestran con F1.
const CONTROLS := [
	["W A S D", "Andar (W dos veces: correr)"],
	["Espacio", "Saltar · nadar hacia arriba"],
	["Ratón", "Mirar"],
	["Clic izquierdo", "Romper bloque · coger un objeto del suelo"],
	["Mayús + clic izq.", "Coger todo un montón del suelo"],
	["Clic derecho", "Colocar bloque · abrir cofre · leer nota"],
	["1-9 / rueda", "Elegir hueco de la barra"],
	["E", "Inventario y equipo"],
	["J", "Diario del capitán"],
	["G", "Dejar el objeto en el suelo (sobre otro: apilarlo)"],
	["R (mantener)", "Fabricar o desmontar lo que brilla"],
	["Q / Ctrl + Q", "Tirar uno / el montón entero"],
	["V", "Cámara: 1ª persona, detrás, de frente"],
	["V + ratón", "Acercar o alejar la cámara"],
	["Alt (mantener)", "Girar la cámara alrededor"],
	["F", "Volar"],
	["C", "Modo creativo"],
	["T (mantener)", "Acelerar el tiempo"],
	["F1 / F3", "Ayuda / FPS"],
	["Esc", "Pausa"],
]

var _pages := {}   # nombre -> Control
var _fps_check: CheckBox
var _invert_check: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego en pausa
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	center.add_child(panel)
	var stack := VBoxContainer.new()  # solo se ve una página a la vez
	panel.add_child(stack)

	_pages["main"] = _build_main()
	_pages["options"] = _build_options()
	_pages["controls"] = _build_controls()
	for page: Control in _pages.values():
		stack.add_child(page)
	_show_page("main")


## Estilo de los paneles del juego (madera oscura con borde cálido).
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.09, 0.96)
	style.border_color = Color(0.55, 0.42, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	return style


static func title_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	return label


static func menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(320, 44)
	button.add_theme_font_size_override("font_size", 18)
	for state in [["normal", Color(0.24, 0.19, 0.15)], ["hover", Color(0.36, 0.28, 0.2)], ["pressed", Color(0.18, 0.14, 0.11)], ["disabled", Color(0.16, 0.14, 0.13)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = state[1]
		style.border_color = Color(0.55, 0.42, 0.28) if state[0] != "hover" else Color(0.85, 0.66, 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state[0], style)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.75))
	return button


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return box


func _build_main() -> Control:
	var box := _column()
	box.add_child(title_label("Isla del Naufragio", 28))
	box.add_child(title_label("En pausa", 16))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	for entry in [["Continuar", close], ["Opciones", _show_page.bind("options")],
			["Controles", _show_page.bind("controls")], ["Guardar y salir", func() -> void: quit_requested.emit()]]:
		var button := menu_button(entry[0])
		button.pressed.connect(entry[1])
		var holder := CenterContainer.new()
		holder.add_child(button)
		box.add_child(holder)
	return box


func _build_options() -> Control:
	var box := _column()
	box.add_child(title_label("Opciones", 24))
	box.add_child(_slider("Sensibilidad del ratón", 0.3, 3.0, Settings.sensitivity / Settings.DEFAULT_SENSITIVITY,
		func(v: float) -> void: Settings.sensitivity = Settings.DEFAULT_SENSITIVITY * v, "x%.1f"))
	box.add_child(_slider("Campo de visión", 60.0, 100.0, Settings.fov,
		func(v: float) -> void: Settings.fov = v, "%d°"))
	var set_volume := func(v: float) -> void:
		Settings.volume = v
		Settings.apply_volume()
	box.add_child(_slider("Volumen", 0.0, 1.0, Settings.volume, set_volume, "%d%%", 100.0))
	_invert_check = CheckBox.new()
	_invert_check.text = "Invertir el ratón (arriba / abajo)"
	_invert_check.button_pressed = Settings.invert_y
	_invert_check.focus_mode = Control.FOCUS_NONE
	_invert_check.toggled.connect(func(on: bool) -> void: Settings.invert_y = on)
	box.add_child(_invert_check)
	_fps_check = CheckBox.new()
	_fps_check.text = "Mostrar FPS (también con F3)"
	_fps_check.button_pressed = Settings.show_fps
	_fps_check.focus_mode = Control.FOCUS_NONE
	_fps_check.toggled.connect(func(on: bool) -> void: Settings.show_fps = on)
	box.add_child(_fps_check)
	var back := menu_button("Volver")
	back.pressed.connect(func() -> void:
		Settings.save_settings()
		_show_page("main"))
	var holder := CenterContainer.new()
	holder.add_child(back)
	box.add_child(holder)
	return box


func _slider(text: String, low: float, high: float, value: float, on_change: Callable, fmt: String, shown_scale := 1.0) -> Control:
	var box := VBoxContainer.new()
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var shown := Label.new()
	row.add_child(shown)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(400, 0)
	var update := func(v: float) -> void:
		shown.text = fmt % (v * shown_scale)
		on_change.call(v)
	slider.value_changed.connect(update)
	shown.text = fmt % (value * shown_scale)
	box.add_child(slider)
	return box


func _build_controls() -> Control:
	var box := _column()
	box.add_child(title_label("Controles", 24))
	box.add_child(controls_grid())
	var back := menu_button("Volver")
	back.pressed.connect(_show_page.bind("main"))
	var holder := CenterContainer.new()
	holder.add_child(back)
	box.add_child(holder)
	return box


## Tabla de controles (tecla en dorado, acción al lado). La usa también la ayuda de F1.
static func controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	for entry in CONTROLS:
		var key := Label.new()
		key.text = entry[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
		key.add_theme_font_size_override("font_size", 14)
		grid.add_child(key)
		var what := Label.new()
		what.text = entry[1]
		what.add_theme_font_size_override("font_size", 14)
		grid.add_child(what)
	return grid


func _show_page(page_name: String) -> void:
	for key in _pages:
		(_pages[key] as Control).visible = key == page_name


func open() -> void:
	_show_page("main")
	_fps_check.button_pressed = Settings.show_fps
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	visible = false
	get_tree().paused = false
	resumed.emit()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if (_pages["main"] as Control).visible:
		close()
	else:
		Settings.save_settings()
		_show_page("main")
	get_viewport().set_input_as_handled()
