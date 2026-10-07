extends SceneTree
## Prepara los objetos 3D de Meshy (assets/models_raw/meshy/items/<id>.glb) para el juego:
## conserva los triángulos, materiales y resolución originales; separa las piezas del mismo modelo
## (las que tienen hueco entre ellas a lo ancho) y guarda cada objeto en assets/models/items/:
## <id>.res (malla normalizada y material original incluido) y <id>.png (color sin pérdidas).
##
## Uso: godot --headless --path . --script res://tools/import_items.gd -- [modelo.glb nombre1,nombre2,...]
## Sin argumentos: todos los .glb de la carpeta, con su propio nombre. Con varios nombres, las
## piezas se nombran de izquierda a derecha.

const SRC := "res://assets/models_raw/meshy/items/"
const OUT := "res://assets/models/items/"
const COPIES := ["stone_axe", "spear", "arrow"]



func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var a := OS.get_cmdline_user_args()
	if a.size() >= 2:
		_import(a[0], a[1].split(","))
	else:
		for f in DirAccess.get_files_at(SRC):
			if f.ends_with(".glb"):
				_import(SRC + f, ["log_bundle", "rock", "flint"] if f.get_basename() == "recursos_madera_piedra" else [f.get_basename()])
	quit()


func _import(path: String, names: PackedStringArray) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		print("no se pudo leer ", path)
		return
	var imesh: ImporterMesh = state.get_meshes()[0].mesh
	var arr := imesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print(path.get_file(), ": ", idx.size() / 3, " triángulos originales")
	# Textura de color, una vez por modelo.
	var mat := imesh.get_surface_material(0) as BaseMaterial3D
	var tex_name := names[0] if names.size() == 1 else path.get_file().get_basename()
	if mat != null and mat.albedo_texture != null:
		var img := mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.save_png(ProjectSettings.globalize_path(OUT + tex_name + ".png"))
	# Piezas: grupos de triángulos separados por huecos a lo ancho (x).
	var copies := names.size() == 1 and names[0] in COPIES
	var groups := _split_x(verts, idx, 2 if copies else names.size())
	for g in groups.size():
		var name := names[0] + "_variant" if copies and g == 1 else names[0] if copies else names[g]
		_save(name, groups[g], verts, normals, uvs, tex_name, mat, arr[Mesh.ARRAY_TANGENT])


## Reparte los triángulos en 'count' grupos según los huecos en x (de izquierda a derecha).
func _split_x(verts: PackedVector3Array, idx: PackedInt32Array, count: int) -> Array:
	if count == 1:
		return [idx]
	var lo := INF
	var hi := -INF
	for v in verts:
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	var bins := 400
	var used := PackedByteArray()
	used.resize(bins)
	for t in range(0, idx.size(), 3):
		for k in 3:
			var b := clampi(int((verts[idx[t + k]].x - lo) / (hi - lo) * (bins - 1)), 0, bins - 1)
			used[b] = 1
	# Los huecos más anchos son los cortes.
	var gaps := []  # [ancho, centro]
	var start := -1
	for b in bins:
		if used[b] == 0 and start < 0:
			start = b
		elif used[b] == 1 and start >= 0:
			gaps.append([b - start, (start + b) * 0.5])
			start = -1
	gaps.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var cuts := []
	for i in mini(count - 1, gaps.size()):
		cuts.append(lo + float(gaps[i][1]) / (bins - 1) * (hi - lo))
	cuts.sort()
	var out := []
	for i in cuts.size() + 1:
		out.append(PackedInt32Array())
	for t in range(0, idx.size(), 3):
		var cx := (verts[idx[t]].x + verts[idx[t + 1]].x + verts[idx[t + 2]].x) / 3.0
		var g := 0
		while g < cuts.size() and cx > cuts[g]:
			g += 1
		var list: PackedInt32Array = out[g]  # (es una copia: se vuelve a guardar)
		list.append_array([idx[t], idx[t + 1], idx[t + 2]])
		out[g] = list
	print("  cortes en x: ", cuts)
	return out


## Guarda una pieza: centrada y escalada para que su medida mayor sea 1.
func _save(name: String, tri: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, tex_name: String, material: BaseMaterial3D, tangents: Variant) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in tri:
		lo = lo.min(verts[i])
		hi = hi.max(verts[i])
	var center := (lo + hi) * 0.5
	var size := hi - lo
	var k := 1.0 / maxf(size.x, maxf(size.y, size.z))
	var remap := {}
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var pu := PackedVector2Array()
	var pi := PackedInt32Array()
	var pt := PackedFloat32Array()
	for i in tri:
		if not remap.has(i):
			remap[i] = pv.size()
			pv.append((verts[i] - center) * k)
			pn.append(normals[i])
			pu.append(uvs[i])
			if tangents != null:
				for component in 4:
					pt.append(tangents[i * 4 + component])
		pi.append(remap[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = pu
	out[Mesh.ARRAY_INDEX] = pi
	if not pt.is_empty():
		out[Mesh.ARRAY_TANGENT] = pt
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	m.surface_set_material(0, material)
	m.set_meta("original_triangles", tri.size() / 3)
	m.set_meta("texture", tex_name)
	ResourceSaver.save(m, OUT + name + ".res")
	print("%s: %d triángulos, medidas %s" % [name, tri.size() / 3, (size * k).snapped(Vector3.ONE * 0.01)])



