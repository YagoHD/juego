extends SceneTree
## Recorta y amplía un trozo de una imagen (para revisar capturas de cerca).
## Uso: godot --headless --path . --script res://tools/crop_image.gd -- entrada.png x y ancho alto zoom salida.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var r := img.get_region(Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4])))
	r.resize(r.get_width() * int(a[5]), r.get_height() * int(a[5]), Image.INTERPOLATE_NEAREST)
	r.save_png(a[6])
	quit()
