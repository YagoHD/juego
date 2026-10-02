extends Node3D
class_name Clouds
## Nubes 3D de bloques (estilo voxel) que se desplazan con el viento.
## El campo de nubes es un "mosaico" de TILE metros generado con ruido que se repite sin
## costuras; se dibujan 3x3 copias alrededor de la cámara y se desplazan con el viento, así
## nunca se acaban.

const CELL := 12.0        # tamaño de cada bloque de nube (m)
const GRID := 160         # celdas por lado del mosaico (160 x 12 m = 1920 m)
const HEIGHT := 150.0     # altura de la capa de nubes (m); la cima de la isla está a ~112 m
const THICKNESS := 6.0    # grosor de las nubes (m)
const COVERAGE := 0.56    # umbral del ruido: más alto = menos nubes
const WIND := Vector2(2.5, 0.8)  # m/s

var _copies: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _offset := Vector2.ZERO


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/clouds.gdshader")
	var mesh := _build_mesh()
	for i in 9:
		var copy := MeshInstance3D.new()
		copy.mesh = mesh
		copy.material_override = _material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(copy)
		_copies.append(copy)


func set_color(color: Color) -> void:
	if _material != null:
		_material.set_shader_parameter("cloud_color", color)


func _process(delta: float) -> void:
	var tile := CELL * GRID
	_offset = Vector2(fposmod(_offset.x + WIND.x * delta, tile), fposmod(_offset.y + WIND.y * delta, tile))
	# Las copias siguen a la cámara a saltos de un mosaico (no se nota porque se repite igual).
	var camera := get_viewport().get_camera_3d()
	var center := Vector2.ZERO
	if camera != null:
		var p := camera.global_position
		center = Vector2(floorf(p.x / tile) * tile, floorf(p.z / tile) * tile)
	var i := 0
	for gz in range(-1, 2):
		for gx in range(-1, 2):
			var origin := center + Vector2(gx, gz) * tile + _offset - Vector2(tile, tile) * 0.5
			_copies[i].position = Vector3(origin.x, HEIGHT, origin.y)
			i += 1


# ------------------------------------------------------------------ malla

func _build_mesh() -> ArrayMesh:
	var filled := PackedByteArray()
	filled.resize(GRID * GRID)
	for z in GRID:
		for x in GRID:
			var v := _noise(x, z, 10, 1) * 0.7 + _noise(x, z, 4, 2) * 0.3
			filled[z * GRID + x] = 1 if v > COVERAGE else 0

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in GRID:
		for x in GRID:
			if filled[z * GRID + x] == 0:
				continue
			var x0 := x * CELL
			var z0 := z * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			var y0 := 0.0
			var y1 := THICKNESS
			_quad(vertices, normals, indices, Vector3.UP,
				Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))
			_quad(vertices, normals, indices, Vector3.DOWN,
				Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0))
			# Lados solo donde no hay nube vecina (el mosaico se repite: vecinos con posmod).
			if not _is_filled(filled, x + 1, z):
				_quad(vertices, normals, indices, Vector3.RIGHT,
					Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1))
			if not _is_filled(filled, x - 1, z):
				_quad(vertices, normals, indices, Vector3.LEFT,
					Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0))
			if not _is_filled(filled, x, z + 1):
				_quad(vertices, normals, indices, Vector3.BACK,
					Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1))
			if not _is_filled(filled, x, z - 1):
				_quad(vertices, normals, indices, Vector3.FORWARD,
					Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _is_filled(filled: PackedByteArray, x: int, z: int) -> bool:
	return filled[posmod(z, GRID) * GRID + posmod(x, GRID)] == 1


## Cara de 4 esquinas en orden horario visto desde fuera.
func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var start := vertices.size()
	vertices.append_array([a, b, c, d])
	normals.append_array([normal, normal, normal, normal])
	indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])


## Ruido de valor suave que se repite cada GRID celdas (para que el mosaico no tenga costuras).
func _noise(x: int, z: int, cell: int, salt: int) -> float:
	var n := GRID / cell
	var fx := float(x) / cell
	var fz := float(z) / cell
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := smoothstep(0.0, 1.0, fx - x0)
	var tz := smoothstep(0.0, 1.0, fz - z0)
	var a := _hash01(posmod(x0, n), posmod(z0, n), salt)
	var b := _hash01(posmod(x0 + 1, n), posmod(z0, n), salt)
	var c := _hash01(posmod(x0, n), posmod(z0 + 1, n), salt)
	var e := _hash01(posmod(x0 + 1, n), posmod(z0 + 1, n), salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, e, tx), tz)


func _hash01(x: int, z: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
