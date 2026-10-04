extends SceneTree
## Foto de estudio de un prefab entero (todas sus piezas), para comparar con el arte conceptual.
## Uso: godot --path . --script res://tools/preview_prefab.gd -- <prefab> <salida.png>
var _frames := 0
var _out := ""
var _vp: SubViewport


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[1]
	PrefabLibrary.load_all()
	_vp = SubViewport.new()
	_vp.size = Vector2i(512, 512)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.91, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var box := AABB()
	for piece in PrefabLibrary.pieces(PrefabLibrary.index_of(a[0])):
		var mi := MeshInstance3D.new()
		mi.mesh = PrefabLibrary.centered_mesh(piece[1], 1.0)
		mi.position = Vector3(piece[0] as Vector3i)
		_vp.add_child(mi)
		box = box.expand(mi.position - Vector3.ONE * 0.5).expand(mi.position + Vector3.ONE * 0.5)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.25
	_vp.add_child(cam)
	var c := box.get_center()
	cam.look_at_from_position(c + Vector3(-1.5, 1.25, 1.5) * cam.size, c)
	cam.far = cam.size * 10.0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		_vp.get_texture().get_image().save_png(_out)
		return true
	return false
