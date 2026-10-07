class_name SkinModel
## Cuerpo del personaje a partir de una skin con el formato de Minecraft (imagen de 64x64).
##
## Cada parte es una caja cuyas 6 caras toman un trozo fijo de la imagen; brazos y piernas se
## parten en dos segmentos (codo y rodilla) que usan la mitad de arriba y la de abajo de su
## textura, así que la imagen sigue siendo una skin normal de Minecraft. Hay dos capas:
## la base (piel y ropa pegada) y la exterior, un poco más grande y con transparencia
## (pelo con volumen, chaquetas, gorros...). Así cualquier editor de skins de Minecraft sirve.
## Ver docs/SKINS.md.
##
## Unidades: el modelo mide 32 "píxeles de skin" de alto; PIXEL lo convierte a metros para que
## mida lo mismo que el jugador (SkinModel.BODY_HEIGHT). El personaje mira hacia -Z y su derecha es +X.

const TEXTURE_SIZE := 64
const BLOCK_SIZE := 0.5               # metros por bloque del mundo
## Altura del personaje EN BLOQUES: 1,8 = como Steve en Minecraft (antes: 2,8). Es el único número
## que hay que tocar para cambiar el tamaño del personaje: todo lo demás se ajusta solo.
const PLAYER_HEIGHT_BLOCKS := 1.8
const BODY_HEIGHT := PLAYER_HEIGHT_BLOCKS * BLOCK_SIZE
const PIXEL := BODY_HEIGHT / 32.0      # 1 píxel de skin en metros (el modelo mide 32 px)
const JOINT_ROW := 6          # brazos y piernas se doblan a 6 px de su extremo superior
const JOINT_OVERLAP := 2.0    # px que el segmento inferior se mete en el superior (sin huecos al doblar)
const JOINT_UNDERLAP := 1.0   # px que el segmento superior baja dentro del inferior
const HIP_OVERLAP := 2.5      # px que el muslo sube dentro del torso (sin hueco en la cadera)
const JOINT_INSET := 0.05     # px de estrechamiento de las piezas que se solapan (evita parpadeos)
## Cuerpo de cubitos (VoxelBody) con manos de 5 dedos (VoxelHand) en vez de cajas lisas.
## Desde el estilo nuevo (docs/ANALISIS_ESTILO.md) el personaje es de cajas, como en la guía.
const VOXEL := false
## El personaje es el náufrago modelado con cubitos (CastawayModel), no una skin de cajas.
const CASTAWAY := false
## Pelo de cubos del náufrago de cajas (sale de la guía con tools/skin_desde_guia.py).
const HAIR_PATH := "res://assets/skins/naufrago/pelo.json"
## Cabeza más grande que la de Minecraft (como en Minecraft Dungeons y la guía visual); el pelo
## abulta aún un poco más.
const HEAD_SCALE := 1.2
const HAIR_SCALE := 1.12
const HAND_CUT := 2           # px del final del brazo que se cambian por la mano de cubitos
## Redondeo de las aristas de cada parte (px) y si se redondean también arriba y abajo.
const ROUNDING := {"head": [1.5, true], "body": [1.0, false], "arm_right": [0.75, false],
	"arm_left": [0.75, false], "leg_right": [0.75, false], "leg_left": [0.75, false]}

static var _voxel_image: Image  # skin de la que salen los colores de los cubitos (mientras se construye)

## Partes: tamaño (px), origen en la imagen de la capa base y de la exterior, pivote (px, desde
## los pies) y esquina mínima de la caja respecto al pivote. "inflate": cuánto sobresale la capa
## exterior (px). Los brazos estrechos ("slim") miden 3 px de ancho en vez de 4.
const PARTS := {
	"head": {"size": Vector3i(8, 8, 8), "base": Vector2i(0, 0), "over": Vector2i(32, 0),
		"pivot": Vector3(0, 24, 0), "min": Vector3(-4, 0, -4), "inflate": 0.5},
	"body": {"size": Vector3i(8, 12, 4), "base": Vector2i(16, 16), "over": Vector2i(16, 32),
		"pivot": Vector3(0, 12, 0), "min": Vector3(-4, 0, -2), "inflate": 0.25},
	"arm_right": {"size": Vector3i(4, 12, 4), "base": Vector2i(40, 16), "over": Vector2i(40, 32),
		"pivot": Vector3(6, 22, 0), "min": Vector3(-2, -10, -2), "inflate": 0.25},
	"arm_left": {"size": Vector3i(4, 12, 4), "base": Vector2i(32, 48), "over": Vector2i(48, 48),
		"pivot": Vector3(-6, 22, 0), "min": Vector3(-2, -10, -2), "inflate": 0.25},
	"leg_right": {"size": Vector3i(4, 12, 4), "base": Vector2i(0, 16), "over": Vector2i(0, 32),
		"pivot": Vector3(2, 12, 0), "min": Vector3(-2, -12, -2), "inflate": 0.25},
	"leg_left": {"size": Vector3i(4, 12, 4), "base": Vector2i(16, 48), "over": Vector2i(0, 48),
		"pivot": Vector3(-2, 12, 0), "min": Vector3(-2, -12, -2), "inflate": 0.25},
}


## Tamaño de una parte teniendo en cuenta los brazos estrechos.
static func part_size(part: String, slim: bool) -> Vector3i:
	var size: Vector3i = PARTS[part]["size"]
	if slim and part.begins_with("arm"):
		size.x = 3
	return size


## Rectángulos (en píxeles de la imagen) de cada cara de una caja desplegada al estilo Minecraft:
##   fila de arriba: [arriba][abajo]      fila de abajo: [derecha][delante][izquierda][detrás]
static func face_rects(origin: Vector2i, size: Vector3i) -> Dictionary:
	var w := size.x
	var h := size.y
	var d := size.z
	return {
		"top": Rect2i(origin.x + d, origin.y, w, d),
		"bottom": Rect2i(origin.x + d + w, origin.y, w, d),
		"right": Rect2i(origin.x, origin.y + d, d, h),
		"front": Rect2i(origin.x + d, origin.y + d, w, h),
		"left": Rect2i(origin.x + d + w, origin.y + d, d, h),
		"back": Rect2i(origin.x + 2 * d + w, origin.y + d, w, h),
	}



static func is_limb(part: String) -> bool:
	return part.begins_with("arm") or part.begins_with("leg")


## Malla de una parte (capa base o exterior), en metros. Para brazos y piernas, rows indica el
## segmento: filas [rows.x, rows.y) de su textura, contadas desde arriba (0..12). La malla se
## coloca respecto a 'origin_px' (el pivote de la parte o el de la articulación).
static func part_mesh(part: String, slim: bool, overlay: bool, rows := Vector2i(0, -1),
		origin_px := Vector3.ZERO, extend_top_px := 0.0, inset_px := 0.0, extend_bottom_px := 0.0) -> ArrayMesh:
	var info: Dictionary = PARTS[part]
	var size := part_size(part, slim)
	var box_min: Vector3 = info["min"]
	if slim and part.begins_with("arm"):
		box_min.x = -1.5
	var row_from := rows.x
	var row_to := size.y if rows.y < 0 else rows.y
	var grow: float = info["inflate"] if overlay else 0.0
	var top_y := box_min.y + size.y  # parte de arriba de la caja completa (en px, desde el pivote)
	var lo := Vector3(box_min.x - grow + inset_px, top_y - row_to - grow - extend_bottom_px, box_min.z - grow + inset_px)
	var hi := Vector3(box_min.x + size.x + grow - inset_px, top_y - row_from + grow + extend_top_px,
		box_min.z + size.z + grow - inset_px)
	lo = (lo - origin_px) * PIXEL
	hi = (hi - origin_px) * PIXEL

	# Trozo de la imagen de cada cara. Los laterales solo usan las filas del segmento; las tapas
	# interiores (en el codo/rodilla) usan una tira de 1 px del lateral delantero.
	var full := face_rects(info["over"] if overlay else info["base"], size)
	var rects := {}
	for face in ["right", "front", "left", "back"]:
		var r: Rect2i = full[face]
		rects[face] = Rect2(r.position.x, r.position.y + row_from, r.size.x, row_to - row_from)
	var front: Rect2i = full["front"]
	rects["top"] = Rect2(full["top"]) if row_from == 0 \
		else Rect2(front.position.x, front.position.y + row_from, front.size.x, 1)
	rects["bottom"] = Rect2(full["bottom"]) if row_to == size.y \
		else Rect2(front.position.x, front.position.y + row_to - 1, front.size.x, 1)
	if VOXEL and _voxel_image != null:
		var rounding: Array = ROUNDING[part]
		return VoxelBody.build(lo, hi, rects, _voxel_image, overlay, 0.0 if overlay else float(rounding[0]),
			bool(rounding[1]), rows.x + (7 if overlay else 0))
	return _box_mesh(lo, hi, rects)


## Caja de lo a hi (metros) con cada cara mapeada a un rectángulo de la imagen (en píxeles).
static func _box_mesh(lo: Vector3, hi: Vector3, rects: Dictionary) -> ArrayMesh:
	var x0 := lo.x
	var y0 := lo.y
	var z0 := lo.z
	var x1 := hi.x
	var y1 := hi.y
	var z1 := hi.z
	# Esquinas de cada cara en el orden de la imagen: arriba-izq, arriba-der, abajo-der, abajo-izq
	# (vista desde fuera). Delante = -Z; derecha del personaje = +X.
	var faces := {
		"front": [Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0)],
		"back": [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1)],
		"right": [Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1)],
		"left": [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0)],
		"top": [Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x1, y1, z0)],
		"bottom": [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x1, y0, z1)],
	}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for face_name in faces:
		var corners: Array = faces[face_name]
		var rect: Rect2 = rects[face_name]
		var a: Vector3 = corners[0]
		var b: Vector3 = corners[1]
		var c: Vector3 = corners[2]
		var normal := (b - a).cross(c - a).normalized() * -1.0
		var u0 := rect.position.x / TEXTURE_SIZE
		var v0 := rect.position.y / TEXTURE_SIZE
		var u1 := rect.end.x / TEXTURE_SIZE
		var v1 := rect.end.y / TEXTURE_SIZE
		var face_uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
		var start := vertices.size()
		for k in 4:
			vertices.append(corners[k])
			normals.append(normal)
			uvs.append(face_uvs[k])
		# Dos triángulos en sentido horario (cara frontal en Godot).
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Material de la skin: píxeles nítidos y transparencia recortada (para la capa exterior).
## on_top = true lo dibuja siempre por encima del mundo (brazo en primera persona).
static func make_material(texture: Texture2D, on_top := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.roughness = 0.9
	if on_top:
		material.no_depth_test = true
		material.render_priority = 10
		material.disable_receive_shadows = true  # el propio cuerpo no le hace sombra
	return material


## Crea una parte completa (base + exterior) como nodo, con el pivote en su articulación
## (hombro, cadera, cuello...). Brazos y piernas llevan además un nodo hijo "lower" en el codo
## o la rodilla, con el segmento de abajo: girándolo se dobla la articulación.
static func make_part(part: String, texture: Texture2D, slim: bool, layer: int, on_top := false) -> Node3D:
	# El náufrago modelado con cubitos (CastawayModel), salvo que el jugador tenga su propia skin.
	if CASTAWAY and not FileAccess.file_exists(SkinComposer.USER_SKIN_PATH):
		return CastawayModel.make_part(part, layer, on_top)
	var pivot := Node3D.new()
	pivot.name = part
	pivot.position = Vector3(PARTS[part]["pivot"]) * PIXEL
	if slim and part.begins_with("arm"):
		pivot.position.x -= signf(pivot.position.x) * 0.5 * PIXEL
	var material: Material = make_material(texture, on_top)
	_voxel_image = null
	if VOXEL:
		_voxel_image = texture.get_image()
		if _voxel_image.is_compressed():
			_voxel_image.decompress()
		_voxel_image.clear_mipmaps()
		_voxel_image.convert(Image.FORMAT_RGBA8)
		material = make_voxel_material(on_top)

	if not is_limb(part):
		for overlay in [false, true]:
			pivot.add_child(_mesh_node(part_mesh(part, slim, overlay), material, layer, on_top))
		if part == "head" and not FileAccess.file_exists(SkinComposer.USER_SKIN_PATH):
			var hair := hair_mesh()
			if hair != null:
				var hair_node := _mesh_node(hair, make_voxel_material(on_top), layer, on_top)
				hair_node.name = "hair"
				hair_node.scale = Vector3.ONE * HAIR_SCALE
				hair_node.position = Vector3(0, 4.0 * (1.0 - HAIR_SCALE), 0) * PIXEL  # crece desde el centro de la cabeza
				pivot.add_child(hair_node)
			pivot.scale = Vector3.ONE * HEAD_SCALE
		_voxel_image = null
		return pivot

	var size := part_size(part, slim)
	var top_y: float = Vector3(PARTS[part]["min"]).y + size.y
	var joint := Vector3(0, top_y - JOINT_ROW, 0)  # codo/rodilla, en px desde el pivote
	var lower := Node3D.new()
	lower.name = "lower"
	lower.position = joint * PIXEL
	pivot.add_child(lower)
	# Con manos de cubitos, el final del brazo (la mano de la skin) se cambia por la mano.
	var arm_hand := VOXEL and part.begins_with("arm")
	var lower_end := size.y - HAND_CUT if arm_hand else size.y
	for overlay in [false, true]:
		# Segmento superior: baja un poco dentro del inferior y, en las piernas, sube dentro del
		# torso; así al doblar codos, rodillas o caderas no se ven rajas entre las piezas.
		var hip := HIP_OVERLAP if part.begins_with("leg") else 0.0
		pivot.add_child(_mesh_node(part_mesh(part, slim, overlay, Vector2i(0, JOINT_ROW),
			Vector3.ZERO, hip, JOINT_INSET if hip > 0.0 else 0.0, JOINT_UNDERLAP), material, layer, on_top))
		lower.add_child(_mesh_node(part_mesh(part, slim, overlay, Vector2i(JOINT_ROW, lower_end),
			joint, JOINT_OVERLAP, JOINT_INSET * 2.0), material, layer, on_top))
	if arm_hand:
		var hand := VoxelHand.new()
		hand.name = "hand"
		hand.position = Vector3(0, -(lower_end - JOINT_ROW), 0) * PIXEL
		lower.add_child(hand)
		hand.build(_skin_color(part, slim), part == "arm_right", material, layer, on_top)
	_voxel_image = null
	return pivot


## Pelo rizado del náufrago: un montón de cubos de 1 píxel de skin alrededor de la cabeza (posición
## en píxeles desde el cuello). Solo se dibujan las caras que no tapa otro cubo.
static func hair_mesh() -> ArrayMesh:
	if not FileAccess.file_exists(HAIR_PATH):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HAIR_PATH))
	if not data is Dictionary:
		return null
	var cubes := {}
	for cube: Array in data["cubos"]:
		cubes[Vector3i(int(cube[0]), int(cube[1]), int(cube[2]))] = Color.html(cube[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector3i in cubes:
		# Cada rizo con su tono (más claro o más oscuro), como en la guía: así se leen los cubos.
		var vary := 0.82 + 0.36 * float(absi(cell.x * 73856093 ^ cell.y * 19349663 ^ cell.z * 83492791) % 100) / 100.0
		var base: Color = cubes[cell]
		var color := Color(base.r * vary, base.g * vary, base.b * vary)
		for dir: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
			# Las caras que dan a la cabeza también se dibujan: el pelo va un poco separado (HAIR_SCALE).
			if cubes.has(cell + dir):
				continue
			# Un poco más oscuro abajo y a los lados: el pelo tiene volumen aunque no le dé la luz.
			var shade := 1.0 if dir == Vector3i.UP else (0.8 if dir == Vector3i.DOWN else 0.92)
			_cube_face(st, Vector3(cell), Vector3(dir), Color(color.r * shade, color.g * shade, color.b * shade))
	return st.commit()


static func _cube_face(st: SurfaceTool, cell: Vector3, n: Vector3, color: Color) -> void:
	# Cara del cubo [cell, cell + 1] (en px) que mira hacia n, en metros.
	var u := Vector3(n.y, n.z, n.x).abs()  # dos ejes perpendiculares a n
	var v := n.cross(u)
	var center := (cell + Vector3.ONE * 0.5 + n * 0.5) * PIXEL
	var a := center + (-u - v) * 0.5 * PIXEL
	var b := center + (u - v) * 0.5 * PIXEL
	var c := center + (u + v) * 0.5 * PIXEL
	var d := center + (-u + v) * 0.5 * PIXEL
	st.set_color(color)
	st.set_normal(n)
	# Sentido horario visto desde fuera (cara frontal en Godot).
	var quad := [a, d, c, a, c, b] if u.cross(v).dot(n) > 0.0 else [a, b, c, a, c, d]
	for p: Vector3 in quad:
		st.add_vertex(p)


## Color de la piel de una parte (el antebrazo, en el centro de su cara de delante).
static func _skin_color(part: String, slim: bool) -> Color:
	var size := part_size(part, slim)
	var front: Rect2i = face_rects(PARTS[part]["base"], size)["front"]
	var k := _voxel_image.get_width() / TEXTURE_SIZE
	return _voxel_image.get_pixel(int((front.position.x + front.size.x * 0.5) * k), int((front.position.y + 8.5) * k))  # el antebrazo


## Material de los cubitos: el color va en cada vértice.
static func make_voxel_material(on_top := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	if on_top:
		material.no_depth_test = true
		material.render_priority = 10
		material.disable_receive_shadows = true
	return material


static func _mesh_node(mesh: ArrayMesh, material: Material, layer: int, on_top: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.layers = layer
	if on_top:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
