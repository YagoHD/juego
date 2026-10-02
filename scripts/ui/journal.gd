extends Control
class_name Journal
## El diario del capitán (tecla J): un libro abierto de dos páginas, con tapas de cuero y papel
## manchado por el agua. Se pasan las páginas con A / D, las flechas, la rueda o los botones.
## Está empapado: hay trozos que no se leen. Se salvan las recetas básicas y un mapa de la isla;
## lo que el personaje aprende después se va apuntando al final, con otra letra (lápiz).

signal closed

const PAGE_SIZE := Vector2(430, 560)
const INK := Color(0.24, 0.15, 0.08)        # tinta del capitán
const PENCIL := Color(0.25, 0.28, 0.36)     # lo que apunta el náufrago
const FADED := Color(0.45, 0.36, 0.26, 0.55)

var _player: Player
var _spread := 0               # índice de la página izquierda (siempre par)
var _pages: Array[Dictionary] = []
var _left: Control
var _right: Control
var _paper: Texture2D
var _map: Texture2D
var _prev: Button
var _next: Button


func _init(player: Player) -> void:
	_player = player


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_paper = _make_paper()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	# Tapas de cuero.
	var cover := PanelContainer.new()
	var leather := StyleBoxFlat.new()
	leather.bg_color = Color(0.33, 0.19, 0.1)
	leather.border_color = Color(0.2, 0.11, 0.05)
	leather.set_border_width_all(4)
	leather.set_corner_radius_all(10)
	leather.set_content_margin_all(14)
	leather.shadow_color = Color(0, 0, 0, 0.5)
	leather.shadow_size = 14
	cover.add_theme_stylebox_override("panel", leather)
	column.add_child(cover)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)
	_left = _make_page_holder(false)
	spread.add_child(_left)
	var spine := ColorRect.new()
	spine.color = Color(0.18, 0.1, 0.05)
	spine.custom_minimum_size = Vector2(6, PAGE_SIZE.y)
	spread.add_child(spine)
	_right = _make_page_holder(true)
	spread.add_child(_right)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	column.add_child(bar)
	_prev = _make_button("◀  A", -2)
	bar.add_child(_prev)
	var help := Label.new()
	help.text = "J o Esc: cerrar"
	help.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	bar.add_child(help)
	_next = _make_button("D  ▶", 2)
	bar.add_child(_next)


func _make_button(text: String, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(110, 0)
	button.pressed.connect(func() -> void: _turn(step))
	return button


func _make_page_holder(right_side: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = PAGE_SIZE
	holder.clip_contents = true
	var paper := TextureRect.new()
	paper.texture = _paper
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.flip_h = right_side
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # manchas suaves, no pixeladas
	holder.add_child(paper)
	return holder


func open() -> void:
	_build_pages()
	_spread = clampi(_spread, 0, _last_spread())
	_show_spread()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn(2)
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn(-2)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed:
		return
	match key.keycode:
		KEY_D, KEY_RIGHT:
			_turn(2)
		KEY_A, KEY_LEFT:
			_turn(-2)
		_:
			return
	get_viewport().set_input_as_handled()


func _turn(step: int) -> void:
	var target := clampi(_spread + step, 0, _last_spread())
	if target == _spread:
		return
	_spread = target
	_show_spread()


func _last_spread() -> int:
	return maxi(0, (_pages.size() - 1) / 2 * 2)


func _show_spread() -> void:
	for holder in [_left, _right]:
		for child in (holder as Control).get_children():
			if not child is TextureRect:
				child.queue_free()
	_fill(_left, _spread)
	_fill(_right, _spread + 1)
	_prev.disabled = _spread == 0
	_next.disabled = _spread >= _last_spread()


func _fill(holder: Control, index: int) -> void:
	if index >= _pages.size():
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34 if side != "bottom" else 28)
	holder.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var page: Dictionary = _pages[index]
	match page["kind"]:
		"title": _page_title(box)
		"text": _page_text(box, page)
		"map": _page_map(box)
		"recipe": _page_recipe(box, page)
	var number := Label.new()
	number.text = str(index + 1)
	number.add_theme_color_override("font_color", FADED)
	number.add_theme_font_size_override("font_size", 12)
	number.position = Vector2(PAGE_SIZE.x * 0.5 - 6, PAGE_SIZE.y - 24)
	holder.add_child(number)


# ------------------------------------------------------------------ contenido

func _build_pages() -> void:
	_pages.clear()
	_pages.append({"kind": "title"})
	_pages.append({"kind": "text", "title": "Día 31 de travesía", "body": [
		["La tormenta nos ha arrastrado tres noches hacia el oeste, hacia una isla que no figura en ninguna carta.", false],
		[" El casco no aguantará otra ola. Mando a los hombres a ", false],
		["subir los víveres y las velas a la playa", true],
		[". Si alguien encuentra este diario: apunto aquí todo lo que aprendamos en tierra, por si sirve de algo.", false],
	]})
	_pages.append({"kind": "text", "title": "El mineral", "body": [
		["En las montañas del este hay vetas de un mineral ", false],
		["que brilla con un tono verdoso cuando cae la noche", true],
		[". Martín, el herrero, juraba que se funde con ", false],
		["carbón de pino y agua de mar, y que el metal que sale", true],
		[" ", false],
		["no se oxida jamás. Hay que golpearlo tres veces mientras", true],
		["...", false],
		["\n\n(La tinta se ha corrido: el resto de la página no se puede leer.)", false],
	]})
	_pages.append({"kind": "map"})
	_pages.append({"kind": "text", "title": "Trabajar en tierra", "body": [
		["Aquí no hay banco ni taller. Se trabaja en el suelo: se ponen las cosas una junto a otra (G), cada una en su sitio, con la forma de lo que se quiere hacer, y se trabaja con las manos (mantener R).", false],
		["\n\nLo que va encima se apila sobre lo de abajo (G apuntando a la cara de arriba).", false],
		["\n\nLas herramientas, como el cuchillo, se ponen al lado y no se gastan.", false],
		["\n\nLo que no sepas hacer, desmóntalo (déjalo solo en el suelo y mantén R): así se aprende cómo está hecho.", false],
	]})
	for recipe_id in GroundRecipes.JOURNAL_RECIPES:
		if _player.known_recipes.has(recipe_id):
			_pages.append({"kind": "recipe", "recipe": recipe_id, "pencil": false})
	if _pages.size() % 2 == 1:
		_pages.append({"kind": "text", "title": "", "body": [["", false]]})
	var mine := false
	for recipe_id in _player.known_recipes:
		if GroundRecipes.JOURNAL_RECIPES.has(recipe_id) or not GroundRecipes.RECIPES.has(recipe_id):
			continue
		if not mine:
			mine = true
			_pages.append({"kind": "text", "title": "Mis notas", "pencil": true, "body": [
				["Lo que he ido aprendiendo en la isla. Lo apunto aquí, en las hojas que quedaban en blanco.", false]]})
		_pages.append({"kind": "recipe", "recipe": recipe_id, "pencil": true})


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size = Vector2(PAGE_SIZE.x - 70, 0)
	return label


func _page_title(box: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)
	box.add_child(spacer)
	for line in [["Diario de a bordo", 30], ["del capitán A. Salvatierra", 20], ["— bergantín «La Golondrina» —", 16]]:
		var label := _label(line[0], line[1], INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	var stain := _label("\n\n\n" + _smudge("Propiedad de la Real Compañía de Mares del Sur"), 13, FADED)
	stain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stain)


## Página de texto: cada trozo es [texto, borroso]. Lo borroso se ve corrido por el agua.
func _page_text(box: VBoxContainer, page: Dictionary) -> void:
	var ink: Color = PENCIL if page.get("pencil", false) else INK
	if page["title"] != "":
		box.add_child(_label(page["title"], 22, ink))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(PAGE_SIZE.x - 70, 0)
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_color_override("default_color", ink)
	var bb := ""
	for part in page["body"]:
		if part[1]:
			bb += "[color=#%s]%s[/color]" % [FADED.to_html(true), _smudge(part[0])]
		else:
			bb += part[0]
	text.text = bb
	box.add_child(text)


## Texto corrido por el agua: muchas letras se pierden.
func _smudge(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		var h := absi(hash(i * 31 + text.length())) % 100
		if c == " ":
			out += " "
		elif h < 45:
			out += "~"
		elif h < 60:
			out += "·"
		else:
			out += c
	return out


func _page_map(box: VBoxContainer) -> void:
	box.add_child(_label("Carta de la isla", 22, INK))
	var holder := Control.new()
	var side := PAGE_SIZE.x - 70
	holder.custom_minimum_size = Vector2(side, side)
	box.add_child(holder)
	var map := TextureRect.new()
	map.texture = _map_texture()
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.size = Vector2(side, side)
	holder.add_child(map)
	_mark(holder, side, Structures.ship_voxel(), "✕", "naufragio", Color(0.55, 0.12, 0.08), Vector2(10, -2))
	_mark(holder, side, Structures.ruins_voxel(), "✕", "ruinas ?", INK, Vector2(10, -2))
	var me := Vector2i(int(_player.global_position.x / 0.5), int(_player.global_position.z / 0.5))
	_mark(holder, side, me, "●", "tú", Color(0.75, 0.1, 0.1), Vector2(-28, -18))
	box.add_child(_label("El norte, arriba. Al este, las montañas del mineral.", 13, FADED))


## Marca en el mapa en la posición (x, z) del mundo, en voxels.
func _mark(holder: Control, side: float, voxel: Vector2i, symbol: String, text: String, color: Color, text_offset: Vector2) -> void:
	var half := IslandGenerator.MAP_HALF
	var p := (Vector2(voxel) + Vector2(half, half)) / (half * 2.0) * side
	for part in [[symbol, p - Vector2(5, 10)], [text, p + text_offset - Vector2(0, 10)]]:
		var label := _label(part[0], 13, color)
		label.custom_minimum_size = Vector2.ZERO
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.position = part[1]
		label.add_theme_color_override("font_outline_color", Color(0.93, 0.87, 0.72))
		label.add_theme_constant_override("outline_size", 4)
		holder.add_child(label)


func _page_recipe(box: VBoxContainer, page: Dictionary) -> void:
	var recipe_id: String = page["recipe"]
	var recipe: Dictionary = GroundRecipes.RECIPES[recipe_id]
	var ink: Color = PENCIL if page["pencil"] else INK
	var title := ItemDB.display_name(recipe["result"])
	if int(recipe["count"]) > 1:
		title += " (salen %d)" % int(recipe["count"])
	box.add_child(_label(title, 22, ink))
	box.add_child(_label("%s (mantener R)" % recipe["action"], 15, ink))
	var layers: Array = recipe["layers"]
	var drawing := HBoxContainer.new()
	drawing.add_theme_constant_override("separation", 22)
	box.add_child(drawing)
	for level in layers.size():
		var col := VBoxContainer.new()
		drawing.add_child(col)
		if layers.size() > 1:
			var caption := _label("abajo" if level == 0 else "encima", 12, FADED)
			caption.custom_minimum_size = Vector2.ZERO  # que no ensanche la columna
			col.add_child(caption)
		var rows: Array = layers[level]
		var grid := GridContainer.new()
		grid.columns = (rows[0] as String).length()
		grid.add_theme_constant_override("h_separation", 3)
		grid.add_theme_constant_override("v_separation", 3)
		col.add_child(grid)
		for line: String in rows:
			for letter in line:
				var cell := TextureRect.new()
				cell.custom_minimum_size = Vector2(40, 40)
				cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				if letter != ".":
					cell.texture = ItemDB.icon(recipe["key"][letter])
				grid.add_child(cell)
	var parts: PackedStringArray = []
	var mats := GroundRecipes.materials_of(recipe_id)
	for id in mats:
		parts.append("%s ×%d" % [ItemDB.display_name(id).to_lower(), mats[id]])
	box.add_child(_label("Hace falta: " + ", ".join(parts) + ".", 14, ink))
	var tools := GroundRecipes.tools_of(recipe_id)
	if not tools.is_empty():
		box.add_child(_label("Con %s al lado (no se gasta)." % ItemDB.display_name(tools[0]).to_lower(), 14, ink))
	box.add_child(_label("Vale girado o al revés.", 12, FADED))


# ------------------------------------------------------------------ dibujos

## Papel amarillento con manchas de agua (se genera una vez).
func _make_paper() -> Texture2D:
	var w := 216
	var h := 280
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.025
	var stains := FastNoiseLite.new()
	stains.seed = 31
	stains.frequency = 0.0125
	for y in h:
		for x in w:
			var base := Color(0.91, 0.85, 0.69)
			base = base.darkened(0.06 * (noise.get_noise_2d(x, y) * 0.5 + 0.5))
			var s := stains.get_noise_2d(x, y)
			# Mancha de agua: por dentro algo más oscura y con el borde marcado (cerco).
			var inside := smoothstep(0.26, 0.34, s)
			var rim := smoothstep(0.24, 0.29, s) * (1.0 - smoothstep(0.29, 0.36, s))
			base = base.darkened(0.12 * inside + 0.14 * rim)
			# Bordes de la hoja un poco quemados por el sol.
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			if edge < 8:
				base = base.darkened(0.12 * (1.0 - edge / 8.0))
			img.set_pixel(x, y, base)
	var tex := ImageTexture.create_from_image(img)
	return tex


## El mapa de la isla, en tonos sepia (se genera una vez).
func _map_texture() -> Texture2D:
	if _map != null:
		return _map
	var res: Resource = load("res://assets/island/preview.png")
	var src: Image = res as Image if res is Image else (res as Texture2D).get_image()
	var img := src.duplicate() as Image
	img.resize(256, 256, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var is_sea := c.b > c.r + 0.12 and c.b > c.g
			var l := c.get_luminance()
			var out: Color
			if is_sea:
				out = Color(0, 0, 0, 0)  # el papel se ve a través: el mar es "en blanco"
			else:
				out = Color(0.62, 0.46, 0.28).lerp(Color(0.32, 0.2, 0.1), 1.0 - l)
				out.a = 0.85
			img.set_pixel(x, y, out)
	_map = ImageTexture.create_from_image(img)
	return _map
