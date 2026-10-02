extends VoxelGeneratorScript
class_name IslandGenerator
## Genera una isla finita, grande y de costa irregular, rodeada de mar: fondo marino,
## playa de arena, praderas con colinas orgánicas y una montaña nevada desplazada.
## Trabaja en coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5

# Alturas en voxels (el mundo va a la mitad por VOXEL_SIZE=0.5).
const OCEAN_FLOOR := 6         # fondo marino lejos de la isla
const SEA_LEVEL := 24          # nivel del mar (coincide con el plano de agua en main.gd)
const LAND_HEIGHT := 46.0      # elevación máxima de la tierra (sin contar la montaña)
const SNOW_LINE := 72          # a partir de esta altura, nieve
const DIRT_DEPTH := 3          # capas de tierra bajo la hierba

const ISLAND_RADIUS := 440.0   # radio base de la isla en voxels (~220 m)
const MOUNTAIN_CENTER := Vector2(150.0, -110.0)
const MOUNTAIN_RADIUS := 200.0
const MOUNTAIN_HEIGHT := 80.0

var _continent := FastNoiseLite.new()  # grandes formas y costa irregular
var _hills := FastNoiseLite.new()      # colinas medianas (fractal)
var _detail := FastNoiseLite.new()     # detalle fino

func _init() -> void:
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_continent.frequency = 0.0035
	_continent.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continent.fractal_octaves = 3

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
	falloff = pow(falloff, 1.8)  # interior llano, caída más marcada hacia la costa

	# Máscara de tierra irregular: el ruido de continente deforma la costa.
	var cont: float = _continent.get_noise_2d(wx, wz) * 0.5 + 0.5  # 0..1
	var land_mask: float = falloff * (0.45 + 0.8 * cont)
	land_mask = clampf(land_mask, 0.0, 1.0)

	var height: float = OCEAN_FLOOR + land_mask * LAND_HEIGHT

	# Colinas y detalle, más fuertes donde hay tierra firme.
	var land_amount: float = clampf(land_mask * 2.0, 0.0, 1.0)
	var hills: float = _hills.get_noise_2d(wx, wz) * 0.5 + 0.5
	height += hills * 16.0 * land_amount
	height += _detail.get_noise_2d(wx, wz) * 2.5 * land_amount

	# Montaña nevada desplazada.
	var mdist: float = (Vector2(wx, wz) - MOUNTAIN_CENTER).length()
	var mcont: float = clampf(1.0 - mdist / MOUNTAIN_RADIUS, 0.0, 1.0)
	mcont = pow(mcont, 2.2)
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
					if is_beach:
						block_id = SAND
					elif is_peak:
						block_id = SNOW
					else:
						block_id = GRASS
				elif wy >= height - 1 - DIRT_DEPTH:
					if is_beach:
						block_id = SAND
					elif is_peak:
						block_id = STONE
					else:
						block_id = DIRT
				out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
