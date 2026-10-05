extends SceneTree
## Saca las piezas de la interfaz de las hojas de ChatGPT (docs/concept/ui1_piezas.png y
## ui2_iconos.png) a assets/ui/: cada pieza se recorta de su zona, el fondo (lo que toca el borde
## de la zona y se parece al beige) se vuelve transparente y se ajusta a lo que queda.
## Las piezas se guardan a la mitad de tamaño (el dibujo es grande); los iconos, a ICON px.
## Uso: godot --headless --path . --script res://tools/extract_ui.gd

const OUT := "res://assets/ui/"
const SCALE := 0.5
const ICON := 48

## Piezas de ui1_piezas.png: nombre -> zona aproximada (con fondo alrededor, sin el número).
const PIECES := {
	"panel": Rect2i(20, 38, 430, 362),
	"parchment": Rect2i(455, 38, 432, 362),
	"slot": Rect2i(890, 158, 145, 152),
	"slot_selected": Rect2i(1042, 158, 150, 152),
	"slot_hover": Rect2i(1202, 158, 148, 152),
	"slot_locked": Rect2i(1362, 158, 152, 152),
	"button": Rect2i(28, 470, 442, 142),
	"button_hover": Rect2i(490, 470, 442, 142),
	"button_pressed": Rect2i(955, 470, 382, 142),
	"close": Rect2i(1375, 470, 132, 128),
	"bar": Rect2i(28, 690, 478, 98),
	"bar_red": Rect2i(532, 690, 466, 98),
	"bar_orange": Rect2i(28, 835, 478, 98),
	"bar_blue": Rect2i(532, 835, 466, 98),
	"tooltip": Rect2i(1022, 715, 330, 205),
	"scroll": Rect2i(1400, 648, 66, 305),
}

## Iconos de ui2_iconos.png (cuadrícula de 6x3, en orden).
const ICONS := ["slot_shirt", "slot_pants", "slot_belt", "slot_backpack", "slot_head", "slot_boots",
	"health", "hunger", "thirst", "sun", "moon", "book",
	"craft", "chest", "options", "objective", "hand", "lock"]

var _img: Image


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_img = _load("res://docs/concept/ui1_piezas.png")
	for name: String in PIECES:
		var piece := _cut(PIECES[name])
		piece.resize(int(piece.get_width() * SCALE), int(piece.get_height() * SCALE), Image.INTERPOLATE_CUBIC)
		_save(piece, name)
	_img = _load("res://docs/concept/ui2_iconos.png")
	var cell := Vector2(_img.get_width() / 6.0, _img.get_height() / 3.0)
	for i in ICONS.size():
		# Sin el borde de la casilla (las líneas de la cuadrícula) ni el número de abajo.
		var r := Rect2i(int((i % 6) * cell.x) + 8, int((i / 6) * cell.y) + 8, int(cell.x) - 16, int(cell.y * 0.74))
		var icon := _cut(r)
		var side := maxi(icon.get_width(), icon.get_height())
		var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
		square.fill(Color(0, 0, 0, 0))
		square.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()),
			Vector2i((side - icon.get_width()) / 2, (side - icon.get_height()) / 2))
		square.resize(ICON, ICON, Image.INTERPOLATE_CUBIC)
		_save(square, "icon_" + ICONS[i])
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("[ui] %s %dx%d" % [name, img.get_width(), img.get_height()])


## Recorta una zona: el fondo conectado con el borde se vuelve transparente y se ajusta al resto.
func _cut(r: Rect2i) -> Image:
	var cut := _img.get_region(r)
	var w := cut.get_width()
	var h := cut.get_height()
	var bg := cut.get_pixel(1, 1)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x] != 0:
			continue
		var c := cut.get_pixelv(p)
		if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.16:
			continue
		seen[p.y * w + p.x] = 1
		cut.set_pixelv(p, Color(0, 0, 0, 0))
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(p + d)
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if cut.get_pixel(x, y).a > 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	return cut.get_region(Rect2i(lo, hi - lo + Vector2i.ONE))
