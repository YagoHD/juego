extends Node3D
## Mano para la cámara: volumen anatómico, cinco dedos articulados y antebrazo continuo.
## Su origen es el centro del mango. No estira ni recorta la malla del personaje.

var _fingers: Array[Node3D] = []
var _tips: Array[Node3D] = []
var _ends: Array[Node3D] = []
var _thumb: Node3D
var _thumb_tip: Node3D
var _target := Vector3.ZERO
var _thumb_target := Vector2.ZERO

func build(skin: Color, layer: int) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = skin
	material.roughness = 0.88
	material.disable_receive_shadows = true
	# Palma detrás del mango; nudillos en columna como al cerrar un puño.
	_ellipsoid(self, Vector3(0.010, -0.002, 0.025), Vector3(0.036, 0.044, 0.017), material, layer)
	_segment(self, Vector3(0.037, -0.008, 0.033), Vector3(0.085, -0.016, 0.033), 0.021, 0.019, material, layer)
	_segment(self, Vector3(0.078, -0.016, 0.033), Vector3(0.36, -0.24, 0.24), 0.021, 0.038, material, layer)
	var lengths := [Vector3(0.029, 0.023, 0.020), Vector3(0.033, 0.025, 0.022), Vector3(0.030, 0.024, 0.020), Vector3(0.023, 0.019, 0.017)]
	for i in 4:
		var root := Node3D.new()
		root.position = Vector3(-0.027, 0.030 - i * 0.020, 0.017)
		_ellipsoid(self, Vector3(-0.025, root.position.y, 0.035), Vector3(0.012, 0.010, 0.010), material, layer)
		add_child(root)
		var length: Vector3 = lengths[i]
		var radius := 0.0085 if i < 3 else 0.0075
		_segment(root, Vector3.ZERO, Vector3(-length.x, 0, 0), radius, radius * 0.94, material, layer)
		var tip := Node3D.new()
		tip.position.x = -length.x
		root.add_child(tip)
		_segment(tip, Vector3.ZERO, Vector3(-length.y, 0, 0), radius * 0.94, radius * 0.85, material, layer)
		var end := Node3D.new()
		end.position.x = -length.y
		tip.add_child(end)
		_segment(end, Vector3.ZERO, Vector3(-length.z, 0, 0), radius * 0.85, radius * 0.7, material, layer)
		_fingers.append(root)
		_tips.append(tip)
		_ends.append(end)
	_thumb = Node3D.new()
	_thumb.position = Vector3(0.030, -0.035, 0.020)
	add_child(_thumb)
	_segment(_thumb, Vector3.ZERO, Vector3(0, 0.041, 0), 0.012, 0.010, material, layer)
	_thumb_tip = Node3D.new()
	_thumb_tip.position.y = 0.041
	_thumb.add_child(_thumb_tip)
	_segment(_thumb_tip, Vector3.ZERO, Vector3(0, 0.028, 0), 0.010, 0.008, material, layer)
	pose("relaxed", true)

func pose(mode: String, instant := false) -> void:
	match mode:
		"handle":
			_target = Vector3(-80, -65, -48)
			_thumb_target = Vector2(-42, 25)
		"cup":
			_target = Vector3(-48, -42, -28)
			_thumb_target = Vector2(-24, 14)
		"pinch":
			_target = Vector3(-66, -58, -35)
			_thumb_target = Vector2(-46, 32)
		"open":
			_target = Vector3(-12, -8, -5)
			_thumb_target = Vector2(-15, -10)
		_:
			_target = Vector3(-24, -20, -12)
			_thumb_target = Vector2(-22, 0)
	if instant:
		_animate(1.0)

func _process(delta: float) -> void:
	_animate(1.0 - exp(-18.0 * delta))

func _animate(t: float) -> void:
	for i in _fingers.size():
		_fingers[i].rotation.y = lerp_angle(_fingers[i].rotation.y, deg_to_rad(_target.x), t)
		_tips[i].rotation.y = lerp_angle(_tips[i].rotation.y, deg_to_rad(_target.y), t)
		_ends[i].rotation.y = lerp_angle(_ends[i].rotation.y, deg_to_rad(_target.z), t)
	_thumb.rotation.x = lerp_angle(_thumb.rotation.x, deg_to_rad(_thumb_target.x), t)
	_thumb.rotation.z = lerp_angle(_thumb.rotation.z, deg_to_rad(_thumb_target.y), t)
	_thumb_tip.rotation.z = lerp_angle(_thumb_tip.rotation.z, deg_to_rad(25.0), t)

func _segment(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, material: Material, layer: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = ra
	mesh.top_radius = rb
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var instance := _instance(mesh, material, layer)
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	_ellipsoid(parent, a, Vector3.ONE * ra, material, layer)
	_ellipsoid(parent, b, Vector3.ONE * rb, material, layer)

func _ellipsoid(parent: Node3D, at: Vector3, radii: Vector3, material: Material, layer: int) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var instance := _instance(sphere, material, layer)
	instance.position = at
	instance.scale = radii
	parent.add_child(instance)

func _instance(mesh: Mesh, material: Material, layer: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.layers = layer
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
