extends VoxelGeneratorScript
class_name BlockyTerrainGenerator
## Genera terreno de cubos por ruido: una capa de hierba, unas de tierra y piedra debajo.
## Escribe el ID del bloque en el canal TYPE del VoxelBuffer.

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3

const BASE_HEIGHT := 10      # altura media del terreno
const AMPLITUDE := 14.0      # cuánto suben/bajan las colinas
const DIRT_DEPTH := 3        # capas de tierra bajo la hierba

var _noise := FastNoiseLite.new()

func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.008

# Le dice al motor que este generador usa el canal TYPE (bloques), no SDF (terreno suave).
func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()
	for x in size.x:
		for z in size.z:
			var wx: int = origin_in_voxels.x + x
			var wz: int = origin_in_voxels.z + z
			var height: int = BASE_HEIGHT + int(roundf(_noise.get_noise_2d(wx, wz) * AMPLITUDE))
			for y in size.y:
				var wy: int = origin_in_voxels.y + y
				if wy >= height:
					continue  # aire (el buffer ya viene a 0)
				var block_id: int = STONE
				if wy == height - 1:
					block_id = GRASS
				elif wy >= height - 1 - DIRT_DEPTH:
					block_id = DIRT
				out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
