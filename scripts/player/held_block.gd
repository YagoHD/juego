extends Node3D
class_name HeldBlock
## Vista de primera persona independiente: mano articulada y objetos a escala uniforme.
const HAND_RIG := preload("res://scripts/player/first_person_hand.gd")
const MESHY_HAND := preload("res://scripts/player/meshy_view_hand.gd")
const ITEM_PROFILES := preload("res://scripts/player/first_person_items.gd")
const REST_POSITION := Vector3(0.20, -0.15, -0.50)
const REST_ROTATION := Vector3(0.10, -0.55, -0.12)
const VIEW_LAYER := 1 << 19

var _arm: Node3D
var _block_mesh: MeshInstance3D
var _item_id := ""
var _swing := 0.0
var _equip := 0.0
var _bob_phase := 0.0
var _bob_amount := 0.0
var _in_leaves := false
var _leaves := 0.0
var _left: Node3D
var _view: SubViewport
var _view_camera: Camera3D
var _view_image: TextureRect
var _fill: DirectionalLight3D

func _ready() -> void:
	position = REST_POSITION
	rotation = REST_ROTATION
	_setup_view()

func _setup_view() -> void:
	var camera := get_parent() as Camera3D
	if camera == null:
		return
	camera.cull_mask &= ~VIEW_LAYER
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.world_3d = get_viewport().world_3d
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.size = get_viewport().get_visible_rect().size
	add_child(_view)
	_view_camera = Camera3D.new()
	_view_camera.cull_mask = VIEW_LAYER
	_view_camera.near = 0.01
	var environment := get_viewport().world_3d.environment
	if environment != null:
		_view_camera.environment = environment.duplicate()
		_view_camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	_view.add_child(_view_camera)
	# Los focos del mundo usan la capa 1; una luz suave permite leer los nudillos en esta capa.
	_fill = DirectionalLight3D.new()
	_fill.light_cull_mask = VIEW_LAYER
	_fill.layers = VIEW_LAYER
	_fill.light_energy = 0.65
	_fill.rotation_degrees = Vector3(-35, -35, 0)
	_view_camera.add_child(_fill)
	_view_image = TextureRect.new()
	_view_image.texture = _view.get_texture()
	_view_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view_image)
	get_viewport().size_changed.connect(func(): _view.size = get_viewport().get_visible_rect().size)

func set_skin(texture: Texture2D, _slim: bool) -> void:
	if _arm != null:
		_arm.queue_free()
	if _left != null:
		_left.queue_free()
	var color := CastawayModel.SKIN
	if texture != null and FileAccess.file_exists(SkinComposer.USER_SKIN_PATH):
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		color = image.get_pixel(46, 28)
		color.a = 1.0
	var original := ResourceLoader.exists(MESHY_HAND.DIR + Settings.body + ".scn")
	_arm = MESHY_HAND.new() if original else HAND_RIG.new()
	add_child(_arm)
	_arm.build(color, VIEW_LAYER)
	_block_mesh = MeshInstance3D.new()
	_block_mesh.name = "held_item"
	_block_mesh.layers = VIEW_LAYER
	_block_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm.add_child(_block_mesh)
	_left = MESHY_HAND.new() if original else HAND_RIG.new()
	_left.build(color, VIEW_LAYER)
	_left.pose("open", true)
	_left.scale.x = -1.0
	_left.visible = false
	get_parent().add_child.call_deferred(_left)
	_show_item(_item_id)

func _show_item(id: String) -> void:
	_block_mesh.visible = id != ""
	if id == "":
		_arm.pose("relaxed")
		return
	var profile := ITEM_PROFILES.get_profile(id)
	_arm.pose(profile["pose"])
	_block_mesh.mesh = ItemMesh.make_held(id, profile["length"], profile["grip"])
	_block_mesh.position = profile.get("offset", Vector3.ZERO)
	_block_mesh.rotation = profile["rotation"]
	var material := ItemMesh.make_material(id).duplicate() as StandardMaterial3D
	material.no_depth_test = false
	material.render_priority = 0
	material.disable_receive_shadows = true
	_block_mesh.material_override = material

func set_item(id: String) -> void:
	if id == _item_id:
		return
	var first_time := _item_id == ""
	_item_id = id
	if _block_mesh != null:
		_show_item(id)
	if not first_time:
		_equip = 1.0

func swing() -> void:
	_swing = 1.0

func set_in_leaves(on: bool) -> void:
	_in_leaves = on

func update_walk(speed01: float, delta: float) -> void:
	_bob_amount = lerpf(_bob_amount, clampf(speed01, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_bob_phase += delta * 9.0 * _bob_amount

func _process(delta: float) -> void:
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_equip = maxf(_equip - delta * 5.0, 0.0)
	_leaves = move_toward(_leaves, 1.0 if _in_leaves else 0.0, delta * 5.0)
	var s := sin(_swing * PI)
	var s2 := sin(_swing * _swing * PI)
	var bob := Vector3(sin(_bob_phase) * 0.009, -absf(cos(_bob_phase)) * 0.012, 0.0) * _bob_amount
	position = REST_POSITION + bob + Vector3(-0.10 * s2, 0.02 * s - 0.25 * _equip, -0.04 * s)
	rotation = REST_ROTATION + Vector3(0.28 * s, 0.35 * s2, -0.22 * s)
	if _leaves > 0.0:
		var w := smoothstep(0.0, 1.0, _leaves)
		var a := sin(Time.get_ticks_msec() * 0.005)
		position += Vector3(-0.07 + 0.03 * a, 0.10, 0.02) * w
		rotation += Vector3(0.12, 0.35 + 0.12 * a, 0.0) * w
		if _left != null:
			_left.visible = is_visible_in_tree() and w > 0.01
			_left.position = Vector3(-REST_POSITION.x + 0.02 * a, REST_POSITION.y + 0.17 * w, REST_POSITION.z)
			_left.rotation = Vector3(0.25, 0.3 + 0.08 * a, 0.1)
	elif _left != null:
		_left.visible = false
	if _view_camera != null:
		var camera := get_parent() as Camera3D
		camera.cull_mask &= ~VIEW_LAYER
		_view_camera.global_transform = camera.global_transform
		# FOV propio: cambiar el FOV del mundo no revela el extremo cortado del antebrazo.
		_view_camera.fov = 65.0
		var show_hand := is_visible_in_tree() and camera.is_current()
		_view_image.visible = show_hand
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show_hand else SubViewport.UPDATE_DISABLED
		var environment := get_viewport().world_3d.environment
		if environment != null and _view_camera.environment != null:
			_view_camera.environment.ambient_light_color = environment.ambient_light_color
			_view_camera.environment.ambient_light_energy = environment.ambient_light_energy
			_view_camera.environment.ambient_light_sky_contribution = environment.ambient_light_sky_contribution
			var ambient := environment.ambient_light_color
			_fill.light_energy = clampf(maxf(ambient.r, maxf(ambient.g, ambient.b)), 0.12, 0.65)

func _exit_tree() -> void:
	if is_instance_valid(_left):
		_left.queue_free()
