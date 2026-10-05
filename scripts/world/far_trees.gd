extends Node3D
class_name FarTrees
## Árboles sencillos para lo lejos: más allá de la zona de detalle, cada árbol de la isla se dibuja
## con un modelo de pocas cajas (copa redonda, pino, árbol seco o arbusto) con los colores de la
## hoja de árboles del concepto, en el mismo sitio que el árbol de verdad. Se dibujan miles con
## una sola orden a la tarjeta gráfica (MultiMesh). Dentro de la zona de detalle se esconden: ahí
## están los árboles completos. Dónde va cada uno se calcula en otro hilo, para no frenar la carga.

# Los verdes de los árboles de cerca (TreeBuilder), algo apagados: allí las copas tienen sombras
# entre los racimos y aquí no. Así casan al pasar de unos a otros.
const LEAF := Color(0.25, 0.47, 0.15)
const LEAF_DARK := Color(0.14, 0.33, 0.11)
const LEAF_LIGHT := Color(0.37, 0.58, 0.17)
const PINE := Color(0.13, 0.40, 0.19)
const BARK := Color(0.50, 0.31, 0.15)
const DEAD := Color(0.56, 0.52, 0.56)

var _gen: IslandGenerator
var _voxel := 0.5
var _hide := 120.0
var _thread: Thread
var _found := {}          # modelo -> Array de [posición, escala, giro, tono]


func start(gen: IslandGenerator, voxel_size: float, hide_radius: float) -> void:
	_gen = gen
	_voxel = voxel_size
	_hide = hide_radius
	add_to_group("graphics")
	visible = Settings.far_trees
	_thread = Thread.new()
	_thread.start(_scan)


func apply_graphics() -> void:
	visible = Settings.far_trees


## (En otro hilo) Recorre la isla y apunta cada árbol con el modelo que le toca.
func _scan() -> void:
	var half := int(IslandGenerator.MAP_HALF)
	var found := {"broad": [], "pine": [], "dead": [], "bush": []}
	for wx in range(-half, half):
		for wz in range(-half, half):
			var kind := _gen._tree_kind(wx, wz)
			if kind == 0:
				continue
			var name: String = PrefabLibrary.NAMES[_gen._tree_prefab(wx, wz, kind)]
			var model := "broad"
			var size := 1.0
			if name.begins_with("t_pine"):
				model = "pine"
				size = 0.6 if name.begins_with("t_pine_small") else 1.0
			elif name.begins_with("t_dead"):
				model = "dead"
			elif name.begins_with("t_bush") or name.begins_with("t_berry"):
				model = "bush"
				size = 1.3 if name.begins_with("t_berry") else 1.0
			elif not name.begins_with("t_giant"):
				size = 0.85  # roble e inclinado (el modelo es del tamaño de un gigante pequeño)
			else:
				size = 1.7
			var base := _gen._height_at(wx, wz)
			var pos := Vector3((wx + 0.5) * _voxel, base * _voxel, (wz + 0.5) * _voxel)
			var r := _gen._hash01(wx * 31 + 5, wz * 17 + 3)
			found[model].append([pos, size * (0.9 + r * 0.2), r * TAU, 0.9 + r * 0.2])
	_found = found
	call_deferred("_build")


func _build() -> void:
	_thread.wait_to_finish()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/far_trees.gdshader")
	material.set_shader_parameter("hide_radius", _hide)
	for model: String in _found:
		var list: Array = _found[model]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh(model)
		mm.instance_count = list.size()
		for i in list.size():
			var e: Array = list[i]
			var t := Transform3D(Basis(Vector3.UP, e[2]).scaled(Vector3.ONE * float(e[1])), e[0])
			mm.set_instance_transform(i, t)
			var k: float = e[3]
			mm.set_instance_color(i, Color(k, k, k))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = material
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # tan lejos, sin sombra
		add_child(inst)
	print("[árboles lejanos] ", _found.keys().map(func(k: String) -> String: return "%s %d" % [k, (_found[k] as Array).size()]))
	_found.clear()


## Modelo sencillo (en metros, el pie en el origen) con colores por vértice.
func _mesh(model: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match model:
		"broad":  # copa redonda: un bulto grande, uno arriba y cuatro alrededor, en tres tonos
			_box(st, Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45), BARK)
			_box(st, Vector3(0, 2.9, 0), Vector3(2.8, 1.8, 2.8), LEAF)
			_box(st, Vector3(0.2, 3.9, -0.1), Vector3(2.0, 1.0, 2.0), LEAF_LIGHT)
			_box(st, Vector3(1.3, 2.7, 0.3), Vector3(1.3, 1.3, 1.6), LEAF_DARK)
			_box(st, Vector3(-1.3, 2.9, -0.2), Vector3(1.3, 1.4, 1.7), LEAF)
			_box(st, Vector3(0.2, 2.6, 1.3), Vector3(1.7, 1.2, 1.3), LEAF_DARK)
			_box(st, Vector3(-0.3, 3.1, -1.3), Vector3(1.6, 1.3, 1.3), LEAF_LIGHT)
		"pine":  # tres pisos que se estrechan
			_box(st, Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), BARK)
			_box(st, Vector3(0, 1.7, 0), Vector3(3.0, 1.2, 3.0), PINE)
			_box(st, Vector3(0, 2.9, 0), Vector3(2.1, 1.2, 2.1), PINE.lightened(0.06))
			_box(st, Vector3(0, 4.0, 0), Vector3(1.1, 1.3, 1.1), PINE.lightened(0.12))
		"dead":  # tronco seco con dos ramas
			_box(st, Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 0.4), DEAD)
			_box(st, Vector3(0.5, 2.5, 0), Vector3(1.0, 0.18, 0.18), DEAD)
			_box(st, Vector3(-0.3, 2.9, 0.3), Vector3(0.18, 0.18, 0.8), DEAD)
		"bush":
			_box(st, Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 2.0), LEAF)
	st.index()
	return st.commit()


## Caja con la cara de arriba más clara y la de abajo más oscura (luz pintada, como el concepto).
func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, 1.0, [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
		[Vector3.DOWN, 0.6, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
		[Vector3.BACK, 0.85, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3.FORWARD, 0.8, [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
		[Vector3.RIGHT, 0.75, [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
		[Vector3.LEFT, 0.7, [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
	]
	for f in faces:
		var c: Color = color * float(f[1])
		c.a = 1.0
		var corners: Array = f[2]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_color(c)
			st.set_normal(f[0])
			st.add_vertex(center + (corners[i] as Vector3) * h)
