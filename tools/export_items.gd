extends SceneTree
## Genera una hoja de vista previa de los objetos que no son bloques.
## Uso: godot --headless --path . --script res://tools/export_items.gd

const ITEMS := [
	"rope", "wheat", "sticks",
	"stone_knife", "berries", "shirt",
	"pants", "belt", "backpack",
]
const COLUMNS := 3
const SCALE := 8


func _init() -> void:
	var rows := int(ceil(float(ITEMS.size()) / COLUMNS))
	var sheet := Image.create(COLUMNS * ItemPainter.S, rows * ItemPainter.S, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.13, 0.15))
	for i in ITEMS.size():
		var icon := ItemPainter.paint(ITEMS[i])
		var cell := Vector2i(i % COLUMNS, i / COLUMNS) * ItemPainter.S
		sheet.blit_rect(icon, Rect2i(Vector2i.ZERO, Vector2i(ItemPainter.S, ItemPainter.S)), cell)
	var path := "res://assets/textures/items_atlas.png"
	sheet.save_png(path)
	var large := sheet.duplicate() as Image
	large.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	large.save_png("res://assets/textures/items_atlas_x8.png")
	print("Vista previa de objetos guardada: ", path, " | orden: ", ITEMS)
	quit()
