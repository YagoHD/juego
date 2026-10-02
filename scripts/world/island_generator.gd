extends VoxelGeneratorScript
class_name IslandGenerator
## Genera una isla grande de costa irregular rodeada de mar: fondo marino, playa de arena,
## praderas con colinas orgánicas, bosque de árboles y una montaña nevada desplazada.
## Trabaja en coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5
const WOOD := 6
const LEAVES := 7

# Alturas en voxels (el mundo va a la mitad por VOXEL_SIZE=0.5).
const OCEAN_FLOOR := 6
const SEA_LEVEL := 24          # nivel del mar (coincide con el plano de agua en main.gd)
const LAND_HEIGHT := 48.0
const SNOW_LINE := 78
const DIRT_DEPTH := 3

const ISLAND_RADIUS := 820.0   # radio base de la isla en voxels (~410 m)
const MOUNTAIN_CENTER := Vector2(260.0, -200.0)
const MOUNTAIN_RADIUS := 320.0
const MOUNTAIN_HEIGHT := 115.0

const TREE_DENSITY := 0.022    # probabilidad de árbol por columna de hierba
const TREE_MARGIN := 3         # columnas extra alrededor del chunk para no cortar copas

var _continent := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()

func _init() -> void:
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_continent.frequency = 0.0022
	_continent.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continent.fractal_octaves = 4

	_hills.noise_type = FastNoiseLite.TYPE_PERLIN
	_hills.frequency = 0.011
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4

	_detail.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail.frequency = 0.035

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _height_at(wx: int, wz: int) -> int:
	var dist: float = sqrt(float(wx * wx + wz * wz))
	var n: float = dist / ISLAND_RADIUS
	var falloff: float = clampf(1.0 - n, 0.0, 1.0)
	falloff = pow(falloff, 1.8)

	var cont: float = _continent.get_noise_2d(wx, wz) * 0.5 + 0.5
	var land_mask: float = clampf(falloff * (0.45 + 0.8 * cont), 0.0, 1.0)

	var height: float = OCEAN_FLOOR + land_mask * LAND_HEIGHT
	var land_amount: float = clampf(land_mask * 2.0, 0.0, 1.0)
	var hills: float = _hills.get_noise_2d(wx, wz) * 0.5 + 0.5
	height += hills * 16.0 * land_amount
	height += _detail.get_noise_2d(wx, wz) * 2.5 * land_amount

	var mdist: float = (Vector2(wx, wz) - MOUNTAIN_CENTER).length()
	var mcont: float = clampf(1.0 - mdist / MOUNTAIN_RADIUS, 0.0, 1.0)
	mcont = pow(mcont, 2.2)
	height += mcont * MOUNTAIN_HEIGHT

	return int(roundf(height))

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()

	# --- Terreno ---
	for x in size.x:
		for z in size.z:
			var wx: int = origin_in_voxels.x + x
			var wz: int = origin_in_voxels.z + z
			var height: int = _height_at(wx, wz)
			var is_beach: bool = height <= SEA_LEVEL + 1
			var is_peak: bool = height >= SNOW_LINE
			for y in size.y:
				var wy: int = origin_in_voxels.y + y
				if wy >= height:
					continue
				var block_id: int = STONE
				if wy == height - 1:
					block_id = SAND if is_beach else (SNOW if is_peak else GRASS)
				elif wy >= height - 1 - DIRT_DEPTH:
					block_id = SAND if is_beach else (STONE if is_peak else DIRT)
				out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)

	# --- Árboles (incluye margen para no cortar copas entre chunks) ---
	for lx in range(-TREE_MARGIN, size.x + TREE_MARGIN):
		for lz in range(-TREE_MARGIN, size.z + TREE_MARGIN):
			var wx: int = origin_in_voxels.x + lx
			var wz: int = origin_in_voxels.z + lz
			var base: int = _tree_base(wx, wz)
			if base >= 0:
				_stamp_tree(out_buffer, origin_in_voxels, size, wx, wz, base)

func _tree_base(wx: int, wz: int) -> int:
	# Devuelve la altura de la base del árbol, o -1 si no hay árbol aquí.
	var height: int = _height_at(wx, wz)
	if height <= SEA_LEVEL + 1 or height >= SNOW_LINE - 2:
		return -1  # ni en la playa ni en la nieve
	if _hash01(wx, wz) < TREE_DENSITY:
		return height
	return -1

func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int) -> void:
	var trunk_h: int = 4 + int(_hash01(wx * 7 + 1, wz * 7 + 3) * 3.0)  # 4..6
	# Tronco
	for i in trunk_h:
		_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
	# Copa (esfera de hojas en lo alto)
	var cy: int = base + trunk_h
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for dz in range(-2, 3):
				if dx * dx + dy * dy + dz * dz <= 5:
					_set_if_air(buffer, origin, size, wx + dx, cy + dy, wz + dz, LEAVES)

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
