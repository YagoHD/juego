extends IslandGenerator
class_name TreeGenerator
## Generador del terreno de los árboles detallados (ver WorldVoxels): solo pone los árboles
## (TreeBuilder) donde nacen en la isla; el suelo, las rocas, las palmeras... van en el terreno
## principal. Este terreno tiene menos distancia de detalle: más allá, FarTrees.


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()
	var span := _chunk_height_range(origin, size)
	if origin.y > span.y + MAX_TREE_HEIGHT + 4 or origin.y + size.y <= span.x:
		return  # muy alto o bajo tierra: ahí no hay árboles
	for lx in range(-_margin, size.x + _margin):
		for lz in range(-_margin, size.z + _margin):
			var wx := origin.x + lx
			var wz := origin.z + lz
			var kind := _tree_kind(wx, wz)
			if kind == 0:
				continue
			var base := tree_base(wx, wz)
			if base + MAX_TREE_HEIGHT < origin.y or base > origin.y + size.y:
				continue
			for piece in PrefabLibrary.pieces(_tree_prefab(wx, wz, kind)):
				var c: Vector3i = piece[0]
				var cell := Vector3i(wx + c.x, base + c.y, wz + c.z)
				if c.y < 6 and cell.y < _height_at(cell.x, cell.z):
					continue  # raíz o rama metida en una cuesta: ahí manda el suelo
				_set_if_air(out_buffer, origin, size, cell.x, cell.y, cell.z, piece[1])
