extends SceneTree
## Pasa un modelo de personaje (GLB) a cubitos y guarda una vista de frente y de lado (para revisar
## la forma). Uso: godot --headless --path . --script res://tools/voxelize_character.gd -- modelo.glb salida.png alto_en_cubitos
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(a[0]), state)
	var mesh: ImporterMesh = state.get_meshes()[0].mesh
	var arr := mesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var n := int(a[2])
	var vs := (hi.y - lo.y) / n
	var cells := {}
	for t in range(0, idx.size(), 3):
		var p0 := verts[idx[t]]
		var p1 := verts[idx[t + 1]]
		var p2 := verts[idx[t + 2]]
		var steps := int(ceil(maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0))) / vs * 2.0)) + 1
		for i in steps + 1:
			for j in steps + 1 - i:
				var u := float(i) / steps
				var w := float(j) / steps
				var p := p0 + (p1 - p0) * u + (p2 - p0) * w
				cells[Vector3i(((p - lo) / vs).floor())] = true
	print("cubitos de superficie: ", cells.size(), "  tamaño: ", ((hi - lo) / vs).ceil())
	var size := Vector3i(((hi - lo) / vs).ceil()) + Vector3i.ONE
	var img := Image.create(size.x + size.z + 4, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.93, 0.88))
	var depth := {}
	for c: Vector3i in cells:
		var f := Vector2i(c.x, size.y - 1 - c.y)
		var shade := 1.0 - float(c.z) / size.z * 0.8
		if not depth.has(f) or depth[f] < shade:
			depth[f] = shade
			img.set_pixelv(f, Color(shade * 0.5, shade * 0.4, shade * 0.3))
		var s := Vector2i(size.x + 4 + c.z, size.y - 1 - c.y)
		var shade2 := float(c.x) / size.x * 0.8 + 0.2
		if not depth.has(s) or depth[s] < shade2:
			depth[s] = shade2
			img.set_pixelv(s, Color(shade2 * 0.3, shade2 * 0.4, shade2 * 0.5))
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(a[1])
	quit()
