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
	["Clic izquierdo", "Romper bloque (mantener) · coger un objeto del suelo"],
	["Mayús + clic izq.", "Coger todo un montón del suelo"],
	["Clic derecho", "Colocar bloque · abrir cofre · leer nota · poner antorcha, hoguera o saco"],
	["Clic der. con comida", "Comer (con semillas sobre hierba o tierra: plantar)"],
	["Clic der., mano vacía", "Beber mirando agua dulce (río o lago)"],
	["Clic izq. con lanza", "Pescar el pez que tengas delante"],
	["1-9 / rueda", "Elegir hueco de la barra"],
	["E", "Inventario, equipo y Fabricar (arrastrar objetos al suelo)"],
	["J", "Diario del capitán"],
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
	theme = UiTheme.wood_theme()
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
	_pages["graphics"] = _build_graphics()
	_pages["controls"] = _build_controls()
	for page: Control in _pages.values():
		stack.add_child(page)
	_show_page("main")


## Estilo de los paneles del juego (madera oscura con borde cálido).
static func panel_style() -> StyleBox:
	return UiTheme.panel(1.0, 26.0)


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
	UiTheme.style_button(button)
	button.pressed.connect(func() -> void: Sfx.play("clic", null, -6.0))
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
	for entry in [["Continuar", close], ["Opciones", _show_page.bind("options")], ["Gráficos", _show_page.bind("graphics")],
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
	var set_music := func(v: float) -> void: Settings.music = v
	box.add_child(_slider("Música", 0.0, 1.0, Settings.music, set_music, "%d%%", 100.0))
	_invert_check = CheckBox.new()
	_invert_check.text = "Invertir el ratón (arriba / abajo)"
	_invert_check.button_pressed = Settings.invert_y
	_invert_check.focus_mode = Control.FOCUS_NONE
	_invert_check.toggled.connect(func(on: bool) -> void: Settings.invert_y = on)
	box.add_child(_invert_check)
	var pack_check := CheckBox.new()
	pack_check.text = "Texturas 16x16 (paquete CC0; al volver a entrar)"
	pack_check.button_pressed = Settings.texture_pack == "16x16"
	pack_check.focus_mode = Control.FOCUS_NONE
	pack_check.toggled.connect(func(on: bool) -> void: Settings.texture_pack = "16x16" if on else "")
	box.add_child(pack_check)
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


## Gráficos: lo que más pesa para la tarjeta gráfica, para ajustarlo a cada ordenador.
func _build_graphics() -> Control:
	var box := _column()
	box.add_child(title_label("Gráficos", 24))
	var distances: Array[String] = []
	for d: float in Settings.VIEW_DISTANCES:
		distances.append("%d m" % d)
	box.add_child(_choice("Distancia de detalle (al volver a entrar)", distances,
		Settings.VIEW_DISTANCES.find(Settings.view_distance),
		func(i: int) -> void: Settings.view_distance = Settings.VIEW_DISTANCES[i]))
	var tree_distances: Array[String] = []
	for d: float in Settings.TREE_DISTANCES:
		tree_distances.append("%d m" % d)
	box.add_child(_choice("Detalle de los árboles (al volver a entrar)", tree_distances,
		Settings.TREE_DISTANCES.find(Settings.tree_distance),
		func(i: int) -> void: Settings.tree_distance = Settings.TREE_DISTANCES[i]))
	box.add_child(_choice("Sombras", Settings.SHADOW_NAMES, Settings.shadows,
		func(i: int) -> void: Settings.shadows = i))
	box.add_child(_choice("Suavizado de bordes", Settings.AA_NAMES, Settings.antialias,
		func(i: int) -> void: Settings.antialias = i))
	box.add_child(_check("Luz realista (luz rebotada, bruma, brillo)", Settings.realistic,
		func(on: bool) -> void: Settings.realistic = on))
	box.add_child(_check("Relieve de las texturas de cerca", Settings.relief,
		func(on: bool) -> void: Settings.relief = on))
	box.add_child(_check("Árboles sencillos a lo lejos (al volver a entrar)", Settings.far_trees,
		func(on: bool) -> void: Settings.far_trees = on))
	box.add_child(_check("Mostrar FPS y rendimiento (también con F3)", Settings.show_fps,
		func(on: bool) -> void: Settings.show_fps = on))
	var back := menu_button("Volver")
	back.pressed.connect(func() -> void:
		Settings.save_settings()
		_show_page("main"))
	var holder := CenterContainer.new()
	holder.add_child(back)
	box.add_child(holder)
	return box


## Una opción con varios valores: "Sombras: Medias"; cada clic pasa al siguiente y se aplica.
func _choice(text: String, names: Array, index: int, on_change: Callable) -> Control:
	var button := menu_button("")
	var state := {"i": maxi(index, 0)}
	var refresh := func() -> void: button.text = "%s: %s" % [text, names[state["i"]]]
	refresh.call()
	button.pressed.connect(func() -> void:
		state["i"] = (int(state["i"]) + 1) % names.size()
		on_change.call(state["i"])
		Settings.apply_graphics(get_tree())
		refresh.call())
	var holder := CenterContainer.new()
	holder.add_child(button)
	return holder


func _check(text: String, value: bool, on_change: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		Settings.apply_graphics(get_tree()))
	return check


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
