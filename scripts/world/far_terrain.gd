extends MeshInstance3D
class_name FarTerrain
## La isla entera vista de lejos: una sola malla simplificada (una celda cada STEP píxeles del
## mapa) con los mismos colores que los bloques. El bosque se dibuja como un manto de copas.
## Cerca del jugador el shader la recorta, porque ahí ya están los voxels de verdad.

const STEP := 4                # píxeles del mapa por celda (4 px = 8 voxels = 4 m)
const CANOPY_VOXELS := 7.0     # altura del manto de copas sobre el suelo
const CANOPY_MIN_DENSITY := 20 # densidad de árboles (milésimas) para dibujar copas
const SINK := 0.3              # se hunde un poco para no asomar entre los voxels cercanos


func build(gen: IslandGenerator, block_colors: Dictionary, voxel_size: float, hide_radius: float) -> void:
	var n := gen.get_map_size()
	var vpp := gen.get_voxels_per_px()
	var heights := gen.get_height_map()
	var water := gen.get_water_map()
	var surface := gen.get_surface_map()
	if n == 0:
		return

	@warning_ignore("integer_division")
	var cells := (n - 1) / STEP
	var side := cells + 1
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	vertices.resize(side * side)
	colors.resize(side * side)
	normals.resize(side * side)

	var leaves: Color = block_colors[IslandGenerator.LEAVES]
	var pine: Color = block_colors[IslandGenerator.PINE_LEAVES]
	var water_color: Color = block_colors[IslandGenerator.WATER]
	water_color.a = 1.0

	for gz in side:
		for gx in side:
			var px := mini(gx * STEP, n - 1)
			var pz := mini(gz * STEP, n - 1)
			var i := pz * n + px
			var y := heights[i]
			var color: Color = block_colors.get(surface[i * 3], Color.MAGENTA)
			if water[i] > y + 0.25:
				y = water[i]
				color = water_color
			else:
				var tree: int = surface[i * 3 + 2]
				if (tree & 63) >= CANOPY_MIN_DENSITY:
					y += CANOPY_VOXELS
					color = pine if (tree >> 6) == 2 else leaves
			var world_x := (float(px) * vpp - IslandGenerator.MAP_HALF) * voxel_size
			var world_z := (float(pz) * vpp - IslandGenerator.MAP_HALF) * voxel_size
			vertices[gz * side + gx] = Vector3(world_x, y * voxel_size - SINK, world_z)
			colors[gz * side + gx] = color

	# Normales a partir de las alturas vecinas (para que el relieve se ilumine bien).
	var cell_size := float(STEP) * vpp * voxel_size
	for gz in side:
		for gx in side:
			var left := vertices[gz * side + maxi(gx - 1, 0)].y
			var right := vertices[gz * side + mini(gx + 1, side - 1)].y
			var up := vertices[maxi(gz - 1, 0) * side + gx].y
			var down := vertices[mini(gz + 1, side - 1) * side + gx].y
			normals[gz * side + gx] = Vector3(left - right, 2.0 * cell_size, up - down).normalized()

	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var k := 0
	for gz in cells:
		for gx in cells:
			var a := gz * side + gx
			var b := a + 1
			var c := a + side
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh

	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/far_terrain.gdshader")
	material.set_shader_parameter("hide_radius", hide_radius)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
