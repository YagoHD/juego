extends VoxelGeneratorScript
class_name IslandGenerator
## Genera la isla a partir de los mapas horneados por tools/island_baker:
##   height.png  -> altura del suelo (16 bits)
##   water.png   -> nivel de ríos/lagos (16 bits, 0 = sin agua)
##   surface.png -> bloque de superficie (R), de subsuelo (G) y árbol (B)
## Todas las decisiones caras (bioma, pendiente, nieve, densidad de árboles) ya vienen hechas
## en los mapas: aquí solo se consultan, para que la isla se genere rápido.
## Coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd y con IslandBaker.cs).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5
const WOOD := 6
const LEAVES := 7
const WATER := 8
const PINE_LEAVES := 9
const CORRUPT_SOIL := 10
const DEAD_WOOD := 11
const WHEAT := 12

const MAP_DIR := "res://assets/island/"
const MAP_HALF := 1024.0      # los mapas cubren [-MAP_HALF, MAP_HALF] voxels en X y Z
const OCEAN_FLOOR := 4.0
const SEA_LEVEL := 24         # coincide con el plano de mar en main.gd y con el horneador
const DIRT_DEPTH := 3
const TREE_MARGIN := 4        # columnas extra alrededor del chunk para no cortar copas
const MAX_TREE_HEIGHT := 16
const MAX_TREE_DENSITY := 0.063  # la densidad del mapa va en milésimas (máx. 63)

var _n := 0
var _h := PackedFloat32Array()
var _w := PackedFloat32Array()
var _surface := PackedByteArray()  # RGB por píxel: superficie, subsuelo, árbol
var _voxels_per_px := 2.0


func _init() -> void:
	_h = _load_16bit(MAP_DIR + "height.png")
	_w = _load_16bit(MAP_DIR + "water.png")
	var surface_img := _load_image(MAP_DIR + "surface.png")
	if surface_img != null:
		_surface = surface_img.get_data()
	if _n > 1:
		_voxels_per_px = 2.0 * MAP_HALF / float(_n - 1)


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


# ------------------------------------------------------------------ carga de mapas

func _load_image(path: String) -> Image:
	# Los mapas se importan como "Image" (sin compresión, ver sus .import): así se leen
	# igual en el editor que en el juego exportado, con los valores exactos.
	var img := load(path) as Image
	if img == null:
		push_error("No se pudo cargar el mapa: " + path)
		return null
	img = img.duplicate() as Image  # el recurso importado es compartido: no lo modificamos
	img.convert(Image.FORMAT_RGB8)
	if _n == 0:
		_n = img.get_width()
	return img


func _load_16bit(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var img := _load_image(path)
	if img == null:
		return out
	var data := img.get_data()
	var count := img.get_width() * img.get_height()
	out.resize(count)
	for i in count:
		out[i] = float(data[i * 3] * 256 + data[i * 3 + 1]) / 64.0
	return out


# ------------------------------------------------------------------ muestreo

func _to_px(w: int) -> float:
	return (float(w) + MAP_HALF) / _voxels_per_px


func _index(wx: int, wz: int) -> int:
	# Índice del píxel más cercano, o -1 si está fuera del mapa.
	var px := int(roundf(_to_px(wx)))
	var pz := int(roundf(_to_px(wz)))
	if px < 0 or pz < 0 or px >= _n or pz >= _n:
		return -1
	return pz * _n + px


func _height_at(wx: int, wz: int) -> int:
	if _h.is_empty():
		return int(OCEAN_FLOOR)
	var fx := _to_px(wx)
	var fz := _to_px(wz)
	if fx < 0.0 or fz < 0.0 or fx > float(_n - 1) or fz > float(_n - 1):
		return int(OCEAN_FLOOR)
	var x0 := floori(fx)
	var z0 := floori(fz)
	var x1 := mini(x0 + 1, _n - 1)
	var z1 := mini(z0 + 1, _n - 1)
	var tx := fx - x0
	var tz := fz - z0
	var a := lerpf(_h[z0 * _n + x0], _h[z0 * _n + x1], tx)
	var b := lerpf(_h[z1 * _n + x0], _h[z1 * _n + x1], tx)
	return int(roundf(lerpf(a, b, tz)))


func _chunk_height_range(origin: Vector3i, size: Vector3i) -> Vector2i:
	# Altura mínima del suelo y máxima (suelo o agua) bajo el bloque, leyendo el mapa en bruto.
	# Incluye el margen de los árboles vecinos. Mucho más barato que muestrear cada columna.
	var p0x := floori(_to_px(origin.x - TREE_MARGIN)) - 1
	var p1x := ceili(_to_px(origin.x + size.x + TREE_MARGIN)) + 1
	var p0z := floori(_to_px(origin.z - TREE_MARGIN)) - 1
	var p1z := ceili(_to_px(origin.z + size.z + TREE_MARGIN)) + 1
	var lo := INF
	var hi := -INF
	if _h.is_empty() or p0x < 0 or p0z < 0 or p1x >= _n or p1z >= _n:
		lo = OCEAN_FLOOR  # toca el borde del mapa: allí es fondo marino
		hi = OCEAN_FLOOR
	for pz in range(maxi(p0z, 0), mini(p1z, _n - 1) + 1):
		for px in range(maxi(p0x, 0), mini(p1x, _n - 1) + 1):
			var i := pz * _n + px
			lo = minf(lo, _h[i])
			hi = maxf(hi, maxf(_h[i], _w[i]))
	return Vector2i(floori(lo), ceili(hi))


# ------------------------------------------------------------------ generación

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()

	# --- 1. Salidas rápidas: la mayoría de bloques son aire puro o roca maciza.
	var span := _chunk_height_range(origin_in_voxels, size)
	if origin_in_voxels.y > span.y + MAX_TREE_HEIGHT + 4:
		return  # todo aire (el buffer ya viene vacío)
	if origin_in_voxels.y + size.y <= span.x - DIRT_DEPTH - 2:
		out_buffer.fill(STONE, VoxelBuffer.CHANNEL_TYPE)  # todo roca, de una vez
		return

	# --- 2. Terreno y agua: cada columna se rellena por tramos, no voxel a voxel.
	for x in size.x:
		for z in size.z:
			var wx: int = origin_in_voxels.x + x
			var wz: int = origin_in_voxels.z + z
			var height := _height_at(wx, wz)
			var i := _index(wx, wz)
			var top := SAND
			var sub := SAND
			var water_top := 0
			if i >= 0:
				top = _surface[i * 3]
				sub = _surface[i * 3 + 1]
				water_top = int(roundf(_w[i]))
			var sub_start := height - 1 - DIRT_DEPTH
			_fill_run(out_buffer, origin_in_voxels, size, x, z, STONE, origin_in_voxels.y, sub_start)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, sub, sub_start, height - 1)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, top, height - 1, height)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, WATER, height, water_top)

	# --- 3. Árboles (con margen para no cortar copas entre chunks).
	for lx in range(-TREE_MARGIN, size.x + TREE_MARGIN):
		for lz in range(-TREE_MARGIN, size.z + TREE_MARGIN):
			var wx: int = origin_in_voxels.x + lx
			var wz: int = origin_in_voxels.z + lz
			var kind := _tree_kind(wx, wz)
			if kind == 0:
				continue
			var base := _height_at(wx, wz)
			if base + MAX_TREE_HEIGHT < origin_in_voxels.y or base > origin_in_voxels.y + size.y:
				continue  # el árbol no toca este bloque
			_stamp_tree(out_buffer, origin_in_voxels, size, wx, wz, base, kind)


func _fill_run(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, x: int, z: int, id: int, from_y: int, to_y: int) -> void:
	# Rellena la columna (x, z) con 'id' entre las alturas [from_y, to_y) del mundo.
	if id == AIR:
		return
	var a := maxi(from_y - origin.y, 0)
	var b := mini(to_y - origin.y, size.y)
	if b > a:
		buffer.fill_area(id, Vector3i(x, a, z), Vector3i(x + 1, b, z + 1), VoxelBuffer.CHANNEL_TYPE)


# Tipos de árbol: 0 ninguno, 1 frondoso, 2 pino, 3 muerto.
func _tree_kind(wx: int, wz: int) -> int:
	var roll := _hash01(wx, wz)
	if roll >= MAX_TREE_DENSITY:
		return 0  # descarte barato antes de mirar el mapa
	var i := _index(wx, wz)
	if i < 0:
		return 0
	var code: int = _surface[i * 3 + 2]
	if roll >= float(code & 63) / 1000.0:
		return 0
	return code >> 6


func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int, kind: int) -> void:
	var r := _hash01(wx * 7 + 1, wz * 7 + 3)
	match kind:
		1:  # Frondoso: tronco y copa redonda (a veces grande).
			var trunk_h := 4 + int(r * 3.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
			var radius2 := 9 if r > 0.75 else 5
			var reach := 3 if radius2 > 5 else 2
			var cy := base + trunk_h
			for dx in range(-reach, reach + 1):
				for dy in range(-reach, reach + 1):
					for dz in range(-reach, reach + 1):
						if dx * dx + dy * dy + dz * dz <= radius2:
							_set_if_air(buffer, origin, size, wx + dx, cy + dy, wz + dz, LEAVES)
		2:  # Pino: tronco alto y copa cónica por pisos.
			var trunk_h := 7 + int(r * 4.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
			var top := base + trunk_h + 1
			for y in range(base + 3, top + 1):
				var radius := mini(int(roundf(float(top - y) * 0.42)), 3)
				for dx in range(-radius, radius + 1):
					for dz in range(-radius, radius + 1):
						if dx * dx + dz * dz <= radius * radius + 1:
							_set_if_air(buffer, origin, size, wx + dx, y, wz + dz, PINE_LEAVES)
		3:  # Muerto: tronco seco con un par de ramas.
			var trunk_h := 4 + int(r * 4.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, DEAD_WOOD)
			_set_if_air(buffer, origin, size, wx + 1, base + trunk_h - 2, wz, DEAD_WOOD)
			_set_if_air(buffer, origin, size, wx - 1, base + trunk_h - 1, wz + 1, DEAD_WOOD)


func _set_if_air(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wy: int, wz: int, id: int) -> void:
	var lx: int = wx - origin.x
	var ly: int = wy - origin.y
	var lz: int = wz - origin.z
	if lx < 0 or ly < 0 or lz < 0 or lx >= size.x or ly >= size.y or lz >= size.z:
		return
	if buffer.get_voxel(lx, ly, lz, VoxelBuffer.CHANNEL_TYPE) == AIR:
		buffer.set_voxel(id, lx, ly, lz, VoxelBuffer.CHANNEL_TYPE)


func _hash01(x: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0x7fffffff) / float(0x7fffffff)


## Acceso de solo lectura a los mapas (lo usa la malla lejana, FarTerrain).
func get_map_size() -> int:
	return _n

func get_voxels_per_px() -> float:
	return _voxels_per_px

func get_height_map() -> PackedFloat32Array:
	return _h

func get_water_map() -> PackedFloat32Array:
	return _w

func get_surface_map() -> PackedByteArray:
	return _surface


## Altura del suelo en coordenadas de voxel (para colocar al jugador al aparecer).
func get_ground_height(wx: int, wz: int) -> int:
	var i := _index(wx, wz)
	var water_top := int(roundf(_w[i])) if i >= 0 else 0
	return maxi(_height_at(wx, wz), water_top)
