class_name ItemMesh
## Malla 3D de un objeto para verlo en la mano o en el suelo: los bloques son cubos con su
## textura; el resto (cuerda, ropa...) es su icono con grosor, un prisma por píxel.


static func make(id: String, size: float) -> Mesh:
	var block := ItemDB.block_of(id)
	if block >= 0:
		return BlockTextures.make_block_mesh(block, size)
	return _flat(id, size)


static func make_material(id: String) -> StandardMaterial3D:
	var block := ItemDB.block_of(id)
	if block >= 0:
		return BlockTextures.make_material(block == IslandGenerator.WATER)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material


static func _flat(id: String, size: float) -> Mesh:
	var img := ItemPainter.paint(id)
	var n := ItemPainter.S
	var px := size / n
	var half := n * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			c.a = 1.0
			var side := c.darkened(0.25)
			var x0 := (x - half) * px
			var x1 := x0 + px
			var y1 := (half - y) * px  # en la imagen la y crece hacia abajo
			var y0 := y1 - px
			var z0 := -px * 0.5
			var z1 := px * 0.5
			_quad(st, c, Vector3.BACK, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)])
			_quad(st, c, Vector3.FORWARD, [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)])
			if not _opaque(img, x - 1, y):
				_quad(st, side, Vector3.LEFT, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)])
			if not _opaque(img, x + 1, y):
				_quad(st, side, Vector3.RIGHT, [Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1)])
			if not _opaque(img, x, y - 1):
				_quad(st, side, Vector3.UP, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)])
			if not _opaque(img, x, y + 1):
				_quad(st, side, Vector3.DOWN, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)])
	return st.commit()


static func _opaque(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a >= 0.5


## Cara de 4 vértices (en sentido antihorario visto desde fuera) como 2 triángulos.
static func _quad(st: SurfaceTool, color: Color, normal: Vector3, v: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v[i])
