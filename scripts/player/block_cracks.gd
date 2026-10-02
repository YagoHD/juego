extends MeshInstance3D
class_name BlockCracks
## Grietas sobre el bloque que se está rompiendo: un cubo un pelín más grande que el bloque, con
## una textura de grietas que crece en 6 etapas según el avance (0..1).

const STAGES := 6
const S := 16

var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _cube()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var branches := _branches(rng)
	for stage in STAGES:
		var material := StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(_crack_image(branches, stage + 1))
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials.append(material)


## Muestra las grietas en el bloque cuya esquina es 'corner' (mundo) de lado 'size'.
func show_on(corner: Vector3, size: float, progress: float) -> void:
	if progress <= 0.0:
		visible = false
		return
	var grow := 0.006
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * (size + grow * 2.0)), corner - Vector3.ONE * grow)
	material_override = _materials[clampi(int(progress * STAGES), 0, STAGES - 1)]
	visible = true


## Ramas de grieta: segmentos que salen del centro y se van partiendo (las mismas en cada etapa,
## cada etapa dibuja más).
func _branches(rng: RandomNumberGenerator) -> Array:
	var out := []
	for b in 7:
		var p := Vector2(7.5, 7.5) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var path: Array[Vector2i] = []
		for step in 10:
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir
			path.append(Vector2i(clampi(roundi(p.x), 0, S - 1), clampi(roundi(p.y), 0, S - 1)))
		out.append(path)
	return out


func _crack_image(branches: Array, stage: int) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.06, 0.05, 0.04, 0.8)
	var count := mini(branches.size(), 1 + stage)
	var reach := 2 + stage * 2  # largo de cada rama según la etapa
	for b in count:
		var path: Array = branches[b]
		for i in mini(reach, path.size()):
			var c: Vector2i = path[i]
			img.set_pixelv(c, ink)
	return img


## Cubo de 1x1x1 (esquina en el origen) con la textura entera en cada cara.
func _cube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
		[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)],
		[Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
		[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for v in faces:
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_uv(uvs[i])
			st.add_vertex(v[i])
	return st.commit()
