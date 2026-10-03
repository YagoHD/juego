extends SceneTree
## Convierte un modelo 3D (OBJ + MTL, como los de Kenney) en un modelo de cubitos al estilo
## Cube World / Hytale: se muestrean sus triángulos en una rejilla, cada cubito toma el color del
## material, y se genera una malla solo con las caras que se ven. Se guarda como recurso .res.
## Uso:
##   godot --headless --path . --script res://tools/voxelize_model.gd -- <entrada.obj> <nombre> <alto_m> <cubito_m>
## Ejemplo (palmera de 5 m con cubitos de 1/4 de bloque):
##   ... -- "C:/.../tree_palmTall.obj" palmera 5.0 0.125
## Sale en res://assets/models/voxel/<nombre>.res

const OUT_DIR := "res://assets/models/voxel/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		print("Uso: -- <entrada.obj> <nombre> <alto_m> <cubito_m>")
		quit(1)
		return
	var mesh := voxelize(args[0], float(args[2]), float(args[3]))
	if mesh == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := OUT_DIR + args[1] + ".res"
	ResourceSaver.save(mesh, path)
	print("[voxelizar] ", path, "  (", mesh.get_meta("voxels"), " cubitos)")
	quit()


static func voxelize(obj_path: String, target_height: float, voxel: float) -> ArrayMesh:
	var data := _read_obj(obj_path)
	if data.is_empty():
		push_error("No se pudo leer " + obj_path)
		return null
	var verts: PackedVector3Array = data["verts"]
	var tris: Array = data["tris"]  # [a, b, c, color]
	# Escala: que el modelo mida 'target_height' de alto, apoyado en y = 0 y centrado.
	var low := Vector3(INF, INF, INF)
	var high := -low
	for v in verts:
		low = low.min(v)
		high = high.max(v)
	var extent := high - low  # la medida mayor (alto o ancho) es la que se pide
	var k := target_height / maxf(maxf(extent.x, extent.y), maxf(extent.z, 0.0001))
	var center := Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
	# Muestrear cada triángulo con puntos más juntos que un cubito.
	var cells := {}  # Vector3i -> Color
	for t in tris:
		var a: Vector3 = (verts[t[0]] - center) * k
		var b: Vector3 = (verts[t[1]] - center) * k
		var c: Vector3 = (verts[t[2]] - center) * k
		var color: Color = t[3]
		var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var steps := maxi(1, int(ceilf(longest / (voxel * 0.45))))
		for i in steps + 1:
			for j in steps + 1 - i:
				var u := float(i) / steps
				var w := float(j) / steps
				var p := a + (b - a) * u + (c - a) * w
				var cell := Vector3i((p / voxel).floor())
				if not cells.has(cell):
					cells[cell] = color
	return _build_mesh(cells, voxel)


## Lee un OBJ sencillo con su MTL: vértices, caras (en triángulos) y el color de cada una. El
## color sale del Kd del material o, si el material tiene imagen (map_Kd, como el Survival Kit),
## de la imagen en el centro de la cara (esas imágenes son paletas de colores lisos).
static func _read_obj(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var materials := {}
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tris := []
	var current := {"color": Color(0.8, 0.8, 0.8), "image": null}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("mtllib "):
			materials = _read_mtl(path.get_base_dir().path_join(line.substr(7).strip_edges()))
		elif line.begins_with("usemtl "):
			current = materials.get(line.substr(7).strip_edges(), current)
		elif line.begins_with("v "):
			var p := line.split(" ", false)
			verts.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			uvs.append(Vector2(float(p[1]), float(p[2])))
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var idx: Array[int] = []
			var tidx: Array[int] = []
			for n in range(1, p.size()):
				var parts := p[n].split("/")
				idx.append(int(parts[0]) - 1)
				tidx.append(int(parts[1]) - 1 if parts.size() > 1 and parts[1] != "" else -1)
			for n in range(1, idx.size() - 1):
				var color: Color = current["color"]
				var img: Image = current["image"]
				if img != null and tidx[0] >= 0:
					var uv := (uvs[tidx[0]] + uvs[tidx[n]] + uvs[tidx[n + 1]]) / 3.0
					var px := clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1)
					var py := clampi(int((1.0 - uv.y) * img.get_height()), 0, img.get_height() - 1)
					color = img.get_pixel(px, py)
				tris.append([idx[0], idx[n], idx[n + 1], color])
	return {"verts": verts, "tris": tris}


static func _read_mtl(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var name := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("newmtl "):
			name = line.substr(7).strip_edges()
			out[name] = {"color": Color(0.8, 0.8, 0.8), "image": null}
		elif line.begins_with("Kd ") and name != "":
			var p := line.split(" ", false)
			# Los colores del MTL de Kenney ya son los que se ven (sRGB): tal cual.
			out[name]["color"] = Color(float(p[1]), float(p[2]), float(p[3]))
		elif line.begins_with("map_Kd ") and name != "":
			var img := Image.load_from_file(path.get_base_dir().path_join(line.substr(7).strip_edges()))
			if img != null:
				img.convert(Image.FORMAT_RGBA8)
				out[name]["image"] = img
	return out


## Malla de cubitos: solo las caras que dan al aire, cada una con un poco de sombra según hacia
## dónde mira (arriba más clara, abajo más oscura), para que se lean bien los volúmenes.
static func _build_mesh(cells: Dictionary, voxel: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3i.UP, 1.0, [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[Vector3i.DOWN, 0.6, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[Vector3i.BACK, 0.85, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3i.FORWARD, 0.8, [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]],
		[Vector3i.RIGHT, 0.75, [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]],
		[Vector3i.LEFT, 0.7, [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	]
	for cell: Vector3i in cells:
		var base := Vector3(cell) * voxel
		var color: Color = cells[cell]
		# Un pelín de variación por cubito: que no parezca plástico liso.
		var jitter := (float(absi(hash(cell)) % 100) / 100.0 - 0.5) * 0.06
		for f in faces:
			if cells.has(cell + (f[0] as Vector3i)):
				continue
			var shade := color * float(f[1])
			shade = Color(shade.r + jitter, shade.g + jitter, shade.b + jitter, 1.0)
			var v: Array = f[2]
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(shade)
				st.set_normal(Vector3(f[0] as Vector3i))
				st.add_vertex(base + (v[i] as Vector3) * voxel)
	st.index()
	var mesh := st.commit()
	mesh.set_meta("voxels", cells.size())
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh
