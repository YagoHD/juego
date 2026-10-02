extends SceneTree
## Guarda el atlas de texturas de bloques (para verlo y como referencia para pintar a mano):
## assets/textures/blocks_atlas.png y una versión ampliada x8.
## Uso: godot --headless --path . --script res://tools/export_textures.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/blocks"))
	var img := BlockTextures.atlas_image()
	img.save_png("res://assets/textures/blocks_atlas.png")
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
	big.save_png("res://assets/textures/blocks_atlas_x8.png")
	print("Atlas guardado (%dx%d)" % [img.get_width(), img.get_height()])
	quit()
