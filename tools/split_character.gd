extends SceneTree
## Prepara un personaje de Meshy (GLB con textura, sin esqueleto) para usarlo liso, sin pasarlo a
## cubitos: lo aligera (menos triángulos, misma forma) y lo trocea por las articulaciones en
## mallas sueltas (cabeza, torso, brazo, antebrazo con la mano, muslo, espinilla con el pie), cada
## una con el pivote en su articulación. Lo usa SmoothCharacter.
##
## Uso: godot --headless --path . --script res://tools/split_character.gd -- res://assets/models_raw/meshy/hombre.glb res://assets/models/character/hombre 40000 hombre
## (cuerpo: "hombre" o "mujer", ver PROFILES).

## Huesos de cada cuerpo (fracciones del alto; pies en y = 0; x hacia su derecha), medidos sobre
## las vistas del modelo, y lo gruesa que es cada zona. Cada triángulo va al hueso más cercano
## (contando su grosor): así la cadera no se confunde con la mano aunque estén cerca.
const PROFILES := {
	"hombre": {"neck": 0.725, "top": 1.0, "hip": Vector2(0.062, 0.42), "knee": Vector2(0.062, 0.24),
		"ankle": Vector2(0.062, 0.03), "shoulder": Vector2(0.15, 0.645), "elbow": Vector2(0.178, 0.50),
		"wrist": Vector2(0.19, 0.40), "hand": Vector2(0.19, 0.335),
		"r_torso": 0.095, "r_arm": 0.035, "r_leg": 0.05, "r_head": 0.1},
	"mujer": {"neck": 0.71, "top": 1.0, "hip": Vector2(0.058, 0.44), "knee": Vector2(0.058, 0.24),
		"ankle": Vector2(0.058, 0.03), "shoulder": Vector2(0.135, 0.655), "elbow": Vector2(0.165, 0.53),
		"wrist": Vector2(0.18, 0.415), "hand": Vector2(0.185, 0.34),
		"r_torso": 0.09, "r_arm": 0.03, "r_leg": 0.055, "r_head": 0.1},
}
var JOINTS: Dictionary
var _bones := []   # [trozo, a, b, grosor]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(a[0]), state)
	var imesh: ImporterMesh = state.get_meshes()[0].mesh
	var out_dir: String = a[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var target := int(a[2])
	JOINTS = PROFILES[a[3]]
	var arr := imesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print("original: ", idx.size() / 3, " triángulos")
	# Aligerar: los niveles de detalle de Godot; se coge el primero que baje del objetivo.
	imesh.generate_lods(25.0, 60.0, [])
	for l in imesh.get_surface_lod_count(0):
		var li := imesh.get_surface_lod_indices(0, l)
		print("  nivel ", l, ": ", li.size() / 3, " triángulos")
		if li.size() / 3 <= target:
			idx = li
			break
	print("se usa: ", idx.size() / 3, " triángulos")
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var h := hi.y - lo.y
	var cx := (lo.x + hi.x) * 0.5
	var cz := (lo.z + hi.z) * 0.5
	# Coordenadas del personaje: pies en y = 0, centrado, mirando a -Z (el modelo mira a +Z).
	var tv := PackedVector3Array()
	tv.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		tv[i] = Vector3(-(v.x - cx), v.y - lo.y, -(v.z - cz)) / h
	var j := JOINTS
	var pivots := {"head": Vector3(0, j["neck"], 0), "body": Vector3(0, j["hip"].y, 0)}
	for s: float in [1.0, -1.0]:
		var side := "right" if s > 0 else "left"
		var sh: Vector2 = j["shoulder"]
		var el: Vector2 = j["elbow"]
		var wr: Vector2 = j["wrist"]
		var ha: Vector2 = j["hand"]
		var hp: Vector2 = j["hip"]
		var kn: Vector2 = j["knee"]
		var an: Vector2 = j["ankle"]
		pivots["arm_" + side] = Vector3(sh.x * s, sh.y, 0)
		pivots["arm_%s_lower" % side] = Vector3(el.x * s, el.y, 0)
		pivots["leg_" + side] = Vector3(hp.x * s, hp.y, 0)
		pivots["leg_%s_lower" % side] = Vector3(kn.x * s, kn.y, 0)
		_bones.append(["arm_" + side, Vector3(sh.x * s, sh.y, 0), Vector3(el.x * s, el.y, 0), j["r_arm"]])
		_bones.append(["arm_%s_lower" % side, Vector3(el.x * s, el.y, 0), Vector3(wr.x * s, wr.y, 0), j["r_arm"]])
		_bones.append(["arm_%s_lower" % side, Vector3(wr.x * s, wr.y, 0), Vector3(ha.x * s, ha.y, 0), j["r_arm"]])
		_bones.append(["leg_" + side, Vector3(hp.x * s, hp.y, 0), Vector3(kn.x * s, kn.y, 0), j["r_leg"]])
		_bones.append(["leg_%s_lower" % side, Vector3(kn.x * s, kn.y, 0), Vector3(an.x * s, an.y, 0), j["r_leg"]])
	_bones.append(["body", Vector3(0, j["hip"].y - 0.03, 0), Vector3(0, j["neck"], 0), j["r_torso"]])
	_bones.append(["head", Vector3(0, j["neck"] + 0.08, 0), Vector3(0, j["top"] - 0.06, 0), j["r_head"]])
	var tris := {}
	for name: String in pivots:
		tris[name] = PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var c := (tv[idx[t]] + tv[idx[t + 1]] + tv[idx[t + 2]]) / 3.0
		var part := _part_of(c)
		var list: PackedInt32Array = tris[part]
		list.append_array([idx[t], idx[t + 1], idx[t + 2]])
		tris[part] = list
	# La textura de color, una sola vez por cuerpo (comprimida); las mallas van sin material.
	var src_mat := imesh.get_surface_material(0) as BaseMaterial3D
	if src_mat != null and src_mat.albedo_texture != null:
		var img := src_mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.save_webp(ProjectSettings.globalize_path(out_dir.path_join("color.webp")), true, 0.9)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for name: String in tris:
		var list: PackedInt32Array = tris[name]
		var remap := {}
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pu := PackedVector2Array()
		var pi := PackedInt32Array()
		var pivot: Vector3 = pivots[name]
		for i in list:
			if not remap.has(i):
				remap[i] = pv.size()
				pv.append(tv[i] - pivot)
				pn.append(Vector3(-normals[i].x, normals[i].y, -normals[i].z))
				pu.append(uvs[i])
			pi.append(remap[i])
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = pv
		out[Mesh.ARRAY_NORMAL] = pn
		out[Mesh.ARRAY_TEX_UV] = pu
		out[Mesh.ARRAY_INDEX] = pi
		var m := ArrayMesh.new()
		if pv.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		ResourceSaver.save(m, out_dir.path_join(name + ".res"))
		print(name, ": ", list.size() / 3, " triángulos")
	var info := ConfigFile.new()
	for name: String in pivots:
		info.set_value("pivots", name, pivots[name])
	info.set_value("model", "height", h)
	info.save(out_dir.path_join("pivots.cfg"))
	quit()


## Trozo al que pertenece un punto (en fracciones del alto, mirando a -Z, derecha = +X).
func _part_of(c: Vector3) -> String:
	# Lo que está por encima del cuello es cabeza (pelo incluido); el resto, el hueso más cercano.
	if c.y >= JOINTS["neck"]:
		return "head"
	var best := "body"
	var best_d := INF
	var flat := Vector3(c.x, c.y, c.z * 0.6)  # de delante a atrás cuenta menos (pecho, nalgas)
	for b: Array in _bones:
		var a: Vector3 = b[1]
		var e: Vector3 = b[2]
		var ab := e - a
		var t := clampf((flat - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := flat.distance_to(a + ab * t) - float(b[3])
		if d < best_d:
			best_d = d
			best = b[0]
	return best
