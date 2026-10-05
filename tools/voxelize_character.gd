extends SceneTree
## Pasa un modelo de personaje (GLB con textura, p. ej. de Meshy) a cubitos con sus colores y
## guarda vistas de frente, de lado y de espaldas para revisarlo. Si se da 'salida.res', guarda
## también los cubitos (Dictionary Vector3i -> Color, con los pies en y = 0 y centrado en x/z).
## Uso: godot --headless --path . --script res://tools/voxelize_character.gd -- modelo.glb vista.png alto_en_cubitos [salida.res]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(a[0]), state)
	var mesh: ImporterMesh = state.get_meshes()[0].mesh
	var arr := mesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tex: Image = null
	var mat := mesh.get_surface_material(0) as BaseMaterial3D
	if mat != null and mat.albedo_texture != null:
		tex = mat.albedo_texture.get_image()
		if tex.is_compressed():
			tex.decompress()
		tex.convert(Image.FORMAT_RGBA8)
	print("vértices=", verts.size(), " triángulos=", idx.size() / 3, " textura=", tex.get_size() if tex else "no")
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var n := int(a[2])
	var vs := (hi.y - lo.y) / n
	# Cada cubito: suma de los colores que caen en él (luego, la media).
	var sums := {}
	var counts := {}
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		var p0 := verts[i0]
		var p1 := verts[i1]
		var p2 := verts[i2]
		var steps := int(ceil(maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0))) / vs * 2.0)) + 1
		for i in steps + 1:
			for j in steps + 1 - i:
				var u := float(i) / steps
				var w := float(j) / steps
				var p := p0 + (p1 - p0) * u + (p2 - p0) * w
				var cell := Vector3i(((p - lo) / vs).floor())
				var c := Color(0.6, 0.6, 0.6)
				if tex != null and uvs.size() > 0:
					var uv := uvs[i0] + (uvs[i1] - uvs[i0]) * u + (uvs[i2] - uvs[i0]) * w
					uv = uv.posmod(1.0)
					c = tex.get_pixel(int(uv.x * (tex.get_width() - 1)), int(uv.y * (tex.get_height() - 1)))
				sums[cell] = sums.get(cell, Color(0, 0, 0, 0)) + c
				counts[cell] = int(counts.get(cell, 0)) + 1
	var size := Vector3i(((hi - lo) / vs).ceil()) + Vector3i.ONE
	var cells := {}
	for cell: Vector3i in sums:
		var col: Color = sums[cell] / float(counts[cell])
		col.a = 1.0
		# Centrado en x y z; los pies en y = 0.
		cells[cell - Vector3i(size.x / 2, 0, size.z / 2)] = col
	print("cubitos de superficie: ", cells.size(), "  tamaño: ", size)
	_views(cells, size, a[1])
	if a.size() > 3:
		var res := VoxelModelData.new()
		res.cells = cells
		res.size = size
		ResourceSaver.save(res, a[3])
		print("guardado ", a[3])
	quit()


## Vistas de frente (mirando -Z), de lado (desde +X) y de espaldas, una al lado de otra.
func _views(cells: Dictionary, size: Vector3i, path: String) -> void:
	var w := size.x
	var d := size.z
	var img := Image.create(w * 2 + d + 8, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.22))
	var front := {}
	var side := {}
	var back := {}
	var hx := size.x / 2
	var hz := size.z / 2
	for c: Vector3i in cells:
		var y := size.y - 1 - c.y
		var col: Color = cells[c]
		# Frente: el más cercano a -Z. Lado: el de mayor x. Espalda: el de mayor z.
		var fk := Vector2i(c.x + hx, y)
		if not front.has(fk) or front[fk][0] > c.z:
			front[fk] = [c.z, col]
		var sk := Vector2i(w + 4 + (d - 1 - (c.z + hz)), y)
		if not side.has(sk) or side[sk][0] < c.x:
			side[sk] = [c.x, col]
		var bk := Vector2i(w * 2 + d + 7 - (c.x + hx), y)
		if not back.has(bk) or back[bk][0] < c.z:
			back[bk] = [c.z, col]
	for view: Dictionary in [front, side, back]:
		for k: Vector2i in view:
			if k.x >= 0 and k.x < img.get_width():
				img.set_pixelv(k, view[k][1])
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
