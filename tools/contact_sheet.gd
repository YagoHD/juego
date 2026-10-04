extends SceneTree
## Junta varias imágenes en una cuadrícula (para revisar muchas capturas de un vistazo).
## Uso: godot --headless --path . --script res://tools/contact_sheet.gd -- salida.png columnas lado img1 img2 ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var cols := int(a[1])
	var side := int(a[2])
	var files := a.slice(3)
	var rows := (files.size() + cols - 1) / cols
	var out := Image.create(cols * side, rows * side, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1))
	for i in files.size():
		var img := Image.load_from_file(files[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(side, side, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(img, Rect2i(0, 0, side, side), Vector2i((i % cols) * side, (i / cols) * side))
	out.save_png(a[0])
	quit()
