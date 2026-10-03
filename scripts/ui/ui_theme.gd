class_name UiTheme
## Aspecto común de la interfaz, con las piezas del "UI Pack (RPG Expansion)" de Kenney (CC0):
## paneles de madera, huecos hundidos para los objetos, botones de madera y el cursor de mano.

const DIR := "res://assets/third_party/kenney_ui/"

static var _cache := {}


static func _tex(file_name: String) -> Texture2D:
	if not _cache.has(file_name):
		var path := DIR + file_name + ".png"
		_cache[file_name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file_name]


## Caja de 9 trozos con una textura: las esquinas no se estiran.
static func _box(file_name: String, margin: float, content: float, alpha := 1.0) -> StyleBox:
	var tex := _tex(file_name)
	if tex == null:  # sin el paquete: un color liso
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.2, 0.15, 0.1, alpha)
		flat.set_corner_radius_all(6)
		flat.set_content_margin_all(content)
		return flat
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.set_content_margin_all(content)
	style.modulate_color = Color(1, 1, 1, alpha)
	return style


## Panel grande (menús, inventario, recetario).
static func panel(alpha := 1.0, content := 20.0) -> StyleBox:
	return _box("panel_brown", 12.0, content, alpha)


## Hueco de un objeto (inventario, equipo).
static func slot(alpha := 1.0) -> StyleBox:
	return _box("panelInset_beige", 10.0, 4.0, alpha)


## Hueco resaltado (seleccionado).
static func slot_light(alpha := 1.0) -> StyleBox:
	return _box("panelInset_beigeLight", 10.0, 4.0, alpha)


## Estilos de botón de madera: normal, encima, pulsado, desactivado.
static func style_button(button: Button) -> void:
	var normal := _box("buttonLong_brown", 10.0, 8.0)
	var hover := _box("buttonLong_brown", 10.0, 8.0)
	if hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = Color(1.18, 1.12, 1.0)
	var pressed := _box("buttonLong_brown_pressed", 10.0, 8.0)
	var disabled := _box("buttonLong_brown", 10.0, 8.0, 0.5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.68))
	button.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.08))
	button.add_theme_constant_override("outline_size", 4)


## Tema para pantallas sobre madera: textos claros con contorno oscuro (se leen sobre el panel).
static func wood_theme() -> Theme:
	var th := Theme.new()
	th.set_color("font_outline_color", "Label", Color(0.22, 0.13, 0.06))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Label", Color(0.99, 0.95, 0.86))
	return th


## Cursor de mano de madera para los menús.
static func apply_cursor() -> void:
	var tex := _tex("cursorHand_beige")
	if tex != null:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(6, 2))
