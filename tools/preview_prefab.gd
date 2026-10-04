extends SceneTree
## Foto de estudio de una pieza de prefab (para comparar con el arte conceptual).
## Uso: godot --path . --script res://tools/preview_prefab.gd -- <prefab> <salida.png>
var _frames := 0
var _out := ""

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[1]
	PrefabLibrary.load_all()
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.91, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var mi := MeshInstance3D.new()
	mi.mesh = PrefabLibrary.centered_mesh(PrefabLibrary.first_id(a[0]), 1.0)
	vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(-1.5, 1.25, 1.5), Vector3.ZERO)
	_vp = vp

var _vp: SubViewport

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		_vp.get_texture().get_image().save_png(_out)
		return true
	return false
