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
## mida lo mismo que el jugador (1,4 m). El personaje mira hacia -Z y su derecha es +X.

const TEXTURE_SIZE := 64
const PIXEL := 1.4 / 32.0
const JOINT_ROW := 6          # brazos y piernas se doblan a 6 px de su extremo superior
const JOINT_OVERLAP := 2.0    # px que el segmento inferior se mete en el superior (sin huecos al doblar)
const JOINT_UNDERLAP := 1.0   # px que el segmento superior baja dentro del inferior
const HIP_OVERLAP := 2.5      # px que el muslo sube dentro del torso (sin hueco en la cadera)
const JOINT_INSET := 0.05     # px de estrechamiento de las piezas que se solapan (evita parpadeos)

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
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.roughness = 0.9
	if on_top:
		material.no_depth_test = true
		material.render_priority = 10
	return material


## Crea una parte completa (base + exterior) como nodo, con el pivote en su articulación
## (hombro, cadera, cuello...). Brazos y piernas llevan además un nodo hijo "lower" en el codo
## o la rodilla, con el segmento de abajo: girándolo se dobla la articulación.
static func make_part(part: String, texture: Texture2D, slim: bool, layer: int, on_top := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part
	pivot.position = Vector3(PARTS[part]["pivot"]) * PIXEL
	if slim and part.begins_with("arm"):
		pivot.position.x -= signf(pivot.position.x) * 0.5 * PIXEL
	var material := make_material(texture, on_top)

	if not is_limb(part):
		for overlay in [false, true]:
			pivot.add_child(_mesh_node(part_mesh(part, slim, overlay), material, layer, on_top))
		return pivot

	var size := part_size(part, slim)
	var top_y: float = Vector3(PARTS[part]["min"]).y + size.y
	var joint := Vector3(0, top_y - JOINT_ROW, 0)  # codo/rodilla, en px desde el pivote
	var lower := Node3D.new()
	lower.name = "lower"
	lower.position = joint * PIXEL
	pivot.add_child(lower)
	for overlay in [false, true]:
		# Segmento superior: baja un poco dentro del inferior y, en las piernas, sube dentro del
		# torso; así al doblar codos, rodillas o caderas no se ven rajas entre las piezas.
		var hip := HIP_OVERLAP if part.begins_with("leg") else 0.0
		pivot.add_child(_mesh_node(part_mesh(part, slim, overlay, Vector2i(0, JOINT_ROW),
			Vector3.ZERO, hip, JOINT_INSET if hip > 0.0 else 0.0, JOINT_UNDERLAP), material, layer, on_top))
		lower.add_child(_mesh_node(part_mesh(part, slim, overlay, Vector2i(JOINT_ROW, size.y),
			joint, JOINT_OVERLAP, JOINT_INSET * 2.0), material, layer, on_top))
	return pivot


static func _mesh_node(mesh: ArrayMesh, material: Material, layer: int, on_top: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.layers = layer
	if on_top:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
