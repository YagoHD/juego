extends SceneTree
## Mosaico de las texturas de assets/textures/blocks/ ampliadas (para revisarlas de un vistazo).
## Uso: godot --headless --path . --script res://tools/texture_sheet.gd -- salida.png
func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/textures/blocks/")
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".png"))
	files.sort()
	var cell := 112
	var cols := 8
	var out := Image.create(cols * cell, ((files.size() + cols - 1) / cols) * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1))
	for i in files.size():
		var img := Image.load_from_file(dir + files[i])
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cell - 8, cell - 8, Image.INTERPOLATE_NEAREST)
		out.blit_rect(img, Rect2i(0, 0, cell - 8, cell - 8), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
		print(i, " ", files[i])
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
