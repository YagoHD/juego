class_name BlockTextures
## Texturas de los bloques: imágenes de 16x16 por cara, reunidas en un atlas (una sola imagen).
##
## Cada textura se genera por código a partir del color del bloque (con detalle de píxel:
## briznas, guijarros, grietas, vetas...). Para pintar una a mano, basta con guardar un PNG de
## 16x16 en OVERRIDE_DIR con el nombre de la textura (p. ej. "grass_top.png"): se usará esa.
##
## Los mipmaps se generan tile a tile, para que a lo lejos no se mezclen los colores de texturas
## vecinas del atlas.

const TILE := 16
const COLUMNS := 8
const OVERRIDE_DIR := "res://assets/textures/blocks/"

## Texturas de cada bloque: [arriba, lados, abajo].
const FACES := {
	IslandGenerator.GRASS: ["grass_top", "grass_side", "dirt"],
	IslandGenerator.DIRT: ["dirt", "dirt", "dirt"],
	IslandGenerator.STONE: ["stone", "stone", "stone"],
	IslandGenerator.SAND: ["sand", "sand", "sand"],
	IslandGenerator.SNOW: ["snow", "snow", "snow"],
	IslandGenerator.WOOD: ["log_top", "log_side", "log_top"],
	IslandGenerator.LEAVES: ["leaves", "leaves", "leaves"],
	IslandGenerator.WATER: ["water", "water", "water"],
	IslandGenerator.PINE_LEAVES: ["pine_leaves", "pine_leaves", "pine_leaves"],
	IslandGenerator.CORRUPT_SOIL: ["corrupt_top", "corrupt_side", "dirt"],
	IslandGenerator.DEAD_WOOD: ["dead_log_top", "dead_log_side", "dead_log_top"],
	IslandGenerator.WHEAT: ["wheat_top", "wheat_side", "dirt"],
	IslandGenerator.CHEST: ["chest_top", "chest_side", "chest_top"],
	IslandGenerator.PLANKS: ["planks", "planks", "planks"],
	IslandGenerator.CLOTH: ["cloth", "cloth", "cloth"],
}

static var _atlas: ImageTexture
static var _tiles := {}  # nombre -> Vector2i (posición en el atlas, en tiles)
static var _averages := {}  # nombre -> Color medio de la textura


## Atlas con todas las texturas (se crea la primera vez que se pide).
static func atlas() -> ImageTexture:
	if _atlas == null:
		_build()
	return _atlas


static func atlas_size_in_tiles() -> Vector2i:
	atlas()
	@warning_ignore("integer_division")
	return Vector2i(COLUMNS, (_tiles.size() + COLUMNS - 1) / COLUMNS)


## Posición en el atlas (en tiles) de la cara de un bloque: face = 0 arriba, 1 lados, 2 abajo.
static func tile_of(block_id: int, face: int) -> Vector2i:
	atlas()
	var names: Array = FACES.get(block_id, ["stone", "stone", "stone"])
	return _tiles[names[face]]


## Rectángulo (en píxeles) de la cara de arriba de un bloque, para iconos.
static func icon_region(block_id: int) -> Rect2:
	return Rect2(Vector2(tile_of(block_id, 0) * TILE), Vector2(TILE, TILE))


## Material con el atlas: píxeles nítidos de cerca, sin parpadeo de lejos.
static func make_material(transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = atlas()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.95
	material.metallic_specular = 0.2  # como la isla lejana; con más, el cielo da un velo blanquecino
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.35
		material.metallic_specular = 0.25
	return material


## Cubo con las texturas de un bloque (para el bloque en la mano y similares), centrado.
static func make_block_mesh(block_id: int, size: float) -> ArrayMesh:
	var grid := Vector2(atlas_size_in_tiles())
	var h := size * 0.5
	var faces := [  # [normal, cara (0 arriba, 1 lado, 2 abajo), esquinas en orden de la imagen]
		[Vector3.UP, 0, [Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h)]],
		[Vector3.DOWN, 2, [Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, -h, -h), Vector3(-h, -h, -h)]],
		[Vector3.FORWARD, 1, [Vector3(h, h, -h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(h, -h, -h)]],
		[Vector3.BACK, 1, [Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(-h, -h, h)]],
		[Vector3.RIGHT, 1, [Vector3(h, h, h), Vector3(h, h, -h), Vector3(h, -h, -h), Vector3(h, -h, h)]],
		[Vector3.LEFT, 1, [Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(-h, -h, h), Vector3(-h, -h, -h)]],
	]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for f in faces:
		var tile := Vector2(tile_of(block_id, f[1]))
		var uv0 := tile / grid
		var uv1 := (tile + Vector2.ONE) / grid
		var face_uvs := [uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]
		var start := vertices.size()
		for k in 4:
			vertices.append(f[2][k])
			normals.append(f[0])
			uvs.append(face_uvs[k])
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	if block_id == IslandGenerator.CLOTH:
		# La tela es una alfombra: el cubo se aplasta hasta 1/8 de su altura, apoyado abajo.
		for i in vertices.size():
			var v := vertices[i]
			vertices[i] = Vector3(v.x, -h + (v.y + h) * 0.125, v.z)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ------------------------------------------------------------------ construcción del atlas

static func _build() -> void:
	var names: Array[String] = []
	for id in FACES:
		for n in FACES[id]:
			if not names.has(n):
				names.append(n)
	_tiles.clear()
	var rows := (names.size() + COLUMNS - 1) / COLUMNS
	var width := COLUMNS * TILE
	var height := rows * TILE
	var images: Array[Image] = []
	for i in names.size():
		_tiles[names[i]] = Vector2i(i % COLUMNS, i / COLUMNS)
		var img := _texture(names[i])
		images.append(img)
		_averages[names[i]] = _average(img)

	# Cadena de mipmaps hecha tile a tile (los tiles no se mezclan entre sí).
	var data := PackedByteArray()
	var level_size := Vector2i(width, height)
	var tile := TILE
	var previous: Image = null
	while true:
		var level := Image.create(level_size.x, level_size.y, false, Image.FORMAT_RGBA8)
		if tile >= 1:
			for i in images.size():
				var img := images[i]
				if tile != TILE:
					img = img.duplicate() as Image
					img.resize(tile, tile, Image.INTERPOLATE_BILINEAR)
				var pos: Vector2i = _tiles[names[i]] * tile
				level.blit_rect(img, Rect2i(0, 0, tile, tile), pos)
		else:
			level = previous.duplicate() as Image  # tiles ya de 1 px: reducir el atlas entero
			level.resize(level_size.x, level_size.y, Image.INTERPOLATE_BILINEAR)
		data.append_array(level.get_data())
		previous = level
		if level_size == Vector2i.ONE:
			break
		level_size = Vector2i(maxi(level_size.x / 2, 1), maxi(level_size.y / 2, 1))
		tile = tile / 2 if tile > 1 else 0
	var atlas_image := Image.create_from_data(width, height, true, Image.FORMAT_RGBA8, data)
	_atlas = ImageTexture.create_from_image(atlas_image)


static func _texture(name: String) -> Image:
	var path := OVERRIDE_DIR + name + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != TILE or img.get_height() != TILE:
				img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
			return img
	return BlockPainter.paint(name)


## Atlas como imagen normal (sin mipmaps), para guardarlo y verlo.
static func atlas_image() -> Image:
	var img := atlas().get_image()
	img.clear_mipmaps()
	return img


## Color medio de la cara de un bloque (face = 0 arriba, 1 lados, 2 abajo). Lo usa la isla lejana
## para que, vista de lejos, tenga el mismo tono que los bloques texturizados de cerca.
static func average_color(block_id: int, face: int) -> Color:
	atlas()
	var names: Array = FACES.get(block_id, ["stone", "stone", "stone"])
	return _averages[names[face]]


static func _average(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			sum += img.get_pixel(x, y)
	return sum / float(img.get_width() * img.get_height())
