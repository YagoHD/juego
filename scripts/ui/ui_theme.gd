class_name UiTheme
## Aspecto común de la interfaz: las piezas dibujadas por ChatGPT (docs/concept/ui1_piezas.png y
## ui2_iconos.png, recortadas con tools/extract_ui.gd en assets/ui/): paneles de madera con
## remaches, pergamino, huecos de cuero cosido, botones de tabla con cuerda, barras e iconos.
## Si falta alguna, se usa la del "UI Pack (RPG Expansion)" de Kenney (CC0).

const DIR := "res://assets/ui/"
const KENNEY_DIR := "res://assets/third_party/kenney_ui/"

static var _cache := {}


static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Caja de 9 trozos: las esquinas no se estiran. margins = izquierda/derecha, arriba/abajo (px de
## la textura). Si no está la pieza dibujada, la de Kenney; si tampoco, un color liso.
static func _box(name: String, margins: Vector2, content: float, alpha := 1.0,
		kenney := "", kenney_margin := 10.0) -> StyleBox:
	var tex := _tex(DIR + name + ".png")
	if tex == null and kenney != "":
		tex = _tex(KENNEY_DIR + kenney + ".png")
		margins = Vector2(kenney_margin, kenney_margin)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.2, 0.15, 0.1, alpha)
		flat.set_corner_radius_all(6)
		flat.set_content_margin_all(content)
		return flat
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = margins.x
	style.texture_margin_right = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_bottom = margins.y
	style.set_content_margin_all(content)
	style.modulate_color = Color(1, 1, 1, alpha)
	return style


## Panel grande de madera oscura con remaches (menús, inventario, recetario).
static func panel(alpha := 1.0, content := 20.0) -> StyleBox:
	return _box("panel", Vector2(24, 24), content + 8.0, alpha, "panel_brown", 12.0)


## Panel de pergamino (opciones, notas, libros).
static func parchment(alpha := 1.0, content := 20.0) -> StyleBox:
	return _box("parchment", Vector2(24, 24), content + 8.0, alpha, "panel_beige", 12.0)


## Cajita de ayuda (nombre del objeto, avisos).
static func tooltip(alpha := 1.0) -> StyleBox:
	return _box("tooltip", Vector2(10, 10), 8.0, alpha, "panel_brown", 12.0)


## Hueco de un objeto (inventario, equipo).
static func slot(alpha := 1.0) -> StyleBox:
	return _box("slot", Vector2(12, 12), 4.0, alpha, "panelInset_beige")


## Hueco resaltado (seleccionado: borde ámbar).
static func slot_light(alpha := 1.0) -> StyleBox:
	return _box("slot_selected", Vector2(12, 12), 4.0, alpha, "panelInset_beigeLight")


## Hueco con el ratón encima.
static func slot_hover(alpha := 1.0) -> StyleBox:
	return _box("slot_hover", Vector2(12, 12), 4.0, alpha, "panelInset_beigeLight")


## Hueco bloqueado (aún no disponible).
static func slot_locked(alpha := 1.0) -> StyleBox:
	return _box("slot_locked", Vector2(12, 12), 4.0, alpha, "panelInset_beige")


## Icono pequeño de la interfaz (assets/ui/icon_<nombre>.png): "health", "hunger", "thirst",
## "sun", "moon", "book", "craft", "chest", "options", "objective", "hand", "lock" y las siluetas
## de los huecos de ropa "slot_shirt", "slot_pants", "slot_belt", "slot_backpack"...
static func icon(name: String) -> Texture2D:
	return _tex(DIR + "icon_" + name + ".png")


## Estilos de botón de tabla con cuerda: normal, encima (brilla), pulsado, desactivado.
static func style_button(button: Button) -> void:
	var m := Vector2(36, 14)
	var normal := _box("button", m, 10.0, 1.0, "buttonLong_brown")
	var hover := _box("button_hover", m, 10.0, 1.0, "buttonLong_brown")
	var pressed := _box("button_pressed", m, 10.0, 1.0, "buttonLong_brown_pressed")
	var disabled := _box("button", m, 10.0, 0.5, "buttonLong_brown")
	for style: StyleBox in [normal, hover, pressed, disabled]:
		style.content_margin_left = 40.0
		style.content_margin_right = 40.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.68))
	button.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.08))
	button.add_theme_constant_override("outline_size", 4)


## Barra de hambre, sed o vida: marco de cuero con remaches y relleno del color de la hoja
## ("red", "orange", "blue"). Si no están las piezas, deja la barra como estaba.
static func style_bar(bar: ProgressBar, fill: String) -> void:
	var frame := _tex(DIR + "bar.png")
	var full := _tex(DIR + "bar_" + fill + ".png")
	if frame == null or full == null:
		return
	var back := StyleBoxTexture.new()
	back.texture = frame
	back.texture_margin_left = 22
	back.texture_margin_right = 22
	back.texture_margin_top = 8
	back.texture_margin_bottom = 8
	var front := StyleBoxTexture.new()
	front.texture = full
	# Solo el relleno de dentro: lo de los extremos es el mismo marco.
	front.region_rect = Rect2(22, 8, full.get_width() - 44, full.get_height() - 16)
	front.expand_margin_top = -4
	front.expand_margin_bottom = -4
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", front)


## Tema para pantallas sobre madera: textos claros con contorno oscuro (se leen sobre el panel).
static func wood_theme() -> Theme:
	var th := Theme.new()
	th.set_color("font_outline_color", "Label", Color(0.22, 0.13, 0.06))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Label", Color(0.99, 0.95, 0.86))
	return th


## Cursor de mano para los menús.
static func apply_cursor() -> void:
	var tex := _tex(KENNEY_DIR + "cursorHand_beige.png")
	if tex != null:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(6, 2))
