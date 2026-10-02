extends VoxelGeneratorScript
class_name IslandGenerator
## Genera una isla finita rodeada de mar: fondo marino, playa de arena, praderas de hierba,
## y una montaña nevada desplazada del centro. Trabaja en coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5

# Alturas en voxels (el mundo va a la mitad por VOXEL_SIZE=0.5).
const OCEAN_FLOOR := 10       # fondo marino lejos de la isla
const SEA_LEVEL := 24         # nivel del mar (debe coincidir con el plano de agua en main.gd)
const LAND_HEIGHT := 40.0     # cuánto se eleva la tierra sobre el fondo en el centro
const SNOW_LINE := 70         # a partir de esta altura, nieve
const DIRT_DEPTH := 3         # capas de tierra bajo la hierba

const ISLAND_RADIUS := 260.0  # radio de la isla en voxels
const MOUNTAIN_CENTER := Vector2(90.0, -60.0)
const MOUNTAIN_RADIUS := 120.0
const MOUNTAIN_HEIGHT := 75.0

var _hills := FastNoiseLite.new()

func _init() -> void:
	_hills.noise_type = FastNoiseLite.TYPE_PERLIN
	_hills.frequency = 0.012

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _height_at(wx: int, wz: int) -> int:
	# Forma de continente: alto en el centro, se hunde bajo el mar en los bordes.
	var dist: float = sqrt(float(wx * wx + wz * wz))
	var cont: float = clampf(1.0 - dist / ISLAND_RADIUS, 0.0, 1.0)
	cont = smoothstep(0.0, 1.0, cont)

	var height: float = OCEAN_FLOOR + cont * LAND_HEIGHT
	height += _hills.get_noise_2d(wx, wz) * 10.0 * cont  # colinas solo en tierra

	# Montaña desplazada.
	var mdist: float = (Vector2(wx, wz) - MOUNTAIN_CENTER).length()
	var mcont: float = clampf(1.0 - mdist / MOUNTAIN_RADIUS, 0.0, 1.0)
	mcont = mcont * mcont
	height += mcont * MOUNTAIN_HEIGHT

	return int(roundf(height))

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()
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
					continue  # aire
				var block_id: int = STONE
				if wy == height - 1:
					# Capa superior según bioma.
					if is_beach:
						block_id = SAND
					elif is_peak:
						block_id = SNOW
					else:
						block_id = GRASS
				elif wy >= height - 1 - DIRT_DEPTH:
					# Subsuelo.
					if is_beach:
						block_id = SAND
					elif is_peak:
						block_id = STONE
					else:
						block_id = DIRT
				out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
