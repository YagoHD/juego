extends SceneTree
## Guarda la skin por defecto en assets/skins/default_skin.png (plantilla para pintar skins)
## y una versión ampliada x8 para verla bien.
## Uso: godot --headless --path . --script res://tools/export_skin.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/skins"))
	var img := SkinComposer.compose(SkinComposer.DEFAULT_OPTIONS)
	img.save_png("res://assets/skins/default_skin.png")
	var big := img.duplicate() as Image
	big.resize(512, 512, Image.INTERPOLATE_NEAREST)
	big.save_png("res://assets/skins/default_skin_x8.png")
	print("Skin guardada en assets/skins/")
	quit()
