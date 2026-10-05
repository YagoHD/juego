class_name SmoothCharacter
## Personaje liso (sin cubitos) hecho con Meshy: hombre o mujer (Settings.body). Cada cuerpo está
## troceado por las articulaciones con tools/split_character.gd en assets/models/character/<cuerpo>/:
## una malla por trozo con su pivote y pivots.cfg con dónde va cada uno (en fracciones del alto).
## Devuelve las mismas piezas que SkinModel.make_part, así las animaciones no cambian. De momento
## las manos son las del modelo (van con el antebrazo, sin dedos que se muevan).

const DIR := "res://assets/models/character/"

static var _cfg := {}       # cuerpo -> ConfigFile
static var _materials := {} # "cuerpo:encima" -> material


static func available(body: String) -> bool:
	return ResourceLoader.exists(DIR + body + "/pivots.cfg") or FileAccess.file_exists(DIR + body + "/pivots.cfg")


static func make_part(body: String, part: String, layer: int, on_top: bool) -> Node3D:
	var cfg := _config(body)
	var h := SkinModel.BODY_HEIGHT
	var pivot := Node3D.new()
	pivot.name = part
	var p: Vector3 = cfg.get_value("pivots", part, Vector3.ZERO)
	pivot.position = p * h
	_add(pivot, body, part, layer, on_top)
	if part.begins_with("arm") or part.begins_with("leg"):
		var lp: Vector3 = cfg.get_value("pivots", part + "_lower", p)
		var lower := Node3D.new()
		lower.name = "lower"
		lower.position = (lp - p) * h
		pivot.add_child(lower)
		_add(lower, body, part + "_lower", layer, on_top)
		if part.begins_with("arm"):
			# Punto de agarre: en la mano (el final del antebrazo), un poco por delante. Ahí va lo que lleve.
			var grip := Node3D.new()
			grip.name = "grip"
			var mesh_path := DIR + body + "/" + part + "_lower.res"
			if ResourceLoader.exists(mesh_path):
				var box := (load(mesh_path) as ArrayMesh).get_aabb()
				grip.position = Vector3(box.get_center().x, box.position.y + 0.03, box.get_center().z - 0.01) * h
			lower.add_child(grip)
	if part == "head":
		var lids := Node3D.new()  # los ojos van pintados: no parpadea
		lids.name = "lids"
		lids.visible = false
		pivot.add_child(lids)
	return pivot


static func _config(body: String) -> ConfigFile:
	if not _cfg.has(body):
		var cfg := ConfigFile.new()
		cfg.load(DIR + body + "/pivots.cfg")
		_cfg[body] = cfg
	return _cfg[body]


static func _add(parent: Node3D, body: String, piece: String, layer: int, on_top: bool) -> void:
	var path := DIR + body + "/" + piece + ".res"
	if not ResourceLoader.exists(path):
		return
	var mesh: ArrayMesh = load(path)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * SkinModel.BODY_HEIGHT  # las mallas van en fracciones del alto
	mi.material_override = _material(body, mesh, on_top)
	mi.layers = layer
	if on_top:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## El material del modelo (su textura de color), mate y, para el brazo en primera persona,
## dibujado por encima de todo.
static func _material(body: String, mesh: ArrayMesh, on_top: bool) -> Material:
	var key := "%s:%s" % [body, on_top]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	var tex_path := DIR + body + "/color.webp"
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	m.metallic = 0.0
	m.roughness = 0.85
	m.disable_receive_shadows = true  # sus brazos se hacían sombra a rayas a sí mismos (sombra de grano)
	if on_top:
		m.no_depth_test = true
		m.render_priority = 10
		m.disable_receive_shadows = true
	_materials[key] = m
	return m
