class_name BoxModel
## Personaje de CAJAS con esqueleto (estilo Minecraft Dungeons), descrito en un .json que sale de
## una hoja de vistas de la guía (tools/modelo_desde_guia.py): huesos (cuello, mentón, cintura,
## hombros, codos, muñecas, caderas, rodillas, tobillos), cajas pegadas a cada hueso con su trozo
## de textura, párpados y rizos del pelo.
##
## make_part devuelve las mismas piezas que SkinModel.make_part (cabeza, torso, brazos y piernas,
## con "lower" en el codo o la rodilla), así PlayerAvatar las anima igual; además trae "lower/wrist"
## (muñeca), "lower/grip" (dónde se agarra), "lower/foot" (tobillo), "chest" (cintura) y "jaw".
##
## Unidades del .json: píxeles de 1/32 de la altura (SkinModel.PIXEL), los pies en y = 0, mirando
## hacia -Z y con la derecha del personaje en +X.

const DEFAULT := "res://assets/models/cajas/naufrago.json"

static var _cache := {}  # ruta -> {"data": Dictionary, "texture": Texture2D}


static func available(path := DEFAULT) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func _load(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var texture: Texture2D = load(path.get_base_dir().path_join(data["atlas"]))
	var entry := {"data": data, "texture": texture}
	_cache[path] = entry
	return entry


## Una parte del cuerpo ("head", "body", "arm_right"...) con sus huesos hijos, como nodos.
static func make_part(part: String, layer: int, on_top := false, path := DEFAULT) -> Node3D:
	var entry := _load(path)
	var data: Dictionary = entry["data"]
	var material := SkinModel.make_material(entry["texture"], on_top)
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var bones := {}
	for bone: Dictionary in data["bones"]:
		bones[bone["id"]] = bone
	var root := _bone_node(bones[part], Vector3.ZERO)
	_add_children(root, part, bones, data, material, layer, on_top)
	if part == "head":
		_add_lids(root, bones[part], data, layer)
		var hair := hair_mesh(data.get("hair", []))
		if hair != null:
			var hair_node := _mesh_node(hair, SkinModel.make_voxel_material(on_top), layer, on_top)
			hair_node.name = "hair"
			root.add_child(hair_node)
	return root


static func _bone_node(bone: Dictionary, parent_pivot: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = bone["name"]
	node.position = (_v(bone["pivot"]) - parent_pivot) * SkinModel.PIXEL
	return node


static func _add_children(node: Node3D, id: String, bones: Dictionary, data: Dictionary,
		material: Material, layer: int, on_top: bool) -> void:
	var pivot := _v(bones[id]["pivot"])
	var mesh := _boxes_mesh(data, id, pivot)
	if mesh != null:
		node.add_child(_mesh_node(mesh, material, layer, on_top))
	for bone: Dictionary in data["bones"]:
		if bone["parent"] == id:
			var child := _bone_node(bone, pivot)
			node.add_child(child)
			_add_children(child, bone["id"], bones, data, material, layer, on_top)


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Todas las cajas de un hueso en una malla (en metros, respecto a su pivote).
static func _boxes_mesh(data: Dictionary, bone_id: String, pivot: Vector3) -> ArrayMesh:
	var size := float(data["size"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for b: Dictionary in data["boxes"]:
		if b["bone"] != bone_id:
			continue
		var lo := (_v(b["from"]) - pivot) * SkinModel.PIXEL
		var hi := (_v(b["to"]) - pivot) * SkinModel.PIXEL
		_add_box(st, lo, hi, b["faces"], size)
		count += 1
	if count == 0:
		return null
	st.generate_tangents()
	return st.commit()


static func _add_box(st: SurfaceTool, lo: Vector3, hi: Vector3, faces: Dictionary, size: float) -> void:
	var x0 := lo.x
	var y0 := lo.y
	var z0 := lo.z
	var x1 := hi.x
	var y1 := hi.y
	var z1 := hi.z
	# Esquinas de cada cara (arriba-izq, arriba-der, abajo-der, abajo-izq vista desde fuera), en el
	# mismo orden en que tools/modelo_desde_guia.py coloca su dibujo. Delante = -Z; derecha = +X.
	var corners := {
		"front": [Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0)],
		"back": [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1)],
		"right": [Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1)],
		"left": [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0)],
		"top": [Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x1, y1, z0)],
		"bottom": [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x1, y0, z1)],
	}
	for face: String in corners:
		var c: Array = corners[face]
		var r: Array = faces[face]
		# Medio píxel hacia dentro: que el filtro no coja la casilla de al lado en el atlas.
		var u0 := (float(r[0]) + 0.02) / size
		var v0 := (float(r[1]) + 0.02) / size
		var u1 := (float(r[0]) + float(r[2]) - 0.02) / size
		var v1 := (float(r[1]) + float(r[3]) - 0.02) / size
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
		var normal: Vector3 = ((c[1] - c[0]) as Vector3).cross(c[2] - c[0]).normalized() * -1.0
		st.set_normal(normal)
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(c[k])


static func _add_lids(head: Node3D, bone: Dictionary, data: Dictionary, layer: int) -> void:
	var lids := Node3D.new()
	lids.name = "lids"
	lids.visible = false
	head.add_child(lids)
	var material := StandardMaterial3D.new()
	var c: Array = data.get("lid_color", [250, 172, 108])
	material.albedo_color = Color8(int(c[0]), int(c[1]), int(c[2]))
	material.roughness = 0.9
	var pivot := _v(bone["pivot"])
	for lid: Dictionary in data.get("lids", []):
		var lo := _v(lid["from"])
		var hi := _v(lid["to"])
		var quad := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = (hi - lo).abs() * SkinModel.PIXEL
		quad.mesh = mesh
		quad.position = ((lo + hi) * 0.5 - pivot) * SkinModel.PIXEL
		quad.material_override = material
		quad.layers = layer
		lids.add_child(quad)


## Rizos del pelo: cada uno un cubo de su tamaño y tono, en px desde el cuello. Arriba más claros
## y abajo más oscuros, para que se lea el volumen.
static func hair_mesh(curls: Array) -> ArrayMesh:
	if curls.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for curl: Array in curls:
		var center := Vector3(float(curl[0]), float(curl[1]), float(curl[2])) * SkinModel.PIXEL
		var half := float(curl[3]) * 0.5 * SkinModel.PIXEL
		var color := Color.html(curl[4])
		for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
			var shade := 1.12 if n == Vector3.UP else (0.72 if n == Vector3.DOWN else 0.9)
			var u := Vector3(n.y, n.z, n.x).abs()
			var v := n.cross(u)
			var o := center + n * half
			var a := o + (-u - v) * half
			var b := o + (u - v) * half
			var c := o + (u + v) * half
			var d := o + (-u + v) * half
			st.set_color(Color(minf(color.r * shade, 1.0), minf(color.g * shade, 1.0), minf(color.b * shade, 1.0)))
			st.set_normal(n)
			var quad := [a, d, c, a, c, b] if u.cross(v).dot(n) > 0.0 else [a, b, c, a, c, d]
			for p: Vector3 in quad:
				st.add_vertex(p)
	return st.commit()


static func _mesh_node(mesh: ArrayMesh, material: Material, layer: int, on_top: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.layers = layer
	if on_top:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
