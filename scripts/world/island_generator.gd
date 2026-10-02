extends VoxelGeneratorScript
class_name IslandGenerator
## Genera la isla a partir de un MAPA DE ALTURAS (res://assets/island/heightmap.png):
## la imagen define la forma (isla, montaña, bahía, tierras altas) y aquí se le añade
## ruido fino y biomas (arena/hierba/bosque/roca/nieve). Centrado en (0,0) en voxels.

# IDs de bloque (el índice debe coincidir con la librería en main.gd).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5
const WOOD := 6
const LEAVES := 7

const HEIGHTMAP_PATH := "res://assets/island/heightmap.png"

# Alturas en voxels (el mundo va a la mitad por VOXEL_SIZE=0.5).
const OCEAN_FLOOR := 6
const SEA_LEVEL := 24
const PEAK := 170             # altura del punto más alto (gris 255 del mapa)
const SNOW_LINE := 92
const DIRT_DEPTH := 3

# La imagen cubre el mundo en voxels [-MAP_HALF, MAP_HALF] en X y Z.
const MAP_HALF := 860.0

const TREE_DENSITY := 0.022
const TREE_MARGIN := 3

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()

var _hmap: Image
var _hmap_w := 0
var _hmap_h := 0

func _init() -> void:
	_hills.noise_type = FastNoiseLite.TYPE_PERLIN
	_hills.frequency = 0.011
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4

	_detail.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail.frequency = 0.035

	_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain.frequency = 0.016
	_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain.fractal_octaves = 4

	var tex := load(HEIGHTMAP_PATH) as Texture2D
	if tex != null:
		_hmap = tex.get_image()
		if _hmap != null:
			if _hmap.is_compressed():
				_hmap.decompress()
			_hmap_w = _hmap.get_width()
			_hmap_h = _hmap.get_height()
	if _hmap == null:
		push_error("No se pudo cargar el mapa de alturas: " + HEIGHTMAP_PATH)

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _sample_height01(wx: int, wz: int) -> float:
	if _hmap == null:
		return 0.0
	var u: float = (float(wx) + MAP_HALF) / (2.0 * MAP_HALF)
	var v: float = (float(wz) + MAP_HALF) / (2.0 * MAP_HALF)
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return 0.0  # fuera del mapa = mar
	var fx: float = u * float(_hmap_w - 1)
	var fy: float = v * float(_hmap_h - 1)
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var x1: int = mini(x0 + 1, _hmap_w - 1)
	var y1: int = mini(y0 + 1, _hmap_h - 1)
	var tx: float = fx - x0
	var ty: float = fy - y0
	var c00: float = _hmap.get_pixel(x0, y0).r
	var c10: float = _hmap.get_pixel(x1, y0).r
	var c01: float = _hmap.get_pixel(x0, y1).r
	var c11: float = _hmap.get_pixel(x1, y1).r
	return lerpf(lerpf(c00, c10, tx), lerpf(c01, c11, tx), ty)

func _height_at(wx: int, wz: int) -> int:
	var g: float = _sample_height01(wx, wz)
	var height: float = OCEAN_FLOOR + g * float(PEAK - OCEAN_FLOOR)

	var land: float = clampf((g - 0.11) / 0.12, 0.0, 1.0)  # 0 en la costa, 1 tierra adentro
	height += (_hills.get_noise_2d(wx, wz) * 0.5 + 0.5) * 12.0 * land
	height += _detail.get_noise_2d(wx, wz) * 2.0 * land

	# Crestas y riscos solo en las zonas altas (la montaña del mapa).
	var high: float = clampf((g - 0.62) / 0.38, 0.0, 1.0)
	var ridge: float = clampf(_mountain.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)
	height += high * ridge * 26.0

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
			var is_snow: bool = height >= SNOW_LINE
			var is_rock: bool = height >= SNOW_LINE - 18
			for y in size.y:
				var wy: int = origin_in_voxels.y + y
				if wy >= height:
					continue
				var block_id: int = STONE
				if wy == height - 1:
					if is_beach:
						block_id = SAND
					elif is_snow:
						block_id = SNOW
					elif is_rock:
						block_id = STONE
					else:
						block_id = GRASS
				elif wy >= height - 1 - DIRT_DEPTH:
					if is_beach:
						block_id = SAND
					elif is_rock:
						block_id = STONE
					else:
						block_id = DIRT
				out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)

	# --- Árboles (con margen para no cortar copas entre chunks) ---
	for lx in range(-TREE_MARGIN, size.x + TREE_MARGIN):
		for lz in range(-TREE_MARGIN, size.z + TREE_MARGIN):
			var wx: int = origin_in_voxels.x + lx
			var wz: int = origin_in_voxels.z + lz
			var base: int = _tree_base(wx, wz)
			if base >= 0:
				_stamp_tree(out_buffer, origin_in_voxels, size, wx, wz, base)

func _tree_base(wx: int, wz: int) -> int:
	var height: int = _height_at(wx, wz)
	if height <= SEA_LEVEL + 1 or height >= SNOW_LINE - 18:
		return -1
	if _hash01(wx, wz) < TREE_DENSITY:
		return height
	return -1

func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int) -> void:
	var trunk_h: int = 4 + int(_hash01(wx * 7 + 1, wz * 7 + 3) * 3.0)
	for i in trunk_h:
		_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
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
